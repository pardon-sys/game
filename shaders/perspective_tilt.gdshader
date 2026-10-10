shader_type canvas_item;
// 透视倾斜（scripts/fx/perspective_view.gd 挂在 2.5D 楼层的世界之上、UI 之下）：
// 把已经画好的世界画面按投影变换映射成梯形——画面上方（远处）宽而扁、下方（近处）窄而大，
// 直线仍是直的，像把地图放在桌上斜着看。远处再蒙一层淡淡的雾，纵深更明显。

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
// 输出 UV → 画面 UV 的投影矩阵的三列（GDScript 里由倾斜角算出来；分开传，免得行列顺序搞混）
uniform vec3 h_col0 = vec3(1.0, 0.0, 0.0);
uniform vec3 h_col1 = vec3(0.0, 1.0, 0.0);
uniform vec3 h_col2 = vec3(0.0, 0.0, 1.0);
uniform vec4 fog_color : source_color = vec4(0.02, 0.02, 0.05, 1.0);
uniform float fog : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	vec3 p = h_col0 * SCREEN_UV.x + h_col1 * SCREEN_UV.y + h_col2;
	vec2 uv = p.xy / p.z;
	vec3 c = texture(screen_tex, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
	float far = 1.0 - SCREEN_UV.y;
	c = mix(c, fog_color.rgb, fog * far * far);
	COLOR = vec4(c, 1.0);
}
