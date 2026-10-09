// Synthesizes the AuraBank promo music bed (15s, 120 BPM, D major) with an
// OfflineAudioContext inside headless Chrome, then writes a 48 kHz stereo WAV.
// Section cuts are locked to the video: 2.5 / 5.5 / 8.5 / 12.0 s.
// Usage: node gen-music.mjs <out.wav>
import puppeteer from "puppeteer-core";
import { writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { homedir } from "node:os";

const out = resolve(process.argv[2] ?? "../aurabank-promo/assets/music/aura-bed.wav");
const chrome =
  process.env.CHROME_PATH ??
  `${homedir()}\\.cache\\puppeteer\\chrome-headless-shell\\win64-152.0.7977.42\\chrome-headless-shell-win64\\chrome-headless-shell.exe`;

async function synth() {
  const SR = 48000;
  const DUR = 15.0;
  const ctx = new OfflineAudioContext(2, Math.round(SR * DUR), SR);

  // Seeded PRNG so every render of the bed is identical.
  let seed = 1337;
  const rnd = () => ((seed = (seed * 1664525 + 1013904223) >>> 0) / 4294967296);
  const mtof = (m) => 440 * Math.pow(2, (m - 69) / 12);

  const noiseBuf = (secs) => {
    const b = ctx.createBuffer(1, Math.round(SR * secs), SR);
    const d = b.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = rnd() * 2 - 1;
    return b;
  };
  const NOISE = noiseBuf(3);

  // ---------- master bus ----------
  const master = ctx.createGain();
  master.gain.value = 0.9;
  const comp = ctx.createDynamicsCompressor();
  comp.threshold.value = -16;
  comp.ratio.value = 3;
  comp.attack.value = 0.006;
  comp.release.value = 0.18;
  comp.knee.value = 8;
  const shaper = ctx.createWaveShaper();
  const curve = new Float32Array(2048);
  for (let i = 0; i < curve.length; i++) {
    const x = (i / (curve.length - 1)) * 2 - 1;
    curve[i] = Math.tanh(1.2 * x) / Math.tanh(1.2);
  }
  shaper.curve = curve;
  const fadeOut = ctx.createGain();
  fadeOut.gain.setValueAtTime(1, 0);
  fadeOut.gain.setValueAtTime(1, 13.6);
  fadeOut.gain.linearRampToValueAtTime(0.55, 14.4);
  fadeOut.gain.linearRampToValueAtTime(0.0, 14.98);
  master.connect(comp).connect(shaper).connect(fadeOut).connect(ctx.destination);

  // ---------- reverb ----------
  const ir = ctx.createBuffer(2, Math.round(SR * 3.2), SR);
  for (let c = 0; c < 2; c++) {
    const d = ir.getChannelData(c);
    for (let i = 0; i < d.length; i++) {
      const t = i / SR;
      d[i] = (rnd() * 2 - 1) * Math.exp(-t * 2.4) * (t < 0.015 ? t / 0.015 : 1);
    }
  }
  const verb = ctx.createConvolver();
  verb.buffer = ir;
  const verbIn = ctx.createGain();
  verbIn.gain.value = 1;
  const verbHP = ctx.createBiquadFilter();
  verbHP.type = "highpass";
  verbHP.frequency.value = 280;
  const verbOut = ctx.createGain();
  verbOut.gain.value = 0.42;
  verbIn.connect(verbHP).connect(verb).connect(verbOut).connect(master);

  // ---------- ping-pong delay (dotted 8th) ----------
  const dIn = ctx.createGain();
  const dl = ctx.createDelay(2);
  const dr = ctx.createDelay(2);
  dl.delayTime.value = 0.375;
  dr.delayTime.value = 0.375;
  const fb = ctx.createGain();
  fb.gain.value = 0.38;
  const dLP = ctx.createBiquadFilter();
  dLP.type = "lowpass";
  dLP.frequency.value = 3800;
  const merge = ctx.createChannelMerger(2);
  const dOut = ctx.createGain();
  dOut.gain.value = 0.5;
  dIn.connect(dl);
  dl.connect(merge, 0, 0);
  dl.connect(dr);
  dr.connect(merge, 0, 1);
  dr.connect(dLP).connect(fb).connect(dl);
  merge.connect(dOut).connect(master);
  dOut.connect(verbIn);

  // ---------- sidechain pump (applied to pad + bass during the groove) ----------
  const pump = ctx.createGain();
  pump.gain.setValueAtTime(1, 0);
  const kickTimes = [];
  for (let t = 2.5; t < 11.5 - 1e-6; t += 0.5) {
    const half = t < 5.5; // half-time feel in the mobile section
    if (!half || Math.abs(((t - 2.5) / 0.5) % 2) < 1e-6) kickTimes.push(+t.toFixed(3));
  }
  for (const t of kickTimes) {
    pump.gain.setValueAtTime(1, t - 0.002);
    pump.gain.linearRampToValueAtTime(0.42, t + 0.012);
    pump.gain.setTargetAtTime(1, t + 0.04, 0.09);
  }
  pump.connect(master);
  const pumpVerb = ctx.createGain();
  pumpVerb.gain.value = 0.55;
  pump.connect(pumpVerb).connect(verbIn);

  // ---------- pad ----------
  const padBus = ctx.createGain();
  padBus.gain.value = 0.11;
  const padLP = ctx.createBiquadFilter();
  padLP.type = "lowpass";
  padLP.Q.value = 0.6;
  padLP.frequency.setValueAtTime(380, 0);
  padLP.frequency.exponentialRampToValueAtTime(2600, 2.4);
  padLP.frequency.setValueAtTime(2600, 2.5);
  padLP.frequency.linearRampToValueAtTime(3200, 8.5);
  padLP.frequency.linearRampToValueAtTime(4200, 11.9);
  padLP.frequency.setValueAtTime(5200, 12.0);
  padLP.frequency.exponentialRampToValueAtTime(1800, 15);
  padBus.connect(padLP).connect(pump);

  const chords = [
    { t0: 0.0, t1: 2.5, notes: [50, 57, 61, 64, 66, 73], bass: 38 },
    { t0: 2.5, t1: 5.5, notes: [50, 57, 62, 64, 66, 69], bass: 38 },
    { t0: 5.5, t1: 8.5, notes: [54, 59, 62, 66, 69, 71], bass: 35 },
    { t0: 8.5, t1: 10.5, notes: [55, 59, 62, 66, 67, 71], bass: 31 },
    { t0: 10.5, t1: 12.0, notes: [57, 61, 64, 69, 71, 73], bass: 33 },
    { t0: 12.0, t1: 15.0, notes: [50, 57, 61, 64, 66, 69, 73, 76], bass: 26 },
  ];

  function padNote(m, t0, t1, pan, atk) {
    const g = ctx.createGain();
    g.gain.setValueAtTime(0, t0);
    g.gain.linearRampToValueAtTime(1, t0 + atk);
    g.gain.setValueAtTime(1, Math.max(t0 + atk, t1 - 0.25));
    g.gain.linearRampToValueAtTime(0, t1 + 0.35);
    const p = ctx.createStereoPanner();
    p.pan.value = pan;
    g.connect(p).connect(padBus);
    for (const det of [-9, -3, 4, 10]) {
      const o = ctx.createOscillator();
      o.type = "sawtooth";
      o.frequency.value = mtof(m);
      o.detune.value = det;
      const og = ctx.createGain();
      og.gain.value = 0.25;
      o.connect(og).connect(g);
      o.start(t0);
      o.stop(t1 + 0.4);
    }
  }
  chords.forEach((c, ci) => {
    c.notes.forEach((m, i) => {
      const pan = ((i / (c.notes.length - 1)) * 2 - 1) * 0.6;
      padNote(m, c.t0, c.t1, pan, ci === 0 ? 1.6 : ci === 5 ? 0.04 : 0.12);
    });
  });

  // ---------- bass (8th pulses) ----------
  const bassBus = ctx.createGain();
  bassBus.gain.value = 0.34;
  const bassLP = ctx.createBiquadFilter();
  bassLP.type = "lowpass";
  bassLP.frequency.value = 520;
  bassBus.connect(bassLP).connect(pump);
  for (const c of chords.slice(1, 5)) {
    for (let t = c.t0; t < Math.min(c.t1, 11.5) - 1e-6; t += 0.25) {
      const m = c.bass + 12;
      const g = ctx.createGain();
      g.gain.setValueAtTime(0, t);
      g.gain.linearRampToValueAtTime(1, t + 0.008);
      g.gain.exponentialRampToValueAtTime(0.3, t + 0.2);
      g.gain.linearRampToValueAtTime(0, t + 0.24);
      g.connect(bassBus);
      const o1 = ctx.createOscillator();
      o1.type = "sawtooth";
      o1.frequency.value = mtof(m);
      const o2 = ctx.createOscillator();
      o2.type = "sine";
      o2.frequency.value = mtof(m - 12);
      const g2 = ctx.createGain();
      g2.gain.value = 1.4;
      o1.connect(g);
      o2.connect(g2).connect(g);
      o1.start(t);
      o2.start(t);
      o1.stop(t + 0.26);
      o2.stop(t + 0.26);
    }
  }

  // ---------- arp pluck ----------
  const arpBus = ctx.createGain();
  arpBus.gain.value = 0.09;
  arpBus.connect(master);
  arpBus.connect(dIn);
  const arpVerb = ctx.createGain();
  arpVerb.gain.value = 0.5;
  arpBus.connect(arpVerb).connect(verbIn);
  const pattern = [0, 2, 4, 3, 5, 4, 2, 3];
  let step = 0;
  for (const c of chords.slice(1, 5)) {
    const tones = [...c.notes].sort((a, b) => a - b).map((m) => m + 12);
    for (let t = c.t0; t < Math.min(c.t1, 11.5) - 1e-6; t += 0.125) {
      const m = tones[pattern[step % pattern.length] % tones.length];
      const accent = step % 4 === 0 ? 1 : 0.62;
      step++;
      const o = ctx.createOscillator();
      o.type = "triangle";
      o.frequency.value = mtof(m);
      const o2 = ctx.createOscillator();
      o2.type = "square";
      o2.frequency.value = mtof(m);
      const sq = ctx.createGain();
      sq.gain.value = 0.18;
      const lp = ctx.createBiquadFilter();
      lp.type = "lowpass";
      lp.frequency.setValueAtTime(5200, t);
      lp.frequency.exponentialRampToValueAtTime(900, t + 0.16);
      const g = ctx.createGain();
      g.gain.setValueAtTime(0, t);
      g.gain.linearRampToValueAtTime(accent, t + 0.004);
      g.gain.exponentialRampToValueAtTime(0.001, t + 0.22);
      const p = ctx.createStereoPanner();
      p.pan.value = Math.sin(step * 0.9) * 0.35;
      o.connect(lp);
      o2.connect(sq).connect(lp);
      lp.connect(g).connect(p).connect(arpBus);
      o.start(t);
      o2.start(t);
      o.stop(t + 0.25);
      o2.stop(t + 0.25);
    }
  }

  // ---------- bells (intro logo, finale) ----------
  function bell(m, t, vel, pan) {
    const g = ctx.createGain();
    g.gain.setValueAtTime(0, t);
    g.gain.linearRampToValueAtTime(vel, t + 0.005);
    g.gain.exponentialRampToValueAtTime(0.0008, t + 2.6);
    const p = ctx.createStereoPanner();
    p.pan.value = pan;
    g.connect(p);
    p.connect(master);
    p.connect(dIn);
    p.connect(verbIn);
    [
      [1, 1],
      [2.0, 0.35],
      [3.01, 0.12],
      [4.2, 0.06],
    ].forEach(([ratio, amp]) => {
      const o = ctx.createOscillator();
      o.type = "sine";
      o.frequency.value = mtof(m) * ratio;
      const og = ctx.createGain();
      og.gain.value = amp;
      o.connect(og).connect(g);
      o.start(t);
      o.stop(t + 2.7);
    });
  }
  bell(78, 0.9, 0.09, -0.3);
  bell(81, 1.05, 0.07, 0.3);
  bell(85, 1.2, 0.05, 0.0);
  bell(74, 12.0, 0.1, 0);
  bell(78, 12.12, 0.08, -0.35);
  bell(81, 12.24, 0.07, 0.35);
  bell(86, 12.4, 0.05, 0);

  // ---------- drums ----------
  const drumBus = ctx.createGain();
  drumBus.gain.value = 0.9;
  drumBus.connect(master);

  function kick(t, vel = 1) {
    const o = ctx.createOscillator();
    o.type = "sine";
    o.frequency.setValueAtTime(140, t);
    o.frequency.exponentialRampToValueAtTime(46, t + 0.11);
    const g = ctx.createGain();
    g.gain.setValueAtTime(0, t);
    g.gain.linearRampToValueAtTime(0.95 * vel, t + 0.003);
    g.gain.exponentialRampToValueAtTime(0.001, t + 0.42);
    o.connect(g).connect(drumBus);
    o.start(t);
    o.stop(t + 0.45);
    const n = ctx.createBufferSource();
    n.buffer = NOISE;
    const hp = ctx.createBiquadFilter();
    hp.type = "highpass";
    hp.frequency.value = 2500;
    const ng = ctx.createGain();
    ng.gain.setValueAtTime(0.18 * vel, t);
    ng.gain.exponentialRampToValueAtTime(0.001, t + 0.02);
    n.connect(hp).connect(ng).connect(drumBus);
    n.start(t, rnd() * 2, 0.03);
  }
  function clap(t, vel = 1) {
    const bp = ctx.createBiquadFilter();
    bp.type = "bandpass";
    bp.frequency.value = 1500;
    bp.Q.value = 0.9;
    const g = ctx.createGain();
    g.gain.setValueAtTime(0, t);
    [0, 0.011, 0.022].forEach((o) => {
      g.gain.setValueAtTime(0.55 * vel, t + o);
      g.gain.exponentialRampToValueAtTime(0.08 * vel, t + o + 0.009);
    });
    g.gain.setValueAtTime(0.5 * vel, t + 0.033);
    g.gain.exponentialRampToValueAtTime(0.001, t + 0.22);
    const n = ctx.createBufferSource();
    n.buffer = NOISE;
    n.connect(bp).connect(g);
    g.connect(drumBus);
    const cv = ctx.createGain();
    cv.gain.value = 0.6;
    g.connect(cv).connect(verbIn);
    n.start(t, rnd() * 2, 0.25);
  }
  function hat(t, vel = 1, len = 0.045) {
    const hp = ctx.createBiquadFilter();
    hp.type = "highpass";
    hp.frequency.value = 7800;
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0, t);
    g.gain.linearRampToValueAtTime(0.16 * vel, t + 0.002);
    g.gain.exponentialRampToValueAtTime(0.001, t + len);
    const p = ctx.createStereoPanner();
    p.pan.value = 0.22;
    const n = ctx.createBufferSource();
    n.buffer = NOISE;
    n.connect(hp).connect(g).connect(p).connect(drumBus);
    n.start(t, rnd() * 2, len + 0.01);
  }
  function snare(t, vel) {
    const bp = ctx.createBiquadFilter();
    bp.type = "bandpass";
    bp.frequency.value = 2200;
    bp.Q.value = 0.7;
    const g = ctx.createGain();
    g.gain.setValueAtTime(0, t);
    g.gain.linearRampToValueAtTime(0.42 * vel, t + 0.002);
    g.gain.exponentialRampToValueAtTime(0.001, t + 0.09);
    const n = ctx.createBufferSource();
    n.buffer = NOISE;
    n.connect(bp).connect(g).connect(drumBus);
    const sv = ctx.createGain();
    sv.gain.value = 0.35;
    g.connect(sv).connect(verbIn);
    n.start(t, rnd() * 2, 0.1);
  }

  for (const t of kickTimes) kick(t, t < 5.5 ? 0.85 : 1);
  for (let t = 6.0; t < 11.5 - 1e-6; t += 1.0) clap(t);
  for (let t = 2.75; t < 11.5 - 1e-6; t += 0.5) hat(t, 1);
  for (let t = 8.5; t < 11.5 - 1e-6; t += 0.25) if (Math.abs((t * 4) % 2 - 0) < 1e-6) hat(t, 0.45, 0.03);
  // snare build into the finale: 16ths then 32nds, rising
  for (let t = 10.5; t < 11.5 - 1e-6; t += 0.125) snare(t, 0.25 + ((t - 10.5) / 1.5) * 0.6);
  for (let t = 11.5; t < 12.0 - 1e-6; t += 0.0625) snare(t, 0.6 + ((t - 11.5) / 0.5) * 0.4);

  // ---------- risers / swells ----------
  function noiseSwell(t0, t1, f0, f1, peak, pan = 0) {
    const n = ctx.createBufferSource();
    n.buffer = NOISE;
    n.loop = true;
    const bp = ctx.createBiquadFilter();
    bp.type = "bandpass";
    bp.Q.value = 1.4;
    bp.frequency.setValueAtTime(f0, t0);
    bp.frequency.exponentialRampToValueAtTime(f1, t1);
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.exponentialRampToValueAtTime(peak, t1 - 0.02);
    g.gain.linearRampToValueAtTime(0, t1 + 0.03);
    const p = ctx.createStereoPanner();
    p.pan.value = pan;
    n.connect(bp).connect(g).connect(p);
    p.connect(master);
    p.connect(verbIn);
    n.start(t0);
    n.stop(t1 + 0.05);
  }
  noiseSwell(1.4, 2.5, 500, 7000, 0.12);
  noiseSwell(4.7, 5.5, 700, 6500, 0.07, -0.2);
  noiseSwell(7.7, 8.5, 700, 6500, 0.07, 0.2);
  noiseSwell(9.6, 12.0, 300, 9000, 0.2);
  // pitch riser
  {
    const o = ctx.createOscillator();
    o.type = "sawtooth";
    o.frequency.setValueAtTime(mtof(57), 10.4);
    o.frequency.exponentialRampToValueAtTime(mtof(81), 11.98);
    const lp = ctx.createBiquadFilter();
    lp.type = "lowpass";
    lp.frequency.setValueAtTime(600, 10.4);
    lp.frequency.exponentialRampToValueAtTime(5000, 11.98);
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, 10.4);
    g.gain.exponentialRampToValueAtTime(0.05, 11.95);
    g.gain.linearRampToValueAtTime(0, 12.0);
    o.connect(lp).connect(g);
    g.connect(master);
    g.connect(verbIn);
    o.start(10.4);
    o.stop(12.02);
  }

  // ---------- finale impact at 12.0 ----------
  {
    const t = 12.0;
    kick(t, 1.1);
    const o = ctx.createOscillator();
    o.type = "sine";
    o.frequency.setValueAtTime(62, t);
    o.frequency.exponentialRampToValueAtTime(34, t + 1.6);
    const g = ctx.createGain();
    g.gain.setValueAtTime(0, t);
    g.gain.linearRampToValueAtTime(0.75, t + 0.01);
    g.gain.exponentialRampToValueAtTime(0.001, t + 2.6);
    o.connect(g).connect(master);
    o.start(t);
    o.stop(t + 2.7);
    const n = ctx.createBufferSource();
    n.buffer = NOISE;
    const hp = ctx.createBiquadFilter();
    hp.type = "highpass";
    hp.frequency.value = 3000;
    const ng = ctx.createGain();
    ng.gain.setValueAtTime(0.22, t);
    ng.gain.exponentialRampToValueAtTime(0.001, t + 2.2);
    n.connect(hp).connect(ng);
    ng.connect(master);
    ng.connect(verbIn);
    n.start(t, 0.2, 2.3);
  }
  // intro sub swell
  {
    const o = ctx.createOscillator();
    o.type = "sine";
    o.frequency.value = mtof(38);
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.0001, 0);
    g.gain.exponentialRampToValueAtTime(0.32, 2.3);
    g.gain.linearRampToValueAtTime(0, 2.6);
    o.connect(g).connect(master);
    o.start(0);
    o.stop(2.7);
  }

  const buf = await ctx.startRendering();

  // Normalize to -1 dBFS peak and encode 16-bit PCM WAV.
  const L = buf.getChannelData(0);
  const R = buf.getChannelData(1);
  let peak = 0;
  for (let i = 0; i < L.length; i++) peak = Math.max(peak, Math.abs(L[i]), Math.abs(R[i]));
  const k = peak > 0 ? 0.891 / peak : 1;
  const n = L.length;
  const ab = new ArrayBuffer(44 + n * 4);
  const v = new DataView(ab);
  const w = (o, s) => [...s].forEach((ch, i) => v.setUint8(o + i, ch.charCodeAt(0)));
  w(0, "RIFF");
  v.setUint32(4, 36 + n * 4, true);
  w(8, "WAVE");
  w(12, "fmt ");
  v.setUint32(16, 16, true);
  v.setUint16(20, 1, true);
  v.setUint16(22, 2, true);
  v.setUint32(24, SR, true);
  v.setUint32(28, SR * 4, true);
  v.setUint16(32, 4, true);
  v.setUint16(34, 16, true);
  w(36, "data");
  v.setUint32(40, n * 4, true);
  let o = 44;
  for (let i = 0; i < n; i++) {
    const dither = (rnd() - rnd()) / 32768;
    v.setInt16(o, Math.max(-32768, Math.min(32767, Math.round((L[i] * k + dither) * 32767))), true);
    v.setInt16(o + 2, Math.max(-32768, Math.min(32767, Math.round((R[i] * k + dither) * 32767))), true);
    o += 4;
  }
  const bytes = new Uint8Array(ab);
  let bin = "";
  for (let i = 0; i < bytes.length; i += 0x8000) bin += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return { b64: btoa(bin), peak };
}

const browser = await puppeteer.launch({ executablePath: chrome, headless: true, args: ["--no-sandbox"] });
try {
  const page = await browser.newPage();
  const { b64, peak } = await page.evaluate(synth);
  writeFileSync(out, Buffer.from(b64, "base64"));
  console.log(`wrote ${out} (raw peak ${peak.toFixed(3)})`);
} finally {
  await browser.close();
}
