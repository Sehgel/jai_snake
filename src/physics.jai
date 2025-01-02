resolve_collisions :: () {

	//@IMPORTANT: All collisions wraps the snake tail and head back to the original viewport

    /*@DANGEROUS!!!: This introduces a bug that teleports the whole snake!!!
    //Collision of the head with the skipped tail point
    for i : 4..TAIL_POINTS_SKIPPED {
        tail_point := snake.tail[i];
        dist := distance(cycle_point2(snake.head),cycle_point2(tail_point));
        scale : float = 1.0 - (cast(float)i / (snake.tail.count));

        radius := HEAD_SIZE + HEAD_SIZE * scale;
        if dist < radius then
            snake.head = constraint_distance(cycle_point2(snake.head),cycle_point2(tail_point),radius);
    }
    */

    //@IMPORTANT: Consider going backwards on the collision checking to check first the smallest parts of the tail
    //Collision with the dead and the tail

    snake_head_wraps := Vector2.{floor(snake.head.x/WINDOW_WIDTH),floor(snake.head.y/WINDOW_HEIGHT)};
    {
        i := snake.tail.count-1;
        while i >= TAIL_POINTS_SKIPPED {
            defer i -= 20;
        //for #v2 < i : TAIL_POINTS_SKIPPED..snake.tail.count-1 {//@NeedsOptimization
            scale : float = 1.0 - (cast(float)i / (snake.tail.count));
            if check_circle_collision(cycle_point2(snake.head),HEAD_SIZE,cycle_point2(snake.tail[i]),HEAD_SIZE*scale) {
                kill();
                print("\n%",i);
                return;
            }
        }
    }


    //Collision of the *HEAD* with *PICKUPS*
    for #v2 < pickup,i : pickups {
        if check_circle_collision(cycle_point2(snake.head),HEAD_SIZE,cycle_point2(pickup.point),pickup.radius) {
            add_to_tail_deferred(8);
            eat_pickup(i);
        }
    }

    //Collision of the *TAIL* with *PICKUPS*
    {
        i := 0;
        while i < snake.tail.count {
            defer i += 20;
        //for *tail_point,i : snake.tail {//@NeedsOptimization
            for *pickup,j : pickups {
                dist := distance(pickup.point,cycle_point2(snake.tail[i]));
                scale : float = 1.0 - (cast(float)i / (snake.tail.count));

                radius := pickup.radius + HEAD_SIZE * scale;
                if dist < radius then{
                    pickup.point = constraint_distance(pickup.point,cycle_point2(snake.tail[i]),radius);
                    if pickup.type == .RAT && pickup.counter > 0.15{
                        pickup.target = pickup.point + rotate(normalize(pickup.point - pickup.target),random_get_within_range(-PI/4,PI/4)) * random_get_within_range(10,64);
                        pickup.counter = 0.0;
                    }
                }
            }
        }
    }

    //Collision with the *HEAD* and *OBSTACLES*
    {
        normal_accum : Vector2;
        hit_count : int;
        for *obstacle,j : obstacles {
            adjusted_obstacle := adjust_wraps(obstacle.point,snake_head_wraps);

            result, pos, dir := constraint_circle_aabb_collision(snake.head,HEAD_SIZE,adjusted_obstacle,Vector2.{1,1}*WALL_SIZE*2);
            if result {
                snake.head = pos;
                normal_accum += dir;
                hit_count += 1;
            }
        }
        if hit_count > 0 {
            normal := normalize(normal_accum / cast(float)hit_count);

            dot := dot_product(normal,normalize(direction));
            if dot > 0.99 {
                print("\nNormal: %, Direction: %, Dot: %",normal,direction,dot);// nocheckin
                kill();
            }
        }
    }

    //Collision of the *TAIL* with *OBSTACLES*
    if true {
        i := snake.tail.count-1;
        while i >= 0 {
            defer i -= 2;
            tail_point := snake.tail[i];
        //for #v2 < *tail_point,i : snake.tail {//@NeedsOptimization
            tail_wraps := Vector2.{floor(tail_point.x/WINDOW_WIDTH),floor(tail_point.y/WINDOW_HEIGHT)};
            for *obstacle,j : obstacles {
                adjusted_obstacle := adjust_wraps(obstacle.point,tail_wraps);
                dist := distance(adjusted_obstacle,tail_point);
                if dist > WALL_SIZE*2 continue;
                scale : float = 1.0 - (cast(float)i / (snake.tail.count*TAIL_END_CUTOFF_MULT-1));

                radius := obstacle.radius + HEAD_SIZE * scale;

                result, pos, dir := constraint_circle_aabb_collision(tail_point,HEAD_SIZE*scale,adjusted_obstacle,Vector2.{1,1}*WALL_SIZE*1.5);

                if result snake.tail[i] = pos;
            }
        }
    }
}

check_circle_collision :: (p0 : Vector2, r0 : float, p1 : Vector2, r1 : float) -> bool {
    return distance(p0,p1) < (r0 +r1);
}

constraint_distance :: (point : Vector2, anchor : Vector2, distance : float) -> Vector2 {
    scale := length(point-anchor);
    return anchor + (normalize(point-anchor) * distance);
}

constraint_away_distance :: (point : Vector2, anchor : Vector2, distance : float) -> Vector2 {
    if check_circle_collision (point,distance/2,anchor,distance/2) {
        return anchor + normalize(point-anchor) * distance;
    }
    return point;
}

check_point_aabb_collision :: (p0 : Vector2, p1 : Vector2, s1 : Vector2) -> bool {
    return (p0.x > p1.x - s1.x*0.5 && p0.x < p1.x + s1.x*0.5) &&
           (p0.y > p1.y - s1.y*0.5 && p0.y < p1.y + s1.y*0.5);
}

check_aabb_collision :: (p0 : Vector2, s0 : Vector2, p1 : Vector2, s1 : Vector2) -> bool {
    return (p0.x + s0.x*0.5 > p1.x - s1.x*0.5 && p0.x - s0.x*0.5 < p1.x + s1.x*0.5) &&
           (p0.y + s0.y*0.5 > p1.y - s1.y*0.5 && p0.y - s0.y*0.5 < p1.y + s1.y*0.5);
}

constraint_circle_aabb_collision :: (p0 : Vector2, radius : float, p1 : Vector2, s1 : Vector2) -> bool, pos : Vector2, direction : Vector2 {
    b_left   := p1.x - s1.x*0.5;
    b_right  := p1.x + s1.x*0.5;

    b_bottom := p1.y + s1.y*0.5;
    b_top    := p1.y - s1.y*0.5;


    closest_point : Vector2;

    closest_point.x = clamp(p0.x, b_left, b_right);
    closest_point.y = clamp(p0.y, b_top, b_bottom);

    dir := normalize(closest_point - p0);

    if check_point_aabb_collision(p0 + dir * radius,p1,s1) {
        return true, p0 - dir*(radius - distance(closest_point,p0)), dir*(radius - distance(closest_point,p0));
    }
    return false, p0, dir;
}

closest :: (x : float, a : float, b : float) -> float {
    if abs(x - a) < abs(x - b) then
        return a;
    else
        return b;
}

constraint_distance_aabb :: (p0 : Vector2, s0 : Vector2, p1 : Vector2, s1 : Vector2) -> Vector2 {

    if check_aabb_collision(p0,s0,p1,s1) {

        a_left := p0.x-s0.x*0.5;
        b_left := p1.x-s1.x*0.5;

        a_right := p0.x + s0.x*0.5;
        b_right := p1.x + s1.x*0.5;

        a_top := p0.y-s0.y*0.5;
        b_top := p1.y-s1.y*0.5;

        a_bottom := p0.y + s0.y*0.5;
        b_bottom := p1.y + s1.y*0.5;

        x := min_abs(a_right - b_left,b_right - a_left);
        y := min_abs(a_bottom - b_top,b_bottom - a_top);

        offset : Vector2;

        if x < y then
            offset.x = x * sign(p0.x-p1.x);
        else
            offset.y = y * sign(p0.y-p1.y);

        return p0 + offset;
    }
    return p0;
}
min_abs :: (x : float, y : float) -> float {
    if abs(x) < abs(y) then
        return x;
    else
        return y;
}
sign :: (x : float) -> float {
    return ifx x > 0.0 then 1.0 else -1.0;
}