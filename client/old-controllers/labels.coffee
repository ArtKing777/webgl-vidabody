
MAX_LABEL_SCORE = 4

MAX_VISIBLE_LABELS = 80

label_list = []
labels_by_id = {}
labels_visible = exports.labels_visible = true
labels_div = null
set_labels_visible = exports.set_labels_visible = (b) ->
    labels_visible = exports.labels_visible = b
    if not b
        label_callouts = exports.label_callouts = false
        for l in label_list
            l.hide()
    return

label_settings = {
                  "min_dist_point1":0.21765454600630588,
                  "max_dist_point1":2,
                  "min_dist_part1":0.26105048408580805,
                  "max_dist_part1":4,
                  "scale1":0.5969788309325039,
                  
                  "min_dist_point2":0.21765454600630588,
                  "max_dist_point2":2,
                  "min_dist_part2":0.26105048408580805,
                  "max_dist_part2":4,
                  "scale2":0.5969788309325039,
                  
                  "min_dist_point3":0.21765454600630588,
                  "max_dist_point3":2,
                  "min_dist_part3":0.26105048408580805,
                  "max_dist_part3":4,
                  "scale3":0.5969788309325039,
                  
                  "clamp_min":0.5427989372113672,"clamp_max":1.0304179807015974,
                  "selection_color":"#00c2ff","hover_color":"#b3ff00",
                  "feat_color":"#ffffff","part_color":"#dddddd"
                  'move_speed': 0.01
                  
                  'hover_scale': 0.5,
                  'hover_x': 10,
                  'hover_y': 10,
                  'hover_lerp': 1,
}

if USE_PHYSICS
    EXPENSIVE_CHECKS = 6
else
    EXPENSIVE_CHECKS = 100

next_label = 0

visible_label_list = []

label_callouts = exports.label_callouts = false
label_callouts_splines = exports.label_callouts_splines = false
set_label_callouts = exports.set_label_callouts = (v) ->
    labels_visible = exports.labels_visible = true if v
    label_callouts = exports.label_callouts = v
    return

set_label_callouts_splines = exports.set_label_callouts_splines = (v) ->
    labels_visible = exports.labels_visible = true if v
    label_callouts = exports.label_callouts = true if v
    label_callouts_splines = exports.label_callouts_splines = v
    return

class Label
    
    constructor: (obj_name, point, text, is_part, type=1, id, alternative_names = []) ->
        @obj = obj = objects[obj_name]
        @obj_name = obj_name
        # This is fixed for point labels
        # but it changes for part labels when query changes
        # to a random point of the mesh
        @point = p = vec4.create()
        #Copy point to @point
        p[0] = point[0]
        p[1] = point[1]
        p[2] = point[2]
        p[3] = 1
        @vis_point = vec3.create()
        if obj
            copy_real_position(@vis_point, obj)
            obj.labels.push(@)
        @text = text
        @elm = null
        @scale = 1
        @visible = false
        @type = type
        @part_score = 0
        @hovering = false
        
        # TODO: Instead of this, a raycast should be performed
        # when assets version of labels != current
        # if obj and not is_part
        #     vec3.sub(p, p, obj.position)
        #     vec3.scale(p, p, 1.01)
        #     vec3.add(p, p, obj.position)

        @is_part = is_part
        if is_part
            if obj and not obj.main_label
                obj.main_label = this
        label_list.append(this)
        @width = 1
        @height = 1
        @x = @y = 0
        id = id or(Math.random()*10000000)|0
        while labels_by_id[id]
            id = (Math.random()*10000000)|0
        @id = id
        labels_by_id[id] = this
        @quiz = null
        @alternative_names = alternative_names
        #alternative_names in uppercase and
        #without spaces or punctuation marks
        #Exlample: ['HUMERUSLEFT','LEFTHUMERUS']
        @animate = false

        # distance multiplier
        # to if you want this label to be visible at greater distance, set this to something < 1
        @distanceMultiplier = 1
        @color = ''
        @alwaysVisible = false
        @delete_timer = null

    setType: (type) ->
        @elm.classList.remove('type'+@type)
        @type = type
        @elm.classList.add('type'+@type)
        
    setColor: (color) ->
        @color = color
        if @elm
            @elm.style.color = color
            @line.setColor(color)
        
    update_orig_size: () ->
        if @elm
            @width = @elm.clientWidth
            @height = @elm.clientHeight
    
    show: (add_to_visible_list=true) ->
        if not @elm
            @elm = e = document.createElement('span')
            @elm.label = this
            labels_div.appendChild(e)
            @line = new Spline('#ffffff', 1)
            e.classList.add('label3d')
            @line.classList()?.add('label3d_line')
            if @is_part
                e.classList.add('label3dpart')
                @line.classList()?.add('label3dpart_line')
            if @color
                @setColor(@color)
            e.classList.add('type'+@type)
            e.textContent = @text
            @elm.style.opacity = 0
            @elm.style.top = '-300px'
        requestAnimationFrame =>
            @update_orig_size()
            if @elm
                @elm.style.opacity = 1
        @visible = true
        @hovering = false
        if @delete_timer?
            clearTimeout(@delete_timer)
            @delete_timer = null
        if this not in visible_label_list and add_to_visible_list
            visible_label_list.push(this)
    
    hide: (force) ->
        if @alwaysVisible and not force
            return
        # Remove element and line after fadeout
        if @elm
            @delete_timer = setTimeout =>
                if @elm and not @visible
                    labels_div.removeChild(@elm)
                    @elm = null
                    @line.remove()
            , 500
            @elm.style.opacity = 0
            @line.hide()
        @alwaysVisible = false
        @visible = false
        # do not animate when the label will appear later
        @animate = false
        visible_label_list.remove(this)
        
    approximate_width: ->
        w = 0
        for letter in @text
            w += letter_sizes[letter] or letter_sizes['a']
        w * 1.15


menu_add_label = (is_part, type) ->
    unselect_all()
    text = prompt('Label text:')
    point = context_menu_picked[1]
    normal = context_menu_picked[2]
    if text
        ob = context_menu_picked[0]
        label = create_label(ob and ob.name, point, text, is_part, type)
        return label

labels_to_JSON = ->
    ret = []
    for l in label_list
        if l.is_part
            continue
        oname = l.obj_name
        ret.append([oname, l.point, l.text, l.is_part, l.type, l.id])
    return ret

labels_from_JSON = (data) ->
    
    labels_div = document.getElementById('labels')
    for i in [0...label_list.length]
        delete_label(label_list[0])
    i=1
    for d in data
        if d[3] # part labels are generated automatically
            continue
        if not d[2] # skip labels without text
            continue
        
        onames = migrations[d[0]] or [d[0]]
        for oname in onames
            l = create_label(oname, #ob name
                d[1], # point
                d[2], # text
                d[3], # is_part
                d[4] or 1, # type
                d[5] or i) # id
            i+=1

            # make point labels searchable
            search_util.addWithWordsAndSynonyms(d[2], {
                'organ' : d[0],
                'label' : d[2]
            })
    
    autogenerate_part_labels()

part_label_excluded_systems = [
    'Microviews',
    'particles',
    'Heart_alternatives',
]

autogenerate_part_labels = ->
    labels_div = document.getElementById('labels')
    
    # Automatic generation of part labels
    for oname in ORGAN_LIST
        ob = scene.objects[oname]
        if ob?.type == 'MESH' and not ob.only_phy and ob.properties.system not in part_label_excluded_systems
            maxdim = max(ob.dimensions...)
            type = 1
            if maxdim < 0.08
                type = 2
            if maxdim < 0.04
                type = 3
            pos = ob.position
            if ob.mirrors == 2
                pos = [-pos[0], pos[1], pos[2]]
            create_label(ob.name, ob.position,
                ORGAN_VISIBLE_NAMES[oname],
                true,
                type,
                ob.name)
    return

exports.hover_labels = ->
    object = null
    hover_color_array = vec4.create()
    hover_label = new Label('', [0,0,0], '', true)
    orig_hover_label = null
    label_list.splice label_list.indexOf(hover_label),1
    lastx = 0
    lasty = 0
    return (event) ->
        if object?.color == hover_color_array
            object.color = object.orig_color
            object.orig_color = null
        orig_hover_label?.hovering = false
        # Don't hover if camera is being moved
        if camera_control.mode != IDLE or
        # or if there are micro views
        camera_control.camera_states.length > 1 or
        # or it's the landing tour
        (tour_viewer.viewing and tour_viewer.is_landing)
            if hover_label.visible
                hover_label.hide()
            return
        x = event.pageX
        y = event.pageY
        pick = pick_object(event.pageX, event.pageY, true)
        if pick
            object = pick.object
            text = ORGAN_VISIBLE_NAMES[object.name]
            if not hover_label.visible
                hover_label.setColor(label_settings.hover_color)
                hover_label.text = text
                hover_label.show(false)
                lerpx = event.pageX
                lerpy = event.pageY
            else
                hover_label.elm.textContent = text
                lerpf = label_settings.hover_lerp
                lerpx = lastx + lerpf * (x - lastx)
                lerpy = lasty + lerpf * (y - lasty)
            style = hover_label.elm.style
            style.left = lerpx + label_settings.hover_x + 'px'
            style.top = lerpy + label_settings.hover_y + 'px'
            style.transform = style.webkitTransform = 'scale('+label_settings.hover_scale+')'
            style.transformOrigin = style.webkitTransformOrigin = '0'
            hover_label.elm.classList.add('hover')
            lastx = lerpx
            lasty = lerpy
            ob_label = orig_hover_label = object.main_label
            orig_hover_label = true
            if ob_label?.visible
                ob_label.hide()
            # object hover color (code copied from old implementation)
            if not vb.tour_viewer?.viewing and not object.orig_color and not window.load_tour_hash and not window.load_tour_uuid
                update_shader_color(hover_color_array, label_settings.hover_color)
                object.orig_color = object.color
                object.color = hover_color_array
        else if hover_label.visible
            hover_label.hide()
            if object.color == hover_color_array
                object.color = object.orig_color
                object.orig_color = null
            


        


init_labels = ->
    scene.post_draw_callbacks.append(-> exports.recalculate_labels())
    $('#canvas_container')[0].addEventListener('mousemove', exports.hover_labels())
    

            

create_label = (obj_name, point, text, is_part, type, id, alternative_names) ->
    new Label obj_name, point, text, is_part, type, id, alternative_names


delete_label = (l) ->
    unquizz(l)
    if label_list.indexOf(l)
        labels_div.removeChild(l.elm)
        label_list.remove(l)
        delete labels_by_id[l.id]
        l.line.remove()


add_label_settings = (gui) ->
    s1 = document.createElement('style')
    s2 = document.createElement('style')
    document.body.appendChild(s1)
    document.body.appendChild(s2)
    
    gui.remember(label_settings)
    folder = gui.addFolder('Label settings')
    # folder1 = gui.addFolder('Part labels')
    # folder1.add(label_settings, 'min_dist_part1', 0.001, 4)
    # folder1.add(label_settings, 'max_dist_part1', 0.001, 4)
    # folder1.add(label_settings, 'min_dist_part2', 0.001, 4)
    # folder1.add(label_settings, 'max_dist_part2', 0.001, 4)
    # folder1.add(label_settings, 'min_dist_part3', 0.001, 4)
    # folder1.add(label_settings, 'max_dist_part3', 0.001, 4)
    # folder1 = gui.addFolder('Point labels')
    # folder1.add(label_settings, 'min_dist_point1', 0.001, 2)
    # folder1.add(label_settings, 'max_dist_point1', 0.001, 2)
    # folder1.add(label_settings, 'min_dist_point2', 0.001, 2)
    # folder1.add(label_settings, 'max_dist_point2', 0.001, 2)
    # folder1.add(label_settings, 'min_dist_point3', 0.001, 2)
    # folder1.add(label_settings, 'max_dist_point3', 0.001, 2)
    folder.add(label_settings, 'scale1', 0.001, 5)
    folder.add(label_settings, 'scale2', 0.001, 5)
    folder.add(label_settings, 'scale3', 0.001, 5)
    folder.add(label_settings, 'clamp_min', 0.001, 5)
    folder.add(label_settings, 'clamp_max', 0.001, 5)
    folder.add(label_settings, 'move_speed', 0, 5)
    folder.add(label_settings, 'hover_scale', 0, 1)
    folder.add(label_settings, 'hover_x', -300, 300)
    folder.add(label_settings, 'hover_y', -300, 300)
    folder.add(label_settings, 'hover_lerp', 0, 1)
    
    
    
    f = ->
        s1.textContent = '.label3d{color:'+label_settings.feat_color+'}\n.label3d_line{stroke:'+label_settings.feat_color+'}'
    folder.addColor(label_settings, 'feat_color').onChange(f)
    f()
    
    g = ->
        s2.textContent = '.label3dpart{color:'+label_settings.part_color+'}\n.label3dpart_line{stroke:'+label_settings.part_color+'}'
    folder.addColor(label_settings, 'part_color').onChange(g)
    g()

    folder.addColor(label_settings, 'selection_color')
    folder.addColor(label_settings, 'hover_color')


outline_labels_by_type = ->
    colors = ['red', 'green', 'blue']
    for l in label_list
        # l.type is 1...3
        l.elm.style.outline = 'dashed 1px ' + colors[l.type - 1]
        if l.is_part
            l.elm.style.backgroundColor = 'black'

# filter labels with same text / organ
kill_duplicate_point_labels = (threshold) ->

    threshold = threshold or 0.001

    dict = {}
    kill = []
    for l in label_list
        if not l.is_part
            key = l.text + l.obj_name
            l2 = dict[key]
            if l2
                if (vec3.distance(l.point, l2.point) < threshold)
                    # keep latest version
                    if l2.id > l.id
                        kill.push(l)
                    else
                        kill.push(l2)
                        dict[key] = l
            else
                dict[key] = l

    console.log('Killing ' + kill.length + ' point labels:', kill.map((e) -> e.text + ' at ' + e.point[0].toFixed(4) + ',' + e.point[1].toFixed(4) + ',' + e.point[2].toFixed(4)))
    for l in kill
        delete_label(l)
    console.log('You may save settings now, I guess')


# call this repearedly from console until it reports 0 patched labels
patch_point_labels = (threshold) ->

    threshold = threshold or 0.01

    ray_direction = vec3.create()
    min_direction = vec3.create()

    count = 0
    patch = 0
    fails = 0

    for l in label_list
        if not l.is_part
            count++

            if not l.obj
                fails++
                console.log('Failed:', l.text, 'no l.obj :(')
                if l.obj_name != ''
                    console.log('mesh: ' + l.obj_name + ' migrations:', migrations[l.obj_name])
                continue

            if not l.obj.data
                fails++
                console.log('Failed:', l.text + '/' + l.obj.name, 'mesh was not loaded, retry...')
                scene.loader.load_mesh_data(l.obj)
                continue


            # remove all other bodies that might be blocking hits
            for name, obj of objects
                if (obj != l.obj) and (obj.physics_type == 'STATIC')
                    obj.physics_type = 'NO_COLLISION'
                    if obj.data
                        obj.instance_physics()
                        if obj.data.phy_mesh
                            destroy(obj.data.phy_mesh)
                            obj.data.phy_mesh = null

            # (re)create the body
            if l.obj.physics_type == 'NO_COLLISION'
                l.obj.physics_type = 'STATIC'
                l.obj.instance_physics()

            min_direction[0] = 1e9
            min_direction[1] = 1e9
            min_direction[2] = 1e9

            process_ray = ->
                hit = ray_intersect_body(scene, l.point, ray_direction)
                if hit?.body.owner == l.obj
                    vec3.subtract(ray_direction, hit.point, l.point)
                    if vec3.len(min_direction) > vec3.len(ray_direction)
                        vec3.copy(min_direction, ray_direction)

            N = 30
            # N uniformly distributed directions (Bauer spiral)
            for i in [1 .. N] # =1, <= N
                h = ((2 * i - 1) / N) - 1
                phi = Math.acos(h)
                theta = phi * Math.sqrt(N * Math.PI)
                r = Math.sin(phi)
                ray_direction[0] = r * Math.sin(theta)
                ray_direction[1] = r * Math.cos(theta)
                ray_direction[2] = 1 * Math.cos(phi)
                # should be already normalized
                #vec3.normalize(ray_direction, ray_direction)

                process_ray()


            vec3.subtract(ray_direction, l.obj.position, l.point)
            vec3.normalize(ray_direction, ray_direction)

            # narrow the center down
            bounds = calculate_bounds_in_direction(l.obj, null, l.point, ray_direction)
            center = vec3.create()
            vec3.add(center, bounds.min, bounds.max)
            vec3.scale(center, center, 0.5)

            # towards the center, in case the label is outside
            vec3.subtract(ray_direction, center, l.point)
            vec3.normalize(ray_direction, ray_direction)
            process_ray()

            # away from center, in case the label is inside
            vec3.subtract(ray_direction, l.point, center)
            vec3.normalize(ray_direction, ray_direction)
            process_ray()

            if vec3.len(min_direction) > 1732050807
                fails++
                console.log('Failed:', l.text + '/' + l.obj.name, 'no intersections :(', l.point)
                continue

            if vec3.len(min_direction) < threshold
                if vec3.len(min_direction) > 5e-5 # half of 1e-4
                    patch++
                    console.log('Patching:', l.text + '/' + l.obj.name, 'by ' + vec3.len(min_direction))
                    vec3.add(l.point, l.point, min_direction)

    console.log('Found ' + count + ' point labels')
    console.log('Failed to find correct point for ' + fails)
    console.log('Patched ' + patch)

    go_home(true)
    console.log('You may save settings now, I guess')

exports.check_labels = (sorted_meshes) ->
    # This function checks whether each label should be visible or not.
    # It uses rays and avoids labels to collide.
    
    # for label in label_list
    #     if label.obj?.visible and not label.visible
    #         label.show()
    if not labels_visible
        return
    
    label_rects = []
    
    s = vec4.create()
    mat = scene.active_camera.world_to_screen_matrix
    double_width = render_manager.width * 2
    double_height = render_manager.height * 2
    {longest_rows_len, longest_rows_x, longest_rows_y} = glraytest
    
    # Hide labels of invisible objects
    for label in visible_label_list by -1 when label.visible
        if not label.obj?.visible
            label.hide()
    
    # Calculate the criteria for the rest of the labels
    for obj in sorted_meshes when obj.visible
        for label in obj.labels
            
            always_visible = (label.quiz and 1) or (not label_callouts and ( label.alwaysVisible or (label.is_part and obj and obj.selected) ))
            vis = always_visible or (
                label_rects.length <= MAX_VISIBLE_LABELS and
                not tour_viewer.viewing and
                not label.hovering and
                label.is_part
            )
            if not vis
                continue
            
            # Find appropiate point to put the label (longest pixel row)
            vis = false
            if longest_rows_len[obj.ob_id] > 12
                ray = glraytest.pick_object(longest_rows_x[obj.ob_id], longest_rows_y[obj.ob_id])
                if ray and ray?.object == obj
                    vis = true
                    vec3.copy(label.vis_point, ray.point)
                    # If label is not visible, move it directly
                    if not label.visible
                        vec3.copy(label.point, ray.point)
            
            if vis and not always_visible
                # Find point in screen
                vec4.transformMat4(s, label.point, mat)
                x = s[0]/s[3]
                y = s[1]/s[3]
                # Check collision with other labels (unclumping)
                hw = label.approximate_width() * label.scale
                hh = exports.letter_height * label.scale
                for [x2, y2, hw2, hh2] in label_rects
                    dx = Math.abs(x-x2) * double_width # double because x/y is from -1 to 1
                    dy = Math.abs(y-y2) * double_height
                    if dx < (hw+hw2) and dy < (hh+hh2)
                        vis = false
                        break
            
            if vis
                label_rects.push([x, y, hw, hh])
            
            # Hide/show
            if label.visible and not vis
                label.hide()
            else if not label.visible and vis
                label.show()
    
    return

exports.recalculate_labels = ->

    keep_animating = false

    
    
    if not scene or not scene.enabled
        return
    cpos = scene.active_camera.position
    mat = scene.active_camera.world_to_screen_matrix
    sqdist = vec3.create()
    s = vec4.create()
    WIDTH = render_manager.width
    HEIGHT = render_manager.height
    Hwidth = render_manager.width * 0.5
    Hheight = render_manager.height * 0.5
    
    
    for l in label_list
        if l.is_part
            # animate l.point towards l.vis_point
            vec3.lerp(l.point, l.point, l.vis_point, label_settings.move_speed)
        #     keep_animating = keep_animating or(vec3.squaredDistance(l.point, l.vis_point) > 300)

        if l.visible
            vec4.transformMat4(s, l.point, mat)
            if s[3] > 0
                # projected coords
                l.px = (1+s[0]/s[3])*Hwidth
                l.py = (1-s[1]/s[3])*Hheight
                l.index = -1
            else
                l.hide()

    # render the labels here
    for l in visible_label_list
        
        # TODO find out why l.width != l.elm.clientWidth(even with scale = 1)
        half_width = l.width * 0.5
        half_height = l.height * 0.5
        a = 0
        b = 1

        if label_callouts

        else

            d = min(label_settings.clamp_max,max(label_settings.clamp_min, (1/vec3.dist(l.point, cpos))))
            l.scale = a * l.scale + b * d*label_settings['scale'+l.type]

            l.x = a * l.x + b * l.px
            l.y = a * l.y + b * l.py

            l.line.hide()

        st = l.elm.style

        st.left = l.x - half_width + 'px'
        st.top = l.y - half_height + 'px'

        scale = 'scale('+l.scale+')'
        st['transform'] = scale
        st['-moz-transform'] = scale
        st['-webkit-transform'] = scale

exports.letter_sizes = letter_sizes = {}

recalc_sizes_timer = null
exports.calc_letter_sizes = ->
    labels_div = document.getElementById('labels')
    lbl = new Label('', vec3.create(), '--', true)
    lbl.show()
    elm = lbl.elm
    base = elm.clientWidth
    zoom = detect_zoom.device()
    exports.letter_height = elm.clientHeight * 1.15 * zoom
    for letter in " abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ.,;-"
        elm.textContent = "-#{letter}-"
        letter_sizes[letter] = (elm.clientWidth-base) * zoom
    lbl.hide()
    if not recalc_sizes_timer
        # Only necessary because of zoom/retina pixel ratio
        window.addEventListener 'resize', ->
            clearTimeout(recalc_sizes_timer)
            recalc_sizes_timer = setTimeout(exports.calc_letter_sizes, 800)
