/*
 * Aura promo kit: deterministic helpers shared by every composition.
 *
 * Nothing here reads a clock or unseeded randomness. Canvas layers are pure
 * functions of composition time, so any frame renders identically whatever
 * order the renderer seeks in.
 */
(function () {
  "use strict";

  const C = {
    ink: "#10171C",
    sky: "#97CFF3",
    mint: "#A7E8D1",
    peri: "#BEC6F7",
    teal: "#7FD6C0",
    deep: "#1C6E5A",
  };

  const clamp = (v, lo = 0, hi = 1) => (v < lo ? lo : v > hi ? hi : v);
  const lerp = (a, b, t) => a + (b - a) * t;
  const smoothstep = (e0, e1, x) => {
    const t = clamp((x - e0) / (e1 - e0));
    return t * t * (3 - 2 * t);
  };

  /** mulberry32: a seeded stream for layouts built once at setup. */
  function rng(seed) {
    let a = seed >>> 0;
    return function () {
      a = (a + 0x6d2b79f5) >>> 0;
      let t = a;
      t = Math.imul(t ^ (t >>> 15), t | 1);
      t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  /** Stateless integer hash in [0, 1), for per-frame values such as grain. */
  function hash(i, j = 0) {
    let n = (Math.imul(i | 0, 374761393) + Math.imul(j | 0, 668265263)) | 0;
    n = Math.imul(n ^ (n >>> 13), 1274126177);
    return ((n ^ (n >>> 16)) >>> 0) / 4294967296;
  }

  const easeCache = Object.create(null);
  const ease = (name = "none") => easeCache[name] || (easeCache[name] = gsap.parseEase(name));

  /**
   * Keyframed value: keys are [time, value, easeIntoThisKey]. Holds the first
   * value before the first key and the last value after the last one.
   */
  function track(keys, t) {
    if (t <= keys[0][0]) return keys[0][1];
    for (let i = 1; i < keys.length; i++) {
      const k = keys[i];
      if (t <= k[0]) {
        const p = keys[i - 1];
        const u = k[0] === p[0] ? 1 : ease(k[2])((t - p[0]) / (k[0] - p[0]));
        return p[1] + (k[1] - p[1]) * u;
      }
    }
    return keys[keys.length - 1][1];
  }

  const bez = (a, b, c, d, t) => {
    const u = 1 - t;
    return u * u * u * a + 3 * u * u * t * b + 3 * u * t * t * c + t * t * t * d;
  };

  const peso = (v) =>
    "₱" + v.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 });

  /** Converts root (global) seconds to a composition's local timeline. */
  const at = (start) => (g) => Math.round((g - start) * 1e4) / 1e4;

  /**
   * Drives draw(localTime) from a timeline with one linear proxy tween, the
   * HyperFrames pattern for canvas layers. draw must be a pure function of t.
   */
  function clock(tl, duration, draw) {
    const p = { t: 0 };
    tl.fromTo(p, { t: 0 }, { t: duration, duration, ease: "none", onUpdate: () => draw(p.t) }, 0);
    draw(0);
  }

  function rgba(hex, a) {
    const n = parseInt(hex.slice(1), 16);
    return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${a})`;
  }

  function roundRect(ctx, x, y, w, h, r) {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }

  /* ---------- assets every painter needs ---------- */

  const visa = new Image();
  visa.src = "assets/brand/visa.webp";
  const ready = Promise.all([
    ...["400", "500", "600", "700"].map((w) => document.fonts.load(`${w} 40px "Onest"`, "Aura ₱0123456789")),
    visa.decode().catch(() => undefined),
  ]).then(() => document.fonts.ready);

  /* ---------- the Aura card, painted the way aura_card.dart paints it ---------- */

  const COLOURWAYS = {
    sky: { ribbon: [C.sky, C.mint], bloom: [C.sky, C.mint] },
    mint: { ribbon: [C.mint, C.teal], bloom: ["#6FC7B0", C.mint] },
    peri: { ribbon: [C.peri, C.sky], bloom: [C.peri, C.sky] },
  };

  /** The ribbon that crosses every card, in card space. */
  function ribbonPath(ctx, w, h) {
    ctx.beginPath();
    ctx.moveTo(w * 0.7, -h * 0.08);
    ctx.bezierCurveTo(w * 0.64, h * 0.16, w * 0.9, h * 0.2, w * 0.84, h * 0.4);
    ctx.bezierCurveTo(w * 0.79, h * 0.56, w * 0.94, h * 0.64, w * 1.06, h * 0.5);
  }

  /** The Aura mark on a 64-unit grid: arch plus ribbon (aura_logo.dart). */
  function drawMark(ctx, x, y, size) {
    const u = size / 64;
    ctx.save();
    ctx.translate(x, y);
    ctx.lineCap = "round";
    const g = ctx.createLinearGradient(18 * u, 15 * u, 46 * u, 48 * u);
    g.addColorStop(0, C.sky);
    g.addColorStop(1, C.mint);
    ctx.beginPath();
    ctx.moveTo(18 * u, 48 * u);
    ctx.bezierCurveTo(18 * u, 29 * u, 24.5 * u, 15 * u, 32 * u, 15 * u);
    ctx.bezierCurveTo(39.5 * u, 15 * u, 46 * u, 29 * u, 46 * u, 48 * u);
    ctx.lineWidth = 6.4 * u;
    ctx.strokeStyle = g;
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(22.5 * u, 37 * u);
    ctx.bezierCurveTo(26.5 * u, 33 * u, 29.5 * u, 33 * u, 32 * u, 35.5 * u);
    ctx.bezierCurveTo(34.5 * u, 38 * u, 37.5 * u, 38 * u, 41.5 * u, 34 * u);
    ctx.lineWidth = 3.6 * u;
    ctx.strokeStyle = "rgba(255,255,255,.94)";
    ctx.stroke();
    ctx.restore();
  }

  function drawContactless(ctx, cx, cy, size) {
    ctx.save();
    ctx.strokeStyle = "rgba(255,255,255,.85)";
    ctx.lineCap = "round";
    ctx.lineWidth = size * 0.085;
    for (let i = 0; i < 4; i++) {
      const r = size * (0.14 + i * 0.12);
      ctx.beginPath();
      ctx.arc(cx - size * 0.24, cy, r, -0.78, 0.78);
      ctx.stroke();
    }
    ctx.restore();
  }

  function drawNetwork(ctx, network, x, y, mw) {
    const mh = mw / 1.55;
    if (network === "mastercard") {
      const r = mh / 2;
      ctx.save();
      ctx.fillStyle = "#EB001B";
      ctx.beginPath();
      ctx.arc(x + r, y + r, r, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "#F79E1B";
      ctx.beginPath();
      ctx.arc(x + mw - r, y + r, r, 0, Math.PI * 2);
      ctx.fill();
      ctx.beginPath();
      ctx.arc(x + r, y + r, r, 0, Math.PI * 2);
      ctx.clip();
      ctx.fillStyle = "#FF5F00";
      ctx.beginPath();
      ctx.arc(x + mw - r, y + r, r, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();
      return;
    }
    ctx.save();
    ctx.fillStyle = "#fff";
    roundRect(ctx, x, y, mw, mh, mw * 0.1);
    ctx.fill();
    if (visa.complete && visa.naturalWidth) {
      const iw = mw * 0.76;
      const ih = Math.min(mh * 0.8, iw / (visa.naturalWidth / visa.naturalHeight));
      ctx.drawImage(visa, x + (mw - iw) / 2, y + (mh - ih) / 2, iw, ih);
    }
    ctx.restore();
  }

  function text(ctx, str, x, y, size, weight, color, spacing = 0, align = "left") {
    ctx.font = `${weight} ${size}px "Onest"`;
    ctx.letterSpacing = `${spacing}px`;
    ctx.fillStyle = color;
    ctx.textAlign = align;
    ctx.textBaseline = "alphabetic";
    ctx.fillText(str, x, y);
  }

  function paintStock(ctx, w, h, cw, ribbon) {
    ctx.fillStyle = C.ink;
    ctx.fillRect(0, 0, w, h);
    // Horizon bloom off the lower left, as the aurora sits low on the sky.
    const g = ctx.createRadialGradient(w * 0.025, h * 1.125, 0, w * 0.025, h * 1.125, h * 1.05);
    g.addColorStop(0, rgba(cw.bloom[0], 0.85));
    g.addColorStop(0.42, rgba(cw.bloom[1], 0.32));
    g.addColorStop(1, rgba(cw.bloom[1], 0));
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, w, h);
    if (ribbon) {
      ribbonPath(ctx, w, h);
      const rg = ctx.createLinearGradient(w * 0.5, 0, w, h);
      rg.addColorStop(0, cw.ribbon[0]);
      rg.addColorStop(1, cw.ribbon[1]);
      ctx.lineWidth = w * 0.034;
      ctx.lineCap = "round";
      ctx.strokeStyle = rg;
      ctx.stroke();
    }
  }

  /**
   * Front of a card. o: { last4, holder, network, balance, colourway, edge }.
   * With a balance it is the wallet face; without one, the physical face.
   */
  function drawCardFace(ctx, w, h, o) {
    const cw = COLOURWAYS[o.colourway || "sky"];
    const pad = w * 0.065;
    const onInk = "rgba(255,255,255,.62)";
    ctx.save();
    roundRect(ctx, 0, 0, w, h, w * 0.055);
    ctx.clip();
    paintStock(ctx, w, h, cw, true);
    if (o.edge !== false) {
      roundRect(ctx, 0.5, 0.5, w - 1, h - 1, w * 0.055);
      ctx.lineWidth = Math.max(1, w * 0.003);
      ctx.strokeStyle = "rgba(255,255,255,.10)";
      ctx.stroke();
    }
    if (o.balance) {
      text(ctx, "Balance", pad, pad + w * 0.049, w * 0.04, 500, onInk);
      if (o.balance !== true) text(ctx, o.balance, pad, pad + w * 0.173, w * 0.092, 600, "#fff", -w * 0.0017);
    } else {
      drawMark(ctx, pad - w * 0.012, pad - w * 0.006, w * 0.1);
    }
    drawContactless(ctx, w - pad - w * 0.03, pad + w * 0.035, w * 0.07);
    const mw = w * 0.15;
    const mh = mw / 1.55;
    text(ctx, `••••  ${o.last4}`, pad, h - pad - mh - w * 0.022, w * 0.045, 400, "rgba(255,255,255,.86)", w * 0.0033);
    text(ctx, o.holder, pad, h - pad - w * 0.01, w * 0.04, 500, onInk);
    drawNetwork(ctx, o.network, w - pad - mw, h - pad - mh, mw);
    ctx.restore();
  }

  /** Back of a card: stripe, masked number, expiry. Never a real PAN or CVV. */
  function drawCardBack(ctx, w, h, o) {
    const cw = COLOURWAYS[o.colourway || "sky"];
    const pad = w * 0.065;
    const label = "rgba(255,255,255,.56)";
    ctx.save();
    roundRect(ctx, 0, 0, w, h, w * 0.055);
    ctx.clip();
    paintStock(ctx, w, h, cw, false);
    ctx.fillStyle = "rgba(0,0,0,.55)";
    ctx.fillRect(0, pad * 0.8, w, w * 0.13);
    const y0 = pad * 0.8 + w * 0.13 + pad * 0.8;
    text(ctx, "CARD NUMBER", pad, y0 + w * 0.03, w * 0.032, 400, label, w * 0.0025);
    text(ctx, `4026  ••••  ••••  ${o.last4}`, pad, y0 + w * 0.1, w * 0.055, 500, "#fff", w * 0.004);
    const mw = w * 0.15;
    const mh = mw / 1.55;
    text(ctx, "EXPIRES", pad, h - pad - w * 0.075, w * 0.032, 400, label, w * 0.0025);
    text(ctx, "09/29", pad, h - pad - w * 0.012, w * 0.055, 500, "#fff");
    text(ctx, "CVV", pad + w * 0.24, h - pad - w * 0.075, w * 0.032, 400, label, w * 0.0025);
    text(ctx, "•••", pad + w * 0.24, h - pad - w * 0.012, w * 0.055, 500, "#fff");
    drawNetwork(ctx, o.network, w - pad - mw, h - pad - mh, mw);
    ctx.restore();
  }

  /** Paints a card face into a <canvas> sized in CSS pixels at 2x density. */
  function paintCardCanvas(canvas, o) {
    const w = canvas.width;
    const h = canvas.height;
    const ctx = canvas.getContext("2d");
    ctx.clearRect(0, 0, w, h);
    drawCardFace(ctx, w, h, o);
  }

  window.AuraKit = {
    C,
    clamp,
    lerp,
    smoothstep,
    rng,
    hash,
    ease,
    track,
    bez,
    peso,
    at,
    clock,
    rgba,
    roundRect,
    ready,
    ribbonPath,
    drawMark,
    drawCardFace,
    drawCardBack,
    paintCardCanvas,
    CARD_ASPECT: 85.6 / 53.98,
    /* The moment the wallet card leaves the phone. s2 holds the phone at this
       pose; card3d starts the 3D card exactly over the DOM card. */
    HANDOFF: {
      t: 4.82,
      phone: { cx: 1400, cy: 540, perspective: 1800, rotX: 3, rotY: -9 },
      card: { dx: 0, dy: -191.5, w: 370 }, // card centre relative to the phone centre, CSS px
    },
  };
})();
