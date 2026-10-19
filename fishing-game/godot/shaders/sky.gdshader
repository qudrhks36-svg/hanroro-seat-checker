// 그라데이션 하늘 (유니티 SkyGradient.shader 포팅, GDD 8번): 위쪽 색 → 지평선(안개) 색, 해 둘레의 빛무리와 해, 밤엔 별과 달.
// 색은 시간대마다 atmosphere.gd가 전역 값으로 넣어 준다(선형 색). 지평선·아래쪽은 안개 색과 같아서 바다 끝과 매끈하게 이어진다.
shader_type sky;

global uniform vec4 sky_top;
global uniform vec4 sky_glow_color;
global uniform vec4 fog_color;
global uniform vec3 sun_dir;      // 해 쪽을 가리키는 방향(세계 좌표)
global uniform float sky_glow;
global uniform float stars;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 horizon = fog_color.rgb;
	float up = clamp(d.y, 0.0, 1.0);
	vec3 col = mix(horizon, sky_top.rgb, pow(up, 0.55));            // 위로 갈수록 짙은 하늘색
	col = mix(col, horizon, clamp(-d.y * 6.0, 0.0, 1.0));            // 지평선 아래는 안개 색

	vec3 sun = normalize(sun_dir);
	float sd = clamp(dot(d, sun), 0.0, 1.0);
	col += sky_glow_color.rgb * (pow(sd, 6.0) * 0.30 + pow(sd, 60.0) * 0.35) * sky_glow;   // 해 둘레 빛무리
	col = mix(col, sky_glow_color.rgb, smoothstep(0.9990, 0.9996, sd) * clamp(sky_glow, 0.0, 1.0));   // 해

	// 밤: 별과 달
	vec2 uv = vec2(atan(d.z, d.x) * 52.0, d.y * 90.0);
	vec2 cell = floor(uv);
	float star = step(0.985, hash(cell)) * smoothstep(0.42, 0.0, length(fract(uv) - 0.5 + (hash(cell + 7.0) - 0.5) * 0.4));
	col += star * stars * smoothstep(0.02, 0.25, d.y);
	float moon = smoothstep(0.9988, 0.9993, clamp(dot(d, -sun), 0.0, 1.0));
	col = mix(col, vec3(0.95, 0.96, 0.85), moon * stars);
	COLOR = col;
}
