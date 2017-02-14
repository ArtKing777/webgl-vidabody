
# TODO!!!
# * put values to null when they're set
# * put ault values to all objects in material
#   when setting a slice
{mat3, mat4, vec2, vec3, vec4, quat} = require 'gl-matrix-2-2'

MAX_SLICES = 1
FIRST_SLICE_UNIFORM = 0
# Values at which slice produces alpha=0
# and regular alpha can be used
DEFAULT_SLICE_P = new Float32Array([0,0,10,1])
DEFAULT_SLICE_N = new Float32Array([0,0,-1,1])

class Slice
    constructor: (names, slice_point, slice_min, slice_max) ->

        @names = names.concat()

        # uniform must be vec4
        @slice_point = vec4.create()
        vec3.copy(@slice_point, slice_point)

        @slice_min = vec3.create()
        vec3.copy(@slice_min, slice_min)

        @slice_max = vec3.create()
        vec3.copy(@slice_max, slice_max)

        # uniform must be vec4
        @slice_normal = vec4.create()
        @updateNormal(true)

    updateNormal: (recalculateBounds) ->
        vec3.sub(@slice_normal, @slice_min, @slice_max)

        if recalculateBounds
            bounds = null
            for name in @names
                ob = objects[name]
                if not ob?.data
                    continue
                # TODO FIXME: slicing may be wrong when data is not loaded
                # (test playing a tour with slices in an object not yet loaded)
                bounds = calculate_bounds_in_direction(ob, bounds, @slice_point, @slice_normal)
            if bounds
                # slice_normal is actually min - max, so these come out inverted
                vec3.copy(@slice_min, bounds.max)
                vec3.copy(@slice_max, bounds.min)

                vec3.sub(@slice_normal, @slice_min, @slice_max)


    getScreenSpaceNormal: () ->
        cam_rot = objects.Camera.rotation
        inv_cam_rot = quat.invert(quat.create(), cam_rot)
        mat = mat4.create() # cam-to-screen matrix
        s = vec4.create()   # result of mat*point
        r = vec3.create()   # screen space normal
        mat4.invert(mat, objects.Camera.world_matrix)
        mat4.mul(mat, objects.Camera.projection_matrix, mat)
        z_to_scale = Math.tan(objects.Camera.field_of_view*0.5)
        h_width = render_manager.width * 0.5
        h_height = render_manager.height * 0.5

        vec4.transformMat4(s, @slice_point, mat)
        x = (1+s[0]/s[3]) * h_width
        y = (1-s[1]/s[3]) * h_height
        scale = z_to_scale / (s[2]/s[3])

        vec3.transformQuat(r, @slice_normal, inv_cam_rot)
        r[0] = -r[0]
        
        vec2.normalize(r, r)

        return { 'x': r[0], 'y': r[1] }


class SlicingManager
    constructor: () ->

        @slices = []

        scene.pre_draw_callbacks.append(@update_slices.bind(this))
    
    update_slices: () ->
        for slice in @slices
            # Assign uniforms
            # TODO this code does not handle MAX_SLICES other than 1...
            for name in slice.names
                obj = objects[name]
                if obj
                    obj.custom_uniform_values[0] = slice.slice_point
                    obj.custom_uniform_values[1] = slice.slice_normal

    slice_objects: (object_list) ->
        names = {}
        min3 = [ Infinity, Infinity, Infinity]
        max3 = [-Infinity,-Infinity,-Infinity]
        h = []
        v = []
        for obj in object_list
            for oname in obj.joint_meshes or [obj.name]
                o = objects[oname]
                if not o
                    continue
                names[oname] = 1
                vec3.scale(h, o.dimensions, 0.5)
                vec3.transformQuat(h, h, quat.invert([], o.rotation))
                pos = real_position(o)
                vec3.min(min3, min3, vec3.sub(v, pos, h))
                vec3.max(max3, max3, vec3.add(v, pos, h))
        center = vec3.add(v, min3, max3)
        vec3.scale(center, center, 0.5)
        names = Object.keys(names)
        @add_slice_group(names, center,
                             [center[0], center[1], min3[2]],
                             [center[0], center[1], max3[2]],
                             false)
        @show_widgets()
    
    add_slice_group: (objectNames, slice_point, slice_min, slice_max, no_widget) ->

        slice = new Slice(objectNames, slice_point, slice_min, slice_max)
        for oname in objectNames
            obj = objects[oname]
            do (obj) ->
                if obj
                    obj.sliced = true
                    obj.slices.push(slice)
                    try_set_mat = ->
                        mat = obj.materials[0]
                        if not mat
                            # Material is not loaded, try again later
                            # (using promises would be very nice)
                            return requestAnimationFrame try_set_mat
                        if obj.sliced and not mat.sliced
                            mat.sliced = true
                            # save original double sided state
                            mat.orig_double_sided = mat.double_sided
                            mat.double_sided = true
                    try_set_mat()
                    # Force always_alpha objects opaque
                    # (not necessary but I put this for the buggy mesh sorting of the pericardium)
                    if obj.always_alpha
                        set_pass(obj, 0)

        @slices.append(slice)
        # TODO check MAX_SLICES per object

        if no_widget
            return

        widget = template('#slice-widget', $('#app')[0])

        slice.widget = widget

        if not render_manager.debug.box.scene
            render_manager.debug.box.scene = scene

        plane = render_manager.debug.box.clone()
        plane.last_sort_rotation = vec3.create()
        plane.last_sort_rotation[2] = -100

        delete objects[plane.name]

        # saving the reference for removing the plane later
        # saving on root, because root is exempt from JSON.stringify in tour editor
        widget.root.plane = plane

        s = vec3.length(slice.slice_normal) / 2
        vec3.set(plane.scale, s, s, 0)

        vec3.set(plane.color, 1, 1, 1) # alpha does not matter
        plane.visible = false

        up = vec3.create()
        up[1] = 1
        m4 = mat4.create()
        m3 = mat3.create()
        updatePlane = (->
            return ->
                # plane rotation
                a = slice.slice_point
                b = slice.slice_max
                if vec3.distance(a, b) < 0.00000001
                    a = slice.slice_min
                    b = slice.slice_point
                mat4.lookAt(m4, a, b, up)
                mat3.fromMat4(m3, m4)
                quat.fromMat3(plane.rotation, m3)
                # plane position
                vec3.copy(plane.position, slice.slice_point)
        )()

        updatePlane()

        widget.root.onmouseover = (e) ->
            updatePlane()

            plane.visible = true

        widget.root.onmouseout = (e) ->
            plane.visible = false

        widget.slice_move.onmousedown = (e) ->
            move = (e, dx, dy) ->
                t0 = vec3.distance(slice.slice_point, slice.slice_min) / vec3.distance(slice.slice_max, slice.slice_min)
                direction = slice.getScreenSpaceNormal()
                # let's say 200px is full move from min to max
                dt = (dx * direction.x + dy * direction.y) / 200.0
                t1 = Math.max(0, Math.min(1, t0 + dt))
                #console.log(t0, '->', t1)
                vec3.lerp(slice.slice_point, slice.slice_min, slice.slice_max, t1)

                updatePlane()

                plane.visible = true
                main_loop.reset_timeout()

            up = ->
                plane.visible = false

                tour_editor.save_state(0, 'slicing')

            modal_mouse_drag(e, move, up)

        widget.slice_rotate.onmousedown = (e) ->
            axis = vec3.create()
            smin = vec3.create()
            smax = vec3.create()
            m4 = mat4.create()

            move = (e, dx, dy) ->
                # camera directions - do not have to be exact
                dir_ahead = objects.Camera.get_ray_direction(0.5, 0.5)
                dir_aside = objects.Camera.get_ray_direction(0.5 - dx / 400.0, 0.5 - dy / 400.0)

                vec3.cross(axis, dir_ahead, dir_aside)
                if vec3.length(axis) > 0
                    # we have good rotation axis - make the matrix to rotate around it
                    # let's say 1 radian per 200 pixels
                    mat4.identity(m4)
                    mat4.rotate(m4, m4, Math.sqrt(dx * dx + dy * dy) / 200.0, axis)

                    # and rotate slice_min/max around slice_point
                    vec3.subtract(smin, slice.slice_min, slice.slice_point)
                    vec3.subtract(smax, slice.slice_max, slice.slice_point)
                    vec3.transformMat4(smin, smin, m4)
                    vec3.transformMat4(smax, smax, m4)
                    vec3.add(slice.slice_min, slice.slice_point, smin)
                    vec3.add(slice.slice_max, slice.slice_point, smax)

                    slice.updateNormal()

                    updatePlane()

                plane.visible = true
                main_loop.reset_timeout()

            up = ->
                plane.visible = false

                slice.updateNormal(true)

                tour_editor.save_state(0, 'slicing')

            modal_mouse_drag(e, move, up)

        widget.root.onmousedown = (e) ->
            move = (e, dx, dy) ->
                x = widget.root.offsetLeft + dx
                y = widget.root.offsetTop + dy
                widget.root.style.left = x + 'px'
                widget.root.style.top = y + 'px'
            if e.target == widget.root
                modal_mouse_drag(e, move)

    # get array of mesh slices(currently just 1)
    get_mesh_slices: (name) ->
        result = []

        for slice in @slices
            if slice.names.indexOf(name) > -1
                result.push(slice)

        return result

    # this method is going to be main slicing manager workhorse
    # it will replace and/or transition old slices by/to new ones
    to: (new_slices, transition_time) ->

        slices_to_remove = @slices.concat()
        slices_to_create = new_slices.concat()

        slices_to_animate = []
        if transition_time
            for to_slice in slices_to_create
                # look for corresponding slice in slices_to_remove
                for from_slice in slices_to_remove
                    if to_slice.names.length == from_slice.names.length
                        same_slice = true
                        for to_name in to_slice.names
                            if from_slice.names.indexOf(to_name) < 0
                                same_slice = false
                                break
                        if same_slice
                            slices_to_animate.push([from_slice, to_slice])
                            break

            for slice_pair in slices_to_animate
                slices_to_remove.remove(slice_pair[0])
                slices_to_create.remove(slice_pair[1])

                animate = (slice_pair) ->
                    t = transition_time
                    slice_point = vec3.clone(slice_pair[0].slice_point)
                    slice_min   = vec3.clone(slice_pair[0].slice_min)
                    slice_max   = vec3.clone(slice_pair[0].slice_max)
                    animate_tick = (dt) ->
                        
                        t -= 0.001 * dt
                        t = Math.max(0.0, t)
                        lerp = 1.0 - t / transition_time
                        vec3.lerp(slice_pair[0].slice_point, slice_point, slice_pair[1].slice_point, lerp)
                        vec3.lerp(slice_pair[0].slice_min,   slice_min,   slice_pair[1].slice_min,   lerp)
                        vec3.lerp(slice_pair[0].slice_max,   slice_max,   slice_pair[1].slice_max,   lerp)
                        slice_pair[0].updateNormal()
                        if t > 0
                            requestAnimationFrame(animate_tick)
                    requestAnimationFrame(animate_tick)
                animate(slice_pair)

        @remove_slices(slices_to_remove)

        while slices_to_create.length > 0
            slice = slices_to_create.pop()

            @add_slice_group(slice.names, slice.slice_point, slice.slice_min, slice.slice_max, not slice.widget)

        @show_widgets()

    remove_slices: (slices_to_remove) ->
        while slices_to_remove.length > 0
            slice = slices_to_remove.pop()
            for name in slice.names
                obj = objects[name]
                if not obj
                    continue
                obj.custom_uniform_values[0] = DEFAULT_SLICE_P
                obj.custom_uniform_values[1] = DEFAULT_SLICE_N
                obj.sliced = false
                obj.slices.splice(0)
                if obj.always_alpha
                    set_pass(obj, 1)
                mat = obj.materials[0]
                if mat
                    mat.sliced = false
                    for mesh in mat.users
                        if mesh.sliced
                            mat.sliced = true
                            break
                    if not mat.sliced
                        mat.double_sided = mat.orig_double_sided

            if slice.widget and slice.widget.root and slice.widget.root.parentNode
                slice.widget.root.parentNode.removeChild(slice.widget.root)
                slice.widget.root.plane.remove()

            @slices.remove(slice)
    
    remove_all_slices: () ->
        @remove_slices(@slices)

    show_widgets: () ->
        for w in $('#slice-widget')
            w.style.display = 'none'
        for slice in @slices
            if slice.widget and slice.widget.root and slice.widget.root.style.display == 'none'
                for name in slice.names
                    obj = objects[name]
                    if obj?.selected
                        slice.widget.root.style.display = ''
                        break


init_slicing = ->
    window.slicing_manager = new SlicingManager()
    
    # Put the default value to all objects
    for _, obj of objects
        if obj.type == 'MESH'
            obj.custom_uniform_values[0] = DEFAULT_SLICE_P
            obj.custom_uniform_values[1] = DEFAULT_SLICE_N
    
    # joint_meshes = [['a', 'b', 'c'], ...]
    # and then a loop can do the equivalent of objects['a'].joint_meshes = joint_meshes[0]
    # for all meshes that are in those lists
    for array in JOINT_MESHES
        for name in array
            obj = objects[name]
            if obj
                obj.joint_meshes = array


JOINT_MESHES = [
    [
        'Exterior',
        'Coronary_Veins',
        'Sinus',
        'Coronary_Arteries_Left',
        'Coronary_Arteries_Right',
        'Mitral_Valve',
        'Pulmonary_Valve',
        'Tricuspi_Valve',
        'Aortic_Artery_Valve',
        'Pericardium',
        'Ventricle_Left',
        'Ventricle_Right',
        'Auricle_Left',
        'Auricle_Right',
        #'Blood_Flow_Right_1',
        #'Blood_Flow_Right_2',
        #'Blood_Flow_Left',
        'Superior_Vena_Cava',
        'Inferior_Vena_Cava',
        'Pulmonary_Veins_Left',
        'Pulmonary_Veins_Right',
        'Pulmonary_Artery',
        'Aortic_Artery_Arch',
    ]
]
