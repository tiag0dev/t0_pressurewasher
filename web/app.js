// Jauge du réservoir, illustration du remplissage + son du jet synthétisé (WebAudio : bruit filtré + ronflement moteur).
// Aucune banque audio GTA : le son est généré ici.
const gauge = document.getElementById('gauge');
const fill = gauge.querySelector('.fill');
const pct = gauge.querySelector('.pct');

let ctx = null;
let master = null;
let volume = 0.35;
const voices = {}; // id -> { gain, nodes }

function audio() {
    if (!ctx) {
        ctx = new AudioContext();
        master = ctx.createGain();
        master.gain.value = volume;
        master.connect(ctx.destination);
    }
    if (ctx.state === 'suspended') ctx.resume();
    return ctx;
}

function noiseBuffer(c) {
    const len = c.sampleRate * 2;
    const buf = c.createBuffer(1, len, c.sampleRate);
    const data = buf.getChannelData(0);
    for (let i = 0; i < len; i++) data[i] = Math.random() * 2 - 1;
    return buf;
}

function startVoice(id) {
    const c = audio();
    const gain = c.createGain();
    gain.gain.value = 0;
    gain.connect(master);

    const noise = c.createBufferSource();
    noise.buffer = noiseBuffer(c);
    noise.loop = true;
    const band = c.createBiquadFilter();
    band.type = 'bandpass';
    band.frequency.value = 2400;
    band.Q.value = 0.6;
    const hiss = c.createGain();
    hiss.gain.value = 0.55;
    noise.connect(band).connect(hiss).connect(gain);

    const motor = c.createOscillator();
    motor.type = 'sawtooth';
    motor.frequency.value = 52;
    const low = c.createBiquadFilter();
    low.type = 'lowpass';
    low.frequency.value = 220;
    const hum = c.createGain();
    hum.gain.value = 0.25;
    motor.connect(low).connect(hum).connect(gain);

    const lfo = c.createOscillator();
    lfo.frequency.value = 7;
    const lfoGain = c.createGain();
    lfoGain.gain.value = 3;
    lfo.connect(lfoGain).connect(motor.frequency);

    noise.start(); motor.start(); lfo.start();
    voices[id] = { gain, nodes: [noise, motor, lfo] };
    return voices[id];
}

function setVoice(id, on, level) {
    let v = voices[id];
    if (!on) {
        if (!v) return;
        const t = ctx.currentTime;
        v.gain.gain.cancelScheduledValues(t);
        v.gain.gain.setTargetAtTime(0, t, 0.06);
        delete voices[id];
        setTimeout(() => v.nodes.forEach(n => n.stop()), 400);
        return;
    }
    if (!v) v = startVoice(id);
    v.gain.gain.setTargetAtTime(Math.max(0, Math.min(1, level)), ctx.currentTime, 0.08);
}

// Remplissage : la bouteille se vide pendant que le réservoir monte de `from` à `to` (0..1).
const refill = document.getElementById('refill');
const tankWater = document.getElementById('rf-tank-water');
const bottleWater = document.getElementById('rf-bottle-water');
const rfPct = refill.querySelector('.rf-pct');
let rfFrame = null;

function setLevels(tank, bottle, ms) {
    tankWater.style.transitionDuration = bottleWater.style.transitionDuration = ms + 'ms';
    tankWater.style.transform = `scaleY(${tank})`;
    bottleWater.style.transform = `scaleY(${bottle})`;
}

function showRefill(d) {
    cancelAnimationFrame(rfFrame);
    if (!d.show) {
        refill.classList.remove('pouring');
        refill.classList.add('hidden');
        return;
    }
    const from = Math.max(0, Math.min(1, d.from)), to = Math.max(0, Math.min(1, d.to));
    refill.querySelector('.rf-title').textContent = d.label || '';
    refill.querySelector('.rf-cancel').textContent = d.cancel || '';
    setLevels(from, 1, 0);
    refill.classList.remove('hidden');
    void refill.offsetWidth; // applique l'état initial avant la transition
    refill.classList.add('pouring');
    setLevels(to, 0, d.duration);

    const start = performance.now();
    const tick = (now) => {
        const t = Math.min(1, (now - start) / d.duration);
        rfPct.textContent = Math.round((from + (to - from) * t) * 100) + '%';
        if (t < 1) rfFrame = requestAnimationFrame(tick); else refill.classList.remove('pouring');
    };
    rfFrame = requestAnimationFrame(tick);
}

window.addEventListener('message', (e) => {
    const d = e.data;
    if (!d || !d.action) return;
    if (d.action === 'gauge') {
        gauge.classList.toggle('hidden', !d.show);
        const p = Math.round(Math.max(0, Math.min(1, d.value)) * 100);
        fill.style.width = p + '%';
        pct.textContent = p + '%';
        gauge.classList.toggle('low', p <= 15);
    } else if (d.action === 'refill') {
        showRefill(d);
    } else if (d.action === 'sound') {
        setVoice(String(d.id), !!d.on, d.gain ?? 1);
    } else if (d.action === 'volume') {
        volume = d.value;
        if (master) master.gain.value = volume;
    }
});
