
main_view = require '../views/main_view'
home_state = null

init_camera_actions = ->
    set_home_state = ->
        scene.post_draw_callbacks.remove(set_home_state)
        home_state = snap_helper.get_state()
    scene.post_draw_callbacks.append(set_home_state)


exports.go_home = go_home = (show_only_skeleton) ->
    # Position/distance is not correctly set
    if tour_viewer.viewing
        snap_helper.set_state(tour_viewer.slides[tour_viewer.current_slide].state, 1000)
        return 1000
    else
        snap_helper.set_state(home_state, 1500)
        if show_only_skeleton
            set_meshes_state({}, false) # This hides all and resets colors
            for o in ORGAN_LIST
                if o and (o.startswith('Skeletal') or objects[o]?.properties.system == 'Skeletal')
                    show_mesh(o)
            update_visiblity_tree()
        tour_editor.save_state(1550)
        return 1500


prepare_state = () ->
    update_visible_area()
    min3 = visible_area.min
    max3 = visible_area.max

    if min3[0] < max3[0]
        # return the center of visible stuff and distance to camera
        target = [(max3[0] + min3[0]) / 2, (max3[1] + min3[1]) / 2, (max3[2] + min3[2]) / 2]
        inv_ratio = render_manager.height / render_manager.width
        distance = max((max3[0] - min3[0])*inv_ratio, max3[2] - min3[2]) * 1.6 + (max3[1] - min3[1]) / 2
        return [distance, target]

    # default to current camera state
    snap_helper.get_state()


exports.go_left_view = () ->
    state = prepare_state()
    snap_helper.set_state([state[0],state[1],[0.5,0.5,0.5,0.5],"Scene",null], 1000)
    if tour_viewer.viewing
        tour_viewer.hide_annotations()

exports.go_right_view = () ->
    state = prepare_state()
    snap_helper.set_state([state[0],state[1],[0.5,-0.5,-0.5,0.5],"Scene",null], 1000)
    if tour_viewer.viewing
        tour_viewer.hide_annotations()
    tour_editor.save_state(1550)

exports.go_front_view = () ->
    s = Math.sqrt(2)/2
    state = prepare_state()
    snap_helper.set_state([state[0],state[1],[s,0,0,s],"Scene",null], 1000)
    if tour_viewer.viewing
        tour_viewer.hide_annotations()
    tour_editor.save_state(1550)

exports.go_back_view = () ->
    s = Math.sqrt(2)/2
    state = prepare_state()
    snap_helper.set_state([state[0],state[1],[0,s,s,0],"Scene",null], 1000)
    if tour_viewer.viewing
        tour_viewer.hide_annotations()
    tour_editor.save_state(1550)

exports.go_bottom_view = () ->
    state = prepare_state()
    snap_helper.set_state([state[0],state[1],[1,0,0,0],"Scene",null], 1000)
    if tour_viewer.viewing
        tour_viewer.hide_annotations()
    tour_editor.save_state(1550)

exports.go_up_view = () ->
    state = prepare_state()
    snap_helper.set_state([state[0],state[1],[0,0,0,-1],"Scene",null], 1000)
    if tour_viewer.viewing
        tour_viewer.hide_annotations()
    tour_editor.save_state(1550)

go_here = (organs) ->
    exports.go_here organs

exports.go_here = (organs) ->
    # world space frustum culling plane normals
    {_cull_top, _cull_bottom, _cull_left, _cull_right, _cam2world} = render_manager
    cam_Z = vec3.normalize vec3.create(), _cam2world[8...11]
    # Get the minimum dot of each organ position minus radius
    min_dot_top = Infinity
    min_dot_bottom = Infinity
    min_dot_left = Infinity
    min_dot_right = Infinity
    min_center = [Infinity, Infinity, Infinity]
    max_center = [-Infinity, -Infinity, -Infinity]
    for name in organs
        show_mesh(name)
        ob = objects[name]
        if ob
            position = real_position(ob)
            min_dot_top = min(min_dot_top, vec3.dot(_cull_top, position) - (ob.radius or 0))
            min_dot_bottom = min(min_dot_bottom, vec3.dot(_cull_bottom, position) - (ob.radius or 0))
            min_dot_left = min(min_dot_left, vec3.dot(_cull_left, position) - (ob.radius or 0))
            min_dot_right = min(min_dot_right, vec3.dot(_cull_right, position) - (ob.radius or 0))
            vec3.min min_center, min_center, position
            vec3.max max_center, max_center, position
    if min_dot_right == Infinity
        return
    # Get points of planes that wrap the objects
    plane_point_top = vec3.scale(vec3.create(), _cull_top, min_dot_top)
    plane_point_bottom = vec3.scale(vec3.create(), _cull_bottom, min_dot_bottom)
    plane_point_left = vec3.scale(vec3.create(), _cull_left, min_dot_left)
    plane_point_right = vec3.scale(vec3.create(), _cull_right, min_dot_right)
    [a,b] = get_frustrum_pos(_cull_top, plane_point_top, _cull_bottom, plane_point_bottom, _cull_right, plane_point_right, _cull_left, plane_point_left)
    camZ = vec3.create()
    vec3.transformQuat(camZ, Z_VECTOR, scene.active_camera.rotation)
    if vec3.dot(camZ, a) < vec3.dot(camZ, b)
        target = b
    else
        target = a
    # Calculate distance and add to camera
    center = vec3.add vec3.create(), min_center, max_center
    vec3.scale center, center, 0.5
    # dist = vec3.dot(cam_Z, objects.Camera.position) - vec3.dot(cam_Z, center)
    # vec3.sub target, target, vec3.scale(vec3.create(), cam_Z, dist)
    # Start auto pilot, save state, set modified view, etc
    timeout = 1200
    snap_helper.set_state([vec3.dist(center, target), center, scene.active_camera.rotation], timeout)
    tour_editor.save_state(timeout + 50)
    if tour_viewer.viewing
        if not tour_viewer.modified_view
            tour_viewer.set_modified_view()
    return timeout
    
    
planes_intersection = (m)->
    # m is the matrix defined by 3 plane equations.

    a = [m[0], m[1], m[2],
         m[4], m[5], m[6],
         m[8], m[9], m[10]]

    inva = []
    mat3.invert inva, a
    r = [0,0,0]

    r[0] =  (inva[0] * m[3]) + (inva[1] * m[7]) + (inva[2] * m[11])
    r[1] =  (inva[3] * m[3]) + (inva[4] * m[7]) + (inva[5] * m[11])
    r[2] =  (inva[6] * m[3]) + (inva[7] * m[7]) + (inva[8] * m[11])

    return r


plane_eq = (n,p)->
    # p is a point of the plane
    # n is the normal of the plane
    return [n[0], n[1], n[2], n[0]*p[0]+n[1]*p[1]+n[2]*p[2]]

mid_point = (a,b) ->
    return [(a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5, (a[2] + b[2]) * 0.5]

get_frustrum_pos = (nu, pu, nd, pd, nr, pr, nl, pl)->
    plane_u = plane_eq nu, pu
    plane_d = plane_eq nd, pd
    plane_r = plane_eq nr, pr
    plane_l = plane_eq nl, pl

    u = planes_intersection plane_r.concat(plane_l).concat(plane_u)
    d = planes_intersection plane_r.concat(plane_l).concat(plane_d)
    r = planes_intersection plane_u.concat(plane_d).concat(plane_r)
    l = planes_intersection plane_u.concat(plane_d).concat(plane_l)

    a = mid_point u, d
    b = mid_point l, r

    return [a,b]
