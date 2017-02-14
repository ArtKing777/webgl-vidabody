

{vec3, vec4, quat} = require 'gl-matrix-2-2'
main_view = require '../views/main_view'

###
TODO:

The engine has a feature for rendering objects mirrored.
Sometimes we want it to render only one of the mirrored versions,
and sometimes we want to render the mirrors separately (as two disctinct objects)
when they have different color/regions/alpha/slicing

Every time we set the settings of one of the mirrors, we check if they're equal or not,
If they are, we remove the R from passes and set L.mirrors to 3
otherwise we add it to the pass, and set the L.mirrors to 1

Each mirrored mesh will be exported in packer as same object
with _R instead of _L, mirror=2 and .mirror_mesh = the other mesh in both

###



# Populated in organ_tree_view.py
exports.ORGAN_LIST = ORGAN_LIST= []
exports.ORGAN_VISIBLE_NAMES = ORGAN_VISIBLE_NAMES = {}

swap_region = (ob, name) ->
    mat = ob.materials[0]
    for tex in scene.materials.sphenoid_regions.textures
        if tex.name=='Sphenoid_'+name+'.crn'
            mat.textures[mat.region_texture] = tex
            ob.region = name
            return

    # Not found, setting black texture
    mat.textures[mat.region_texture] = render_manager.textures.Region_highlight
    ob.region = ''


get_meshes_state = ->
    r = {}
    for name in ORGAN_LIST
        o = objects[name]
        if o
            if o.passes
                c = o.orig_color or o.color
                r[name] = [c[0], c[1], c[2],
                    # pass is not used
                    o.bg, o.visible, o.region or '', o.passes[0], o.alpha, o.fg,
                    o.color_delay, o.alpha_delay, o.keep_prev_color
                ]
            else if o.curves
                r[name] = [0, 0, 0,
                0, o.visible, '', 0, 1, 0,
                0, 0]
    return r


set_meshes_state = (state, will_transition, lod_filter='^$') ->
    re = new RegExp(lod_filter)
    transition_meshes = []
    for name in ORGAN_LIST
        ob = objects[name]
        props = state[name]
        if not ob
            continue
        transition = false
        hide_ob = false
        # Default values
        r = g = b = 0
        bg = visible = region = pass = fg = 0
        color_delay = alpha_delay = 0
        alpha = 1
        keep_prev_color = false
        if props
            [r, g, b,
            #3  4        5       6     7      8
            bg, visible, region, pass, alpha, fg
            color_delay, alpha_delay, keep_prev_color] = props
            # Old tours don't have *_delay so we ensure they're 0
            # NOTE: Mutating for use in transition_state()
            props[9] = color_delay or 0
            props[10] = alpha_delay or 0
            props[11] = keep_prev_color or false
        ob.color_delay = color_delay or 0
        ob.alpha_delay = alpha_delay or 0
        ob.keep_prev_color = keep_prev_color or false

        # Get actual color
        c = ob.orig_color or ob.color

        # show_mesh resets fg/bg so we put it before
        if (not ob.visible) != (not visible)
            if ob.type == 'MESH' and not ob.only_phy
                transition = true
            if visible
                ob.alpha = 0
                lod = if re.test(name) then 0.2 else 1
                show_mesh(null, ob, lod)
            else
                hide_ob = true
        else if will_transition and visible and alpha > 0
            # Compare values to see if we'll assign the color
            # during transition_state
            transition = c[0]!=r or c[1]!=g or c[2]!=b

        # Having a mesh both in bg and fg was allowed in the past
        # so we ensure we set only one of those states
        bg = bg and not fg
        # If any of them is assigned, we won't transition them
        # (no alpha + always over/under pass yet)
        if ob.bg and not bg
            scene.bg_pass.remove(ob)
        else if not ob.bg and bg
            transition = false
            scene.bg_pass.append(ob)
        if ob.fg and not fg
            scene.fg_pass.remove(ob)
        else if not ob.fg and fg
            transition = false
            scene.fg_pass.append(ob)
        ob.bg = bg
        ob.fg = fg

        #if ob.region or s[5]
            #swap_region(ob, s[5])
        if ob.alpha != alpha and (not fg or bg)
            if visible
                # when it's not visible but it was, this is assigned above
                transition = true
        if props and transition and will_transition and ob.type=='MESH' and not ob.only_phy
            # Pass of objects with default alpha are special cased in slicing
            if not ob.default_alpha
                set_pass(ob, 1)
            # Set a lower threshold when neither alpha was
            # almost opaque on purpose
            props[12] = if Math.max(ob.alpha, alpha) < 0.95 then 0.84 else 0.99
            transition_meshes.push(ob)
        else
            # Assign color, alpha, etc, directly
            c[0] = r
            c[1] = g
            c[2] = b
            set_alpha(ob, alpha)
            if hide_ob
                hide_mesh(null, ob)
    return transition_meshes

# Call this after set_meshes_state(..., true) every frame until finished is true
# and when finished or canceled, call ensure_invisible_meshes_are_hidden(meshes)
transition_state = (
    old_state # get_meshes_state(); or if there weren't changes and
              # there wasn't another transition, the state of the previous slide
    new_state # Target mesh state (with delay times)
    meshes    # List of meshes affected by the transition
    duration  # Transition duration in milliseconds
    t         # Current time (from transition start) in milliseconds
    t_offset  # time offset for substracting delays (clamp to 0)
    ) ->

    inv_duration = 1/duration
    finished = true

    for ob in meshes
        mesh_name = ob.name
        [r1, g1, b1,
        _, visible1, _, _, alpha1] = old_state[mesh_name]
        alpha1 = 0 if not visible1
        [r2, g2, b2,
        _, visible2, _, _, alpha2, _,
        color_delay, alpha_delay, keep_prev_color, alpha_threshold] = new_state[mesh_name]
        alpha2 = 0 if not visible2
        color_delay = max(color_delay - t_offset, 0)
        alpha_delay = max(alpha_delay - t_offset, 0)
        # Calculate factors, range [0, 1]
        color_f = Math.min(1, Math.max(0, (t - color_delay) * inv_duration))
        alpha_f = Math.min(1, Math.max(0, (t - alpha_delay) * inv_duration))
        if keep_prev_color
            inv_color_f = 1 - color_f
        else
            inv_color_f = 1 - Math.min(1, t * inv_duration)
        c = ob.orig_color or ob.color
        # Lerp color
        c[0] = r1 * inv_color_f + r2 * color_f
        c[1] = g1 * inv_color_f + g2 * color_f
        c[2] = b1 * inv_color_f + b2 * color_f
        # Lerp alpha
        set_alpha(ob, alpha1 + alpha_f * (alpha2 - alpha1), alpha_threshold)
        # It's finished when all factors reach 1
        finished = finished and color_f == 1 and alpha_f == 1
    return finished

# Use this when a transition ends or is canceled!
ensure_invisible_meshes_are_hidden = (meshes) ->
    for ob in meshes when ob.visible and ob.alpha <= 0.01
        hide_mesh(null, ob)
    return


dispose_phy_meshes = (list) ->
    for obj in list or scene.children
        if obj.data and obj.data.phy_mesh and (obj.physics_type == 'NO_COLLISION')
            destroy(obj.data.phy_mesh)
            obj.data.phy_mesh = null

# This function returns a mirrored position of the object
# if the object is mirrored
real_position = do ->
    _pos = vec3.create()
    (object) ->
        pos = object.world_matrix.subarray(12,15)
        pos = vec3.copy(_pos, pos)
        vec3.add(pos, pos, object.center)
        if object.mirrors == 2
            pos[0] = -pos[0]
        pos

copy_real_position = (out, object) ->
    vec3.copy(out, object.world_matrix.subarray(12,15))
    if object.mirrors == 2
        out[0] = -out[0]
    out

visible_area = { min: vec3.create(), max: vec3.create(), center: vec3.create() }
update_visible_area = (->
    h = vec3.create()
    t = vec3.create()
    q = quat.create()
    ->
        vec3.set(visible_area.min,  1e9,  1e9,  1e9)
        vec3.set(visible_area.max, -1e9, -1e9, -1e9)
        vec3.set(h, 0, 0, 0)
        for oname in ORGAN_LIST
            o = objects[oname]
            # skip object from microscenes
            if o?.scene != scene
                continue
            if o?.visible
                vec3.scale(h, o.dimensions, 0.5)
                vec3.transformQuat(h, h, quat.invert(q, o.rotation))
                pos = real_position(o)
                vec3.min(visible_area.min, visible_area.min, vec3.sub(t, pos, h))
                vec3.max(visible_area.max, visible_area.max, vec3.add(t, pos, h))
        vec3.add(visible_area.center, visible_area.min, visible_area.max)
        vec3.scale(visible_area.center, visible_area.center, 0.5)

)()


update_visiblity_tree = ->
    update_particles()
    update_visible_area()


exports.show_mesh = show_mesh = (name, object, min_lod) ->
    if object
        obj = object
    else
        main_loop.reset_timeout() #TODO: move this out
        obj = objects[name]
        if not obj
            return
    if not obj.visible
        if obj.particle_systems?
            for p in obj.particle_systems
                if not ('instance' of p)
                    p.instance = ParticleSystem(p.properties)
                    p.instance.pause()
                p.instance.play()

        if not obj.no_phy
            obj.physics_type = 'STATIC'

        obj.visible = true
        if obj.data
            try
                obj.instance_physics()
            catch
                console.error 'Error when instancing physics of mesh #{obj.name}'
        else if obj.type == 'MESH'
            scene.loader.load_mesh_data(obj, min_lod)
        if obj.default_alpha != 1
            set_alpha(obj, obj.default_alpha)
        # If it's in pass 1, we did remove it from mesh_passes, add it back
        if obj.passes?[0] == 1
            scene.mesh_passes[1].push(obj)

    if 'children' of obj
        for child in obj.children
            show_mesh(null, child, min_lod)
    return


exports.hide_mesh = hide_mesh = (name, object) ->
    if object
        obj = object
    else
        main_loop.reset_timeout() #TODO: move this out
        obj = objects[name]
        if not obj
            return
    if obj.visible
        if obj.particle_systems?
            for p in obj.particle_systems
                if 'instance' of p
                    p.instance.stop()

        obj.physics_type = 'NO_COLLISION'
        try
            obj.instance_physics()
        catch
            console.error 'Error when removing physics of mesh #{obj.name}'
        obj.visible = false
        unselect_object(obj)
        obj.alpha_delay = 0
        # Remove from pass 1 (better perf sorting alpha)
        if obj.passes?[0] == 1
            scene.mesh_passes[1].remove(obj)

    if 'children' of obj
        for child in obj.children
            hide_mesh(null, child)
    return


all_meshes_in_background = (mesh_names) ->
    all_in_bg = true
    for name in mesh_names
        ob = objects[name]
        if ob and not ob.bg
            all_in_bg = false
    all_in_bg


all_meshes_in_foreground = (mesh_names) ->
    all_in_fg = true
    for name in mesh_names
        ob = objects[name]
        if ob and not ob.fg
            all_in_fg = false
    all_in_fg


toggle_meshes_in_background = (mesh_names) ->
    all_in_bg = true
    # Calculate whether we'll set or remove the setting
    # and we'll show any mesh in the list that is hidden
    for name in mesh_names
        ob = objects[name]
        if ob
            show_mesh(null, ob)
            if not ob.bg
                all_in_bg = false
    # We need to do this because some meshes may become visible
    update_visiblity_tree()
    # Iterate and set
    for name in mesh_names
        ob = objects[name]
        if ob and ob.passes[0] < 5
            if ob.bg and all_in_bg
                scene.bg_pass.remove(ob)
            else if not ob.bg and not all_in_bg
                set_alpha(ob, 1)
                scene.bg_pass.append(ob)
                scene.fg_pass.remove(ob)
                ob.fg = false
            ob.bg = not all_in_bg
    # Call all things affected by this
    tour_editor.save_state()
    if not tour_viewer.modified_view
        tour_viewer.set_modified_view()


toggle_meshes_in_foreground = (mesh_names) ->
    all_in_fg = true
    # Calculate whether we'll set or remove the setting
    # and we'll show any mesh in the list that is hidden
    for name in mesh_names
        ob = objects[name]
        if ob
            show_mesh(null, ob)
            if not ob.fg
                all_in_fg = false
    # We need to do this because some meshes may become visible
    update_visiblity_tree()
    # Iterate and set
    for name in mesh_names
        ob = objects[name]
        if ob and ob.passes[0] < 5
            if ob.fg and all_in_fg
                scene.fg_pass.remove(ob)
            else if not ob.fg and not all_in_fg
                set_alpha(ob, 1)
                scene.fg_pass.append(ob)
                scene.bg_pass.remove(ob)
                ob.bg = false
            ob.fg = not all_in_fg
    # Call all things affected by this
    tour_editor.save_state()
    if not tour_viewer.modified_view
        tour_viewer.set_modified_view()

set_alpha = (o, alpha, threshold=0.99) ->
    o.alpha = alpha
    # Pass of objects with default alpha are special cased in slicing
    if o.sliced and o.always_alpha
        return
    mpass = if alpha < threshold then 1 else (o.always_alpha|0)
    if o.passes and o.passes[0] != mpass and o.passes[0] < 5
        otherpass = mpass ^ 1
        scene = o.scene
        scene.bg_pass?.remove(o)
        scene.fg_pass?.remove(o)
        o.bg = o.fg = false
        mesh_passes = scene.mesh_passes
        mesh_passes[otherpass].remove(o)
        mesh_passes[mpass].append(o)
        o.passes[0] = mpass

set_pass = (o, mpass) ->
    if o.passes and o.passes[0] != mpass and o.passes[0] < 5
        otherpass = mpass ^ 1
        scene = o.scene
        scene.bg_pass?.remove(o)
        scene.fg_pass?.remove(o)
        mesh_passes = scene.mesh_passes
        mesh_passes[otherpass].remove(o)
        mesh_passes[mpass].append(o)
        o.passes[0] = mpass



sort_mesh = do ->
  vector = vec3.create()
  inv_obj_quat = quat.create()
  sort_mesh = (mesh, cam_rotation) ->
    vec3.transformQuat(vector, Z_VECTOR, cam_rotation or mesh.scene.active_camera.rotation)
    # the above is world coords, we need to go to mesh local coords
    quat.invert(inv_obj_quat, mesh.rotation)
    vec3.transformQuat(vector, vector, inv_obj_quat)

    # scale up so that fractional dot values would actually sort
    vecScale = 8000/3  # (Limit = 16000 units in +-1 meter, /3 because x+y+z)
    vec3.scale(vector, vector, vecScale)

    vx = vector[0]
    vy = vector[1]
    vz = vector[2]

    data = mesh.data
    iarray = data.iarray
    varray = data.varray
    facesNumber = iarray.length / 3

    stride = data.stride >> 2

    mesh.sort_dot = 0

    if facesNumber < 65536
        sa = data.sortingArray
        if not sa
            data.sortingArray = new Uint32Array(facesNumber)
            sa = data.sortingArray

        mindot3 = Infinity
        j = 0
        for i in [0... facesNumber]
            k = iarray[j] * stride
            x = varray[k]
            y = varray[k + 1]
            z = varray[k + 2]

            k = iarray[j + 1] * stride
            x += varray[k]
            y += varray[k + 1]
            z += varray[k + 2]

            k = iarray[j + 2] * stride
            x += varray[k]
            y += varray[k + 1]
            z += varray[k + 2]

            # no need to divide by 3, since the order is preserved

            dot = (vx * x + vy * y + vz * z) + vecScale
            mindot3 = Math.min(mindot3, -dot)

            sa[i] = ((dot+vecScale) << 16) | i

            j += 3

        timsort_numeric(sa)

        # now reorder indices
        # can't be done without shadow copy
        if not data.icopy
            data.icopy = new Uint16Array(iarray)
        data.icopy.set(iarray)

        icopy = data.icopy

        j = 0
        for i in [0... facesNumber]

            k = 3 * (sa[i] & 65535)

            iarray[j] = icopy[k]
            j += 1
            k += 1

            iarray[j] = icopy[k]
            j += 1
            k += 1

            iarray[j] = icopy[k]
            j += 1

        # mark iarray for re-upload now
        mesh.update_iarray(iarray)

        mesh.sort_dot = mindot3/3

random_rot_scale = (ob, position) ->
    vec3.copy(ob.position, position)
    quat.normalize(ob.rotation,vec4.random(ob.rotation))
    ob.scale[0]=ob.scale[1]=ob.scale[2]=(Math.random()*0.5)+0.5

add_custom_scene_and_mesh_attributes = (scene) ->
    scene.bg_pass = []
    scene.fg_pass = []
    dim_half = vec3.create()
    for ob in scene.children
        if ob.particle_systems?
            ob.visible = false
            for p in ob.particle_systems
                p_name = p.properties.particle
                scn_name = p.properties.particle_scene or 'Scene'
                scn = scenes[scn_name]
                if scn and scn.parents[p_name]
                    scn.parents[p_name].visible = false
        if ob.type=='MESH'
            ob.default_alpha = 1 # TODO: Obsolete?
            # Remove from pass, to add it back when it's made visible
            if not ob.visible and ob.passes[0] == 1
                scene.mesh_passes[1].remove(ob)
            c = ob.color
            c[0] = c[1] = c[2] = 0
            ob.orig_color = null
            ob.random_n = 0.0
            ob.ob_id = ob.ob_id|0
            # Last Z axis of camera
            ob.last_sort_rotation = vec3.create()
            ob.last_sort_rotation[2] = -100
            for lod_ob in ob.lod_objects
                lod_ob.last_sort_rotation = vec3.create()
                lod_ob.last_sort_rotation[2] = -100
            ob.micro_cloned = null
            ob.micro_cloned_original = null
            ob.micro_scene_cs = null
            ob.slider_animation = null
            # Slicing
            ob.sliced = false
            ob.slices = []
            ob.custom_uniform_values = [
                null, null, # Filled in init_slicing
                null,       # alpha
                1,          # lod_scale (of texture LoD distance transition)
            ]
            # The first two will be filled by init_slicing
            # The last one is LoD scaling of distance transition
            # See custom_uniforms text block in base_material.blend

            # Transition properties
            ob.transitioning = false
            ob.color_delay = ob.alpha_delay = ob.keep_prev_color = 0
            # Visual size
            ob.visual_size = 0
            # Bounding box (to be replaced in engine)
            # ob.position - ob.dimensions/2
            # ob.position + ob.dimensions/2
            ob.bounding_box_low = vec4.create()
            ob.bounding_box_high = vec4.create()
            ob.bounding_box_low[3] = ob.bounding_box_high[3] = 1
            vec3.scale(dim_half, ob.dimensions, 0.5)
            vec3.sub(ob.bounding_box_low, ob.position, dim_half)
            vec3.add(ob.bounding_box_high, ob.position, dim_half)
            # Labels
            ob.main_label = null
            ob.labels = []

            if /^Blood_Flow_/.test(ob.name)
                ob.physics_type = 'NO_COLLISION' # no_phy is added later

            # Workaround for mirror alpha sort bugs
            # (very noticeable in the beginning of heart tour)
            switch ob.name
                when 'Integumentary:Skin:Skin'
                    ob.zindex = 4
                # Workaround for other zindex inconsistencies
                when 'Respiratory:Lungs:Superior_Right'
                    ob.zindex = 1.3
                when 'Skeletal:Chest:Costae_IV_L'
                    ob.zindex = 1.1
                when 'Skeletal:Chest:Costae_III_L'
                    ob.zindex = 1.2
                when 'Skeletal:Chest:Costae_II_L'
                    ob.zindex = 1.4
                when 'Skeletal:Chest:Costae_I_L'
                    ob.zindex = 2
                when 'Skeletal:Chest:Costae_IV_R'
                    ob.zindex = 1.1
                when 'Skeletal:Chest:Costae_III_R'
                    ob.zindex = 1.2
                when 'Skeletal:Chest:Costae_II_R'
                    ob.zindex = 1.4
                when 'Skeletal:Chest:Costae_I_R'
                    ob.zindex = 2
    return

for k,v of {get_meshes_state, set_meshes_state, transition_state,
    ensure_invisible_meshes_are_hidden, real_position, copy_real_position,
    visible_area, update_visible_area, update_visiblity_tree,
    all_meshes_in_background, all_meshes_in_foreground, toggle_meshes_in_background,
    toggle_meshes_in_foreground, set_alpha, set_pass, set_pass,
    random_rot_scale, random_rot_scale, add_custom_scene_and_mesh_attributes}
        exports[k] = v
