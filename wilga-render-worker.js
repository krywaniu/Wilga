// wilga-render-worker.js  (ES5 + optional Pixel Art upscale)

// === PODSTAWOWE ZMIENNE ===
var canvas = null;
var ctx     = null;

var gradients    = {};
var textures     = {};
var loadedFonts  = {};

// === PIXEL ART – KONFIGURACJA ===
//
// Domyślnie wyłączone (żeby nic nie psuć).
// Jeśli chcesz mieć pixel-art zawsze włączony, ustaw tu na true.
var pixelArtEnabledDefault = false;

// Startowe wartości "logicznej" rozdzielczości pixel-artu.
// Możesz spokojnie zmienić na np. 160x90, 120x68 itd.
var pixelWidthDefault  = 600;
var pixelHeightDefault = 600;

// Aktualny stan (można zmieniać w runtime przez komunikat 'setPixelArt')
var pixelArtEnabled = pixelArtEnabledDefault;
var pixelWidth      = pixelWidthDefault;
var pixelHeight     = pixelHeightDefault;

// Bufor pełnej rozdzielczości (render 1:1)
var fullCanvas = null;
var fullCtx    = null;

// Bufor pixel-art (mała rozdzielczość)
var pixelCanvas = null;
var pixelCtx    = null;


// === POMOCNICZE FUNKCJE ===
function trackSaveRestore(curCtx, fnName) {
  if (!curCtx) return;
  if (curCtx.__wilgaSaveDepth == null) curCtx.__wilgaSaveDepth = 0;

  if (fnName === 'save') {
    curCtx.__wilgaSaveDepth++;
  } else if (fnName === 'restore') {
    curCtx.__wilgaSaveDepth = Math.max(0, curCtx.__wilgaSaveDepth - 1);
  }
}

function unwindContextState(curCtx) {
  if (!curCtx || curCtx.__wilgaSaveDepth == null) return;

  while (curCtx.__wilgaSaveDepth > 0) {
    try { curCtx.restore(); } catch (e) { break; }
    curCtx.__wilgaSaveDepth--;
  }
}

function decodeStyle(v) {
  if (v && v.__wilgaGradient) {
    return gradients[v.__wilgaGradient] || 'black';
  }
  return v;
}

function ensureFullCanvas() {
  if (!canvas) return;

  if (typeof OffscreenCanvas !== 'function') {
    // Fallback: środowisko nie wspiera OffscreenCanvas
    fullCanvas = null;
    fullCtx = null;
    return;
  }

  if (!fullCanvas ||
      fullCanvas.width  !== canvas.width ||
      fullCanvas.height !== canvas.height) {

    fullCanvas = new OffscreenCanvas(canvas.width, canvas.height);
    fullCtx = fullCanvas.getContext('2d');
    if (fullCtx) {
      fullCtx.__wilgaSaveDepth = 0;
      fullCtx.imageSmoothingEnabled = false;
    }
  }
}

function ensurePixelCanvas() {
  if (!pixelArtEnabled) return;
  if (typeof OffscreenCanvas !== 'function') {
    // Nie wspieramy pixel-artu bez OffscreenCanvas
    pixelArtEnabled = false;
    pixelCanvas = null;
    pixelCtx = null;
    return;
  }

  if (!pixelCanvas ||
      pixelCanvas.width  !== pixelWidth ||
      pixelCanvas.height !== pixelHeight) {

    pixelCanvas = new OffscreenCanvas(pixelWidth, pixelHeight);
    pixelCtx = pixelCanvas.getContext('2d');
    if (pixelCtx) {
      pixelCtx.__wilgaSaveDepth = 0;
      pixelCtx.imageSmoothingEnabled = false;
    }
  }
}


// Wspólna funkcja – wykonuje pojedyncze polecenie na AKTUALNYM ctx
function applyCommand(cmd) {
  if (!ctx || !cmd || !cmd.m) return;

  switch (cmd.m) {
    // ===== settery =====
    case 'setFillStyle':
      ctx.fillStyle = decodeStyle(cmd.v);
      break;
    case 'setStrokeStyle':
      ctx.strokeStyle = decodeStyle(cmd.v);
      break;
    case 'setShadowColor':
      ctx.shadowColor = cmd.v;
      break;
    case 'setShadowBlur':
      ctx.shadowBlur = cmd.v;
      break;
    case 'setFont':
      ctx.font = cmd.v;
      break;
    case 'setLineWidth':
      ctx.lineWidth = cmd.v;
      break;
    case 'setLineJoin':
      ctx.lineJoin = cmd.v;
      break;
    case 'setLineCap':
      ctx.lineCap = cmd.v;
      break;
    case 'setTextAlign':
      ctx.textAlign = cmd.v;
      break;
    case 'setTextBaseline':
      ctx.textBaseline = cmd.v;
      break;

    case 'setGlobalAlpha':
      ctx.globalAlpha = cmd.v;
      break;
    case 'setGlobalCompositeOperation':
      ctx.globalCompositeOperation = cmd.v;
      break;
    case 'setImageSmoothingEnabled':
      ctx.imageSmoothingEnabled = !!cmd.v;
      break;

    // ===== gradienty =====
    case 'createLinearGradient':
      gradients[cmd.id] = ctx.createLinearGradient(cmd.x0, cmd.y0, cmd.x1, cmd.y1);
      break;

    case 'createRadialGradient':
      gradients[cmd.id] = ctx.createRadialGradient(
        cmd.x0, cmd.y0, cmd.r0,
        cmd.x1, cmd.y1, cmd.r1
      );
      break;

    case 'gradientAddColorStop':
      var g = gradients[cmd.id];
      if (g) {
        g.addColorStop(cmd.offset, cmd.color);
      }
      break;

    // ===== tekstury =====
    case 'drawImage':
      var tex = textures[cmd.texId];
      if (!tex) break;
      var a = cmd.a || [];
      ctx.drawImage.apply(ctx, [tex].concat(a));
      break;
    // ===== bufor pikseli (ImageData w ramach frame) =====
 case 'putImageData':
  if (!ctx) break;
  if (!cmd.buffer ||
      typeof cmd.width  !== 'number' ||
      typeof cmd.height !== 'number') {
    break;
  }

  try {
    var buf = cmd.buffer;
    if (!(buf instanceof Uint8ClampedArray)) {
      buf = new Uint8ClampedArray(buf);
    }

    var imgData = new ImageData(buf, cmd.width, cmd.height);

    // jeśli mamy OffscreenCanvas – zrób z ImageData teksturę i narysuj ją drawImage
    if (typeof OffscreenCanvas === 'function') {
      var tmp = new OffscreenCanvas(cmd.width, cmd.height);
      var tctx = tmp.getContext('2d');
      tctx.putImageData(imgData, 0, 0);

      // I TERAZ: drawImage — tutaj działa alpha-blending
      ctx.drawImage(tmp, cmd.x || 0, cmd.y || 0);
    } else {
      // fallback – jak wcześniej, bez blendu
      ctx.putImageData(imgData, cmd.x || 0, cmd.y || 0);
    }
  } catch (e) {
    // można zostawić prosty fallback albo zignorować
  }

  break;


case 'call':
  var fn = ctx[cmd.fn];
  if (typeof fn === 'function') {

    // śledzimy głębokość save/restore (żeby móc unwind na początku frame)
    if (cmd.fn === 'save' || cmd.fn === 'restore') {
      trackSaveRestore(ctx, cmd.fn);
    }

    fn.apply(ctx, cmd.a || []);
  }
  break;
} // <-- zamyka switch(cmd.m)
} // <-- zamyka function applyCommand(cmd)






// === GŁÓWNY HANDLER WIADOMOŚCI ===
self.onmessage = function (e) {
  var data = e.data;
  if (!data || !data.type) return;

  switch (data.type) {

    // inicjalizacja canvasu
    case 'initCanvas':
      canvas = data.canvas;
      ctx = canvas.getContext('2d');
      ctx.__wilgaSaveDepth = 0;

      ensureFullCanvas();
      ensurePixelCanvas();
      break;

    // zmiana rozmiaru
    case 'resize':
      if (canvas) {
        canvas.width  = data.width;
        canvas.height = data.height;

        if (ctx) {
          ctx.setTransform(1, 0, 0, 1, 0, 0);
          ctx.clearRect(0, 0, canvas.width, canvas.height);
        }

        ensureFullCanvas();
        ensurePixelCanvas();
      }
      break;

    // rejestracja tekstury (ImageBitmap)
    case 'registerTexture':
      textures[data.id] = data.bitmap;
      break;
      
    case 'unregisterTexture':
      if (textures[data.id]) {
        delete textures[data.id];
      }
      break;

    // ===== WŁĄCZANIE / KONFIGURACJA PIXEL-ARTU Z ZEWNĄTRZ =====
    //
    // Możesz z Wilgi (Pascal → JS) wysłać:
    //
    //   postMessage({
    //     type: 'setPixelArt',
    //     enabled: true,
    //     width: 60,
    //     height: 120
    //   });
    //
    case 'setPixelArt':
      pixelArtEnabled = !!data.enabled;
      if (typeof data.width === 'number' && data.width > 0) {
        pixelWidth = data.width;
      }
      if (typeof data.height === 'number' && data.height > 0) {
        pixelHeight = data.height;
      }
      ensurePixelCanvas();
      break;


    // ===== RYSOWANIE RAMKI =====
    case 'frame':
      if (!ctx) return;
      var cmds = data.cmds || [];

      // tryb normalny — bez pixel-artu, pełna zgodność wstecz
// tryb normalny — bez pixel-artu, pełna zgodność wstecz
if (!pixelArtEnabled) {

  // ★ resetuje clip/save-stack z poprzedniej klatki
  unwindContextState(ctx);

  ctx.setTransform(1,0,0,1,0,0);
  ctx.clearRect(0, 0, canvas.width, canvas.height);  // ★★★ NAPRAWA DUCHÓW ★★★

  for (var i = 0; i < cmds.length; i++) {
    applyCommand(cmds[i]);
  }
  break;
}


      // tryb pixel-art
      ensureFullCanvas();
      ensurePixelCanvas();

      // jeśli z jakiegoś powodu nie mamy buforów, robimy fallback
      if (!fullCtx || !pixelCtx) {
        for (var j = 0; j < cmds.length; j++) {
          applyCommand(cmds[j]);
        }
        break;
      }

      // 1) rysujemy całą scenę w pełnej rozdzielczości do fullCanvas
      var oldCtx = ctx;
      ctx = fullCtx;

unwindContextState(fullCtx);

      fullCtx.setTransform(1, 0, 0, 1, 0, 0);
      fullCtx.clearRect(0, 0, fullCanvas.width, fullCanvas.height);

      for (var k = 0; k < cmds.length; k++) {
        applyCommand(cmds[k]);
      }

      ctx = oldCtx;

      // 2) downscale do malego pixelCanvas
      pixelCtx.setTransform(1, 0, 0, 1, 0, 0);
      pixelCtx.clearRect(0, 0, pixelWidth, pixelHeight);
      pixelCtx.drawImage(
        fullCanvas,
        0, 0, fullCanvas.width, fullCanvas.height,
        0, 0, pixelWidth, pixelHeight
      );

      // 3) upscale z pixelCanvas na ekran bez wygładzania
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      ctx.imageSmoothingEnabled = false;
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      ctx.drawImage(
        pixelCanvas,
        0, 0, pixelWidth, pixelHeight,
        0, 0, canvas.width, canvas.height
      );

      break;

    // ===== rysowanie z bufora pikseli (ImageData) =====
    //
    // oczekuje:
    // {
    //   type:  'putImageData',
    //   x:     <number>,
    //   y:     <number>,
    //   width: <number>,
    //   height:<number>,
    //   buffer: Uint8ClampedArray  // RGBA, length = width*height*4
    // }
    //
    

    // ===== stare pojedyncze wiadomości – zostawione na wszelki wypadek =====
    case 'call':
      if (!ctx) return;
      var fn = ctx[data.method];
      if (typeof fn === 'function') {
        fn.apply(ctx, data.args || []);
      }
      break;

    case 'loadFont':
      // HARD MODE: ładowanie fontu wewnątrz workera
      if (!data.family || !data.url) break;

      var key = data.family + '|' + data.url;
      if (loadedFonts[key]) break; // już ładowaliśmy
      loadedFonts[key] = true;

      // Sprawdzamy, czy środowisko wspiera FontFace w workerze
      if (typeof FontFace === 'function' && self.fonts && self.fonts.add) {
        (function (family, url) {
          try {
            var face = new FontFace(family, 'url(' + url + ')');
            face.load().then(function (loadedFace) {
              try {
                self.fonts.add(loadedFace);
              } catch (e) {
                // ignore
              }
            }).catch(function () {
              // ignore
            });
          } catch (e) {
            // ignore
          }
        })(data.family, data.url);
      }
      break;
  }
};
