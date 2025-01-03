#version 330 core
in vec2 uv;

out vec4 out_color;

uniform vec4 tint = vec4(1.0,0.0,0.0,1.0);
uniform sampler2D text;

void main()
{
    //out_color = vec4(1.0,0.0,0.0,1.0);
    out_color = texture(text,uv) * tint;
}