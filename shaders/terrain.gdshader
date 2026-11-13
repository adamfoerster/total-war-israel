shader_type spatial;
render_mode specular_disabled;
// Terreno: cor base por vértice (COLOR.rgb) e brilho (COLOR.a). UV.x = quanto é parede
// rochosa (declive intransponível); UV.y = quanto é plano o bastante para ter vegetação.
// As texturas são procedurais, em coordenadas do mundo (sem esticar nas encostas).

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x),
			mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x),
			mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}

varying vec3 wpos;
varying vec2 masks;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	masks = UV;
}

void fragment() {
	vec3 base = COLOR.rgb;
	float depth = -VERTEX.z;
	float detail = 1.0 - smoothstep(250.0, 900.0, depth);

	// vegetação rasteira: manchas grandes nas áreas planas, com tufos de perto
	float pm = vnoise(vec3(wpos.x * 0.011, 3.7, wpos.z * 0.011)) * 0.65
		+ vnoise(vec3(wpos.x * 0.031, 1.3, wpos.z * 0.031)) * 0.35;
	float sm = masks.y * smoothstep(0.48, 0.60, pm);
	float t1 = vnoise(vec3(wpos.x * 0.9, 0.3, wpos.z * 0.9));
	float t2 = vnoise(vec3(wpos.x * 3.1, 0.7, wpos.z * 3.1));
	vec3 scrub = mix(vec3(0.27, 0.36, 0.15), vec3(0.46, 0.51, 0.24), t1);
	scrub = mix(scrub, vec3(0.18, 0.25, 0.10), step(0.70, t2) * 0.85);
	scrub = mix(vec3(0.33, 0.41, 0.18), scrub, detail);
	base = mix(base, scrub, sm * 0.92);

	// parede rochosa: estratos horizontais e manchas, borda irregular
	float rn = vnoise(wpos * 0.18);
	float rn2 = vnoise(wpos * 0.85);
	float strata = smoothstep(0.25, 0.75, 0.5 + 0.5 * sin(wpos.y * 1.4 + rn * 4.0));
	vec3 rock = mix(vec3(0.34, 0.31, 0.29), vec3(0.66, 0.60, 0.51), rn * 0.3 + strata * 0.7);
	rock *= 1.0 - 0.12 * rn2 * detail;
	float crack = smoothstep(0.30, 0.0, abs(vnoise(wpos * vec3(0.35, 0.12, 0.35)) - 0.5));
	rock *= 1.0 - 0.35 * crack * detail;
	float rm = smoothstep(0.35, 0.65, masks.x + (rn - 0.5) * 0.6);
	base = mix(base, rock, rm);

	ALBEDO = base * COLOR.a;
	ROUGHNESS = 1.0;
}
