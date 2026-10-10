shader_type canvas_item;
// 2.5D 楼层的人物 / 怪物（scripts/fx/lit_sprite.gd 套上）：
//   受击闪色（和 flash.gdshader 一样的 flash / flash_color，Actor.flash 照常能用）
//   + 按轮廓和明暗实时算出的法线（像轻轻鼓起来的浮雕）+ 柔和的高光：配合 2D 灯光，人物身上有受光面、背光面和一点反光。
// 图集里每帧周围是透明的，所以邻近采样不会串到别的帧。

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
// 轮廓往里鼓起来的程度、明暗细节的凹凸、高光（都调得比较柔：不要太「真实」、不要锐化感）
uniform float bulge = 1.2;
uniform float detail = 0.2;
uniform float specular_strength : hint_range(0.0, 1.0) = 0.15;
uniform float shininess : hint_range(0.0, 1.0) = 0.3;
// 柔光：受光面 / 背光面的差别往「平光」靠（0 = 完全按法线、1 = 不分明暗）
uniform float soft : hint_range(0.0, 1.0) = 0.45;
// 透视倾斜（scripts/fx/perspective_view.gd）会把人物纵向压扁一点：以脚底（feet_y，精灵本地坐标）为基准纵向拉回来
uniform float upright = 1.0;
uniform float feet_y = 0.0;

void vertex() {
	VERTEX.y = feet_y + (VERTEX.y - feet_y) * upright;
}

// 法线：邻近像素透明度的差（轮廓边缘往外倾斜，像鼓起来）+ 明暗的差（衣服褶皱、头发的细节）。
// 画布着色器的自定义函数里不能用 TEXTURE，所以都写在 fragment 里。
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(mix(c.rgb, flash_color.rgb, flash), c.a);
	vec2 px = TEXTURE_PIXEL_SIZE;
	float gx = 0.0;
	float gy = 0.0;
	for (int i = 1; i <= 3; i++) {
		float r = float(i);
		float w = 1.0 / r;
		gx += (texture(TEXTURE, UV - vec2(px.x * r, 0.0)).a - texture(TEXTURE, UV + vec2(px.x * r, 0.0)).a) * w;
		gy += (texture(TEXTURE, UV + vec2(0.0, px.y * r)).a - texture(TEXTURE, UV - vec2(0.0, px.y * r)).a) * w;
	}
	vec3 lw = vec3(0.299, 0.587, 0.114);
	float lx = dot(texture(TEXTURE, UV - vec2(px.x, 0.0)).rgb, lw) - dot(texture(TEXTURE, UV + vec2(px.x, 0.0)).rgb, lw);
	float ly = dot(texture(TEXTURE, UV + vec2(0.0, px.y)).rgb, lw) - dot(texture(TEXTURE, UV - vec2(0.0, px.y)).rgb, lw);
	NORMAL = normalize(vec3((gx * bulge + lx * detail) * 0.5, (gy * bulge + ly * detail) * 0.5, 1.0));
}

// 灯光：法线决定受光面 / 背光面，再加一点 Blinn 高光（像身上的反光）
void light() {
	float nl = mix(max(dot(NORMAL, LIGHT_DIRECTION), 0.0), 1.0, soft);
	vec3 h = normalize(LIGHT_DIRECTION + vec3(0.0, 0.0, 1.0));
	float spec = pow(max(dot(NORMAL, h), 0.0), mix(8.0, 48.0, shininess)) * specular_strength;
	LIGHT = vec4(LIGHT_COLOR.rgb * LIGHT_ENERGY * (COLOR.rgb * nl + vec3(spec)), LIGHT_COLOR.a);
}
