    BASE_WIDTH    :: 32;
BASE_HEIGHT   :: 32;

FPS_TARGET :: 240;

MULTIPLIER :: 1080/48;

WINDOW_WIDTH  :: BASE_WIDTH*MULTIPLIER;
WINDOW_HEIGHT :: BASE_HEIGHT*MULTIPLIER;

CENTER_POINT :: Vector2.{WINDOW_WIDTH/2,WINDOW_HEIGHT/2};
//CENTER_POINT :: Vector2.{0,0};

TAIL_POINTS_SKIPPED :: 10;
TAIL_ADD_DELAY :: 0.1;
DISTANCE_BETWEEN_TAIL_POINTS :: 5.0;

PIXEL_SIZE :: 8;
HEAD_SIZE :: 12;

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

direction : Vector2 = .{1,0};
input := Vector2.{0,0};
inputv2 := Vector2.{0,0};
speed : float = 300;
last_time : float64;
dt : float;
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

head_VAO : u32;
head_VBO : u32;
head_vertices : [..]float;

camera_pos : Vector2;

main :: () {
    SDL_Init(SDL_INIT_VIDEO);

    //This seems to be optional
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, xx SDL_GL_CONTEXT_PROFILE_CORE);
    SDL_GL_SetAttribute(SDL_GL_MULTISAMPLESAMPLES, 4);

    window := SDL_CreateWindow("Snake",
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

    create_base_tail();
    is_alive = true;
    for 0..10 {
        create_new_pickup_at_random(Pickup_Type.APPLE,0.5);
    }
}

update_tail_graphic :: () {
    prev := snake.head;
    for 0..snake.tail.count-1 {
        dir_to_last := normalize(prev - snake.tail[it]);

        scale : float = 1.0 - (cast(float)(it) / (snake.tail.count-1));
        p0 := prev + rotate(dir_to_last,TAU/4.0)*scale*HEAD_SIZE;
        p1 := prev + rotate(dir_to_last,-TAU/4.0)*scale*HEAD_SIZE;
        prev = snake.tail[it];

        snake.tail_graphic[it*2] = cycle_point2(p0);
        snake.tail_graphic[(it*2)+1] = cycle_point2(p1);
    }
}

kill :: () {
    is_alive = false;
    time_scale = 0;
    print("\n[%]You lost!",frame_counter);
}

cut_tail_at :: (index : int) {
    snake.tail.count = index;
}

restart_game :: () {
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
    input.x = ifx key_left then -1.0 else 0.0 + ifx key_right then 1.0 else 0.0;
    input.y = ifx key_down then 1.0 else 0.0 + ifx key_up then -1.0 else 0.0;

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
        direction = normalize(input);
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

    //Move head
    move_dir := direction;
    move_dir += (rotate(direction,TAU/4) * (cast(float)sin(last_time*15))*15)*dt;
    snake.head += move_dir * speed * dt;
    //print("\nPos: %",snake.head);
    //Move body
    prev_point := snake.head;
    for 0..snake.tail.count-1 {
        snake.tail[it] = constraint_distance(snake.tail[it],prev_point,DISTANCE_BETWEEN_TAIL_POINTS);
        prev_point = snake.tail[it];
    }
    //@IMPORTANT: All collisions wraps the snake tail and head back to the original viewport


    //Collision of the head with the skipped tail point
    /*for i : 4..TAIL_POINTS_SKIPPED {
        tail_point := snake.tail[i];
        dist := distance(cycle_point(snake.head),cycle_point(tail_point));
        scale : float = 1.0 - (cast(float)i / (snake.tail.count));

        radius := HEAD_SIZE + HEAD_SIZE * scale;
        if dist < radius then
            snake.head = constraint_distance(cycle_point(snake.head),cycle_point(tail_point),radius);
    }*/


    //@IMPORTANT: Consider going backwards on the collision checking to check first the smallest parts of the tail
    //Collision with the dead and the tail

    /*
    for #v2 < i : TAIL_POINTS_SKIPPED..snake.tail.count-1 {
        scale : float = 1.0 - (cast(float)i / (snake.tail.count));
        if check_collision(cycle_point(snake.head),HEAD_SIZE,cycle_point(snake.tail[i]),HEAD_SIZE*scale) {
            print("\nCollided with tail: % of %",i,snake.tail.count);
            print("\nHead at: %, other at: %",cycle_point(snake.head),snake.tail[i]);
            //kill();
            cut_tail_at(i);
            break;
        }
    }

    //Collision of the head with pickups
    for #v2 < pickup,i : pickups {
        if check_collision(cycle_point(snake.head),HEAD_SIZE,cycle_point(pickup.point),pickup.radius) {
            for 0..4 {
                add_to_tail_deferred();
            }
            destroy_pickup(i);
            create_new_pickup_at_random(.APPLE,0.5);
        }
    }

    //Collision of the tail with pickups
    for *tail_point,i : snake.tail {
        for *pickup,j : pickups {
            dist := distance(cycle_point(pickup.point),cycle_point(tail_point));
            scale : float = 1.0 - (cast(float)i / (snake.tail.count));

            radius := pickup.radius + HEAD_SIZE * scale;
            if dist < radius then
                pickup.point = constraint_distance(cycle_point(pickup.point),cycle_point(tail_point),radius);
        }
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
    */
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

    array_add(*snake.tail_graphic, snake.tail[snake.tail.count-1] + dir);
    array_add(*snake.tail_graphic, snake.tail[snake.tail.count-1] + dir);

    glBindBuffer(GL_ARRAY_BUFFER,tail_VBO);
    glBufferData(GL_ARRAY_BUFFER,2*snake.tail_graphic.count*size_of(float),snake.tail_graphic.data,GL_DYNAMIC_DRAW);
}
add_to_tail :: (pos : Vector2) {
    array_add(*snake.tail, pos);

    array_add(*snake.tail_graphic, pos);
    array_add(*snake.tail_graphic, pos);
}
add_to_tail_deferred :: () {
    tail_points_to_add += 1;
}

remove_from_tail :: (index : int) {
    array_ordered_remove_by_index(*snake.tail,index);
}

create_new_pickup :: (type : Pickup_Type, point : Vector2, radius : float) {
    array_add(*pickups,.{point,radius,type});
}

create_new_pickup_at_random :: (type : Pickup_Type, radius : float) {
    array_add(*pickups,.{.{random_get_within_range(0,BASE_WIDTH),random_get_within_range(0,BASE_HEIGHT)},radius,type});
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

    //***********************************
    //***************Head****************
    //***********************************
    generate_fan_circle(*head_vertices,HEAD_SIZE,32);

    glGenVertexArrays(1,*head_VAO);
    glGenBuffers(1,*head_VBO);

    glBindBuffer(GL_ARRAY_BUFFER,head_VBO);
    glBufferData(GL_ARRAY_BUFFER,head_vertices.count*size_of(float),head_vertices.data,GL_STATIC_DRAW);

    glBindVertexArray(head_VAO);

    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0,2,GL_FLOAT,GL_FALSE,2*size_of(float),xx 0);

    //**********************************
    //***************Tail***************
    //**********************************

    //VBO
    glGenBuffers(1,*tail_VBO);
    glBindBuffer(GL_ARRAY_BUFFER,tail_VBO);
    print("\ncount: %",snake.tail_graphic.count);
    glBufferData(GL_ARRAY_BUFFER,2*snake.tail_graphic.count*size_of(float) + 50,snake.tail_graphic.data,GL_DYNAMIC_DRAW);
    //VAO
    glGenVertexArrays(1,*tail_VAO);
    glBindVertexArray(tail_VAO);
    //Vertex Pointers
    glVertexAttribPointer(0,2,GL_FLOAT,GL_FALSE,2*size_of(float),xx 0);
    glEnableVertexAttribArray(0);


}
new_render_stuff :: () {

    update_tail_graphic();

    glClearColor(0.369, 0.69, 0.588,1.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glUseProgram(tail_shader);

    model_location      := glGetUniformLocation(tail_shader, "model");
    view_location       := glGetUniformLocation(tail_shader, "view");
    projection_location := glGetUniformLocation(tail_shader, "projection");
    tint_location       := glGetUniformLocation(tail_shader, "tint");

    glBindVertexArray(head_VAO);
    //View
    view := Matrix4_Identity;
    view = make_translation_matrix4(.{camera_pos.x,camera_pos.y,0});
    //Projection
    projection := orthographic_projection_matrix(0.0,WINDOW_WIDTH,WINDOW_HEIGHT,0.0,-1.0,1.0);
    //Model
    head_model := translate(Matrix4_Identity,cycle_point3(snake.head));

    glUniformMatrix4fv(model_location     , 1, GL_TRUE, xx *head_model);
    glUniformMatrix4fv(view_location      , 1, GL_TRUE, xx *view);
    glUniformMatrix4fv(projection_location, 1, GL_TRUE, xx *projection);
    glUniform3f(tint_location, 0.086, 0.322, 0.306);
    glDrawArrays(GL_TRIANGLE_FAN,0,xx head_vertices.count);


    glBindVertexArray(tail_VAO);

    tail_model := Matrix4_Identity;
    glUniformMatrix4fv(model_location     , 1, GL_TRUE, xx *tail_model);
    glUniformMatrix4fv(view_location      , 1, GL_TRUE, xx *view);
    glUniformMatrix4fv(projection_location, 1, GL_TRUE, xx *projection);
    glUniform3f(tint_location, 1.0, 0.322, 0.306);
    //glBindBuffer(GL_ARRAY_BUFFER,tail_VBO);
    glBufferSubData(GL_ARRAY_BUFFER,0,2*snake.tail_graphic.count*size_of(float),snake.tail_graphic.data);
    glDrawArrays(GL_TRIANGLE_STRIP,0,xx snake.tail_graphic.count);


    err := glGetError();
    if err != GL_NO_ERROR then
        print("\nOpenGL Error: 0x0%",formatInt(err,16));
}
/*
render_stuff :: () {


    glClearColor(0.369, 0.69, 0.588,1.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    //glColor4f(0.086, 0.322, 0.306,1.0);

    width := WINDOW_WIDTH;
    height := WINDOW_HEIGHT;
    //Head
    padding := 10.0;

    head_pos := snake.head;
    head_pos = cycle_point(head_pos,padding);

    glViewport(xx -(padding),xx -(padding),xx (WINDOW_WIDTH+padding*2),xx (WINDOW_HEIGHT+padding*2));
    draw_circle(head_pos,HEAD_SIZE,32);

    //Tail
    glColor4f(0.086, 0.322, 0.306,1.0);

    glBegin(GL_TRIANGLE_STRIP);
    previous_point := snake.head;
    for 0..snake.tail.count-1 {
        center_cycled := previous_point;
        center_cycled = cycle_point(center_cycled,padding);

        tail_cycled := snake.tail[it];
        tail_cycled = cycle_point(tail_cycled,padding);

        dist := distance(tail_cycled, center_cycled);

        previous_point = tail_cycled;
        if dist > 16.0 {
            glEnd();
            glBegin(GL_TRIANGLE_STRIP);
            continue;
        }

        scale : float = 1.0 - (cast(float)(it) / (snake.tail.count));
        dir := normalize(tail_cycled - center_cycled);

        p0 := to_clip_space(center_cycled + rotate(dir, TAU/4)*scale*HEAD_SIZE);
        p1 := to_clip_space(center_cycled + rotate(dir,-TAU/4)*scale*HEAD_SIZE);

        glVertex2f(p0.x,p0.y);
        glVertex2f(p1.x,p1.y);
    }

    //Draw last tip of the tail:
    last_point := cycle_point(snake.tail[snake.tail.count-1],padding);
    dir := normalize(last_point - previous_point);
    p0 := to_clip_space(last_point); //to_clip_space(last_point + rotate(dir, TAU/4)*scale*HEAD_SIZE);

    glVertex2f(p0.x,p0.y);
    glVertex2f(p0.x,p0.y);

    glEnd();

    if IS_DEBUGGING_GRAPHICS then
        glColor4f(0.3, 1, 0.306,1.0); //Debug color

    for pickup : pickups {
        draw_circle(cycle_point(pickup.point),pickup.radius,6);
    }

    //Debug drawing...
    //Circle

    if true {
        if IS_DEBUGGING_GRAPHICS {
            glBegin(GL_LINES);
            draw_wired_circle(cycle_point(snake.head),HEAD_SIZE,16);
            glEnd();
            glColor4f(1.0, 0.0, 0.0,1.0); //Debug color
            for TAIL_POINTS_SKIPPED..snake.tail.count-1 {
                glBegin(GL_LINES);
                scale : float = 1.0 - (cast(float)it / (snake.tail.count));
                center := cycle_point(snake.tail[it]);
                draw_wired_circle(center,scale*HEAD_SIZE,16);
                glEnd();
            }
        }
    }

    //Drawing point dots
    if IS_DEBUGGING_GRAPHICS {
        glColor4f(0.0, 0.0, 0.0,1.0); //Debug color

        //Body
        for point : snake.tail {
            draw_circle(cycle_point(point),0.05);
        }
    }
}
*/
cycle_point3 :: (point : Vector2, padding : float = 0.0) -> Vector3 {
    return .{fmod_cycling(point.x + WINDOW_WIDTH ,  WINDOW_WIDTH),
             fmod_cycling(point.y + WINDOW_HEIGHT,  WINDOW_HEIGHT),
             0};
}
cycle_point2 :: (point : Vector2, padding : float = 0.0) -> Vector2 {
    return .{fmod_cycling(point.x + WINDOW_WIDTH ,  WINDOW_WIDTH),
             fmod_cycling(point.y + WINDOW_HEIGHT,  WINDOW_HEIGHT)};
}

check_collision :: (p0 : Vector2, r0 : float, p1 : Vector2, r1 : float) -> bool {
    return distance(p0,p1) < (r0 +r1);
}

constraint_distance :: (point : Vector2, anchor : Vector2, distance : float) -> Vector2 {
    scale := length(point-anchor);
    return anchor + (normalize(point-anchor) * distance);
}

/*to_clip_space :: (pos : Vector2) -> Vector2 {
    return Vector2.{ ((pos.x/BASE_WIDTH) * 2) - 1, ((pos.y/BASE_HEIGHT) * 2) - 1};
}*/
generate_fan_circle :: (vertices : *[..]float, radius : float = 1.0, count : int = 8) {
    array_add(vertices,0);
    array_add(vertices,0);
    for 0..count {
        angle_0 := (it / cast(float)count) * TAU;
        array_add(vertices,cos(angle_0) * radius);
        array_add(vertices,sin(angle_0) * radius);
    }
}
to_grid :: (position : Vector2) -> Vector2 {
    return .{floor(position.x),floor(position.y)};
}
/*
draw_quad :: (pos : Vector2, size : float) {
    p0 := to_clip_space(pos + Vector2.{-size , size});
    p1 := to_clip_space(pos + Vector2.{-size ,-size});
    p2 := to_clip_space(pos + Vector2.{ size ,-size});
    p3 := to_clip_space(pos + Vector2.{ size , size});

    glVertex2f(p0.x,p0.y);
    glVertex2f(p1.x,p1.y);
    glVertex2f(p2.x,p2.y);

    glVertex2f(p0.x,p0.y);
    glVertex2f(p2.x,p2.y);
    glVertex2f(p3.x,p3.y);
}
*/

/*
draw_circle :: (pos : Vector2, radius : float, count : int = 8) {
    glBegin(GL_TRIANGLE_FAN);
    center := to_clip_space(pos);
    glVertex2f(center.x,center.y);
    for 0..count {
        angle_0 := (it / cast(float)count) * TAU;
        p0 := to_clip_space(pos + .{cos(angle_0),sin(angle_0)}*radius);
        glVertex2f(p0.x,p0.y);
    }
    glEnd();
}*/
/*
draw_wired_circle :: (pos : Vector2, radius : float, count : int = 8) {
    px := to_clip_space(pos + Vector2.{0,1}*radius);
    for 1..count {
        angle_0 := (it / cast(float)count) * TAU;
        angle_1 := ((it-1) / cast(float)count) * TAU;

        p0 := to_clip_space(pos + .{cos(angle_0),sin(angle_0)}*radius);
        p1 := to_clip_space(pos + .{cos(angle_1),sin(angle_1)}*radius);

        glVertex2f(p0.x,p0.y);
        glVertex2f(p1.x,p1.y);
    }
}*/
/*
draw_line :: (p0 : Vector2, p1 : Vector2) {
    clip_point := to_clip_space(p0);
    clip_point2 := to_clip_space(p1);
    glVertex2f(clip_point.x,clip_point.y);
    glVertex2f(clip_point2.x,clip_point2.y);
}*/

Snake :: struct {
    head : Vector2;
    tail : [..]Vector2;
    tail_graphic : [..]Vector2;
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
}
Pickup_Type :: enum u32 {
    APPLE;
    ORANGE;
}
#import "Basic";
#import "Math";
#import "Window_Creation";
#import "GL";
#import "SDL";
#import "Random";
Input :: #import "Input";
#load "shader_program.jai";