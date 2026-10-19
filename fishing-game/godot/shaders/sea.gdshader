// 바다 (유니티 Sea.shader 포팅, GDD 8번): 깊이에 따른 색, 물결무늬, 해안 거품, 햇빛 반짝임. 섬 중심은 (0,0), 해안은 반지름 20.
// 색은 시간대마다 atmosphere.gd가 전역 값으로 바꿔 준다(선형 색). 안개는 유니티와 같은 지수 제곱 식을 직접 계산한다.
shader_type spatial;
render_mode unshaded, fog_disabled;

uniform float shore_radius = 20.0;
global uniform vec4 sea_shallow;
global uniform vec4 sea_deep;
global uniform vec4 sea_foam;
global uniform vec4 fog_color;
global uniform float sea_glint;
global uniform float fog_density;

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 xz = wpos.xz;
	float t = TIME;
	float sd = length(xz) - shore_radius;                          // 해안에서 얼마나 먼가

	float depth = pow(clamp(sd / 22.0, 0.0, 1.0), 0.65);
	vec3 col = mix(sea_shallow.rgb, sea_deep.rgb, depth);

	// 부드러운 물결무늬 (움직이는 두 겹의 잔물결)
	float n = vnoise(xz * 0.30 + vec2(t * 0.10, t * 0.07)) * 0.6 + vnoise(xz * 0.85 - vec2(t * 0.16, t * 0.05)) * 0.4;
	col += (n - 0.5) * 0.10;
	col = mix(col, sea_shallow.rgb * 1.15, smoothstep(0.62, 0.78, n) * 0.35);

	// 해안 거품: 밀려오는 물결 선 + 모래 가까이의 띠
	float near = 1.0 - clamp(sd / 7.0, 0.0, 1.0);
	float wave = sin(sd * 1.5 - t * 0.9 + n * 2.0);
	float lines = smoothstep(0.88, 1.0, wave) * near;
	float band = smoothstep(2.4 + 0.6 * sin(t * 0.8 + n * 4.0), 0.0, sd);
	float foam = clamp(lines * 0.9 + band * (0.55 + 0.45 * vnoise(xz * 1.6 + t * 0.2)), 0.0, 1.0);
	col = mix(col, sea_foam.rgb, foam);

	// 햇빛 반짝임
	float sp = vnoise(xz * 2.6 + vec2(t * 0.6, -t * 0.4));
	col += sea_foam.rgb * pow(clamp(sp, 0.0, 1.0), 14.0) * sea_glint * (0.4 + depth * 0.6);

	// 안개: 유니티 지수 제곱(ExponentialSquared) 식, 눈에서의 깊이 기준
	float z = -VERTEX.z;
	float f = exp(-(fog_density * z) * (fog_density * z));
	col = mix(fog_color.rgb, col, f);
	ALBEDO = col;
}
