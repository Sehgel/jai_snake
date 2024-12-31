cycle_point2 :: (point : Vector2, padding : float = 0.0) -> Vector2 {
    return .{fmod_cycling(point.x + WINDOW_WIDTH ,  WINDOW_WIDTH),
             fmod_cycling(point.y + WINDOW_HEIGHT,  WINDOW_HEIGHT)};
}

cycle_point3 :: (point : Vector2, padding : float = 0.0) -> Vector3 {
    return .{fmod_cycling(point.x + WINDOW_WIDTH ,  WINDOW_WIDTH),
             fmod_cycling(point.y + WINDOW_HEIGHT,  WINDOW_HEIGHT),
             0};
}

to_grid :: (position : Vector2) -> Vector2 {
    return .{floor(position.x),floor(position.y)};
}

angle_between :: (a : Vector2, b : Vector2) -> float {
    return atan2(b.y,b.x) - atan2(a.y,a.x);
}

move_towards :: (current : Vector2, target : Vector2, speed : float = 1.0, max_delta : float = 0.1) -> Vector2{
    dir := target - current;
    dist := length(dir);
    if (dist <= max_delta*speed)
    {
        return target;
    }
    return current + dir*speed / dist * max_delta;
}

orthonormalize :: (v : Vector2) -> Vector2 {
    if abs(v.x) > abs(v.y) {
        return .{ifx v.x > 0.0 then 1.0 else -1.0,0};
    }else {
        return .{0,ifx v.y > 0.0 then 1.0 else -1.0};
    }
}

adjust_wraps :: (point : Vector2, wrap_count : Vector2) -> Vector2 {
    return point + .{WINDOW_WIDTH,WINDOW_HEIGHT}*wrap_count;
}

floor_vector2 :: (v : Vector2) -> Vector2 {
    return .{floor(v.x),floor(v.y)};
}

floor_vector3 :: (v : Vector3) -> Vector3 {
    return .{floor(v.x),floor(v.y),floor(v.z)};
}

get_quaternion_from_axis_and_angle :: (axis : Vector3, angle : float) -> Quaternion {
    q : Quaternion;
    set_from_axis_and_angle(*q,axis,angle);
    return q;
}