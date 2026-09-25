// Animated sprite previews, drawn from the mod's own sprite sheets.
//
// Grid sheets (the transformation forms), one animation per row:
//   <div class="sprite-stage" data-src="img/ChainsawDevilSheet.png" data-cw="94" data-ch="58"
//        data-scale="3" data-anims='[["Idle",0,6],["Walk",1,8]]'></div>
//   Each anim is [label, row, frame count]. Buttons to switch between them are added when there is more than one.
//
// Vertical strips (NPCs and pets), frames stacked top to bottom:
//   <div class="sprite-stage" data-src="img/BatDevil.png" data-frames="4" data-scale="2"></div>
//   Add data-anims='[["Walk",5,6]]' (label, first frame, frame count) to play only part of a strip.
(function () {
  "use strict";

  var reduceMotion = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  function setup(stage) {
    var img = new Image();
    img.onload = function () { start(stage, img); };
    img.src = stage.dataset.src;
  }

  function start(stage, img) {
    var scale = parseFloat(stage.dataset.scale || "2");
    var fps = parseFloat(stage.dataset.fps || "8");
    var anims, cw, ch;

    var strip = !!stage.dataset.frames;

    if (strip) {
      var frames = parseInt(stage.dataset.frames, 10);
      cw = img.naturalWidth;
      ch = Math.floor(img.naturalHeight / frames);
      anims = stage.dataset.anims ? JSON.parse(stage.dataset.anims) : [["", 0, frames]];
    } else {
      anims = JSON.parse(stage.dataset.anims);
      cw = parseInt(stage.dataset.cw, 10);
      ch = parseInt(stage.dataset.ch, 10);
    }

    var canvas = document.createElement("canvas");
    canvas.width = Math.round(cw * scale);
    canvas.height = Math.round(ch * scale);
    canvas.setAttribute("role", "img");
    canvas.setAttribute("aria-label", stage.dataset.label || "Animated sprite");
    stage.prepend(canvas);

    var ctx = canvas.getContext("2d");
    var current = 0;
    var frame = 0;

    function draw() {
      var anim = anims[current];
      var sx, sy;
      if (strip) {
        sx = 0;
        sy = (anim[1] + frame) * ch;
      } else {
        sx = frame * cw;
        sy = anim[1] * ch;
      }
      ctx.imageSmoothingEnabled = false;
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      ctx.drawImage(img, sx, sy, cw, ch, 0, 0, canvas.width, canvas.height);
    }

    if (anims.length > 1) {
      var bar = document.createElement("div");
      bar.className = "anim-buttons";
      anims.forEach(function (anim, i) {
        var b = document.createElement("button");
        b.type = "button";
        b.textContent = anim[0];
        b.setAttribute("aria-pressed", i === 0 ? "true" : "false");
        b.addEventListener("click", function () {
          current = i;
          frame = 0;
          bar.querySelectorAll("button").forEach(function (other, j) {
            other.setAttribute("aria-pressed", j === i ? "true" : "false");
          });
          draw();
        });
        bar.appendChild(b);
      });
      canvas.after(bar);
    }

    draw();
    if (reduceMotion) return;

    setInterval(function () {
      frame = (frame + 1) % anims[current][2];
      draw();
    }, 1000 / fps);
  }

  document.querySelectorAll(".sprite-stage[data-src]").forEach(setup);
})();
