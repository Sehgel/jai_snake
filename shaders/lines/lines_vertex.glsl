#version 330 core
layout (location = 0) in vec2 in_pos;

//uniform mat4 model;
//uniform mat4 view;
//uniform mat4 projection;

void main()
{
    //vec4 pos = projection * view * model * vec4(in_pos,0.0, 1.0);
    gl_Position = vec4(in_pos,0.0,1.0);
    //uv = in_uv;
}