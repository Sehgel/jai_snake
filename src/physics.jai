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
    print("\nSnake head: %",snake_head_wraps);



    for #v2 < i : TAIL_POINTS_SKIPPED..snake.tail.count-1 {
        scale : float = 1.0 - (cast(float)i / (snake.tail.count));
        if check_circle_collision(cycle_point2(snake.head),HEAD_SIZE,cycle_point2(snake.tail[i]),HEAD_SIZE*scale) {
            print("\nCollided with tail: % of %",i,snake.tail.count);
            print("\nHead at: %, other at: %",cycle_point2(snake.head),snake.tail[i]);
            kill();
            //cut_tail_at(i);
            break;
        }
    }

    //Collision of the head with pickups
    for #v2 < pickup,i : pickups {
        if check_circle_collision(cycle_point2(snake.head),HEAD_SIZE,cycle_point2(pickup.point),pickup.radius) {
            for 0..4 {
                add_to_tail_deferred();
            }
            destroy_pickup(i);
            create_new_pickup_at_random(get_random_pickup_type(),0.5*HEAD_SIZE);

            calculate_next_pickup_target(*pickups[pickups.count-1]);
            shake_camera(0.2,1.5);
            slow_time_for(0.1,0.25);
        }
    }

    //Collision of the tail with pickups
    for *tail_point,i : snake.tail {
        for *pickup,j : pickups {
            dist := distance(pickup.point,cycle_point2(tail_point));
            scale : float = 1.0 - (cast(float)i / (snake.tail.count));

            radius := pickup.radius + HEAD_SIZE * scale;
            if dist < radius then
                pickup.point = constraint_distance(pickup.point,cycle_point2(tail_point),radius);
        }
    }



    //Collision with the *HEAD* and *OBSTACLES*
    for *obstacle,j : obstacles {
        adjusted_obstacle := adjust_wraps(obstacle.point,snake_head_wraps);
        dist := distance(adjusted_obstacle,snake.head);
        radius := obstacle.radius + HEAD_SIZE;
        if dist < radius {
            snake.head = constraint_distance(snake.head,adjusted_obstacle,radius);
            head_dir := normalize(snake.head - snake.tail[0]);
            obstacle_normal := normalize(snake.head-adjusted_obstacle);

            dot := dot_product(direction,orthonormalize(obstacle_normal));
            if dot < -0.98 then
                kill();
            print("\nDot: %, direction: %, normal: %, ortho: %",dot,direction,obstacle_normal,orthonormalize(obstacle_normal));
        }
    }

    //Collision of the *TAIL* with *OBSTACLES*
    for #v2 < *tail_point,i : snake.tail {
        for *obstacle,j : obstacles {
            adjusted_obstacle := adjust_wraps(obstacle.point,snake_head_wraps);
            dist := distance(adjusted_obstacle,tail_point);
            scale : float = 1.0 - (cast(float)i / (snake.tail.count));

            radius := obstacle.radius + HEAD_SIZE * scale;
            if dist < radius {
                snake.tail[i] = constraint_distance(tail_point,adjusted_obstacle,radius);
            }
        }
    }
}

check_circle_collision :: (p0 : Vector2, r0 : float, p1 : Vector2, r1 : float) -> bool {
    return distance(p0,p1) < (r0 +r1);
}

check_aabb_circle_collision :: (p0 : Vector2, size : float, p1 : Vector2, r1 : float) -> bool {
    return distance(p0,p1) < (r0 +r1);
}

constraint_distance :: (point : Vector2, anchor : Vector2, distance : float) -> Vector2 {
    scale := length(point-anchor);
    return anchor + (normalize(point-anchor) * distance);
}