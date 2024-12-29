#version 330 core
layout (location = 0) in vec2 in_pos;
layout (location = 1) in vec2 in_uv;
layout (location = 2) in float tail_percentage;

out vec2 uv;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;
uniform vec2 tummy_bloats[10];

const float DIGESTION_RADIUS = 20.0;
const float DIGESTION_SIZE = 0.05;

void main()
{
    vec2 new_pos = in_pos;
    vec2 world_pos = (model * vec4(in_pos,0,1.0)).xy;

    float dist = 0.0;
    vec2 dir = vec2(0.0,0.0);

    for (int i = 0; i < 10;++i) {
        if (length(tummy_bloats[i]) > 0.0) {
            float new_dist = distance( tummy_bloats[i],world_pos );
            if (new_dist < DIGESTION_RADIUS) {
                dist = distance( tummy_bloats[i],world_pos );
                dir  = world_pos-tummy_bloats[i];
            }
        }
    }

    if (dist > 0.0) {
        new_pos = new_pos + (dir*(DIGESTION_RADIUS - dist)*DIGESTION_SIZE)*tail_percentage;
    }

    vec4 pos = projection * view * model * vec4(new_pos,0.0, 1.0);
    gl_Position = pos;
    uv = in_uv;
}