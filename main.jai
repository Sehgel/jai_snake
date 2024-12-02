BASE_WIDTH    :: 32;
BASE_HEIGHT   :: 32;
FPS_TARGET :: 240;
MULTIPLIER :: 16;
WINDOW_WIDTH  :: BASE_WIDTH*MULTIPLIER;
WINDOW_HEIGHT :: BASE_HEIGHT*MULTIPLIER;
CENTER_POINT :: Vector2.{BASE_WIDTH/2,BASE_HEIGHT/2};
TAIL_POINTS_SKIPPED :: 10;
DISTANCE_BETWEEN_TAIL_POINTS :: 0.25;

PIXEL_SIZE :: 8;
HEAD_SIZE :: 0.5;

window : Window_Type;

key_left  : bool;
key_right : bool;
key_up    : bool;
key_down  : bool;
key_space : bool;

key_debug_draw : KeyState;
key_slow_mo : KeyState;
key_restart : KeyState;

snake : Snake;
pickups : [..]PickUp;

direction : Vector2 = .{1,0};
input := Vector2.{0,0};
inputv2 := Vector2.{0,0};
speed : float = 20;
last_time : float64;
dt : float;
time_scale : float = 1.0;
frame_counter : u64;
is_alive : bool = false;

test_point : Vector2;
test_circle : Vector2;

//DEBUG
IS_DEBUGGING_GRAPHICS := false;
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

            }
        }

        process_input();
        process_logic();
        render_stuff();
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
    create_base_tail();
    is_alive = true;
    create_new_pickup_at_random(Pickup_Type.APPLE,0.5);
}
kill :: () {
    is_alive = false;
    time_scale = 0;
    print("\n[%]You lost!",frame_counter);
}
restart_game :: () {
    time_scale = 1.0;
    destroy_tail();
    destroy_all_dead_segments();
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
    input.y = ifx key_down then -1.0 else 0.0 + ifx key_up then 1.0 else 0.0;

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
    if key_slow_mo.was_just_pressed{
        time_scale = ifx time_scale == 1.0 then 0.1 else 1.0;
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

    //Move body
    prev_point := snake.head;
    for 0..snake.tail.count-1 {
        snake.tail[it] = constraint_distance(snake.tail[it],prev_point,DISTANCE_BETWEEN_TAIL_POINTS);
        prev_point = snake.tail[it];
    }

    //Move dead points
    for #v2 < *segment,i : snake.dead_segments {
        segment.out_point += move_dir * speed * dt;

        prev_point_2 := segment.out_point;
        was_whole_tail_outside := true;
        for #v2 < *dead_point,j : segment.dead_points {

            dead_point.point = constraint_distance(dead_point.point,prev_point_2,DISTANCE_BETWEEN_TAIL_POINTS);
            prev_point_2 = dead_point.point;

            was_whole_tail_outside = was_whole_tail_outside && (dead_point.point.x < 0 || dead_point.point.x > BASE_WIDTH ||
                                     dead_point.point.y < 0 || dead_point.point.y > BASE_HEIGHT);
        }

        if was_whole_tail_outside {
            for #v2 < j : 0..segment.dead_points.count-1 {
                remove_dead_snake_point(i,j);
            }
            remove_dead_snake_segment(i);
            print("\nRemoved segment: %",i);
        }
    }
    /*
    Old movement system (Trashy)
    for #v2 < *segment,i : snake.dead_segments {
        if segment.dead_points.count <= 0{
            remove_dead_snake_segment(i);
            continue;
        }
        for #v2 < *dead_point,j : segment.dead_points {
            if dead_point.trace_path.count <= 0{
                remove_dead_snake_point(i,j);
                continue;
            }

            next_point := dead_point.trace_path[0];
            dead_point.time = min(dead_point.time + ((speed*dt)/DISTANCE_BETWEEN_TAIL_POINTS),1.0);//@@IMPORTANT: Need to sync up this speed with the alive parts.

            dead_point.point = lerp(dead_point.from,next_point,dead_point.time);

            if dead_point.time >= 1.0 {
                dead_point.from = next_point;
                dead_point.time = 0.0;
                array_ordered_remove_by_index(*dead_point.trace_path,0);
            }
        }
    }*/

    //Wrap around
    padding := 0.0;
    if snake.head.x < -padding || snake.head.x > BASE_WIDTH +padding ||
       snake.head.y < -padding || snake.head.y > BASE_HEIGHT+padding {
        dissappear_point := snake.head;
        snake.head.x = fmod_cycling(snake.head.x + BASE_WIDTH+padding, BASE_WIDTH+padding);
        snake.head.y = fmod_cycling(snake.head.y + BASE_HEIGHT+padding, BASE_HEIGHT+padding);

        create_new_dead_segment(dissappear_point,
             .{ifx dissappear_point.x < -padding then -1.0 else (ifx dissappear_point.x > BASE_WIDTH +padding then 1.0 else 0.0),
               ifx dissappear_point.y < -padding then -1.0 else (ifx dissappear_point.y > BASE_HEIGHT +padding then 1.0 else 0.0)});

        //Delete the tail one by one and create a ghost tail then regenerate the tail on the other side
        for #v2 < 0..snake.tail.count-1 {
            trace_path : [..]Vector2;
            for #v2 < it2 : 0..it {
                array_add(*trace_path,snake.tail[it2]);
            }
            array_add(*trace_path,dissappear_point);

            add_dead_point_to_last_segment(snake.tail[it],it,trace_path);
            remove_from_tail(it);
            add_to_tail(snake.head-direction*cast(float)(it+1));
        }
    }

    //@@IMPORTANT: Consider going backwards on the collision checking to check first the smallest parts of the tail
    //Collision with the dead and the tail

    for i : TAIL_POINTS_SKIPPED..snake.tail.count-1 {
        scale : float = 1.0 - (cast(float)i / (snake.tail.count));
        if check_collision(snake.head,HEAD_SIZE,snake.tail[i],HEAD_SIZE*scale) {
            print("\nCollided with tail: %",i);
            print("\nHead at: %, other at: %",snake.head,snake.tail[i]);
            kill();
            break;
        }
    }

    //Collision with the head and the dead points

    for i : 0..snake.dead_segments.count-1 {
        for j : 0..snake.dead_segments[i].dead_points.count-1 {
            scale : float = (cast(float)j / (snake.tail.count));

            if check_collision(snake.head,HEAD_SIZE,snake.dead_segments[i].dead_points[j].point,HEAD_SIZE*scale) {
                print("\nCollided with dead segment: %",i);
                print("\nHead at: %, other at: %",snake.head,snake.dead_segments[i].dead_points[j].point);
                kill();
                break i;
            }
        }
    }

    //Collision of the head with pickups
    for #v2 < pickup,i : pickups {
        if check_collision(snake.head,HEAD_SIZE,pickup.point,pickup.radius) {
            for 0..5 {
                add_to_tail();
            }
            destroy_pickup(i);
            create_new_pickup_at_random(.APPLE,0.5);
        }
    }
    //Collision of the tail with pickups
    for tail_point,i : snake.tail {
        for *pickup,j : pickups {
            dist := distance(pickup.point,tail_point);
            scale : float = 1.0 - (cast(float)i / (snake.tail.count));

            radius := pickup.radius + HEAD_SIZE * scale;
            if dist < radius then
                pickup.point = constraint_distance(pickup.point,tail_point,radius);
        }
    }
    //Collision of the dead parts with pickups
    for segment : snake.dead_segments {
        for dead_point : segment.dead_points {
            for *pickup,j : pickups {
                dist := distance(pickup.point,dead_point.point);
                scale : float = 1.0 - ((cast(float)dead_point.index_equivalent) / (snake.tail.count));

                radius := pickup.radius + HEAD_SIZE * scale;
                if dist < radius then
                    pickup.point = constraint_distance(pickup.point,dead_point.point,radius);
            }
        }
    }
}
destroy_tail :: () {
    for #v2 < 0..snake.tail.count-1 {
        remove_from_tail(it);
    }
}
destroy_all_dead_segments :: () {
    for #v2 < i : 0..snake.dead_segments.count-1 {
        for #v2 < j : 0..snake.dead_segments[i].dead_points.count-1 {
            remove_dead_snake_point(i,j);
        }
        remove_dead_snake_segment(i);
    }
}
remove_dead_snake_segment :: (index : int) {
    array_free(snake.dead_segments[index].dead_points);
    array_ordered_remove_by_index(*snake.dead_segments,index);
}
remove_dead_snake_point :: (segment_index : int, point_index : int) {
    array_free(snake.dead_segments[segment_index].dead_points[point_index].trace_path);
    array_ordered_remove_by_index(*snake.dead_segments[segment_index].dead_points,point_index);
}
create_new_dead_segment :: (warp_point : Vector2, dir : Vector2) {
    array_add(*snake.dead_segments,.{out_point = warp_point, out_dir = dir});
}
add_dead_point_to_last_segment ::(pos : Vector2, index : int, points_left : []Vector2) {
    array_add(*snake.dead_segments[snake.dead_segments.count-1].dead_points,DeadPoint.{
            point = pos,
            from = pos,
            trace_path = points_left,
            max_trace_count = points_left.count,
            index_equivalent = index
        });
}
add_to_tail :: () {
    dir := ifx snake.tail.count > 1 then snake.tail[snake.tail.count-1] - snake.tail[snake.tail.count-2] else direction;

    array_add(*snake.tail, snake.tail[snake.tail.count-1] + dir);
}
add_to_tail :: (pos : Vector2) {
    array_add(*snake.tail, pos);
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
render_stuff :: () {

    glEnable(GL_MULTISAMPLE);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glHint(GL_POLYGON_SMOOTH_HINT, GL_NICEST);


    glClearColor(0.369, 0.69, 0.588,1.0);
    glClear(GL_COLOR_BUFFER_BIT);

    glColor4f(0.086, 0.322, 0.306,1.0);


    //Head
    draw_circle(snake.head,HEAD_SIZE,32);

    //Tail

    //Alive parts
    glColor4f(0.086, 0.322, 0.306,1.0);

    glBegin(GL_TRIANGLE_STRIP);
    previous_point := snake.head;
    for 0..snake.tail.count-2 {
        dist := distance(snake.tail[it], previous_point);
        if dist <= 0.2 {
            glEnd();
            glBegin(GL_TRIANGLE_STRIP);
            continue;
        }
        else if dist > 16.0 {
            glEnd();
            glBegin(GL_TRIANGLE_STRIP);
            continue;
        }

        scale : float = 1.0 - (cast(float)it / (snake.tail.count));
        dir := normalize(snake.tail[it] - previous_point);

        center := previous_point;
        p0 := to_clip_space(center + rotate(dir,TAU/4)*scale*HEAD_SIZE);
        p1 := to_clip_space(center + rotate(dir,-TAU/4)*scale*HEAD_SIZE);
        glVertex2f(p0.x,p0.y);
        glVertex2f(p1.x,p1.y);
        previous_point = snake.tail[it];
    }
    glEnd();

    //Dead parts
    if IS_DEBUGGING_GRAPHICS then
        glColor4f(0.3, 1, 0.306,1.0); //Debug color

    for i : 0..snake.dead_segments.count-1 {
        glBegin(GL_TRIANGLE_STRIP);
        for j : 0..snake.dead_segments[i].dead_points.count-2 {
            dist := distance(snake.dead_segments[i].dead_points[j].point,snake.dead_segments[i].dead_points[j+1].point);

            if dist > 16.0 {
                glEnd();
                glBegin(GL_TRIANGLE_STRIP);
                continue;
            }

            scale : float = 1.0 - (cast(float)snake.dead_segments[i].dead_points[j].index_equivalent / (snake.tail.count));
            dir := normalize(snake.dead_segments[i].dead_points[j+1].point - snake.dead_segments[i].dead_points[j].point);

            center := snake.dead_segments[i].dead_points[j+1].point;

            p0 := to_clip_space(center + rotate(dir,TAU/4.0)*scale*HEAD_SIZE);
            p1 := to_clip_space(center + rotate(dir,-TAU/4.0)*scale*HEAD_SIZE);

            glVertex2f(p0.x,p0.y);
            glVertex2f(p1.x,p1.y);
        }
        //Extra triangles on the wrap point
        last_index := snake.dead_segments[i].dead_points.count-2;
        if snake.dead_segments[i].dead_points.count > 1 {
            for 1..10 {
                scale : float = 1.0 - ((cast(float)snake.dead_segments[i].dead_points[last_index].index_equivalent) / (snake.tail.count));

                dir := (snake.dead_segments[i].out_point
                        - snake.dead_segments[i].dead_points[last_index].point) * (cast(float)it)*0.1;

                out_dir := snake.dead_segments[i].out_dir;
                dir = rotate(dir, it * 0.1 * -(out_dir.x  * dir.y - out_dir.y * dir.x));

                center := snake.dead_segments[i].out_point + dir * (cast(float)it-1)*0.1;

                p0 := to_clip_space(center + rotate(normalize(dir),TAU/4.0)*scale*HEAD_SIZE);
                p1 := to_clip_space(center + rotate(normalize(dir),-TAU/4.0)*scale*HEAD_SIZE);

                glVertex2f(p0.x,p0.y);
                glVertex2f(p1.x,p1.y);
            }
        }
        glEnd();
/*
        glBegin(GL_TRIANGLES);
        index_2 := snake.dead_segments[i].dead_points.count-2;
        index_1 := snake.dead_segments[i].dead_points.count-1;
        scale : float = 1.0 - (cast(float)snake.dead_segments[i].dead_points[index_2].index_equivalent / (snake.points.count));
        dir := normalize(snake.dead_segments[i].dead_points[index_1].point - snake.dead_segments[i].dead_points[index_2].point);
        center := to_clip_space(snake.dead_segments[i].dead_points[index_2].point);

        p0 := to_clip_space(center + rotate(dir,TAU/4.0)*scale*HEAD_SIZE);
        p1 := to_clip_space(center + rotate(dir,-TAU/4.0)*scale*HEAD_SIZE);
        glVertex2f(p0.x,p0.y);
        glVertex2f(p1.x,p1.y);

        last_center := snake.dead_segments[i].dead_points[index_1].point;

        glVertex2f(last_center.x,last_center.y);
        glEnd();
*/

    }

    for pickup : pickups {
        draw_circle(pickup.point,pickup.radius,16);
    }




    //Debug drawing...
    if IS_DEBUGGING_GRAPHICS {
        glColor4f(1.0, 0.0, 0.0,1.0); //Debug color
        for TAIL_POINTS_SKIPPED..snake.tail.count-1 {
            glBegin(GL_LINES);
            scale : float = 1.0 - (cast(float)it / (snake.tail.count));
            center := snake.tail[it];
            draw_wired_circle(center,scale*HEAD_SIZE,16);
            glEnd();
        }
        for i : 0..snake.dead_segments.count-1 {
            for j : 0..snake.dead_segments[i].dead_points.count-1 {
                glBegin(GL_LINES);
                scale : float = (cast(float)j / (snake.tail.count));
                center := snake.dead_segments[i].dead_points[j].point;
                draw_wired_circle(center,scale*HEAD_SIZE,16);
                glEnd();
            }
        }
    }

    //Drawing point dots
    if IS_DEBUGGING_GRAPHICS {
        glColor4f(0.0, 0.0, 0.0,1.0); //Debug color

        //Body
        for 0..snake.tail.count-1 {
            draw_circle(snake.tail[it],0.1);
        }
        //Dead parts
        for i : 0..snake.dead_segments.count-1 {
            for j : 0..snake.dead_segments[i].dead_points.count-1 {
                draw_circle(snake.dead_segments[i].dead_points[j].point,0.1);
            }
        }
    }
}
check_collision :: (p0 : Vector2, r0 : float, p1 : Vector2, r1 : float) -> bool {
    return distance(p0,p1) < (r0 +r1);
}
constraint_distance :: (point : Vector2, anchor : Vector2, distance : float) -> Vector2 {
    scale := length(point-anchor);
    return anchor + (normalize(point-anchor) * distance);
}
to_clip_space :: (pos : Vector2) -> Vector2 {
    return Vector2.{ ((pos.x/BASE_WIDTH) * 2) - 1, ((pos.y/BASE_HEIGHT) * 2) - 1};
}
to_grid :: (position : Vector2) -> Vector2 {
    return .{floor(position.x),floor(position.y)};
}
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
draw_circle :: (pos : Vector2, radius : float, count : int = 8) {
    glBegin(GL_TRIANGLE_FAN);
    center := to_clip_space(pos);
    glVertex2f(center.x,center.y);
    for 0..count {
        angle_0 := (it / cast(float)count) * TAU;
        p0 := to_clip_space(pos + rotate(Vector2.{0,1},angle_0)*radius);
        glVertex2f(p0.x,p0.y);
    }
    glEnd();
}
draw_wired_circle :: (pos : Vector2, radius : float, count : int = 8) {
    px := to_clip_space(pos + Vector2.{0,1}*radius);
    glVertex2f(px.x,px.y);

    for 1..count {
        angle_0 := (it / cast(float)count) * TAU;
        angle_1 := (it / cast(float)count) * TAU;
        p0 := to_clip_space(pos + rotate(Vector2.{0,1},angle_0)*radius);
        p1 := to_clip_space(pos + rotate(Vector2.{0,1},angle_1)*radius);
        glVertex2f(p0.x,p0.y);
        glVertex2f(p1.x,p1.y);
    }
}
draw_line :: (p0 : Vector2, p1 : Vector2) {
    clip_point := to_clip_space(p0);
    clip_point2 := to_clip_space(p1);
    glVertex2f(clip_point.x,clip_point.y);
    glVertex2f(clip_point2.x,clip_point2.y);
}

Snake :: struct {
    head : Vector2;
    tail : [..]Vector2;
    dead_segments : [..]DeadSegment;
}
DeadSegment :: struct {
    dead_points : [..]DeadPoint;
    //dead_head : Vector2;
    out_point : Vector2;
    out_dir : Vector2;
}
DeadPoint :: struct {
    point : Vector2;
    from : Vector2;
    time : float;
    trace_path : []Vector2;
    max_trace_count : int;
    index_equivalent : int;
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
Simp :: #import "Simp";