BASE_WIDTH    :: 32;
BASE_HEIGHT   :: 32;

FPS_TARGET :: 240;

MULTIPLIER :: 1080/48;

WINDOW_WIDTH  :: BASE_WIDTH*MULTIPLIER;
WINDOW_HEIGHT :: BASE_HEIGHT*MULTIPLIER;

CENTER_POINT :: Vector2.{WINDOW_WIDTH-256,WINDOW_HEIGHT/2};
//CENTER_POINT :: Vector2.{0,0};
PADDING :: 10.0;

TAIL_POINTS_SKIPPED :: 10;
TAIL_ADD_DELAY :: 0.1;
DISTANCE_BETWEEN_TAIL_POINTS :: 5.0;
TAIL_END_CUTOFF_MULT :: 1.5;

PIXEL_SIZE :: 8;
HEAD_SIZE :: 12;
WALL_SIZE :: 16;

//CAMERA
cam_shake_strength := 3.0;
cam_shake_counter : float;

//Time
time_slow_counter : float;
time_slow_time : float;

//DEBUG
IS_DEBUGGING_GRAPHICS := false;

window : Window_Type;

key_left  : bool;
key_right : bool;
key_up    : bool;
key_down  : bool;
key_space : bool;

key_debug_draw : KeyState;
key_slow_mo : KeyState;
key_restart : KeyState;
key_pause : KeyState;

snake : Snake;
pickups : [..]PickUp;
obstacles : [..]Obstacle;
map_details : [..]MapDetail;

graphics : GraphicBuffers;

direction : Vector2 = .{1,0};
input := Vector2.{0,0};
inputv2 := Vector2.{0,0};
speed : float = 300;
last_time : float64;
dt : float;
u_dt : float;
time_scale : float = 1.0;
frame_counter : u64;
is_alive : bool = false;
test_point : Vector2;
test_circle : Vector2;

tail_adding_counter : float;
tail_points_to_add : int;


tail_VBO : u32;
tail_VAO : u32;
tail_shader : GLuint;
tail_texture : u32;

head_VAO : u32;
head_VBO : u32;
head_EBO : u32;
head_vertices : [..]float;
head_rotation : Quaternion;

apple_texture : u32;
rat_texture : u32;

sprite_quad_vertices := float.[
    -0.5,-0.5,0.0,0.0,
     0.5,-0.5,1.0,0.0,
     0.5, 0.5,1.0,1.0,
    -0.5, 0.5,0.0,1.0,
];
sprite_indices := u32.[
    0,1,2,
    0,2,3
];

SPRITE_ATLAS_SIZE :: 64.0;
sprite_atlas : *u8;
sprite_atlas_texture : u32;
sprite_atlas_width : s32;
sprite_atlas_height : s32;
sprite_atlas_uv_size : Vector2;
sprite_atlas_uv_correction_offset : Vector2;
camera_pos : Vector2;

main :: () {
    SDL_Init(SDL_INIT_VIDEO);

    //This seems to be optional
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, xx SDL_GL_CONTEXT_PROFILE_CORE);
    SDL_GL_SetAttribute(SDL_GL_MULTISAMPLESAMPLES, 4);

    window := SDL_CreateWindow("Jai Snake",
        SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
        WINDOW_WIDTH, WINDOW_HEIGHT,
        SDL_WINDOW_OPENGL|SDL_WINDOW_SHOWN);


    if window == null {
        print("Couldn't create window: %\n", to_string(SDL_GetError()));
        return;
    }

    gl_context := SDL_GL_CreateContext(window);

    if !gl_context {
        print("Couldn't create OpenGL context: %\n", to_string(SDL_GetError()));
        return;
    }

    //This two seems to be optional
    gl_load(*gl, SDL_GL_GetProcAddress);
    using gl;

    print ("GL Vendor = %\n", to_string(glGetString(GL_VENDOR)));
    print ("GL Version = %\n", to_string(glGetString(GL_VERSION)));

    init_game();
    prepare_render();

    // Enable MSAA
    SDL_GL_SetAttribute(SDL_GL_MULTISAMPLEBUFFERS, 1);
    SDL_GL_SetAttribute(SDL_GL_MULTISAMPLESAMPLES, 4);
    glEnable(GL_MULTISAMPLE);
    //VSync?
    wglSwapIntervalEXT(1);

    quit := false;
    while main := !quit {
        now := seconds_since_init();
        dt = xx (now - last_time) * time_scale;
        u_dt = xx (now - last_time);

        event : SDL_Event;

        if key_slow_mo.awaits_reset then key_slow_mo.was_just_pressed = false;
        if key_debug_draw.awaits_reset then key_debug_draw.was_just_pressed = false;
        if key_restart.awaits_reset then key_restart.was_just_pressed = false;
        if key_pause.awaits_reset then key_pause.was_just_pressed = false;

        while SDL_PollEvent(*event) {


            if event.type == {
                case SDL_QUIT;
                    quit = true;
                case SDL_KEYDOWN;
                    if event.key.keysym.sym == SDLK_UP key_up         = true;
                    if event.key.keysym.sym == #char "h" key_up       = true;//Beakl43 support
                    if event.key.keysym.sym == #char "w" key_up       = true;

                    if event.key.keysym.sym == SDLK_DOWN key_down     = true;
                    if event.key.keysym.sym == #char "i" key_down       = true;//Beakl43 support
                    if event.key.keysym.sym == #char "s" key_down       = true;

                    if event.key.keysym.sym == SDLK_RIGHT key_right   = true;
                    if event.key.keysym.sym == #char "e" key_right       = true;//Beakl43 support
                    if event.key.keysym.sym == #char "d" key_right       = true;

                    if event.key.keysym.sym == SDLK_LEFT key_left     = true;
                    if event.key.keysym.sym == #char "j" key_left       = true;//Beakl43 support
                    if event.key.keysym.sym == #char "a" key_left       = true;


                    if event.key.keysym.sym == SDLK_SPACE key_space   = true;
                    if event.key.keysym.sym == SDLK_RETURN{
                        key_slow_mo.is_pressed = true;
                        if !key_slow_mo.awaits_reset {
                            key_slow_mo.awaits_reset = true;
                            key_slow_mo.was_just_pressed = true;
                        }
                    }
                    if event.key.keysym.sym == SDLK_F1{
                        key_debug_draw.is_pressed = true;
                        if !key_debug_draw.awaits_reset {
                            key_debug_draw.awaits_reset = true;
                            key_debug_draw.was_just_pressed = true;
                        }
                    }
                    if event.key.keysym.sym == #char "r"{
                        key_restart.is_pressed = true;
                        if !key_restart.awaits_reset {
                            key_restart.awaits_reset = true;
                            key_restart.was_just_pressed = true;
                        }
                    }
                    if event.key.keysym.sym == #char "u"{
                        key_restart.is_pressed = true;
                        if !key_restart.awaits_reset {
                            key_restart.awaits_reset = true;
                            key_restart.was_just_pressed = true;
                        }
                    }
                    if event.key.keysym.sym == #char "p"{
                        key_pause.is_pressed = true;
                        if !key_pause.awaits_reset {
                            key_pause.awaits_reset = true;
                            key_pause.was_just_pressed = true;
                        }
                    }
                case SDL_KEYUP;
                    if event.key.keysym.sym == SDLK_ESCAPE quit       = true;

                    if event.key.keysym.sym == SDLK_UP key_up         = false;
                    if event.key.keysym.sym == #char "h" key_up       = false;//Beakl43 support
                    if event.key.keysym.sym == #char "w" key_up       = false;

                    if event.key.keysym.sym == SDLK_DOWN key_down     = false;
                    if event.key.keysym.sym == #char "i" key_down       = false;//Beakl43 support
                    if event.key.keysym.sym == #char "s" key_down       = false;

                    if event.key.keysym.sym == SDLK_RIGHT key_right   = false;
                    if event.key.keysym.sym == #char "e" key_right       = false;//Beakl43 support
                    if event.key.keysym.sym == #char "d" key_right       = false;

                    if event.key.keysym.sym == SDLK_LEFT key_left     = false;
                    if event.key.keysym.sym == #char "j" key_left       = false;//Beakl43 support
                    if event.key.keysym.sym == #char "a" key_left       = false;

                    if event.key.keysym.sym == SDLK_SPACE key_space   = false;
                    if event.key.keysym.sym == SDLK_RETURN key_slow_mo = .{was_just_pressed = false, is_pressed = false,awaits_reset=false};

                    if event.key.keysym.sym == SDLK_F1 key_debug_draw = .{was_just_pressed = false, is_pressed = false,awaits_reset=false};
                    if event.key.keysym.sym == #char "r" key_restart = .{was_just_pressed = false, is_pressed = false,awaits_reset=false};
                    if event.key.keysym.sym == #char "u" key_restart = .{was_just_pressed = false, is_pressed = false,awaits_reset=false};
                    if event.key.keysym.sym == #char "p" key_pause = .{was_just_pressed = false, is_pressed = false,awaits_reset=false};

            }
        }

        process_input();
        process_logic();
        new_render_stuff();
        SDL_GL_SwapWindow(window);

        reset_temporary_storage();
        //print("\nFPS: %",1/dt);

        //Wait routine
        target_delta := 1.0 / cast(float64) FPS_TARGET;

        sleep_ms := cast(s32) target_delta;

        if (sleep_ms > 0)
            sleep_milliseconds(sleep_ms);

        while seconds_since_init() < now + target_delta { }

        last_time = now;
        frame_counter+=1;
    }
    SDL_DestroyWindow(window);
    SDL_Quit();
}

init_game :: () {
    test_point = CENTER_POINT;
    snake.head = CENTER_POINT;

    //sarray_reserve(*snake.tail,500);//Should I be doing this? Not sure.
    //print("\ncount: %, allocated: %",snake.tail_graphic.count,snake.tail_graphic.allocated);
    //array_reserve(*snake.tail_graphic,snake.tail.allocated*2);
    generate_walls();
    generate_map_details();
    create_base_tail();
    is_alive = true;
    for 0..2 {
        create_new_pickup_at_random(get_random_pickup_type(),0.5*HEAD_SIZE);
    }
    for *pickup : pickups {
        calculate_next_pickup_target(pickup);
    }
    //array_add(*graphics.tail_cuts,50);
    //array_add(*graphics.tail_cuts,100);
}

generate_map_details :: () {
    array_reset(*map_details);
    //Generate details
    for i : 0..WINDOW_WIDTH/(WALL_SIZE*2)-1 {

        /*if it % 2 != 0 then
            continue;
            */
        for j : 0..WINDOW_HEIGHT/(WALL_SIZE*2)-1 {

            if random_get_within_range(0,100) > 75 {
                pos := Vector2.{xx (i*(WALL_SIZE*2) + WALL_SIZE),xx (j*(WALL_SIZE*2) + WALL_SIZE)};
                pos.x += PADDING;
                pos.y += PADDING;
                array_add(*map_details,MapDetail.{pos,xx
                random_get_within_range(40,43)});
            }
        }
    }
}

generate_walls :: () {

    array_reset(*obstacles);
    //Generate obstacles
    for i : 1..WINDOW_WIDTH/(WALL_SIZE*2)-3 {

        /*if it % 2 != 0 then
            continue;
            */
        for j : 1..WINDOW_HEIGHT/(WALL_SIZE*2)-3 {

            if random_get_within_range(0,100) > 95 {
                pos := Vector2.{xx (i*(WALL_SIZE*2) + WALL_SIZE),xx (j*(WALL_SIZE*2) + WALL_SIZE)};
                pos.x += PADDING;
                pos.y += PADDING;
                array_add(*obstacles,Obstacle.{pos,WALL_SIZE});
            }
        }
    }
}

update_tail_graphic :: () {
    //print("\nCuts: %, Count: %",graphics.tail_cuts,graphics.tail_cuts.count);
    prev := snake.head;
    last_pc := cycle_point2(snake.head);
    graphics.tail_cuts.count = 0;
    for i : 0..snake.tail.count-1 {
        dir_to_last := normalize(prev - snake.tail[i]);

        scale : float = 1.0 - (cast(float)(i) / (snake.tail.count*TAIL_END_CUTOFF_MULT-1));

        pc := cycle_point2(prev);

        p0 := pc + rotate(dir_to_last,TAU/4.0)*scale*HEAD_SIZE;
        p1 := pc + rotate(dir_to_last,-TAU/4.0)*scale*HEAD_SIZE;


        if distance(last_pc,pc) >= 10 {
            array_add(*graphics.tail_cuts,xx ((i)*2));
        }

        tail_repeat_factor := 2.0;
        uv_y := cast(float)(i/tail_repeat_factor) / (snake.tail.count/tail_repeat_factor-1);
        graphics.tail[i*2] = .{p0.x,p0.y,0.0,uv_y};
        graphics.tail[(i*2)+1] = .{p1.x,p1.y,1.0,uv_y};

        prev = snake.tail[i];
        last_pc = pc;
    }
}

kill :: () {
    is_alive = false;
    time_scale = 0;
    shake_camera(0.2,10);
    print("\n[%]You lost!",frame_counter);
}

cut_tail_at :: (index : int) {
    snake.tail.count = index;
    graphics.tail.count = index*2;
}

restart_game :: () {
    generate_walls();
    generate_map_details();
    time_scale = 1.0;
    destroy_tail();
    snake.head = CENTER_POINT;
    direction = .{1,0};
    create_base_tail();
    is_alive = true;
}

create_base_tail :: () {
    for 0..49 {
        add_to_tail(CENTER_POINT-Vector2.{(it)*DISTANCE_BETWEEN_TAIL_POINTS*2,0});
    }
}

process_input :: () {

    if is_alive {
        input.x = ifx key_left then -1.0 else 0.0 + ifx key_right then 1.0 else 0.0;
        input.y = ifx key_down then 1.0 else 0.0 + ifx key_up then -1.0 else 0.0;
    }

    x_state := ifx key_left then -1 else 0.0 + ifx key_right then 1.0 else 0.0;
    y_state := ifx key_down then -1 else 0.0 + ifx key_up then 1.0 else 0.0;

    strength := 1;
    if x_state != 0 then
        inputv2.x = clamp(inputv2.x + x_state*dt*strength,-1.0,1.0);
    else
        inputv2.x *= 0.6;

    if y_state != 0 then
        inputv2.y = clamp(inputv2.y + y_state*dt*strength,-1.0,1.0);
    else
        inputv2.y *= 0.6;

    if input != .{0,0} && (direction + input) != .{0,0} {
        direction = normalize(lerp(direction,normalize(input),dt*10));
    }
    //direction = (inputv2);
    //Debug
    test_point.x += direction.x*speed*dt;
    test_point.y += direction.y*speed*dt;

    if key_space{
        add_to_tail();
    }

    //print("\nKey: pressed: %,awaits: %",key_return.was_just_pressed,key_return.awaits_reset);
    if key_slow_mo.was_just_pressed {
        time_scale = ifx time_scale == 1.0 then 0.1 else 1.0;
    }

    if key_pause.was_just_pressed {
        if time_scale > 0.0 then
            time_scale = 0.0;
        else
            time_scale = 1.0;
    }

    if key_debug_draw.was_just_pressed {
        IS_DEBUGGING_GRAPHICS = !IS_DEBUGGING_GRAPHICS;
    }

    if key_restart.was_just_pressed {
        restart_game();
    }
}

process_logic :: () {
    if !is_alive then
        return;

    //Time slow
    if time_slow_counter > 0.0 {
        time_scale = min(time_scale + u_dt/time_slow_time,1.0);
        time_slow_counter = max(time_slow_counter-u_dt,0.0);
    }

    //Move head
    move_dir := direction;
    move_dir += (rotate(direction,TAU/4) * (cast(float)sin(last_time*15))*15)*dt;
    snake.head += move_dir * speed * dt;

    //Move body
    prev_point := snake.head;
    for 0..snake.tail.count-1 {
        snake.tail[it] = constraint_distance(snake.tail[it],prev_point,DISTANCE_BETWEEN_TAIL_POINTS);
        prev_point = snake.tail[it];
    }

    //Move rats
    for *pickup : pickups {
        if pickup.type != .RAT then
            continue;
        dist := distance(pickup.target,pickup.point);
        if dist < 0.01 {
            calculate_next_pickup_target(pickup);
            continue;
        }
        dir := normalize(pickup.target - pickup.point);

        pickup.point = move_towards(pickup.point,pickup.target,25);
        //pickup.point.x += dir.x*dt*100;
    }

    //Consume queued tail grows
    if tail_points_to_add > 0 {
        if tail_adding_counter <= 0.0 {
            add_to_tail();
            tail_adding_counter = TAIL_ADD_DELAY;
            tail_points_to_add -= 1;
        }else {
            tail_adding_counter -= dt;
        }
    }

    resolve_collisions();
}

is_outside_game_area :: (point : Vector2) -> bool {
   return (point.x < 0 || point.x > BASE_WIDTH ||
           point.y < 0 || point.y > BASE_HEIGHT);
}

destroy_tail :: () {
    for #v2 < 0..snake.tail.count-1 {
        remove_from_tail(it);
    }

}

add_to_tail :: () {
    dir := ifx snake.tail.count > 1 then snake.tail[snake.tail.count-1] - snake.tail[snake.tail.count-2] else direction;

    array_add(*snake.tail, snake.tail[snake.tail.count-1] + dir);

    point := snake.tail[snake.tail.count-1] + dir;
    array_add(*graphics.tail, .{point.x,point.y,0,0});
    array_add(*graphics.tail, .{point.x,point.y,0,0});

    glBindBuffer(GL_ARRAY_BUFFER,tail_VBO);
    glBufferData(GL_ARRAY_BUFFER,4*graphics.tail.count*size_of(float),graphics.tail.data,GL_DYNAMIC_DRAW);
}
add_to_tail :: (pos : Vector2) {
    array_add(*snake.tail, pos);

    array_add(*graphics.tail, .{pos.x,pos.y,0,0});
    array_add(*graphics.tail, .{pos.x,pos.y,0,0});
}
add_to_tail_deferred :: () {
    tail_points_to_add += 1;
}

remove_from_tail :: (index : int) {
    array_ordered_remove_by_index(*snake.tail,index);

    array_ordered_remove_by_index(*graphics.tail,(index*2)+1);
    array_ordered_remove_by_index(*graphics.tail,index*2);
}

create_new_pickup :: (type : Pickup_Type, point : Vector2, radius : float) {
    array_add(*pickups,.{point,radius,type,.{},0.0});
}

create_new_pickup_at_random :: (type : Pickup_Type, radius : float){
    random_pos := Vector2.{random_get_within_range(0,WINDOW_WIDTH),random_get_within_range(0,WINDOW_HEIGHT)};
    create_new_pickup(type,random_pos,radius);
}

destroy_pickup :: (index : int) {
    array_ordered_remove_by_index(*pickups,index);
}

prepare_render :: () {
    //Shaders
    tail_shader = create_shader_program("shaders/tail/tail_vertex.glsl","shaders/tail/tail_fragment.glsl");

    glEnable(GL_MULTISAMPLE);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glHint(GL_POLYGON_SMOOTH_HINT, GL_NICEST);

    //**********************************
    //******Resources loading***********
    //**********************************
    //stbi_set_flip_vertically_on_load(1);

    //ATLAS
    {
        glGenTextures(1,*sprite_atlas_texture);
        glBindTexture(GL_TEXTURE_2D,sprite_atlas_texture);

        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

        nr_channels : s32;

        sprite_atlas = stbi_load("sprites/sprites_atlas.png",*sprite_atlas_width,*sprite_atlas_height,*nr_channels,4);
        if sprite_atlas {
            glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA,xx sprite_atlas_width,xx sprite_atlas_height,0,GL_RGBA,GL_UNSIGNED_BYTE,sprite_atlas);
            glGenerateMipmap(GL_TEXTURE_2D);
        } else {
            print("\nFailed to load texture: sprites_atlas.png");
        }
        sprite_atlas_uv_size = .{SPRITE_ATLAS_SIZE/sprite_atlas_width,SPRITE_ATLAS_SIZE/sprite_atlas_height};
        sprite_atlas_uv_correction_offset = .{1.0 / (sprite_atlas_width/4),1.0 / (sprite_atlas_height/4)};
        print("\nSprite Atlas UV Correction offset: %",sprite_atlas_uv_correction_offset);
        sprite_atlas_uv_size -= sprite_atlas_uv_correction_offset;
        stbi_image_free(sprite_atlas);
    }
    //HEAD TEXTURE
    /*
    {
        glGenTextures(1,*head_texture);
        glBindTexture(GL_TEXTURE_2D,head_texture);

        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

        width       : s32;
        height      : s32;
        nr_channels : s32;

        data := stbi_load("sprites/snake_head.png",*width,*height,*nr_channels,4);
        if data {
            glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA,xx width,xx height,0,GL_RGBA,GL_UNSIGNED_BYTE,data);
            glGenerateMipmap(GL_TEXTURE_2D);
        } else {
            print("\nFailed to load texture: snake_head.png");
        }
        stbi_image_free(data);
    }
    //TAIL TEXTURE
    {
        glGenTextures(1,*tail_texture);
        glBindTexture(GL_TEXTURE_2D,tail_texture);

        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

        width       : s32;
        height      : s32;
        nr_channels : s32;

        data := stbi_load("sprites/snake_body.png",*width,*height,*nr_channels,4);
        if data {
            glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA,xx width,xx height,0,GL_RGBA,GL_UNSIGNED_BYTE,data);
            glGenerateMipmap(GL_TEXTURE_2D);
        } else {
            print("\nFailed to load texture: snake_body.png");
        }
        stbi_image_free(data);
    }
    //Apple TEXTURE
    {
        glGenTextures(1,*apple_texture);
        glBindTexture(GL_TEXTURE_2D,apple_texture);

        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

        width       : s32;
        height      : s32;
        nr_channels : s32;

        data := stbi_load("sprites/apple.png",*width,*height,*nr_channels,4);
        if data {
            glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA,xx width,xx height,0,GL_RGBA,GL_UNSIGNED_BYTE,data);
            glGenerateMipmap(GL_TEXTURE_2D);
        } else {
            print("\nFailed to load texture: apple.png");
        }
        stbi_image_free(data);
    }
    //Rat TEXTURE
    {
        glGenTextures(1,*rat_texture);
        glBindTexture(GL_TEXTURE_2D,rat_texture);

        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

        width       : s32;
        height      : s32;
        nr_channels : s32;

        data := stbi_load("sprites/rat.png",*width,*height,*nr_channels,4);
        if data {
            glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA,xx width,xx height,0,GL_RGBA,GL_UNSIGNED_BYTE,data);
            glGenerateMipmap(GL_TEXTURE_2D);
        } else {
            print("\nFailed to load texture: rat.png");
        }
        stbi_image_free(data);
    }
    */
    //**********************************
    //***************Tail***************
    //**********************************

    //VBO
    glGenBuffers(1,*tail_VBO);
    glBindBuffer(GL_ARRAY_BUFFER,tail_VBO);
    glBufferData(GL_ARRAY_BUFFER,4*graphics.tail.count*size_of(float) + 50,graphics.tail.data,GL_DYNAMIC_DRAW);
    //VAO
    glGenVertexArrays(1,*tail_VAO);
    glBindVertexArray(tail_VAO);
    //Vertex Pointers
    glVertexAttribPointer(0,2,GL_FLOAT,GL_FALSE,4*size_of(float),xx 0);
    glEnableVertexAttribArray(0);
    //Texture uvs
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE,4*size_of(float), xx (2 * size_of(float)));
    glEnableVertexAttribArray(1);

    //***********************************
    //***************HEAD****************
    //***********************************

    //VBO
    glGenBuffers(1,*head_VBO);
    glBindBuffer(GL_ARRAY_BUFFER,head_VBO);
    glBufferData(GL_ARRAY_BUFFER,sprite_quad_vertices.count*size_of(float),sprite_quad_vertices.data,GL_STATIC_DRAW);
    //VAO
    glGenVertexArrays(1,*head_VAO);
    glBindVertexArray(head_VAO);
    //Vertex Pointers
    glVertexAttribPointer(0,2,GL_FLOAT,GL_FALSE,4*size_of(float),xx 0);
    glEnableVertexAttribArray(0);
    //Texture uvs
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE,4*size_of(float), xx (2 * size_of(float)));
    glEnableVertexAttribArray(1);

    //EBO
    glGenBuffers(1,*head_EBO);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, head_EBO);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sprite_indices.count*size_of(u32),*sprite_indices,GL_STATIC_DRAW);
    //glUniform1i(glGetUniformLocation(tail_shader, "text"), 0);


    //***********************************
    //***************APPLE****************
    //***********************************

//*****END PREPARE RENDER*****
    //glPolygonMode( GL_FRONT_AND_BACK, GL_LINE );

}

new_render_stuff :: () {

    error := glGetError();
    if error != GL_NO_ERROR then
        print("\nOpenGL Error: 0x0%",formatInt(error,16));

    glViewport(xx -(PADDING),xx -(PADDING),xx (WINDOW_WIDTH+PADDING*2),xx (WINDOW_HEIGHT+PADDING*2));

    update_tail_graphic();

    glClearColor(0.369, 0.69, 0.588,1.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glUseProgram(tail_shader);

    model_location      := glGetUniformLocation(tail_shader, "model");
    view_location       := glGetUniformLocation(tail_shader, "view");
    projection_location := glGetUniformLocation(tail_shader, "projection");
    tint_location       := glGetUniformLocation(tail_shader, "tint");
    uv_size_location       := glGetUniformLocation(tail_shader, "uv_size");
    uv_offset_location       := glGetUniformLocation(tail_shader, "uv_offset");

    //View
    view := Matrix4_Identity;

    cam_shake : Vector2;

    if cam_shake_counter > 0.0 {
        cam_shake = Vector2.{random_get_within_range(-1.0,1.0),random_get_within_range(-1.0,1.0)};
        cam_shake_counter -= u_dt;
    }
    view = make_translation_matrix4(.{camera_pos.x+cam_shake.x*cam_shake_strength,camera_pos.y+cam_shake.x*cam_shake_strength,0});
    //Projection
    projection := orthographic_projection_matrix(0.0,WINDOW_WIDTH,WINDOW_HEIGHT,0.0,-1.0,1.0);

    //****************
    //Drawing Map Details
    //****************
    for detail : map_details {
        detail_model :=  translate(Matrix4_Identity,cycle_point3(detail.point)) * scale(Matrix4_Identity,Vector3.{1,1,1}*HEAD_SIZE*4);

        glBindVertexArray(head_VAO);
        glUniformMatrix4fv(model_location     , 1, GL_TRUE, xx *detail_model);
        glUniformMatrix4fv(view_location      , 1, GL_TRUE, xx *view);
        glUniformMatrix4fv(projection_location, 1, GL_TRUE, xx *projection);
        glUniform3f(tint_location, 1,1,1);
        glUniform2f(uv_size_location,sprite_atlas_uv_size.x,sprite_atlas_uv_size.y);
        glBindBuffer(GL_ARRAY_BUFFER,head_VBO);//@TODO: CHANGE head_VBO to sprites_VBO

        uv_offset : Vector2;
        glBindTexture(GL_TEXTURE_2D, sprite_atlas_texture);
        uv_offset = get_atlas_uv_offset(xx detail.graphic);
        glUniform2f(uv_offset_location,uv_offset.x,uv_offset.y);
        glDrawElements(GL_TRIANGLES, xx sprite_indices.count, GL_UNSIGNED_INT, null);


        glBindBuffer(GL_ARRAY_BUFFER,0);
        glBindTexture(GL_TEXTURE_2D,0);
    }

    //****************
    //Drawing Obstacles
    //****************
    for obstacle : obstacles {
        obstacle_model :=  translate(Matrix4_Identity,cycle_point3(obstacle.point)) * scale(Matrix4_Identity,Vector3.{1,1,1}*obstacle.radius*2);

        glBindVertexArray(head_VAO);
        glUniformMatrix4fv(model_location     , 1, GL_TRUE, xx *obstacle_model);
        glUniformMatrix4fv(view_location      , 1, GL_TRUE, xx *view);
        glUniformMatrix4fv(projection_location, 1, GL_TRUE, xx *projection);
        glUniform3f(tint_location, 1,1,1);
        glUniform2f(uv_size_location,sprite_atlas_uv_size.x,sprite_atlas_uv_size.y);
        glBindBuffer(GL_ARRAY_BUFFER,head_VBO);//@TODO: CHANGE head_VBO to sprites_VBO

        uv_offset : Vector2;
        glBindTexture(GL_TEXTURE_2D, sprite_atlas_texture);
        uv_offset = get_atlas_uv_offset(30);
        glUniform2f(uv_offset_location,uv_offset.x,uv_offset.y);
        glDrawElements(GL_TRIANGLES, xx sprite_indices.count, GL_UNSIGNED_INT, null);


        glBindBuffer(GL_ARRAY_BUFFER,0);
        glBindTexture(GL_TEXTURE_2D,0);
    }

    //****************
    //Drawing Pickups
    //****************
    for pickup : pickups {
        dir := ifx pickup.point.x < pickup.target.x then 1.0 else -1.0;
        pickup_model :=  translate(Matrix4_Identity,floor_vector3(cycle_point3(pickup.point))) * scale(Matrix4_Identity,Vector3.{1 * dir,1,1}*HEAD_SIZE*2);

        glBindVertexArray(head_VAO);
        glUniformMatrix4fv(model_location     , 1, GL_TRUE, xx *pickup_model);
        glUniformMatrix4fv(view_location      , 1, GL_TRUE, xx *view);
        glUniformMatrix4fv(projection_location, 1, GL_TRUE, xx *projection);
        glUniform3f(tint_location, 1,1,1);
        glUniform2f(uv_size_location,sprite_atlas_uv_size.x,sprite_atlas_uv_size.y);
        glBindBuffer(GL_ARRAY_BUFFER,head_VBO);

        uv_offset : Vector2;
        glBindTexture(GL_TEXTURE_2D, sprite_atlas_texture);
        if pickup.type == {
            case .APPLE;
                uv_offset = get_atlas_uv_offset(20);
            case .RAT;
                uv_offset = get_atlas_uv_offset(21);
        }
        glUniform2f(uv_offset_location,uv_offset.x,uv_offset.y);
        glDrawElements(GL_TRIANGLES, xx sprite_indices.count, GL_UNSIGNED_INT, null);


        glBindBuffer(GL_ARRAY_BUFFER,0);
        glBindTexture(GL_TEXTURE_2D,0);
    }



    //****************
    //Drawing Tailtip
    //****************
    //Model
    {
        tail_direction := normalize(snake.tail[snake.tail.count-3]-snake.tail[snake.tail.count-2]);
        angle := angle_between(.{0,-1},tail_direction);
        tail_tip_rotation : Quaternion;
        set_from_axis_and_angle(*tail_tip_rotation,.{0,0,1},xx angle);
        head_model :=  translate(Matrix4_Identity,cycle_point3(snake.tail[snake.tail.count-2])) * scale(Matrix4_Identity,Vector3.{1,1,1}*HEAD_SIZE*2.25)  * rotate(Matrix4_Identity,tail_tip_rotation);

        glBindVertexArray(head_VAO);
        glUniformMatrix4fv(model_location     , 1, GL_TRUE, xx *head_model);
        glUniformMatrix4fv(view_location      , 1, GL_TRUE, xx *view);
        glUniformMatrix4fv(projection_location, 1, GL_TRUE, xx *projection);
        glUniform3f(tint_location, 1,1,1);

        uv_offset := get_atlas_uv_offset(xx 19);
        glUniform2f(uv_size_location,sprite_atlas_uv_size.x,sprite_atlas_uv_size.y);
        glUniform2f(uv_offset_location,uv_offset.x,uv_offset.y);
        glBindBuffer(GL_ARRAY_BUFFER,head_VBO);
        //glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, sprite_atlas_texture);
        glDrawElements(GL_TRIANGLES, xx sprite_indices.count, GL_UNSIGNED_INT, null);
    }

    //****************
    //Drawing Under Head
    //****************
    //Model
    {
        head_model :=  translate(Matrix4_Identity,cycle_point3(snake.head)) * scale(Matrix4_Identity,Vector3.{1,1,1}*HEAD_SIZE*2);


        glBindVertexArray(head_VAO);
        glUniformMatrix4fv(model_location     , 1, GL_TRUE, xx *head_model);
        glUniformMatrix4fv(view_location      , 1, GL_TRUE, xx *view);
        glUniformMatrix4fv(projection_location, 1, GL_TRUE, xx *projection);
        glUniform3f(tint_location, 1,1,1);
        
        uv_offset := get_atlas_uv_offset(xx 3);
        glUniform2f(uv_size_location,sprite_atlas_uv_size.x,sprite_atlas_uv_size.y);
        glUniform2f(uv_offset_location,uv_offset.x,uv_offset.y);
        glBindBuffer(GL_ARRAY_BUFFER,head_VBO);
        //glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, sprite_atlas_texture);
        glDrawElements(GL_TRIANGLES, xx sprite_indices.count, GL_UNSIGNED_INT, null);
    }


    //****************
    //Drawing Tail
    //****************
    {
        glBindVertexArray(tail_VAO);

        tail_model := Matrix4_Identity;
        glUniformMatrix4fv(model_location     , 1, GL_TRUE, xx *tail_model);
        glUniformMatrix4fv(view_location      , 1, GL_TRUE, xx *view);
        glUniformMatrix4fv(projection_location, 1, GL_TRUE, xx *projection);
        glUniform3f(tint_location, 1,1,1);
        uv_offset := get_atlas_uv_offset(10);
        glUniform2f(uv_size_location,sprite_atlas_uv_size.x,sprite_atlas_uv_size.y);
        glUniform2f(uv_offset_location,uv_offset.x,uv_offset.y);
        glBindBuffer(GL_ARRAY_BUFFER,tail_VBO);
        glBindTexture(GL_TEXTURE_2D, sprite_atlas_texture);
        glBufferSubData(GL_ARRAY_BUFFER,0,4*graphics.tail.count*size_of(float),graphics.tail.data);

        start : s32 = 0;
        for cut : graphics.tail_cuts {
            glDrawArrays(GL_TRIANGLE_STRIP,start,xx (cut-start));
            start = cut;
        }
        glDrawArrays(GL_TRIANGLE_STRIP,start, xx (graphics.tail.count-start));
    }

    //****************
    //Drawing Head
    //****************
    //Model
    {
        angle := angle_between(.{0,-1}, direction);
        set_from_axis_and_angle(*head_rotation,.{0,0,1},xx angle);
        head_model :=  translate(Matrix4_Identity,cycle_point3(snake.head)) * scale(Matrix4_Identity,Vector3.{1,1,1}*HEAD_SIZE*2) * rotate(Matrix4_Identity,head_rotation);


        glBindVertexArray(head_VAO);
        glUniformMatrix4fv(model_location     , 1, GL_TRUE, xx *head_model);
        glUniformMatrix4fv(view_location      , 1, GL_TRUE, xx *view);
        glUniformMatrix4fv(projection_location, 1, GL_TRUE, xx *projection);
        glUniform3f(tint_location, 1,1,1);

        sprite_index := 0;
        if !is_alive {
            sprite_index = 2;
        }
        else{
            sprite_index = ifx is_pickup_nearbyv2(cycle_point2(snake.head),snake.head-snake.tail[0],100.0) then 1 else 0;
        }
        uv_offset := get_atlas_uv_offset(xx sprite_index);
        glUniform2f(uv_size_location,sprite_atlas_uv_size.x,sprite_atlas_uv_size.y);
        glUniform2f(uv_offset_location,uv_offset.x,uv_offset.y);
        glBindBuffer(GL_ARRAY_BUFFER,head_VBO);
        //glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, sprite_atlas_texture);
        glDrawElements(GL_TRIANGLES, xx sprite_indices.count, GL_UNSIGNED_INT, null);
    }
}



generate_fan_circle :: (vertices : *[..]float, radius : float = 1.0, count : int = 8) {
    array_add(vertices,0);
    array_add(vertices,0);
    for 0..count {
        angle_0 := (it / cast(float)count) * TAU;
        array_add(vertices,cos(angle_0) * radius);
        array_add(vertices,sin(angle_0) * radius);
    }
}

Snake :: struct {
    head : Vector2;
    tail : [..]Vector2;
}

GraphicBuffers :: struct {
    tail : [..]Vector4;
    tail_cuts : [..]s32;
}

KeyState :: struct {
    was_just_pressed : bool;
    is_pressed : bool;
    awaits_reset : bool;
}

PickUp :: struct {
    point : Vector2;
    radius : float;
    type : Pickup_Type;

    target : Vector2;
    counter : float;
}

Obstacle :: struct {
    point : Vector2;
    radius : float;
}

MapDetail :: struct {
    point : Vector2;
    graphic : s32;
}

Pickup_Type :: enum u32 {
    START;
    APPLE;
    RAT;
    END;
}

get_atlas_uv_offset :: (index : s32) -> Vector2 {
    y : float = xx (index / (sprite_atlas_width/64));
    y = (y*SPRITE_ATLAS_SIZE) / sprite_atlas_height;
    uv_offset := Vector2.{index * SPRITE_ATLAS_SIZE/sprite_atlas_width,y};
    return uv_offset + sprite_atlas_uv_correction_offset/2;
}

get_pickup_types_count :: () -> u32{
    return xx (Pickup_Type.END-Pickup_Type.START);
}

get_random_pickup_type :: () -> Pickup_Type{
    return cast(Pickup_Type)random_get_within_range(1.0,xx get_pickup_types_count());
}

calculate_next_pickup_target :: (pickup : *PickUp) {
    pickup.target = .{random_get_within_range(0,WINDOW_WIDTH),pickup.point.y};
    pickup.counter = 0.0;
}

is_pickup_nearby :: (point : Vector2, radius : float) -> bool {
    for pickup : pickups {
       if check_circle_collision(point,radius,pickup.point,pickup.radius) return true;
    }
    return false;
}

is_pickup_nearbyv2 :: (point : Vector2, look_direction : Vector2, range : float, dot_treshold : float = 0.5) -> bool {
    for pickup : pickups {
        if distance(point,pickup.point) < range {
            if dot_product(normalize(look_direction),normalize(pickup.point-point)) > dot_treshold then
                return true;
        }
    }
    return false;
}

shake_camera :: (time : float, strength : float) {
    cam_shake_counter = time;
    cam_shake_strength = strength;
}

slow_time_for :: (time : float, time_scale_start : float = 0.0) {
    time_slow_time = time;
    time_slow_counter = time;
    time_scale = time_scale_start;
}

#import "Basic";
#import "Math";
#import "Window_Creation";
#import "GL";
#import "SDL";
#import "Random";
Input :: #import "Input";
#import "stb_image";
#load "shader_program.jai";
#load "src/physics.jai";
#load "src/math.jai";