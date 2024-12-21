#version 330 core

out vec4 out_color;

uniform vec3 tint;

void main()
{
    out_color = vec4(tint,1.0);
}