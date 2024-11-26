BASE_WIDTH    :: 32;
BASE_HEIGHT   :: 32;
FPS_TARGET :: 75;
MULTIPLIER :: 16;
WINDOW_WIDTH  :: BASE_WIDTH*MULTIPLIER;
WINDOW_HEIGHT :: BASE_HEIGHT*MULTIPLIER;

PIXEL_SIZE :: 8;
HEAD_SIZE :: 0.5;

window : Window_Type;

key_left  : bool;
key_right : bool;
key_up    : bool;
key_down  : bool;
key_space : bool;
key_f1 : bool;
key_f2 : bool;

key_return : KeyState;

snake : Snake;
direction : Vector2;
input := Vector2.{0,0};
speed : float = 20;
last_time : float64;
dt : float;
time_scale : float = 1.0;

test_x : float;
test_y : float;

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

    prepare();

    // Enable MSAA
    SDL_GL_SetAttribute(SDL_GL_MULTISAMPLEBUFFERS, 1);
    SDL_GL_SetAttribute(SDL_GL_MULTISAMPLESAMPLES, 4);
    glEnable(GL_MULTISAMPLE);

    quit := false;
    while main := !quit {
        now := seconds_since_init();
        dt = xx (now - last_time) * time_scale;

        event : SDL_Event;

        if key_return.awaits_reset then key_return.was_just_pressed = false;

        while SDL_PollEvent(*event) {


            if event.type == {
                case SDL_QUIT;
                    quit = true;
                case SDL_KEYDOWN;
                    if event.key.keysym.sym == SDLK_F1 key_f1         = true;
                    if event.key.keysym.sym == SDLK_F2 key_f2         = true;

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
                        key_return.is_pressed = true;
                        if !key_return.awaits_reset {
                            key_return.awaits_reset = true;
                            key_return.was_just_pressed = true;
                        }
                    }
                case SDL_KEYUP;
                    if event.key.keysym.sym == SDLK_ESCAPE quit       = true;

                    if event.key.keysym.sym == SDLK_F1 key_f1         = false;
                    if event.key.keysym.sym == SDLK_F2 key_f2         = false;

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
                    if event.key.keysym.sym == SDLK_RETURN key_return = .{was_just_pressed = false, is_pressed = false,awaits_reset=false};
            }
        }

        process_logic();

        render_stuff();
        SDL_GL_SwapWindow(window);


        last_time = now;

        //print("\nFPS: %",1/dt);

        //Wait routine
        target_delta := 1.0 / cast(float64) FPS_TARGET;

        sleep_ms := cast(s32) target_delta;

        if (sleep_ms > 0)
            sleep_milliseconds(sleep_ms);

        while seconds_since_init() < now + target_delta { }


        reset_temporary_storage();
    }
    SDL_DestroyWindow(window);
    SDL_Quit();
}

prepare :: () {
    array_add(*snake.points, Vector2.{BASE_WIDTH-4,BASE_HEIGHT/2});
    array_add(*snake.points_last_frame, Vector2.{BASE_WIDTH/2-1,BASE_HEIGHT/2});

    for 0..16{
        add_new_snake_segment();
    }
}
process_logic :: () {


    input.x = ifx key_left then -1.0 else 0.0 + ifx key_right then 1.0 else 0.0;
    input.y = ifx key_down then -1.0 else 0.0 + ifx key_up then 1.0 else 0.0;

    if input != Vector2.{0,0} {
        direction = normalize(input);
    }

    if key_space{
        add_new_snake_segment();
    }

    //print("\nKey: pressed: %,awaits: %",key_return.was_just_pressed,key_return.awaits_reset);
    if key_return.was_just_pressed{
        time_scale = 1.0 - time_scale;
        print("\nTime scale: %",time_scale);
    }

    //Move head
    snake.points_last_frame[0] = snake.points[0];
    snake.points[0] += direction * speed * dt;

    //Move body
    for 1..snake.points.count-1 {

        new_dir := snake.points_last_frame[it-1] - snake.points[it];

        dist := distance(snake.points_last_frame[it-1],snake.points[it]);

        snake.points[it] += new_dir * speed * dt;
        snake.points_last_frame[it] = snake.points[it];
    }

    //Move dead parts
    for #v2 < 0..snake.dead_parts.count-1 {
        if snake.dead_parts[it].trace_path.count <= 0{
            remove_dead_snake_segment(it);
            continue;
        }

        next_point := snake.dead_parts[it].trace_path[0] ;
        snake.dead_parts[it].time = min(snake.dead_parts[it].time + speed*dt*2,1.0);//@@IMPORTANT: This speed may not be the same as when moving the main parts

        snake.dead_parts[it].point = lerp(snake.dead_parts[it].from,next_point,snake.dead_parts[it].time);
        if snake.dead_parts[it].time >= 1.0 {
            snake.dead_parts[it].from = next_point;
            snake.dead_parts[it].time = 0.0;
            array_ordered_remove_by_index(*snake.dead_parts[it].trace_path,0);
        }
    }

    //Wrap around
    padding := 1.25;
    if snake.points[0].x < -padding || snake.points[0].x > BASE_WIDTH +padding ||
       snake.points[0].y < -padding || snake.points[0].y > BASE_HEIGHT+padding {
        dissappear_point := snake.points[0];
        snake.points[0].x = fmod_cycling(snake.points[0].x + BASE_WIDTH+padding, BASE_WIDTH+padding);
        snake.points[0].y = fmod_cycling(snake.points[0].y + BASE_HEIGHT+padding, BASE_HEIGHT+padding);

        for #v2 < 1..snake.points.count-1 {
            parts_left : [..]Vector2;

            for #v2 < it2 : 1..it-1 {
                array_add(*parts_left,snake.points[it2]);
            }
            array_add(*parts_left,dissappear_point);
            remove_snake_segment(it,parts_left);
            add_new_snake_segment(snake.points[0]);
        }
    }
}
add_new_snake_segment :: () {
    dir := ifx snake.points.count > 1 then snake.points[snake.points.count-1] - snake.points[snake.points.count-2] else direction;

    array_add(*snake.points,
        snake.points[snake.points.count-1] + dir);
    array_add(*snake.points_last_frame,
        snake.points_last_frame[snake.points_last_frame.count-1] + dir);
}
add_new_snake_segment :: (pos : Vector2) {
    dir := direction;

    array_add(*snake.points,
        pos - dir);
    array_add(*snake.points_last_frame,
        pos - dir);
}
remove_snake_segment :: (index : int, points_left : []Vector2) {
    array_add(*snake.dead_parts,DeadPart.{point = snake.points[index],from = snake.points[index], trace_path = points_left, index_equivalent = index});

    array_ordered_remove_by_index(*snake.points,index);
    array_ordered_remove_by_index(*snake.points_last_frame,index);
}
remove_dead_snake_segment :: (index : int) {
    array_free(snake.dead_parts[index].trace_path);
    array_ordered_remove_by_index(*snake.dead_parts,index);
}
render_stuff :: () {

    /*
    glEnable(GL_MULTISAMPLE);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glHint(GL_POLYGON_SMOOTH_HINT, GL_NICEST);
    */

    glClearColor(0.369, 0.69, 0.588,1.0);
    glClear(GL_COLOR_BUFFER_BIT);

    glColor4f(0.086, 0.322, 0.306,1.0);
    glBegin(GL_TRIANGLE_FAN);
    //Head
    draw_circle(snake.points[0],HEAD_SIZE/16,32);
    glEnd();

    //Body
    /*
    for 1..snake.points.count-1 {
        draw_quad(snake.points[it],0.05);
    }

    //Dead parts
    for part, index : snake.dead_parts {
        draw_quad(part.point,0.05);
    }
    glEnd();
    */
    //Body

    //Alive parts

    glBegin(GL_TRIANGLE_STRIP);
    for 0..snake.points.count-2 {
        dist := distance(snake.points[it],snake.points[it+1]);
        if dist > 16.0 then continue;

        scale : float = 1.0 - (cast(float)it / (snake.points.count-2));
        dir := normalize(snake.points[it+1] - snake.points[it]);

        center := snake.points[it];
        p0 := to_clip_space(center + rotate(dir,TAU/4)*scale*HEAD_SIZE);
        p1 := to_clip_space(center + rotate(dir,-TAU/4)*scale*HEAD_SIZE);
        glVertex2f(p0.x,p0.y);
        glVertex2f(p1.x,p1.y);
    }
    glEnd();

    //Dead parts
    //glColor4f(0.75, 0.1, 0.306,1.0); //Debug color

    glBegin(GL_TRIANGLE_STRIP);
    for 0..snake.dead_parts.count-2 {
        dist := distance(snake.dead_parts[it].point,snake.dead_parts[it+1].point);
        if dist > 16.0{//This fixes the bug where the strips would teleport to the other side of the screen when wrapping
            glEnd();
            glBegin(GL_TRIANGLE_STRIP);
            continue;
        }

        scale : float = 1.0 - (cast(float)snake.dead_parts[it].index_equivalent / (snake.points.count-2));
        dir := normalize(snake.dead_parts[it+1].point - snake.dead_parts[it].point);

        center := snake.dead_parts[it].point;
        p0 := to_clip_space(center + rotate(dir,TAU/4)*scale*HEAD_SIZE);
        p1 := to_clip_space(center + rotate(dir,-TAU/4)*scale*HEAD_SIZE);

        glVertex2f(p0.x,p0.y);
        glVertex2f(p1.x,p1.y);

    }
    glEnd();
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
    center := to_clip_space(pos);
    glVertex2f(center.x,center.y);
    for 0..count {
        angle_0 := (it / cast(float)count) * TAU;
        p0 := center + rotate(Vector2.{0,1},angle_0)*radius;
        glVertex2f(p0.x,p0.y);
    }
}
draw_line :: (p0 : Vector2, p1 : Vector2) {
    clip_point := to_clip_space(p0);
    clip_point2 := to_clip_space(p1);
    glVertex2f(clip_point.x,clip_point.y);
    glVertex2f(clip_point2.x,clip_point2.y);
}

Snake :: struct {
    points : [..]Vector2;
    points_last_frame : [..]Vector2;//This crap may have to go at some point
    dead_parts : [..]DeadPart;
}
DeadPart :: struct {
    point : Vector2;
    from : Vector2;
    time : float;
    trace_path : []Vector2;
    index_equivalent : int;
}
KeyState :: struct {
    was_just_pressed : bool;
    is_pressed : bool;
    awaits_reset : bool;
}
#import "Basic";
#import "Math";
#import "Window_Creation";
#import "GL";
#import "SDL";
Input :: #import "Input";
Simp :: #import "Simp";