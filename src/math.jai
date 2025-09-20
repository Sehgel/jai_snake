cycle :: (point : Vector2, padding : float = 0.0) -> Vector2 {
    return .{fmod_cycling(point.x + WINDOW_WIDTH ,  WINDOW_WIDTH),
             fmod_cycling(point.y + WINDOW_HEIGHT,  WINDOW_HEIGHT)};
}

cycle3 :: (point : Vector2, padding : float = 0.0) -> Vector3 {
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

ease_out_elastic :: (x : float) -> float {
    C4 :: (2.0 * PI) / 3.0;
    return pow(2.0, -10.0 * x) * sin((x * 10.0 - 0.75) * C4) + 1.0;
}

closest :: (x : float, a : float, b : float) -> float {
    if abs(x - a) < abs(x - b) then
        return a;
    else
        return b;
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

remap :: (value : float, from_a : float, from_b: float, to_a : float, to_b : float) -> float{
    return from_b + (value - from_a) * (to_b - from_b) / (to_a - from_a);
}