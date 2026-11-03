shader_type spatial;
render_mode cull_disabled;

uniform bool usar_textura = true;
uniform sampler2D textura : source_color, filter_linear_mipmap_anisotropic;
uniform float ancho = 1.5;
uniform float alto = 0.95;
uniform float amplitud = 0.14;
uniform float ondas = 1.3;
uniform float velocidad = 5.0;
uniform float caida = 0.18;
uniform float desfase = 0.0;
uniform vec3 celeste : source_color = vec3(0.455, 0.675, 0.875);
uniform vec3 color_sol : source_color = vec3(0.965, 0.706, 0.055);
uniform vec3 borde_sol : source_color = vec3(0.52, 0.2, 0.04);

varying float pliegue;

// Fuerza del viento entre ~0.2 y 1.0, con ráfagas irregulares
float viento(float t) {
	return clamp(0.6 + 0.4 * sin(t * 0.7) * sin(t * 0.31 + 1.7) + 0.15 * sin(t * 1.9), 0.15, 1.0);
}

// Cuánto se desplaza un punto de la tela (u = 0 en el mástil, 1 en la punta; y en metros)
vec3 ola(float u, float y, float t) {
	float v = viento(t);
	float x = u * ancho;
	float k = 6.2832 * ondas / ancho;
	float fase = x * k - t * velocidad + y * 1.5;

	// Profundidad (hacia adelante/atrás)
	float z = sin(fase)
		+ 0.35 * sin(x * k * 2.3 - t * velocidad * 1.7 + y * 3.0)
		+ 0.12 * sin(x * k * 4.1 - t * velocidad * 2.9 - y * 2.0);
	z *= amplitud * u * (0.35 + 0.65 * v);

	// Panza general: la tela se infla un poco hacia un lado
	z += amplitud * 0.6 * sin(3.1416 * u) * (0.5 + 0.5 * v);

	// Bordes de arriba y abajo ondulan (cambia el contorno)
	float dy = amplitud * 0.45 * u * cos(fase * 0.8 + 0.6) * (0.4 + 0.6 * v);
	dy -= caida * u * u * (1.0 - v);

	// La tela se encoge al doblarse, y la punta libre "latiguea"
	float dx = -abs(z) * 0.35 * u;
	dx -= amplitud * 0.7 * u * u * u * (0.5 + 0.5 * sin(y * 9.0 - t * velocidad * 2.2)) * (0.4 + 0.6 * v);

	return vec3(dx, dy, z);
}

void vertex() {
	float t = TIME + desfase;
	float u = UV.x;
	float y = VERTEX.y;
	vec3 d = ola(u, y, t);
	VERTEX += d;

	// Normal calculada con dos puntos vecinos, para que la luz marque bien los pliegues
	float e = 0.01;
	vec3 p0 = vec3(u * ancho, y, 0.0) + d;
	vec3 px = vec3((u + e) * ancho, y, 0.0) + ola(u + e, y, t);
	vec3 py = vec3(u * ancho, y + e * alto, 0.0) + ola(u, y + e * alto, t);
	NORMAL = normalize(cross(px - p0, py - p0));

	pliegue = d.z;
}

void fragment() {
		vec3 col;
	if (usar_textura) {
		col = texture(textura, UV).rgb;
	} else {
		col = celeste;
		if (UV.y > 1.0 / 3.0 && UV.y < 2.0 / 3.0) {
			col = vec3(1.0);
		}
		vec2 p = (UV - 0.5) * vec2(ancho, alto);
		float r = length(p);
		float radio_disco = (alto / 3.0) * 0.17;
		float tramo = fract(atan(p.y, p.x) * 16.0 / 6.2832);
		float largo_rayo = radio_disco * (1.25 + 0.95 * (1.0 - abs(tramo * 2.0 - 1.0)));
		if (r < largo_rayo) {
			col = color_sol;
		}
		if (r < radio_disco && r > radio_disco * 0.88) {
			col = borde_sol;
		}
	}

	// Oscurece un poco el fondo de los pliegues
	col *= 0.85 + 0.15 * clamp(pliegue / max(amplitud, 0.001) + 0.5, 0.0, 1.0);

	ALBEDO = col;
	EMISSION = col * 0.15;
	ROUGHNESS = 0.85;
}