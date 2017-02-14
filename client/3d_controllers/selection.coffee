
main_view = require '../views/main_view'
{popup_menu} = require '../views/ui_elements'
{show_color_picker} = require '../views/color_picker'

CLICK_MOVEMENT_THRESHOLD = 8

selected_objects = exports.selected_objects = []
selection_color1=[0.3, 0.5, 1, 1]
selection_color2=[0.2, 0.4, 1, 1]


nerve_flows = {}

enable_curve = (curve, speed=1) ->
    if curve not of nerve_flows
        #TODO: Investigate this: nerve flow is saved with strange values.
        #This ensures speed value is +1 or -1
        if speed < 0
            speed = -1
        else
            speed = 1
        particle_settings = {
            'particle':'nerve_flow_particle'
            'tracker': curve,
            'accel':0
            'type': 'flow',
            'freq': 2,
            'speed': 0.1*speed, #speed is scaled by 1/10 because 1 is too fast.
            'auto_pause': false,
            'fill': false,
            'formula': (ob,position) ->
                vec3.copy(ob.position, position)
                quat.normalize(ob.rotation,vec4.random(ob.rotation))
                ob.scale[0]=ob.scale[1]=ob.scale[2]=(Math.random()*1.2)+0.5
        }
        p = nerve_flows[curve] = new ParticleSystem(particle_settings)

    else
        p = nerve_flows[curve]
        if p.properties['speed'] != speed
            p.reset()

disable_all_curves = () ->
    for name, p of nerve_flows
        p.remove()
        delete nerve_flows[name]
    return

disable_curve = (curve) ->
    p = nerve_flows[curve]
    if not p
        return console.warn "Warning: nerve flow curve '#{curve}' not found"
    p.remove()
    delete nerve_flows[curve]
    return

toggle_fc = (curve, speed=1, user=true) ->
    if curve not of nerve_flows
        #TODO:Replace this confusing UI
        if user and confirm('Reverse?')
            #It flips the particle direction
            speed*=-1
        enable_curve(curve, speed)
    else
        disable_curve(curve)
    if user
        tour_editor.save_state()

get_nerves = () ->
    r = []
    for _, p of nerve_flows
        r.append([
            p.properties.tracker,
            p.properties.speed,
        ])
    return r

set_nerves = (nerves) ->
    enabled_nerves = []
    for p in nerves
        curve = p[0]
        speed = p[1]
        enable_curve(curve, speed)
        enabled_nerves.append(curve)
    for p of nerve_flows
        enabled = p in enabled_nerves
        if not enabled
            disable_curve(p)
    return

update_particles = () ->
    for cName, p of nerve_flows
        mName = cName.substr(0, cName.length - 5) # xxx_flow
        if objects[mName]
            if objects[mName].visible
                p.enable()
            else
                p.disable()
                p.remove_all_particles()
    return

pick_label_above_cursor = () ->
    mx = mouse.x
    my = mouse.y

    for l in label_list
        if l.visible
            w = l.width * l.scale
            h = l.height * l.scale

            x = l.x - w*0.5
            y = l.y + h*0.5

            if mx > x and mx < x + w and my < y and my > y - h
                return l

get_alpha = (obs) ->
    alpha = 0
    for o in obs
        if o.alpha?
            alpha += o.alpha
    return alpha / obs.length

transparency_menu = (obs) ->
    type: 'slider'
    id: 'opacity'
    text: 'Opacity'
    min: 10
    max: 100
    soft_max: null
    soft_min: null
    unit: '%'
    read: -> get_alpha(obs) * 100
    write: (v) ->
        for o in obs
            set_alpha(o, v/100)
        tour_editor.save_state()
    onmove: true
    onup: true

alpha_delay_menu = (obs) ->
    type: 'slider'
    id: 'alpha_delay'
    text: 'Opacity/fade-in delay'
    min: 0
    max: 10
    soft_max: 600
    soft_min: 0
    unit: 's'
    read: ->
        v = 0
        for ob in obs
            v += ob.alpha_delay
        v/obs.length * 0.001
    write: (v) ->
        v *= 1000
        for ob in obs
            ob.alpha_delay = v
        tour_editor.save_state()
        if tour_editor.audio_player and tour_editor.auto_play_audio
            tour_editor.preview_audio_delay(v*0.001)
    onmove: false
    onup: true

color_delay_menu = (obs) ->
    type: 'slider'
    id: 'color_delay'
    text: 'Color delay'
    min: 0
    max: 10
    soft_max: 600
    soft_min: 0
    unit: 's'
    read: ->
        v = 0
        for ob in obs
            v += ob.color_delay
        v/obs.length * 0.001
    write: (v) ->
        v *= 1000
        for ob in obs
            ob.color_delay = v
        tour_editor.save_state()
        if tour_editor.audio_player and tour_editor.auto_play_audio
            tour_editor.preview_audio_delay(v*0.001)
    onmove: false
    onup: true

color_delay_keep_prev_color_menu = (obs) ->
    type: 'switch',
    states : 3,
    state: 0,
    id:'keep_prev_color',
    text:'Keep previous color',
    read: ->
        trues = 0
        for ob in obs
            trues += if ob.keep_prev_color then 1 else 0
        if trues == obs.length
            2
        else if trues
            1
        else
            0
    write: (v) ->
        v = not not v
        for ob in obs
            ob.keep_prev_color = v
        tour_editor.save_state()

apply_color_to_selected = (r,g,b) ->
    for o in selected_objects
        c = o.orig_color or o.color
        c[0] = r
        c[1] = g
        c[2] = b
        # unselect_all() restores orig_color back to color
    unselect_all()
    tour_editor.save_state()

apply_color = (color, obs)->
    r = color[0]
    g = color[1]
    b = color[2]
    for o in obs
        c = o.orig_color or o.color
        c[0] = r
        c[1] = g
        c[2] = b

    # restore selection after user saw the color so that he can continue
    obs = obs.slice()
    setTimeout((-> select_objects(obs)), 400)

    unselect_all()
    tour_editor.save_state()

hide_selected = (obs=selected_objects) ->
    for o in obs by -1
        hide_mesh(null, o)
    update_visiblity_tree()
    main_view.render_all_views()
    tour_editor.save_state()
    if not tour_viewer.modified_view
        tour_viewer.set_modified_view()

show_only_selected = (obs=selected_objects) ->
    organs = []
    for o in ORGAN_LIST
        if obs.indexOf(objects[o]) > -1
            show_mesh(o)
            organs.push(o)
        else
            hide_mesh(o)
    t = go_here(organs)
    # dispose_phy_meshes()
    if not tour_viewer.modified_view
        tour_viewer.set_modified_view()

slice_selected = (obs=selected_objects)->
    slice_objects(obs)

slice_objects = (obs) ->
    if obs.length > 0
        # check if selected objects are sliced already
        for obj in obs
            if slicing_manager.get_mesh_slices(obj.name).length > 0
                tour_editor.warning_popup('One of selected objects is already sliced.')
                return
        slicing_manager.slice_objects(obs)
        tour_editor.save_state(0, 'slicing')
    else
        tour_editor.warning_popup('Nothing is selected.')

selection_is_in_background = (obs = selected_objects) ->
    names = for o in obs
        o.name
    if all_meshes_in_background names
        return 1
    0

selection_toggle_background = (obs = selected_objects) ->
    names = for o in obs
        o.name
    toggle_meshes_in_background names
    tour_editor.save_state()
    main_loop.reset_timeout()
    if not tour_viewer.modified_view
        tour_viewer.set_modified_view()

selection_is_in_foreground = (obs = selected_objects) ->
    names = for o in obs
        o.name
    if all_meshes_in_foreground names
        return 1
    0

selection_toggle_foreground = (obs = selected_objects) ->
    names = for o in obs
        o.name
    toggle_meshes_in_foreground names
    tour_editor.save_state()
    main_loop.reset_timeout()
    if not tour_viewer.modified_view
        tour_viewer.set_modified_view()

animations_menu = (obs) ->
    ob = null
    if obs.length
        ob = obs[0]
    if ob?.properties.anim_mode == 'slider'
        anim = ob.slider_animation
        return {
            type: 'slider'
            id: 'animation'
            text: 'Animation pos'
            min: ob.properties.anim_start
            max: ob.properties.anim_end
            soft_max: null
            soft_min: null
            unit: ''
            read: -> anim.pos
            write: (v) ->
                anim.pos = v
            onmove: true
            onup: true
            onup_func: ->
                console.log('Saving state...')
                tour_editor?.save_state()
        }
    else
        return null

exports.selection_menu = selection_menu = (obs=selected_objects)->
    editing = tour_editor?.editing
    viewing = tour_viewer?.viewing
    if obs.length == 1
        name = ORGAN_VISIBLE_NAMES[obs[0].name]
        skip_moving = obs[0].always_alpha
    else
        name = obs.length + ' selected parts'
    menu = [
        {'text': 'Hide '+name, 'func': -> hide_selected(obs)},
        {'text': 'Show only this', 'func': -> show_only_selected(obs)},
    ]
    if not viewing and not skip_moving
        menu.append(
            {
                type: 'switch',
                states : 2,
                state: 0,
                text:'Put to background',
                read: -> selection_is_in_background(obs)
                write: -> selection_toggle_background(obs)
            }
            {
                type: 'switch',
                states : 2,
                state: 0,
                text:'Put always on top',
                read: -> selection_is_in_foreground(obs)
                write: -> selection_toggle_foreground(obs)
            }
        )
    if editing
        menu.append({
            'text': 'Color',
            'func': ->
                base_colors = [
                    [0.4,0.4,0.4, 'Grey'],
                    [1.0,0.0,0.2, 'Red'],
                    [1.0,0.2,0.0, 'Orange'],
                    [0.6,0.6,0.0, 'Yellow'],
                    [0.0,1.2,0.0, 'Green'],
                    [0.0,0.2,1.0, 'Blue']
                ]

                colors = []
                for j in [0 ... 3]
                    for i in [0 ... 6]
                        c = base_colors[i].slice()
                        c[0] += 0.2 * j * (c[2] - c[1]) * i/5
                        c[1] += 0.2 * j * (c[0] - c[2]) * i/5
                        c[2] += 0.2 * j * (c[1] - c[0]) * i/5
                        c[0] *= 1 + 0.2 * j * (1 - i/5)
                        c[1] *= 1 + 0.2 * j * (1 - i/5)
                        c[2] *= 1 + 0.2 * j * (1 - i/5)
                        c[3] = c[3] + ' ' + (j + 1)
                        colors.push(c)
                # adjust 1st column
                colors[0] = [0,0,0, 'No color']
                colors[6][3] = 'Grey'
                colors[12] = [1.0,1.0,1.0, 'White']

                show_color_picker(colors, ((color) -> apply_color(color, obs)), true)
        },
        transparency_menu(obs),
        alpha_delay_menu(obs),
        color_delay_menu(obs),
        color_delay_keep_prev_color_menu(obs),
        #{'text': 'Delete custom labels', 'func': () -> delete_custom_labels()}, #It doesn't works
        {
            'text': 'Toggle nerve flow curves'
            'submenu': [
                {
                    'text':'Optic nerve',
                    'submenu':[
                        {'text': 'Optic nerve, Left', 'func': ()-> toggle_fc('optic_nerve_flow_left')}
                        {'text': 'Optic nerve, Right', 'func': ()-> toggle_fc('optic_nerve_flow_right')}
                    ]
                }
                {
                    'text':'Trigeminal',
                    'submenu':[
                        {'text': 'Trigeminal up', 'func': ()-> toggle_fc('Trigeminalup')}
                        {'text': 'Trigeminal middle', 'func': ()-> toggle_fc('Trigeminalmiddle')}
                        {'text': 'Trigeminal side', 'func': ()-> toggle_fc('Trigeminalside')}
                        {'text': 'Trigeminal down', 'func': ()-> toggle_fc('Trigeminaldown')}
                    ]
                }
                {
                    'text':'Stem',
                    'submenu':[
                        {'text': 'Stem and brain', 'func': ()-> toggle_fc('Stemandbrain')}
                        {'text': 'Stem', 'func': ()-> toggle_fc('Stemflow')}
                    ]
                }
                {
                    'text': 'Capillary',
                    'submenu':[
                        {'text': 'Capillary neuron', 'func': ()-> toggle_fc('neuron_capillary_flow')}
                        {'text': 'Capillary neuron 2', 'func': ()-> toggle_fc('neuron_capillary_flow.001')}
                    ]
                }
                {
                    'text': 'Selected nerve'
                    'func': ()->
                        flow = objects[obs[0].name.replace(/_L$|_R$/, '')+'_flow']
                        flow and toggle_fc(flow.name)
                }
                {'text': 'Disable all', 'func': disable_all_curves}
            ]
        },
        animations_menu(obs),

        )
#         if vida_body_auth.is_admin
#             menu.push
#                 'text': 'Add label'
#                 'submenu': [
#                     {
#                         'text': 'Large',
#                         'func': () ->add_label_to_selection(true, 1)
#                     },
#                     {
#                         'text': 'Medium',
#                         'func': () ->add_label_to_selection(true, 2)
#                     },
#                     {
#                         'text': 'Small',
#                         'func': () ->add_label_to_selection(true, 3)
#                     },
#                 ]


    if editing
        menu.insert(4, {'text': 'Slice', 'func': -> slice_selected(obs)})
        menu.insert(5, {'text': 'Remove all slices', 'func': ->
            slicing_manager.remove_all_slices()
            tour_editor.save_state(0, 'slicing')
        })

    return menu

init_selection = () ->

    last_time_selected = Date.now()

    up = (event) ->
        if mouse.movement_since_mousedown >= CLICK_MOVEMENT_THRESHOLD
            # Don't select/show menu
            return

        # Unselect annotations
        document.activeElement.blur()
        for e in $('#annotations')[0].children
            e.classList.remove('selected')

        if tour_viewer.viewing and tour_viewer.is_landing
            return

        l = pick_label_above_cursor()
        left_button = event.button == 0
        right_button = event.button == 2 or (event.button == 0 and event.ctrlKey)
        ctrl = event.ctrlKey and event.button != 0 # Mac ctrl+tap means context menu

        if not(l and right_button and tour_editor.is_editing()) and (l and right_button and vida_body_auth.is_admin and not l.is_part)
            change = () ->
                t = prompt('Edit label text', l.elm.real_text)
                if t
                    l.elm.textContent = l.elm.real_text = t
            popup_menu(event.pageX, event.pageY, [
                {
                    'text': 'Edit label text',
                    'func': change
                },
                {
                    'text': 'Edit label type \u00A0 \u00A0',
                    'submenu': [
                        {'text': 'Large', 'func': () -> l.setType(1)},
                        {'text': 'Medium', 'func': () -> l.setType(2)},
                        {'text': 'Small', 'func': () -> l.setType(3)}
                    ]
                },
                {
                    'text': 'Delete label',
                    'func': () -> delete_label(l)
                }
            ])
        else
            toggling = (ctrl or event.shiftKey) and not tour_viewer.viewing

            #                       selected  unselected
            # left_button                       un all
            # left_button toggling      un       sel
            # right_button                      un all

            if left_button or right_button
                pick = pick_object(event.pageX, event.pageY)
                window.context_menu_picked = pick # for compatibility with menu_add_*_label

                if pick
                    obj = pick.object
                    # If there are several objs with same data and group_id
                    # choose the visible one
                    if not obj.visible
                        for ob2 in (obj.last_lod_object or obj).data.users
                            if ob2.group_id == obj.group_id and ob2.mirrors == obj.mirrors and ob2.visible
                                obj = ob2
                                break
                    # If it's still invisible or alpha 0, it means it shouldn't
                    # be selectable at all
                    if obj.visible and obj.alpha > 0.1
                        if obj.selected and left_button and toggling
                            unselect_object(obj)
                        if not obj.selected and not toggling
                            unselect_all()
                        select_objects([obj])

                        t = Date.now()

                        if t - last_time_selected < DOUBLE_CLICK_MS
                            go_here([obj.name])
                        last_time_selected = t
                    else if (left_button or tour_viewer.viewing) and not toggling
                        unselect_all()
                else if (left_button or tour_viewer.viewing) and not toggling
                    unselect_all()


            if right_button
                if selected_objects.length
                    popup_menu(event.pageX, event.pageY, selection_menu())
                else if tour_viewer.viewing and tour_viewer.modified_view
                    popup_menu event.pageX, event.pageY, [
                        {text: 'Restore view', icon: 'restore_view.png', backgroundSize: 'contain', func: -> tour_viewer.restore_view()}
                    ]
                else
                    popup_menu event.pageX, event.pageY, [
                        {text: '(Nothing is selected)', disabled: true, func: ->}
                    ]
            else
                main_view.render_all_views()

    canvas = document.getElementById('canvas_container')
    canvas.addEventListener('mouseup', up)

# slicing-aware version of ray_intersect_body
# TODO: using masks test fg first, then regular objects, then bg
pick_object_ray = do ->
  pos = vec3.create()
  dir = vec3.create()
  tmp = vec4.create()
  (origin, direction) ->
    if glraytest
        # Assuming origin is camera.position
        vec3.add(tmp, origin, direction)
        quat.invert(tmp, glraytest.cam_rot)
        # tmp[3]=-tmp[3]
        vec3.transformQuat(tmp, direction, tmp)
        tmp[3] = 1
        vec4.transformMat4(tmp, tmp, objects.Camera.projection_matrix)
        x = Math.max(0, Math.min(1, (1+tmp[0]/tmp[3])*0.5))
        y = Math.max(0, Math.min(1, (1-tmp[1]/tmp[3])*0.5))
        return glraytest.pick_object(x,y)
    vec3.copy(pos, origin)
    vec3.copy(dir, direction)
    while true
        ray_hit = ray_intersect_body(scene, pos, dir)
        if ray_hit
            ob = ray_hit.body.owner
            ## This is for testing where the ray collides
            # o = ray_hit.body.owner.clone()
            # o.mirrors = 1
            # o.position = ray_hit.point
            # vec3.scale(o.scale, o.scale, 0.05)
            # o.physics_type = 'NO_COLLISION'
            # o.instance_physics()
            if ob.sliced
                # check if this part of object is actually visible
                visible = true
                for slice in ob.slices
                    vec3.subtract(tmp, ray_hit.point, slice.slice_point)
                    if vec3.dot(tmp, slice.slice_normal) < 0
                        visible = false
                        break
                if visible
                    # visible part of sliced object
                    ray_hit.object = ob
                    return ray_hit
                else
                    # need to re-trace the ray from ray_hit.point
                    vec3.subtract(tmp, ray_hit.point, pos)
                    vec3.subtract(dir, dir, tmp)

                    vec3.scale(tmp, dir, 0.00001)
                    vec3.add(pos, ray_hit.point, tmp)
            else
                # found object is not sliced
                ray_hit.object = ob
                return ray_hit
        else
            return null

pick_object = (x, y, debug) ->
    x /= render_manager.width
    y /= render_manager.height
    pick_object_f(x, y, debug)

pick_object_f = (x, y, debug) ->
    if glraytest
        if debug
            glraytest.debug_xy(x, y)
        return glraytest.pick_object(x, y)
    else
        cam = camera_control.current_camera_state.camera
        v = cam.get_ray_direction(x, y)
        v[0]*=10
        v[1]*=10
        v[2]*=10
        return pick_object_ray(cam.position, v)

select_objects = (objs) ->
    for ob in objs
        if not ob.selected
            ob.orig_color = ob.orig_color or ob.color
            ob.selected = true
            if not tour_viewer.viewing
                ob.color = selection_color1
            selected_objects.push(ob)
            label = ob.main_label
            if label
                label.setColor(label_settings.selection_color)
    slicing_manager?.show_widgets()

unselect_object = (ob) ->
    if ob.selected
        ob.color = ob.orig_color
        ob.orig_color = null
        ob.selected = false
        selected_objects.remove(ob)
        label = ob.main_label
        if label
            label.setColor('')
            label.alwaysVisible = false
            if not labels_visible
                label.hide()
    slicing_manager?.show_widgets()

unselect_all = () ->
    for ob in selected_objects
        ob.color = ob.orig_color
        ob.orig_color = null
        ob.selected = false
        label = ob.main_label
        if label
            label.setColor('')
            label.alwaysVisible = false
            if not labels_visible
                label.hide()
    selected_objects.clear()
    slicing_manager?.show_widgets()

alternate_selection_colors = () ->
    if selected_objects.length == 0 or tour_viewer.viewing
        return
    update_shader_color(selection_color1, label_settings.selection_color)
    for i in [0... 3]
        selection_color2[i] = selection_color1[i] * 0.6

    other = if selected_objects[0].color == selection_color1 then selection_color2 else selection_color1
    for ob in selected_objects
        ob.color = other

# setInterval(alternate_selection_colors, 500)
