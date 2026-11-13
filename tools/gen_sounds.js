// Gera por síntese os sons dos projéteis (flechas e fundas) em assets/sounds/.
// Uso: node tools/gen_sounds.js
// Determinístico (semente fixa): rodar de novo produz os mesmos arquivos.
"use strict";
const fs = require("fs");
const path = require("path");

const SR = 22050;
const OUT = path.join(__dirname, "..", "assets", "sounds");

let seed = 12345;
function rnd() {
	seed = (seed * 1664525 + 1013904223) >>> 0;
	return seed / 4294967296;
}
function rr(a, b) { return a + (b - a) * rnd(); }
function noise() { return rnd() * 2 - 1; }

// passa-faixa RBJ (ganho 0 dB no pico), coeficientes recalculáveis por amostra
function makeBP() {
	return { x1: 0, x2: 0, y1: 0, y2: 0 };
}
function bp(st, x, f, q) {
	const w = 2 * Math.PI * Math.min(f, SR * 0.45) / SR;
	const al = Math.sin(w) / (2 * q);
	const a0 = 1 + al;
	const b0 = al / a0, b2 = -al / a0;
	const a1 = -2 * Math.cos(w) / a0, a2 = (1 - al) / a0;
	const y = b0 * x + b2 * st.x2 - a1 * st.y1 - a2 * st.y2;
	st.x2 = st.x1; st.x1 = x; st.y2 = st.y1; st.y1 = y;
	return y;
}

function writeWav(name, data) {
	let peak = 1e-9;
	for (const v of data) peak = Math.max(peak, Math.abs(v));
	const g = 0.85 / peak;
	const buf = Buffer.alloc(44 + data.length * 2);
	buf.write("RIFF", 0); buf.writeUInt32LE(36 + data.length * 2, 4); buf.write("WAVE", 8);
	buf.write("fmt ", 12); buf.writeUInt32LE(16, 16); buf.writeUInt16LE(1, 20); buf.writeUInt16LE(1, 22);
	buf.writeUInt32LE(SR, 24); buf.writeUInt32LE(SR * 2, 28); buf.writeUInt16LE(2, 32); buf.writeUInt16LE(16, 34);
	buf.write("data", 36); buf.writeUInt32LE(data.length * 2, 40);
	for (let i = 0; i < data.length; i++) {
		const s = Math.max(-1, Math.min(1, data[i] * g));
		buf.writeInt16LE(Math.round(s * 32767), 44 + i * 2);
	}
	fs.writeFileSync(path.join(OUT, name), buf);
	console.log(name, (data.length / SR).toFixed(2) + " s");
}

// Volley de flechas: estalos de corda e dezenas de assobios com Doppler descendente.
function volley({ count, spread, fHi, fLo, len, twang, q }) {
	const dur = spread + len + 0.1;
	const n = Math.floor(dur * SR);
	const out = new Float32Array(n);
	for (let a = 0; a < count; a++) {
		const t0 = Math.floor(rr(0, spread) * SR);
		const l = Math.floor(rr(len * 0.7, len) * SR);
		const st = makeBP();
		const hi = fHi * rr(0.85, 1.15), lo = fLo * rr(0.85, 1.15);
		const amp = rr(0.5, 1.0);
		const peakAt = rr(0.35, 0.6);
		for (let i = 0; i < l && t0 + i < n; i++) {
			const t = i / l;
			const f = hi + (lo - hi) * t;
			const env = t < peakAt ? Math.pow(t / peakAt, 2) : Math.pow(1 - (t - peakAt) / (1 - peakAt), 1.5);
			out[t0 + i] += amp * env * bp(st, noise(), f, q);
		}
		// estalo da corda / da funda no disparo
		if (twang > 0) {
			const tf = rr(110, 170);
			const tl = Math.floor(0.08 * SR);
			for (let i = 0; i < tl && t0 + i < n; i++) {
				const e = Math.exp(-i / (0.015 * SR));
				out[t0 + i] += twang * amp * e * (Math.sin(2 * Math.PI * tf * i / SR) + 0.4 * noise() * Math.exp(-i / (0.002 * SR)));
			}
		}
	}
	// entrada e saída suaves
	const fade = Math.floor(0.03 * SR);
	for (let i = 0; i < fade; i++) { out[i] *= i / fade; out[n - 1 - i] *= i / fade; }
	return out;
}

writeWav("flechas.wav", volley({ count: 40, spread: 0.35, fHi: 3200, fLo: 1300, len: 0.9, twang: 0.35, q: 3.5 }));
writeWav("fundas.wav", volley({ count: 25, spread: 0.4, fHi: 900, fLo: 380, len: 0.8, twang: 0.0, q: 2.5 }));
