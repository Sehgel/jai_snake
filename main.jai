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


snake : Snake;
direction : Vector2;
input := Vector2.{0,0};
speed : float = 0.35;
last_time : float64;
dt : float64;

test_x : float;
test_y : float;

main :: () {
    SDL_Init(SDL_INIT_VIDEO);

    window := SDL_CreateWindow("Snake",
        SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
        WINDOW_WIDTH, WINDOW_HEIGHT,
        SDL_WINDOW_OPENGL|SDL_WINDOW_SHOWN);


    if window == null {
        print("Couldn't create window: %\n", to_string(SDL_GetError()));
        return;
    }

    //This seems to be optional
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, xx SDL_GL_CONTEXT_PROFILE_CORE);

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
        dt = now - last_time;

        event : SDL_Event;

        while SDL_PollEvent(*event) {

            if event.type == {
                case SDL_QUIT;
                    quit = true;
                case SDL_KEYUP;
                    if event.key.keysym.sym == SDLK_ESCAPE quit = true;

                    if event.key.keysym.sym == SDLK_F1 key_f1 = false;
                    if event.key.keysym.sym == SDLK_F2 key_f2 = false;

                    if event.key.keysym.sym == SDLK_UP key_up       = false;
                    if event.key.keysym.sym == SDLK_DOWN key_down   = false;
                    if event.key.keysym.sym == SDLK_RIGHT key_right = false;
                    if event.key.keysym.sym == SDLK_LEFT key_left   = false;

                    if event.key.keysym.sym == SDLK_SPACE key_space   = false;
                case SDL_KEYDOWN;
                    if event.key.keysym.sym == SDLK_F1 key_f1 = true;
                    if event.key.keysym.sym == SDLK_F2 key_f2 = true;

                    if event.key.keysym.sym == SDLK_UP key_up       = true;
                    if event.key.keysym.sym == SDLK_DOWN key_down   = true;
                    if event.key.keysym.sym == SDLK_RIGHT key_right = true;
                    if event.key.keysym.sym == SDLK_LEFT key_left   = true;

                    if event.key.keysym.sym == SDLK_SPACE key_space   = true;
            }
        }

        process_logic();

        render_stuff();
        SDL_GL_SwapWindow(window);


        last_time = now;

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

    for 0..7{
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

    //Move head
    snake.points_last_frame[0] = snake.points[0];
    snake.points[0] += (direction * speed);

    //Move body
    for 1..snake.points.count-1 {

        new_dir := snake.points_last_frame[it-1] - snake.points[it];

        dist := distance(snake.points_last_frame[it-1],snake.points[it]);

        snake.points[it] += new_dir * speed;
        snake.points_last_frame[it] = snake.points[it];


    }
    //Move dead parts

    for #v2 < 0..snake.dead_parts.count-1 {
        if snake.dead_parts[it].trace_path.count <= 0{
            remove_dead_snake_segment(it);
            continue;
        }
        next_point := snake.dead_parts[it].trace_path[0];
        new_dir := normalize(next_point - snake.dead_parts[it].point);
        if distance(snake.dead_parts[it].point, next_point) <= 0.5 {
            array_ordered_remove_by_index(*snake.dead_parts[it].trace_path,0);
        }
        snake.dead_parts[it].point += new_dir * speed;
    }

    //Wrap around
    if snake.points[0].x < -2 || snake.points[0].x > BASE_WIDTH+2 ||
       snake.points[0].y < -2 || snake.points[0].y > BASE_HEIGHT+2 {
        dissappear_point := snake.points[0];
        snake.points[0].x = fmod_cycling(snake.points[0].x + BASE_WIDTH+2, BASE_WIDTH+2);
        snake.points[0].y = fmod_cycling(snake.points[0].y + BASE_HEIGHT+2, BASE_HEIGHT+2);

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
    array_add(*snake.points,
        snake.points[snake.points.count-1] - direction);
    array_add(*snake.points_last_frame,
        snake.points_last_frame[snake.points_last_frame.count-1] - direction);
}

add_new_snake_segment :: (pos : Vector2) {
    array_add(*snake.points,
        pos - direction);
    array_add(*snake.points_last_frame,
        pos - direction);
}

remove_snake_segment :: (index : int, points_left : []Vector2) {
    array_add(*snake.dead_parts,.{point = snake.points[index], trace_path = points_left});

    array_ordered_remove_by_index(*snake.points,index);
    array_ordered_remove_by_index(*snake.points_last_frame,index);
}
remove_dead_snake_segment :: (index : int) {
    array_free(snake.dead_parts[index].trace_path);
    array_unordered_remove_by_index(*snake.dead_parts,index);
}
render_stuff :: () {
    glViewport(0,0,WINDOW_WIDTH,WINDOW_HEIGHT);
    glEnable(GL_LINE_SMOOTH);
    glHint(GL_LINE_SMOOTH_HINT,GL_NICEST);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    glClear(GL_COLOR_BUFFER_BIT);

    glBegin(GL_TRIANGLES);
    //Head
    draw_quad(snake.points[0],HEAD_SIZE/2);
    //Body

    for 1..snake.points.count-1 {
        draw_quad(snake.points[it],0.25);
    }

    //Dead parts
    for part, index : snake.dead_parts {
        draw_quad(part.point,0.25);
    }
    glEnd();

    //Body

    return;
    //Alive parts
    for 0..snake.points.count-2 {
        scale : float = 1.0 - (cast(float)it / (snake.points.count-2));
        glLineWidth(PIXEL_SIZE * scale);
        glBegin(GL_LINES);
        dist := distance(snake.points[it],snake.points[it+1]);
        if dist > 16.0 then continue;
        draw_line(snake.points[it],snake.points[it+1]);
        glEnd();
    }
    //Dead parts

    for 0..snake.dead_parts.count-2 {
        scale : float = (cast(float)it / (snake.dead_parts.count-2));
        glLineWidth(PIXEL_SIZE * scale);
        glBegin(GL_LINES);
        dist := distance(snake.dead_parts[it].point,snake.dead_parts[it+1].point);
        if dist > 16.0 then continue;
        draw_line(snake.dead_parts[it].point,snake.dead_parts[it+1].point);
        glEnd();
    }

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
    trace_path : []Vector2;
}

#import "Basic";
#import "Math";
#import "Window_Creation";
#import "GL";
#import "SDL";
Input :: #import "Input";
Simp :: #import "Simp";