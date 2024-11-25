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


snake : [..]Vector2;
direction : Vector2;
input := Vector2.{0,0};
speed : float = 0.25;

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
    array_add(*snake, Vector2.{BASE_WIDTH/2-1,BASE_HEIGHT/2});

    for 0..2{
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

    //move head
    snake[0] += (direction * speed);
    //move body
    for 1..snake.count-1 {
        new_dir := snake[it-1] - snake[it];
        snake[it] += new_dir * speed;
    }

    //Wrap around
    for *position : snake {
        position.x = fmod_cycling(position.x + BASE_WIDTH, BASE_WIDTH);
        position.y = fmod_cycling(position.y + BASE_HEIGHT, BASE_HEIGHT);
    }
}

add_new_snake_segment :: () {
    array_add(*snake,snake[snake.count-1] - direction);
}

render_stuff :: () {
    glViewport(0,0,WINDOW_WIDTH,WINDOW_HEIGHT);
    glEnable(GL_LINE_SMOOTH);
    glEnable(GL_BLEND);
    glDepthMask(GL_FALSE);
    glHint(GL_LINE_SMOOTH_HINT,GL_NICEST);

    glClear(GL_COLOR_BUFFER_BIT);

    //Head
    glBegin(GL_TRIANGLES);
    draw_quad(snake[0],HEAD_SIZE/2);
    glEnd();

    //Body
    glLineWidth(PIXEL_SIZE);
    glBegin(GL_LINES);
    for 0..snake.count-2 {
        dist := distance(snake[it],snake[it+1]);
        if dist > 1.0 then continue;
        draw_line(snake[it],snake[it+1]);
        //draw_quad(snake[it+1],0.05);
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
draw_line :: (p0 : Vector2, p1 : Vector2) {
    clip_point := to_clip_space(p0);
    clip_point2 := to_clip_space(p1);
    glVertex2f(clip_point.x,clip_point.y);
    glVertex2f(clip_point2.x,clip_point2.y);
}

#import "Basic";
#import "Math";
#import "Window_Creation";
#import "GL";
#import "SDL";
Input :: #import "Input";
Simp :: #import "Simp";