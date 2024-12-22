#version 330 core
in vec2 uv;

out vec4 out_color;

uniform vec3 tint;
uniform sampler2D text;

void main()
{
    out_color = texture(text,uv) * vec4(tint,1.0);
}