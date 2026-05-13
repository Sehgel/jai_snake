#version 330 core
in vec2 uv;

out vec4 out_color;

uniform vec4 tint;
uniform sampler2D text;
uniform vec2 uv_size;
uniform vec2 uv_offset;

void main()
{
    out_color = texture(text,uv*uv_size + uv_offset) * tint;
}