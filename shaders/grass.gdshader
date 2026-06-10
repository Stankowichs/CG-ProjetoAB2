// Grama procedural pro campo de futebol.
//
// Combina:
//   * 2 oitavas de Value Noise pra variação natural de tom (não fica uniforme)
//   * listras de corte (mowing stripes) alternando claro/escuro a cada N metros
//   * normal map sintetizado a partir do gradiente do ruído (simula lâminas)
//   * roughness alta (grama é fosca)
//
// Tudo em world-space XZ, então não importa como o mesh é tileado.
// Os parâmetros @export ficam editáveis no Inspector do material.

shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3  grass_color_a : source_color = vec3(0.13, 0.34, 0.09);   // verde escuro
uniform vec3  grass_color_b : source_color = vec3(0.23, 0.55, 0.18);   // verde claro
uniform float color_noise_scale : hint_range(0.5, 20.0)  = 4.0;
uniform float stripe_period_m   : hint_range(1.0, 15.0)  = 6.0;        // largura de cada listra (metros)
uniform float stripe_strength   : hint_range(0.0, 0.6)   = 0.22;
uniform float blade_noise_scale : hint_range(2.0, 200.0) = 60.0;       // detalhe alta-freq do normal map
uniform float normal_strength   : hint_range(0.0, 2.0)   = 0.55;
uniform float roughness_val     : hint_range(0.4, 1.0)   = 0.92;
uniform float ao_amount         : hint_range(0.0, 1.0)   = 0.25;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// hash de qualidade decente sem texturas
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	vec2 uv = world_pos.xz;

	// Cor base com variação de ruído de 2 oitavas
	float n1 = vnoise(uv * color_noise_scale);
	float n2 = vnoise(uv * color_noise_scale * 4.0);
	float n  = n1 * 0.65 + n2 * 0.35;
	vec3 base = mix(grass_color_a, grass_color_b, n);

	// Listras de corte (faixas alternadas ao longo do eixo Z mundial)
	float stripe_t = sin(uv.y * 6.2831853 / stripe_period_m) * 0.5 + 0.5;
	stripe_t = smoothstep(0.35, 0.65, stripe_t);
	base = mix(base, base * (1.0 + stripe_strength),  stripe_t);
	base = mix(base, base * (1.0 - stripe_strength * 0.55), 1.0 - stripe_t);

	ALBEDO = base;
	METALLIC = 0.0;
	ROUGHNESS = roughness_val;

	// Normal map sintetizado: gradiente do ruído fino
	float e = 0.5 / blade_noise_scale;
	float h_x1 = vnoise((uv + vec2(e, 0.0)) * blade_noise_scale);
	float h_x0 = vnoise((uv - vec2(e, 0.0)) * blade_noise_scale);
	float h_z1 = vnoise((uv + vec2(0.0, e)) * blade_noise_scale);
	float h_z0 = vnoise((uv - vec2(0.0, e)) * blade_noise_scale);
	vec3 nrm = normalize(vec3((h_x0 - h_x1) * normal_strength,
							  1.0,
							  (h_z0 - h_z1) * normal_strength));
	// Godot espera NORMAL_MAP no espaço tangente codificado [0,1]
	NORMAL_MAP = nrm * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;

	// AO sutil em áreas mais escuras do ruído pra dar profundidade
	AO = mix(1.0 - ao_amount, 1.0, n);
}
