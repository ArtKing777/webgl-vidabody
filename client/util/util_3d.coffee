

# Useful constants
UNIT_QUAT = new Float32Array([0,0,0,1])
Z_VECTOR = new Float32Array([0,0,1])

{mat3, mat4, vec2, vec3, vec4, quat} = require 'gl-matrix-2-2'

# For the engine while it's not a module
if window?
    window.mat3 = mat3
    window.mat4 = mat4
    window.vec3 = vec3
    window.vec4 = vec4
    window.quat = quat
    

# Compares two 3D mat4 for equality
# (ignoring 4D vector)
mat4_equal = (a, b) ->
    a[0]==b[0] and a[1]==b[1] and a[2]==b[2] and a[12]==b[12] and a[4]==b[4] and \
    a[5]==b[5]  and a[6]==b[6] and a[13]==b[13] and a[8]==b[8] and a[9]==b[9] and a[10]==b[10] and a[14]==b[14]

# updates shader color array from hex string
update_shader_color = (array, str) ->
    hex = parseInt(str.substr(1), 16)
    r = ( hex >> 16 & 255 ) / 255
    g = ( hex >> 8 & 255 ) / 255
    b = ( hex & 255 ) / 255
    array[0] = r
    array[1] = g
    array[2] = b

# calculate coordinate ranges of the object
# along specified axis in the world space
calculate_bounds_in_direction = (mesh, bounds, origin, direction) ->
    dir = vec3.create()
    vec3.normalize(dir, direction)

    data = mesh.data
    varray = data.varray
    stride = data.stride >> 2

    min = vec3.create()
    vec3.copy(min, origin)
    max = vec3.create()
    vec3.copy(max, origin)

    if bounds
        min = bounds.min
        max = bounds.max
    else
        bounds = { 'min': min, 'max': max }

    tmp = vec3.create()

    vec3.subtract(tmp, min, origin)
    dot_min = vec3.dot(tmp, dir)

    vec3.subtract(tmp, max, origin)
    dot_max = vec3.dot(tmp, dir)

    k = 0
    L = varray.length - 2
    while k < L
        vec3.set(tmp, varray[k], varray[k + 1], varray[k + 2])
        vec3.transformMat4(tmp, tmp, mesh.world_matrix)

        vec3.subtract(tmp, tmp, origin)
        dot = vec3.dot(tmp, dir)

        if dot < dot_min
            dot_min = dot
            vec3.scale(min, dir, dot)
            vec3.add(min, min, origin)
        else if dot > dot_max
            dot_max = dot
            vec3.scale(max, dir, dot)
            vec3.add(max, max, origin)

        k += stride

    return bounds

point3d_to_screen = do ->
    p = new Float32Array(4)
    mat = mat4.create()
    point3d_to_screen = (point) ->
        p[0] = point[0]
        p[1] = point[1]
        p[2] = point[2]
        p[3] = 1
        mat4.invert(mat, scene.active_camera.world_matrix)
        mat4.mul(mat, scene.active_camera.projection_matrix, mat)
        vec4.transformMat4(p, p, mat)
        p[3] = Math.max(p[3],0.000001)
        x = (p[0]/p[3] + 1)*0.5
        y = (1 - p[1]/p[3])*0.5
        return [x,y]

trackball_rotation = (out, center_x, center_y, rel_x, rel_y, radius, rotation_speed) ->
    dist_from_center = min(1, Math.sqrt(center_x**2 + center_y**2)/radius)
    influence = (1-dist_from_center) ** 2
    out[0] += rel_y * rotation_speed * influence
    out[1] += rel_x * rotation_speed * influence
    last_x = center_x - rel_x
    last_y = center_y - rel_y
    if last_y < 0 and center_y < 0
        ang1 = Math.atan2(-center_x, -center_y)
        ang2 = Math.atan2(-last_x, -last_y)
    else
        ang1 = Math.atan2(center_x, center_y)
        ang2 = Math.atan2(last_x, last_y)
    out[2] += (ang2 - ang1) * (1-influence)
    return out

turntable_rotation = (out, center_x, center_y, rel_x, rel_y, radius, rotation_speed) ->
    dist_from_center = min(1, Math.sqrt(center_x**2 + center_y**2)/radius)
    influence = (1-dist_from_center) ** 2
    out[0] += rel_y * rotation_speed * influence
    out[1] += rel_x * rotation_speed * influence
    return out


lookat = do ->
    tmp1 = vec3.create()
    tmp2 = vec3.create()
    q = quat.create()
    (viewer,target,viewer_up,viewer_front,smooth,frame_duration_seconds) ->
        SIGNED_AXES = {'X': 1, 'Y': 2, 'Z': 3, '-X': -1, '-Y': -2, '-Z': -3}
        u_idx = SIGNED_AXES[viewer_up]
        f_idx = SIGNED_AXES[viewer_front]
        tup = Z_VECTOR
        #vec3.transformQuat(tup, tup, viewer.rotation)
        if u_idx<0
            tup = vec3.negate(vec3.clone(tup),tup)
        origin = viewer.get_world_position()
        u = abs(u_idx) - 1
        f = abs(f_idx) - 1
        s = 3 - u - f

        if f_idx < 0
            front = vec3.sub(tmp1, origin, target)
        else
            front = vec3.sub(tmp1, target, origin)
        up = vec3.clone(tup)
        if u == 1 or f == 2
            side = vec3.cross(tmp2, up, front)
        else
            side = vec3.cross(tmp2, front, up)
        # TODO: should be this condition above?
        if [0,1,0,0,1][2-f+s]
            up = vec3.cross(up, side, front)
        else
            up = vec3.cross(up, front, side)
        vec3.normalize(side, side)
        vec3.normalize(up, up)
        vec3.normalize(front, front)
        m = mat3.create()
        m[u] = up[0]
        m[u+3] = up[1]
        m[u+6] = up[2]
        m[f] = front[0]
        m[f+3] = front[1]
        m[f+6] = front[2]
        m[s] = side[0]
        m[s+3] = side[1]
        m[s+6] = side[2]
        n = frame_duration_seconds * 60
        smooth = max(0,1 - smooth)
        smooth = 1 - Math.pow(smooth, n) * Math.pow((1/smooth - 1), n)
        viewer_rotation = viewer.rotation
        quat.slerp(viewer_rotation, viewer_rotation, quat.fromMat3(q, m), smooth)
        # necessary only for paralell up and front
        # also for lerps
        # won't be necessary later with the animation system

        quat.normalize(viewer_rotation, viewer_rotation)


tilt_rotation = (center_x, center_y, rel_x, rel_y) ->
    last_x = center_x - rel_x
    last_y = center_y - rel_y
    if last_y < 0 and center_y < 0
        ang1 = Math.atan2(-center_x, -center_y)
        ang2 = Math.atan2(-last_x, -last_y)
    else
        ang1 = Math.atan2(center_x, center_y)
        ang2 = Math.atan2(last_x, last_y)
    return ang2 - ang1

rotate_object_space = do ->
    q = new Float32Array(4)
    rot = new Float32Array(4)
    (out, in_rot, reference, x, y, z) ->
        inv = quat.invert(q, reference)
        quat.mul(out, inv, in_rot)
        rot.set(UNIT_QUAT)
        quat.rotateX(rot, rot, x)
        quat.rotateY(rot, rot, y)
        quat.rotateZ(rot, rot, z)
        quat.mul(out, rot, out)
        quat.mul(out, reference, out)
        quat.normalize(out, out)

rotate_around = do ->
    q = new Float32Array(4)
    obr = new Float32Array(4)
    (ob, point, euler) ->
        pos = ob.position
        rot = ob.rotation
        # pos and rot are mutated in place
        invrot = quat.invert(q, rot)
        obr.set(UNIT_QUAT)
        quat.rotateX(obr, obr, euler[0])
        quat.rotateY(obr, obr, euler[1])
        quat.rotateZ(obr, obr, euler[2])
        pos = vec3.sub(pos, pos, point)
        vec3.transformQuat(pos, pos, invrot)
        vec3.transformQuat(pos, pos, obr)
        vec3.transformQuat(pos, pos, rot)
        vec3.add(pos, pos, point)
        quat.mul(rot, rot, obr)


mat4_to_quat = (out, m) ->
    m3 = mat3.fromMat4(mat3.create(), m);
    v = m3.subarray(0,3)
    vec3.normalize(v, v)
    v = m3.subarray(3,6)
    vec3.normalize(v, v)
    v = m3.subarray(6,9)
    vec3.normalize(v, v)
    quat.fromMat3(out, m3);
    # gl-matrix quats and ours have opposite signs
    out[3] = -out[3]
    return out
