shader_type canvas_item;
// 立绘的粉色光晕（PortraitFx 每帧设置 strength / mode / region）：
//   mode 0：普通立绘，沿人物轮廓（透明度边缘）向外发一圈柔和的粉光，只出现在人物外侧的透明处，没有矩形边
//   mode 1：横版 CG 图，大框内侧四周一圈粉色晕光，中心不受影响
// region：立绘在贴图里的 UV 范围（左上 xy、右下 zw）。立绘是图集里的一格，采样不能越界采到隔壁的立绘。

uniform vec4 glow_color : source_color = vec4(1.0, 0.45, 0.75, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.0;
// 外发光半径（贴图像素）
uniform float radius = 8.0;
// 呼吸幅度（失控时）：强度在 1 - pulse 到 1 之间起伏
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform int mode = 0;
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);
// mode 1 晕光宽度（占短边的比例）
uniform float edge = 0.14;

// 顶点色（modulate / self_modulate）：fragment 里的 COLOR 已经乘过贴图颜色，透明处 alpha 为 0，不能直接用
varying vec4 vcolor;

const int RINGS = 4;
const int DIRS = 12;

// 越界（采到图集隔壁的立绘）算透明
float inside(vec2 uv) {
	return step(region.x, uv.x) * step(region.y, uv.y) * step(uv.x, region.z) * step(uv.y, region.w);
}

void vertex() {
	vcolor = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * vcolor;
	float s = strength * (1.0 - pulse * (0.5 + 0.5 * sin(TIME * 4.0)));
	if (s > 0.001) {
		if (mode == 0) {
			// 越靠近轮廓越亮：第 1 圈取满，外圈逐渐变淡
			float g = 0.0;
			for (int ring = 1; ring <= RINGS; ring++) {
				float r = radius * float(ring) / float(RINGS);
				float w = 1.0 - float(ring - 1) / float(RINGS);
				for (int i = 0; i < DIRS; i++) {
					float ang = float(i) * TAU / float(DIRS) + float(ring) * 0.26;
					vec2 uv = UV + vec2(cos(ang), sin(ang)) * r * TEXTURE_PIXEL_SIZE;
					g = max(g, texture(TEXTURE, uv).a * inside(uv) * w);
				}
			}
			float ga = g * s * glow_color.a * vcolor.a;
			// 人物在上、光晕垫在下面
			float a = c.a + ga * (1.0 - c.a);
			vec3 rgb = a > 0.0 ? (c.rgb * c.a + glow_color.rgb * ga * (1.0 - c.a)) / a : c.rgb;
			c = vec4(rgb, a);
		} else {
			vec2 span = region.zw - region.xy;
			vec2 n = (UV - region.xy) / span;
			float aspect = (span.x / TEXTURE_PIXEL_SIZE.x) / max(span.y / TEXTURE_PIXEL_SIZE.y, 1.0);
			float d = min(min(n.x, 1.0 - n.x) * aspect, min(n.y, 1.0 - n.y));
			float v = 1.0 - smoothstep(0.0, edge, d);
			c.rgb = mix(c.rgb, glow_color.rgb, v * v * s * 0.7);
		}
	}
	COLOR = c;
}
