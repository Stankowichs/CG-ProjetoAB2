// Blur gaussiano simples para o fundo do menu (cena do jogo desfocada).
// Aplicado a um TextureRect que exibe a textura do SubViewport.
shader_type canvas_item;

// Intensidade do desfoque, em pixels.
uniform float blur_radius : hint_range(0.0, 8.0) = 3.0;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * blur_radius;
	vec4 acc = vec4(0.0);
	float total = 0.0;

	// Kernel 5x5 com pesos gaussianos aproximados.
	float weights[5] = float[](1.0, 4.0, 6.0, 4.0, 1.0);
	for (int y = 0; y < 5; y++) {
		for (int x = 0; x < 5; x++) {
			float w = weights[x] * weights[y];
			vec2 offset = vec2(float(x - 2), float(y - 2)) * px;
			acc += texture(TEXTURE, UV + offset) * w;
			total += w;
		}
	}

	COLOR = acc / total;
}
