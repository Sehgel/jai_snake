#version 330 core

out vec4 out_color;

uniform vec4 tint = vec4(1.0,0.0,0.0,1.0);

void main()
{
    out_color = tint;
}