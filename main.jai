BASE_WIDTH    :: 32;
BASE_HEIGHT   :: 32;

FPS_TARGET :: 9999;

MULTIPLIER :: 1080/48;

WINDOW_WIDTH  :: BASE_WIDTH*MULTIPLIER;
WINDOW_HEIGHT :: BASE_HEIGHT*MULTIPLIER;

CENTER_POINT :: Vector2.{WINDOW_WIDTH-256,WINDOW_HEIGHT/2};
//CENTER_POINT :: Vector2.{0,0};
PADDING :: 10.0;

TAIL_POINTS_SKIPPED :: 20;
TAIL_ADD_DELAY :: 0.05;
DISTANCE_BETWEEN_TAIL_POINTS :: 2.0;
TAIL_END_CUTOFF_MULT :: 1.5;
DIGEST_TIME :: 0.75;

PIXEL_SIZE :: 8;
HEAD_SIZE :: 12;
PICKUP_RADIUS :: 8;
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
tummy_bloats : [10]Vector2;
tummy_counters : [10]float;
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
is_started : bool = false;
test_point : Vector2;
test_circle : Vector2;


Digestion :: struct {
    tail_points_to_add : int;
    tail_adding_counter : float;
}

digesting : [..]Digestion;


tail_VBO : u32;
tail_VAO : u32;
tail_shader : GLuint;
tail_texture : u32;

sprite_shader : GLuint;


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

score : u32;

eat_particles_pool : [..]*Particles_Emitter;

//Sounds
crunch_sound : Sound_Data;
fail_sound : Sound_Data;
music : Sound_Data;

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

    init();
    prepare_render();

    // Enable MSAA
    SDL_GL_SetAttribute(SDL_GL_MULTISAMPLEBUFFERS, 1);
    SDL_GL_SetAttribute(SDL_GL_MULTISAMPLESAMPLES, 8);
    glEnable(GL_MULTISAMPLE);
    //VSync?
    if OS == .WINDOWS wglSwapIntervalEXT(1);

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
        simulate();
        render();
        SDL_GL_SwapWindow(window);

        reset_temporary_storage();
        //print("\nFPS: %",1/dt);

        //Wait routine
        /*target_delta := 1.0 / cast(float64) FPS_TARGET;

        sleep_ms := cast(s32) target_delta;

        if (sleep_ms > 0)
            sleep_milliseconds(sleep_ms);

        while seconds_since_init() < now + target_delta { }
        */
        last_time = now;
        frame_counter+=1;

        update();
    }
    sound_player_shutdown();

    SDL_DestroyWindow(window);
    SDL_Quit();
}

init :: () {

    //Load sounds

    crunch_sound = load_audio_file("sounds/crunch.wav");
    if !crunch_sound.loaded {
        print("\nCouldn't load audio file crunch");
        exit(1);
    }
    fail_sound = load_audio_file("sounds/fail.ogg");
    if !fail_sound.loaded {
        print("\nCouldn't load audio file fail");
        exit(1);
    }

    do_async_audio := (OS != .ANDROID);
    success := sound_player_init(.{update_from_a_thread = do_async_audio});
    assert(success);

    //
    // Create the music stream.
    //
    if false {
        music = load_audio_file("sounds/bailout.ogg");

        if !music.loaded {
            print("Could not load theme music");
            exit(1);
        }

        stream := make_stream(*music, .MUSIC);
        set_repeating(stream, true);
        stream.user_volume_scale *= 0.15;
        start_playing(stream);
    }


    test_point = CENTER_POINT;
    snake.head = CENTER_POINT;

    init_text_renderer();

    init_particles_renderer();
    generate_particles_texture(0,"sprites/blood.png");

    for 0..5 {
        array_add(*eat_particles_pool,generate_particles_system(0,12));
    }

    //sarray_reserve(*snake.tail,500);//Should I be doing this? Not sure.
    //print("\ncount: %, allocated: %",snake.tail_graphic.count,snake.tail_graphic.allocated);
    //array_reserve(*snake.tail_graphic,snake.tail.allocated*2);
    generate_map_details();
    generate_base_tail();

    is_alive = true;
    generate_walls();
    for 0..2 {
        generate_new_pickup_at_random(get_random_pickup_type(),PICKUP_RADIUS);
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

        for j : 1..WINDOW_HEIGHT/(WALL_SIZE*2)-3 {
            //Skip middle row so the snake doesn't immediately crash with a wall
            if j == cast(int)(WINDOW_HEIGHT/(WALL_SIZE*2))/2 -1 {
                continue;
            }

            if random_get_within_range(0,100) > 97 {
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

        tail_percentage := 1.0 - (cast(float)i / snake.tail.count);

        graphics.tail[i*2] =     .{p0.x,p0.y,0.0,uv_y,tail_percentage};
        graphics.tail[(i*2)+1] = .{p1.x,p1.y,1.0,uv_y,tail_percentage};

        prev = snake.tail[i];
        last_pc = pc;
    }
}

kill :: () {

    play_sound(*fail_sound);


    //Particles
    forward_dir := normalize(direction);
    perpendicular := rotate(forward_dir,TAU/4);

    point := cycle_point2(snake.head);

    a := (point - perpendicular*HEAD_SIZE) + forward_dir * HEAD_SIZE;
    b := (point + perpendicular*HEAD_SIZE) + forward_dir * HEAD_SIZE;

    eat_particle := get_available_particles_system(eat_particles_pool);
    if eat_particle != null {
        play_particle_system_random_between_two_point(eat_particle,a,b,forward_dir);
    }

    is_alive = false;
    time_scale = 0;
    shake_camera(0.2,10);
    print("\n[%]You lost!",frame_counter);//nocheckin
}

cut_tail_at :: (index : int) {
    snake.tail.count = index;
    graphics.tail.count = index*2;
}

get_available_particles_system :: (particle_system_pool : [..]*Particles_Emitter) -> *Particles_Emitter{//Consider make this generic
    for particle : particle_system_pool {
        if !particle.is_active then
            return particle;
    }
    return null;
}

play_sound :: (data: *Sound_Data) {
    stream := make_stream(data);
    //stream.user_volume_scale = random_get_within_range(0.5,  1);
    stream.rate_scale        = random_get_within_range(0.75, 1.22);
    start_playing(stream);
}

eat_pickup :: (pickup_index : int) {

    play_sound(*crunch_sound);

    pickup_point := pickups[pickup_index].point;

    snake_head_wraps := Vector2.{floor(snake.head.x/WINDOW_WIDTH),floor(snake.head.y/WINDOW_HEIGHT)};
    snake.head = adjust_wraps(pickup_point,snake_head_wraps);

    //Particles
    forward_dir := normalize(direction);
    perpendicular := rotate(forward_dir,TAU/4);

    a := (pickup_point - perpendicular*HEAD_SIZE) + forward_dir * HEAD_SIZE;
    b := (pickup_point + perpendicular*HEAD_SIZE) + forward_dir * HEAD_SIZE;

    eat_particle := get_available_particles_system(eat_particles_pool);
    if eat_particle != null {
        play_particle_system_random_between_two_point(eat_particle,a,b,(-perpendicular+forward_dir*2));
    }
    eat_particle2 := get_available_particles_system(eat_particles_pool);
    if eat_particle2 != null{
        play_particle_system_random_between_two_point(eat_particle2,a,b,(perpendicular+forward_dir*2));
    }

    found_place := false;
    for i : 0..tummy_bloats.count-1 {
        if length(tummy_bloats[i]) <= 0.0 {
            tummy_bloats[i] = snake.tail[0];
            tummy_counters[i] = 1.0 - (5.0/snake.tail.count);//This 5 is the same as below
            found_place = true;
            break;
        }
    }
    //If no tummy space available just remove the last one, move everything up and set the new one as the first one
    if !found_place {
        for i : 0..tummy_bloats.count-2{
            tummy_bloats[i] = tummy_bloats[i+1];
            tummy_counters[i] = tummy_counters[i+1];
        }

        tummy_bloats[tummy_bloats.count-1] = snake.tail[5];//This 5 is the same as above
        tummy_counters[tummy_counters.count-1] = 1.0 - (5.0/snake.tail.count);//This 5 is the same as above
    }

    destroy_pickup_by_index(pickup_index);
    generate_new_pickup_at_random(get_random_pickup_type(),PICKUP_RADIUS);

    calculate_next_pickup_target(*pickups[pickups.count-1]);
    shake_camera(0.2,1.5);
    //slow_time_for(0.2,0.25);

    score += 100;
}

restart_game :: () {
    score = 0;
    is_started = false;
    generate_walls();
    pickups.count = 0;
    for 0..2 {
        generate_new_pickup_at_random(get_random_pickup_type(),PICKUP_RADIUS);
    }
    for *pickup : pickups {
        calculate_next_pickup_target(pickup);
    }
    //generate_map_details();
    time_scale = 1.0;
    destroy_tail();
    snake.head = CENTER_POINT;
    direction = .{1,0};
    generate_base_tail();
    is_alive = true;

    //Restart digestion
    for *digestion : digesting {
        digestion.tail_points_to_add = 0;
        digestion.tail_adding_counter = 0.0;
    }

    //Restart tummy
    for i : 0..tummy_bloats.count-1 {
        tummy_bloats[i] = .{0.0,0.0};
        tummy_counters[i] = 0.0;
    }
}

generate_base_tail :: () {
    for 0..50 {
        add_to_tail(CENTER_POINT-Vector2.{(it)*DISTANCE_BETWEEN_TAIL_POINTS,0});
    }
    prev_point := snake.head;

    //Constraint
    for 0..snake.tail.count-1 {
            snake.tail[it] = constraint_distance(snake.tail[it],prev_point,DISTANCE_BETWEEN_TAIL_POINTS);
            prev_point = snake.tail[it];
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
        is_started = true;
    }
    //direction = (inputv2);
    //Debug
    test_point.x += direction.x*speed*dt;
    test_point.y += direction.y*speed*dt;

    if key_space{
        //for 0..5 add_to_tail();
        generate_new_pickup_at_random(.APPLE,PICKUP_RADIUS);
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

simulate :: () {
    //Particles
    update_particle_systems(u_dt);

    if !is_alive then
        return;

    //Time slow
    if time_slow_counter > 0.0 {
        time_scale = min(time_scale + u_dt/time_slow_time,1.0);
        time_slow_counter = max(time_slow_counter-u_dt,0.0);
    }

    //Move head
    move_dir : Vector2;
    if is_started {
        move_dir = direction;
        move_dir += rotate(direction,TAU/4)*(cast(float)sin(last_time*15))*0.125;
    }else{
        strife := rotate(direction,TAU/4)*(cast(float)sin(last_time*15))*0.125;
        snake.head += strife * speed * dt;

        for *tail_point, i : snake.tail {
            tail_strife := rotate(direction,TAU/4)*(cast(float)sin(last_time*15 - i*0.0075*HEAD_SIZE*2))*0.125;
            <<tail_point += tail_strife * speed * dt;
        }
    }
    snake.head += move_dir * speed * dt;

    //Move body
    if is_started {
        prev_point := snake.head;
        for 0..snake.tail.count-1 {
            snake.tail[it] = constraint_distance(snake.tail[it],prev_point,DISTANCE_BETWEEN_TAIL_POINTS);
            prev_point = snake.tail[it];
        }
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

        pickup.point = move_towards(pickup.point,pickup.target,1500*dt);
        pickup.counter += dt;
        //pickup.point.x += dir.x*dt*100;
    }

    //@IMPORTANT: This needs a rework to account for multiple digestions
    //Consume queued tail grows

    for #v2 < *digestion, i : digesting {
        if digestion.tail_points_to_add > 0 {
            if digestion.tail_adding_counter <= 0.0 {
                for 0..2 add_to_tail();
                digestion.tail_points_to_add -= 1;
                digestion.tail_adding_counter = TAIL_ADD_DELAY;
                if digestion.tail_points_to_add <= 0 {
                    array_ordered_remove_by_index(*digesting,i);
                }
            }else {
                digestion.tail_adding_counter -= dt/(DIGEST_TIME*snake.tail.count*0.05);//Same here and below
            }
        }
    }

    //Tummy logic
    for i : 0..tummy_bloats.count-1{
        if !(tummy_counters[i] <= 0.0) {
            current_index : u32 = xx ((snake.tail.count-1)*(1.0-tummy_counters[i]));
            tummy_bloats[i] = *cycle_point2(snake.tail[current_index]);
            tummy_counters[i] -= dt/(DIGEST_TIME*snake.tail.count*0.05);//Same here and above
        }else {
            tummy_bloats[i] = Vector2.{0.0,0.0};
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
    array_add(*graphics.tail, .{point.x,point.y,0,0,0});
    array_add(*graphics.tail, .{point.x,point.y,0,0,0});

    glBindBuffer(GL_ARRAY_BUFFER,tail_VBO);
    glBufferData(GL_ARRAY_BUFFER,5*graphics.tail.count*size_of(float),graphics.tail.data,GL_DYNAMIC_DRAW);

    print("\nTail count: %",snake.tail.count);
}
add_to_tail :: (pos : Vector2) {
    array_add(*snake.tail, pos);

    array_add(*graphics.tail, .{pos.x,pos.y,0,0,0});
    array_add(*graphics.tail, .{pos.x,pos.y,0,0,0});
}
add_to_tail_deferred :: (count : int) {
    array_add(*digesting,.{count,0.75});
    //tail_points_to_add += 1;
    //tail_adding_counter = 1.0;
}

remove_from_tail :: (index : int) {
    array_ordered_remove_by_index(*snake.tail,index);

    array_ordered_remove_by_index(*graphics.tail,(index*2)+1);
    array_ordered_remove_by_index(*graphics.tail,index*2);
}

generate_new_pickup :: (type : Pickup_Type, point : Vector2, radius : float) {
    array_add(*pickups,.{point,radius,type,.{},0.0});
}

generate_new_pickup_at_random :: (type : Pickup_Type, radius : float){
    random_pos := Vector2.{random_get_within_range(WALL_SIZE*2,WINDOW_WIDTH-WALL_SIZE*2),random_get_within_range(WALL_SIZE*2,WINDOW_HEIGHT-WALL_SIZE*2)};

    for obstacle : obstacles {
        random_pos = constraint_away_distance(random_pos,obstacle.point,PICKUP_RADIUS*6);
    }
    generate_new_pickup(type,random_pos,radius);
}

destroy_pickup_by_index :: (index : int) {
    array_ordered_remove_by_index(*pickups,index);
}

prepare_render :: () {
    //Shaders
    sprite_shader = create_shader_program("shaders/sprite/sprite_vertex.glsl","shaders/sprite/sprite_fragment.glsl");
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
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

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
        sprite_atlas_uv_size -= sprite_atlas_uv_correction_offset;
        stbi_image_free(sprite_atlas);
    }
    //**********************************
    //***************Tail***************
    //**********************************

    //VBO
    glGenBuffers(1,*tail_VBO);
    glBindBuffer(GL_ARRAY_BUFFER,tail_VBO);
    glBufferData(GL_ARRAY_BUFFER,5*graphics.tail.count*size_of(float) + 100,graphics.tail.data,GL_DYNAMIC_DRAW);
    //VAO
    glGenVertexArrays(1,*tail_VAO);
    glBindVertexArray(tail_VAO);
    //Vertex Pointers
    glVertexAttribPointer(0,2,GL_FLOAT,GL_FALSE,5*size_of(float),xx 0);
    glEnableVertexAttribArray(0);
    //Texture uvs
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE,5*size_of(float), xx (2 * size_of(float)));
    glEnableVertexAttribArray(1);
    //Texture uvs
    glVertexAttribPointer(2, 1, GL_FLOAT, GL_FALSE,5*size_of(float), xx (4 * size_of(float)));
    glEnableVertexAttribArray(2);

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
    //glUniform1i(glGetUniformLocation(sprite_shader, "text"), 0);

//*****END PREPARE RENDER*****
    //glPolygonMode( GL_FRONT_AND_BACK, GL_LINE );


}

render :: () {

    error := glGetError();
    if error != GL_NO_ERROR then
        print("\nOpenGL Error: 0x0%",formatInt(error,16));

    glViewport(xx -(PADDING),xx -(PADDING),xx (WINDOW_WIDTH+PADDING*2),xx (WINDOW_HEIGHT+PADDING*2));

    update_tail_graphic();

    glClearColor(0.369, 0.69, 0.588,1.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glUseProgram(sprite_shader);

    //TODO: @Do this on preprare_render::()
    sprite_model_location      := glGetUniformLocation(sprite_shader, "model");
    sprite_view_location       := glGetUniformLocation(sprite_shader, "view");
    sprite_projection_location := glGetUniformLocation(sprite_shader, "projection");
    sprite_tint_location       := glGetUniformLocation(sprite_shader, "tint");
    sprite_uv_size_location       := glGetUniformLocation(sprite_shader, "uv_size");
    sprite_uv_offset_location       := glGetUniformLocation(sprite_shader, "uv_offset");

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
        glUniformMatrix4fv(sprite_model_location     , 1, GL_TRUE, xx *detail_model);
        glUniformMatrix4fv(sprite_view_location      , 1, GL_TRUE, xx *view);
        glUniformMatrix4fv(sprite_projection_location, 1, GL_TRUE, xx *projection);
        glUniform3f(sprite_tint_location, 1,1,1);
        glUniform2f(sprite_uv_size_location,sprite_atlas_uv_size.x,sprite_atlas_uv_size.y);
        glBindBuffer(GL_ARRAY_BUFFER,head_VBO);//@TODO: CHANGE head_VBO to sprites_VBO

        uv_offset : Vector2;
        glBindTexture(GL_TEXTURE_2D, sprite_atlas_texture);
        uv_offset = get_atlas_uv_offset(xx detail.graphic);
        glUniform2f(sprite_uv_offset_location,uv_offset.x,uv_offset.y);
        glDrawElements(GL_TRIANGLES, xx sprite_indices.count, GL_UNSIGNED_INT, null);


        glBindBuffer(GL_ARRAY_BUFFER,0);
        glBindTexture(GL_TEXTURE_2D,0);
    }

    //****************
    //Drawing Pickups
    //****************
    pickup_rotation : Quaternion;
    for pickup : pickups {
        dir := ifx pickup.point.x < pickup.target.x then 1.0 else -1.0;
        pickup_model :=  translate(Matrix4_Identity,cycle_point3(pickup.point));

        glBindVertexArray(head_VAO);
        glUniformMatrix4fv(sprite_view_location      , 1, GL_TRUE, xx *view);
        glUniformMatrix4fv(sprite_projection_location, 1, GL_TRUE, xx *projection);
        glUniform3f(sprite_tint_location, 1,1,1);
        glUniform2f(sprite_uv_size_location,sprite_atlas_uv_size.x,sprite_atlas_uv_size.y);
        glBindBuffer(GL_ARRAY_BUFFER,head_VBO);

        uv_offset : Vector2;
        glBindTexture(GL_TEXTURE_2D, sprite_atlas_texture);
        if pickup.type == {
            case .APPLE;
                uv_offset = get_atlas_uv_offset(20);
            case .RAT;
                uv_offset = get_atlas_uv_offset(22);
                angle := angle_between(.{0,-1}, normalize(pickup.target - pickup.point));
                set_from_axis_and_angle(*pickup_rotation,.{0,0,1},xx angle);
                pickup_model *= rotate(Matrix4_Identity,pickup_rotation);
        }

        pickup_model *= scale(Matrix4_Identity,Vector3.{1 * dir,1,1}*HEAD_SIZE*2.25);
        glUniformMatrix4fv(sprite_model_location     , 1, GL_TRUE, xx *pickup_model);
        glUniform2f(sprite_uv_offset_location,uv_offset.x,uv_offset.y);
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
        glUniformMatrix4fv(sprite_model_location     , 1, GL_TRUE, xx *obstacle_model);
        glUniformMatrix4fv(sprite_view_location      , 1, GL_TRUE, xx *view);
        glUniformMatrix4fv(sprite_projection_location, 1, GL_TRUE, xx *projection);
        glUniform3f(sprite_tint_location, 1,1,1);
        glUniform2f(sprite_uv_size_location,sprite_atlas_uv_size.x,sprite_atlas_uv_size.y);
        glBindBuffer(GL_ARRAY_BUFFER,head_VBO);//@TODO: CHANGE head_VBO to sprites_VBO

        uv_offset : Vector2;
        glBindTexture(GL_TEXTURE_2D, sprite_atlas_texture);
        uv_offset = get_atlas_uv_offset(30);
        glUniform2f(sprite_uv_offset_location,uv_offset.x,uv_offset.y);
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
        glUniformMatrix4fv(sprite_model_location     , 1, GL_TRUE, xx *head_model);
        glUniformMatrix4fv(sprite_view_location      , 1, GL_TRUE, xx *view);
        glUniformMatrix4fv(sprite_projection_location, 1, GL_TRUE, xx *projection);
        glUniform3f(sprite_tint_location, 1,1,1);

        uv_offset := get_atlas_uv_offset(xx 19);
        glUniform2f(sprite_uv_size_location,sprite_atlas_uv_size.x,sprite_atlas_uv_size.y);
        glUniform2f(sprite_uv_offset_location,uv_offset.x,uv_offset.y);
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
        glUniformMatrix4fv(sprite_model_location     , 1, GL_TRUE, xx *head_model);
        glUniformMatrix4fv(sprite_view_location      , 1, GL_TRUE, xx *view);
        glUniformMatrix4fv(sprite_projection_location, 1, GL_TRUE, xx *projection);
        glUniform3f(sprite_tint_location, 1,1,1);

        uv_offset := get_atlas_uv_offset(xx 3);
        glUniform2f(sprite_uv_size_location,sprite_atlas_uv_size.x,sprite_atlas_uv_size.y);
        glUniform2f(sprite_uv_offset_location,uv_offset.x,uv_offset.y);
        glBindBuffer(GL_ARRAY_BUFFER,head_VBO);
        //glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, sprite_atlas_texture);
        glDrawElements(GL_TRIANGLES, xx sprite_indices.count, GL_UNSIGNED_INT, null);
    }


    //****************
    //Drawing Tail
    //****************
    glUseProgram(tail_shader);
    {
        glBindVertexArray(tail_VAO);
        tail_model_location      := glGetUniformLocation(tail_shader, "model");
        tail_view_location       := glGetUniformLocation(tail_shader, "view");
        tail_projection_location := glGetUniformLocation(tail_shader, "projection");
        tail_tint_location       := glGetUniformLocation(tail_shader, "tint");
        tail_uv_size_location       := glGetUniformLocation(tail_shader, "uv_size");
        tail_uv_offset_location       := glGetUniformLocation(tail_shader, "uv_offset");
        tail_tummy_bloats_location       := glGetUniformLocation(tail_shader, "tummy_bloats");

        tail_model := Matrix4_Identity;
        glUniformMatrix4fv(tail_model_location     , 1, GL_TRUE, xx *tail_model);
        glUniformMatrix4fv(tail_view_location      , 1, GL_TRUE, xx *view);
        glUniformMatrix4fv(tail_projection_location, 1, GL_TRUE, xx *projection);
        glUniform3f(tail_tint_location, 1,1,1);
        glUniform2fv(tail_tummy_bloats_location,xx tummy_bloats.count,xx *tummy_bloats);
        uv_offset := get_atlas_uv_offset(10);
        glUniform2f(tail_uv_size_location,sprite_atlas_uv_size.x,sprite_atlas_uv_size.y);
        glUniform2f(tail_uv_offset_location,uv_offset.x,uv_offset.y);
        glBindBuffer(GL_ARRAY_BUFFER,tail_VBO);
        glBindTexture(GL_TEXTURE_2D, sprite_atlas_texture);
        glBufferSubData(GL_ARRAY_BUFFER,0,5*graphics.tail.count*size_of(float),graphics.tail.data);

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
    glUseProgram(sprite_shader);
    {
        angle := angle_between(.{0,-1}, direction);
        set_from_axis_and_angle(*head_rotation,.{0,0,1},xx angle);
        head_model :=  translate(Matrix4_Identity,cycle_point3(snake.head)) * scale(Matrix4_Identity,Vector3.{1,1,1}*HEAD_SIZE*2) * rotate(Matrix4_Identity,head_rotation);


        glBindVertexArray(head_VAO);
        glUniformMatrix4fv(sprite_model_location     , 1, GL_TRUE, xx *head_model);
        glUniformMatrix4fv(sprite_view_location      , 1, GL_TRUE, xx *view);
        glUniformMatrix4fv(sprite_projection_location, 1, GL_TRUE, xx *projection);
        glUniform3f(sprite_tint_location, 1,1,1);

        sprite_index := 0;
        if !is_alive {
            sprite_index = 2;
        }
        else{
            sprite_index = ifx is_pickup_nearbyv2(cycle_point2(snake.head),snake.head-snake.tail[0],100.0) then 1 else 0;
        }
        uv_offset := get_atlas_uv_offset(xx sprite_index);
        glUniform2f(sprite_uv_size_location,sprite_atlas_uv_size.x,sprite_atlas_uv_size.y);
        glUniform2f(sprite_uv_offset_location,uv_offset.x,uv_offset.y);
        glBindBuffer(GL_ARRAY_BUFFER,head_VBO);
        //glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, sprite_atlas_texture);
        glDrawElements(GL_TRIANGLES, xx sprite_indices.count, GL_UNSIGNED_INT, null);
    }

    draw_particles_systems(*view,*projection);


    //****************
    //Drawing Text
    //****************

    if !is_started {
        render_text("Move to start!",WINDOW_WIDTH/2-122,WINDOW_HEIGHT/2 - 64,0.75,.{0.369, 0.69, 0.588}*0.5,*  transpose(projection));
        render_text("Move to start!",WINDOW_WIDTH/2-124,WINDOW_HEIGHT/2 - 64,0.75,.{0.369, 0.69, 0.588}*0.75,* transpose(projection));
    } else if is_alive {
        text := tprint("Score: %",score);
        render_text(text,WINDOW_WIDTH/2-56, 18,0.5,.{0.369, 0.69, 0.588}*0.75,* transpose(projection));

    }

    if !is_alive {
        render_text("Game over!",WINDOW_WIDTH/2-82,WINDOW_HEIGHT/2 - 32,0.75,.{0.369, 0.69, 0.588}*0.5,* transpose(projection));

        score_text := tprint("Score: %",score);
        render_text(score_text,WINDOW_WIDTH/2-42,WINDOW_HEIGHT/2 + 8,0.5,.{0.369, 0.69, 0.588}*0.5,* transpose(projection));

    }

    if true{
        text := tprint("FPS: %",cast(int)(1/u_dt));
        render_text(text,16,WINDOW_HEIGHT -32,0.5,.{0.369, 0.69, 0.588}*0.75,* transpose(projection));
    } else {
        print("\nFPS: %",cast(int)(1/dt));//nocheckin
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

TummyBloat :: struct {
    point : Vector2;
    counter : float;
}

GraphicBuffers :: struct {
    tail : [..]Vector5;
    tail_cuts : [..]s32;
}

Vector5 :: struct {
    x : float;
    y : float;
    z : float;
    w : float;
    k : float;
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
    pickup.target = .{random_get_within_range(0,WINDOW_WIDTH),random_get_within_range(0,WINDOW_HEIGHT)};
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
#import "Sound_Player";

#load "src/shader_program.jai";
#load "src/physics.jai";
#load "src/math.jai";
#load "src/text_renderer.jai";
#load "src/particles_renderer.jai";