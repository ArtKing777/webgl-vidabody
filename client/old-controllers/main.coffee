
main_view = require '../views/main_view'
window.detect_zoom = require 'detect-zoom'

# If vidabody_app_path is present, it's expected to have a trailing slash
if not window?.vidabody_app_path?
    window?.vidabody_app_path = ''

DOUBLE_CLICK_MS = 300

window.achievements = {
    'oscc':false,
    'main_menu':false,
    'login_pannel':false,
    }

exports.on_page_load = ->
    require('../views/tutorials').load_tutorials()
    require('../views/organ_tree_view').init_organ_tree()
    main_view.render_all_views()
    # Modules to be ported to react
    init_tour_tree()
    init_all_accordions()
    auth_init() # Must init after accordions

    exports.init_rest_of_UI_modules = ->
        init_lines()
        reading_panel_init()
        load_public_tree()
        init_tour_viewer()
        init_tour_editor()
        window.addEventListener 'resize', ->
            requestAnimationFrame(main_view.render_all_views)
        document.getElementById('app').oncontextmenu = (e) ->
            e.target.classList.contains('enable-native-context-menu')
        get_asset_version_of_linked_tour (version)->
            MYOU_PARAMS.data_dir = ASSETS_BASE + version + '/'
            init_myou_in_browser()
            requestAnimationFrame -> requestAnimationFrame ->
                exports.calc_letter_sizes()
    if window.is_pearson and not window.vidabody_app_path
        # For pearson author access,
        # Hide progress bar and wait for the user to log in
        $('#splash')[0].style.display = 'none'
    else
        # Otherwise, run modules now
        exports.init_rest_of_UI_modules()

    window.addEventListener 'keydown', (e) ->
        if e.keyCode == 9 # tab
            if document.activeElement == document.body
                e.preventDefault()
                e.stopPropagation()
    , true
    window.addEventListener 'keyup', (e) ->
        if e.keyCode == 48 and (e.ctrlKey or e.metaKey) # ctrl+0
            requestAnimationFrame ->
                if localStorageSupported
                    window.current_zoom = detect_zoom.device()+''
                    localStorage.defaultZoom = window.current_zoom
                    main_view.render_all_views()
    , true

    if is_maximized()
        mouse.cancel_wheel = true
        window.addEventListener 'wheel', cancel_wheel_f, true

if localStorage?
    localStorageSupported = do ->
        # Safari in incognito mode exposes localStorage but
        # throws a QuotaExceededError when trying to write anything
        try
            localStorage.test = 1
            return true
        catch e
            return false
    window.current_zoom = detect_zoom.device()+''
    if localStorageSupported
        localStorage.defaultZoom = localStorage.defaultZoom or window.current_zoom
        setInterval ->
            zoom = detect_zoom.device()+''
            changed = zoom != window.current_zoom
            window.current_zoom = zoom
            if changed
                main_view.render_all_views()
        , 2000
    else
        window.current_zoom = localStorage.defaultZoom # probably undefined
else
    window.localStorage = {}

exports.alpha_sort_options = alpha_sort_options =
    sort_sq_threshold: 0.02
    max_indices_per_frame: 16000

last_sorted_mesh_index = 0
transparency_test = ->
    # Block sorting during transitions
    if camera_control.mode == AUTOPILOT
        return
    # Sort polygons of meshes with alpha of active scene
    scene = camera_control.current_camera_state.scene
    mpasses = scene.mesh_passes[1]
    camZ = vec3.create()
    vec3.transformQuat(camZ, Z_VECTOR, scene.active_camera.rotation)
    l = mpasses.length
    if l == 0
        return
    sorted_indices = 0
    for i in [last_sorted_mesh_index... last_sorted_mesh_index+18]
        mesh = mpasses[i%l]
        amesh = mesh.last_lod_object or mesh
        if not amesh.last_sort_rotation
            # This shouldn't be necessary
            amesh.last_sort_rotation = vec3.create()
            amesh.last_sort_rotation[2] = -100
        if mesh.visible and amesh.data and
                vec3.sqrDist(amesh.last_sort_rotation, camZ) > alpha_sort_options.sort_sq_threshold
            sort_mesh(amesh)
            sorted_indices += amesh.data.num_indices[0] or 0
            if sorted_indices > alpha_sort_options.max_indices_per_frame
                break
            vec3.copy(amesh.last_sort_rotation, camZ)
        last_sorted_mesh_index += 1
    last_sorted_mesh_index %= l


sort_meshes = (meshes, cam_rotation) ->
    for mesh in meshes
        if mesh.data
            sort_mesh(mesh, cam_rotation)


MYOU_PARAMS?.oninitfail = ->
    main_loop.stop()

    $(if window.WebGLRenderingContext then '#error_blacklisted' else '#error_unsupported')[0].classList.remove('hidden')

    # hide canvas and splash
    $('#canvas')[0].style.visibility = 'hidden'
    $('#splash')[0].style.display = 'none'


MYOU_PARAMS?.oncontextlost = ->
    main_loop.stop()

    $('#error_context_lost')[0].classList.remove('hidden')

    # hide canvas and splash
    $('#canvas')[0].style.visibility = 'hidden'
    $('#splash')[0].style.display = 'none'


# On scene load
MYOU_PARAMS?.onload = ->

    if exports.migrations and exports.migrations != migrations
        for k of migrations
            migrations[k] = undefined
        for k,v of exports.migrations
            migrations[k] = v

    # Remove carrousel of landing page
    e = $('.et_pb_slider')[0]
    if e
        e.innerHTML = ''
        e.style.visibility = 'hidden'

    # Prevent accidental exit when editing or saving
    goodbye = (e) ->
        confirmation_message = ''
        if tour_editor.is_editing()
            confirmation_message = 'You have unsaved changes. Are you sure you want to exit?'
        else if file_manager.pending_tasks
            confirmation_message = 'Warning! Changes are still being saved!'
        if confirmation_message
            (e or window.event).returnValue = confirmation_message # Gecko + IE
            return confirmation_message                            # Webkit, Safari, Chrome etc.
    window.addEventListener('beforeunload', goodbye)

    # Show canvas, hide splash
    canvas = document.getElementById('canvas')
    canvas_container = document.getElementById('canvas_container')
    canvas.style.visibility = 'visible'
    document.getElementById('splash').style.display = 'none'
    document.querySelector('[data-myou-app]').style.background = 'none'

    # In mesh_state
    add_custom_scene_and_mesh_attributes(scene)

    # Initialize modules
    init_labels()
    init_camera_control()
    init_camera_actions()
    init_selection()
    init_slicing()
    exports.init_animations()
    exports.init_glraytest()
    update_visiblity_tree()

    init_annotations_with_3D_anchors()

    # Request settings and init hidden dat.gui
    # Also labels are loaded here
    request_debug_settings()

    # Remember objects withouot physics and with alpha effects
    for ob in scene.children
        ob.no_phy = ob.physics_type == 'NO_COLLISION'
        ob.always_alpha = ob.passes?[0] == 1
        ob.only_phy = ob.material_names and ob.material_names.length and ob.material_names[0] == 'physics_only'
        if ob.only_phy
            if ob.passes
                # non-existant pass: invisible
                # leaving the visible flag for visibility states
                ob.passes[0] = 99
        # Invisible = don't enable physics please
        # (important for non mesh physics)
        # TODO: move this to packer?
        if ob.body and not ob.visible
            ob.physics_type = 'NO_COLLISION'
            ob.instance_physics()

    steps = [
        [3.0, 1],
        [3.8, 1],
        [4.4, 1],
        [4.4, .7],
        [4.6, .7],
        [4.8, .7],
    ]
    current_step = 1
    render_manager.lod_factor = steps[current_step][0]
    tick_tock = true
    window.pixel_ratio_swapper_timer = setInterval ->
        if scene.enabled and main_loop.enabled
            tick_tock = not tick_tock
            if tick_tock
                frame_duration = 0
                for fd in main_loop.last_frame_durations
                    frame_duration += fd
                frame_duration /= main_loop.last_frame_durations.length
                rm = render_manager
                if frame_duration > 66 and current_step!=(steps.length-1)# < 15 fps
                    current_step += 1
                    px_ratio = steps[current_step][1]
                    rm.resize(rm.width, rm.height, px_ratio, px_ratio)
                    render_manager.lod_factor = steps[current_step][0]
                else if frame_duration < 33 and current_step != 0 # > 30 fps
                    current_step -= 1
                    px_ratio = steps[current_step][1]
                    rm.resize(rm.width, rm.height, px_ratio, px_ratio)
                    render_manager.lod_factor = steps[current_step][0]
    , 1000

    # # Load higher resolution textures
    # for _, t of render_manager.textures
    #     if t.load_additional_level
    #         t.load_additional_level()
    #         # TODO: use a callback to load more levels?

    # Set default background color
    change_bg_color(DEFAULT_BG_COLOR)

    # Misc events
    # TODO: there's no toggle maximized button now
    if not is_maximized()
        for e in document.querySelectorAll('.maximize_button')
            e.onclick = toggle_maximized
            e.style.cursor = 'pointer'
            e.style['pointer-events'] = 'all'

    #document.getElementById('app').addEventListener('contextmenu', (e) ->e.preventDefault())
    requestAnimationFrame -> requestAnimationFrame -> requestAnimationFrame ->
        scene.pre_draw_callbacks.append(transparency_test)

    scene.post_draw_callbacks.append(window.spline_tracker)

    window.prev_hash = ''
    tour_hashing = ->
        if location.hash != prev_hash
            window.prev_hash = location.hash
            if prev_hash.startswith('#tour=')
                s = prev_hash[6...].split('@')
                if s.length == 2
                    name = s[0].replace(/%20/g,' ')
                    tour_viewer.start({hash: s[1], from_link: true}, name, 0, false)
                    maximize()
    setInterval(tour_hashing, 1000)

    has_pearson_data =
        window.is_pearson and
        (window.load_tour_hash or window.load_tour_uuid)

    should_render_tree = is_maximized() and not has_pearson_data

    if should_render_tree
        main_menu_visibility.set_state('unhidden')

    load_micro_scenes()
    explore_mode_undo.save_state()

    # Placeholder for blood_flow_particle if not available
    if not objects.blood_flow_particle and objects.Iris_L
        objects.blood_flow_particle = objects.Iris_L.clone()
        objects.blood_flow_particle.no_phy = true
        objects.blood_flow_particle.physics_type = 'NO_COLLISION'


if /version\/([^\s]+)\ssafari/i.exec(navigator?.userAgent)
    window.frameTime = 0
    window.skipFrame = 0
    originalRAF = window.requestAnimationFrame or window.webkitRequestAnimationFrame
    window.requestAnimationFrame = (f) ->
        if window.skipFrame > 0
            originalRAF( ->
                originalRAF((t) ->
                    f(t)
                    window.skipFrame--
                )
            )
        else
            originalRAF((t) ->
                before = performance.now()
                f(t)
                window.frameTime = performance.now() - before
                # if a frame takes longer than 10ms, skip half of frames for a few seconds
                window.skipFrame = if (window.frameTime > 10) then 300 else (window.skipFrame - 1)
            )

# Testing this functionality manually until we can automate it(it works
# as long as you execute it after the previous levels finished loading)
load_aditional_texture_level = ->
    any_remaining = false
    for _, t of render_manager.textures
        if t.load_additional_level
            any_remaining = any_remaining or t.load_additional_level(2)
    if any_remaining
        scene.loader.add_queue_listener 2, ->
            load_additional_level()

toggle_maximized = ->
    # This used to be toggled when clicking the logo or the old menus
    # I'm awaiting Julio's decisions regarding this functionality
    document.body.classList.toggle('maximized_app')
    maximized = is_maximized()
    mouse.cancel_wheel = maximized
    if maximized
        window.addEventListener 'wheel', cancel_wheel_f, true
        s = document.body.scrollTop
        main_menu_visibility.set_state('unhidden')
        scroll = ->
            s = s*0.8 - 5
            document.body.scrollTop = s
            if s>=0
                requestAnimationFrame(scroll)
        scroll()
        hidestuff = ->
            document.body.classList.add('hidestuff')
            # trigger reexpand_main_menu_accordions()
            trigger_window_resize()
        # This hides the body children that != the app
        # without this there's a scrollbar that shouldn't be there
        # it also recalculates the accordion height, but it can't be seen now
        # Eventually, this will be made differently for embedding in external pages
        setTimeout(hidestuff, 1000)
    else
        window.removeEventListener 'wheel', cancel_wheel_f, true
        document.body.classList.remove('hidestuff')
        fold_accordion(main_menu.querySelector('.accordion'))
        main_menu.classList.remove('expanded')
        main_menu_visibility.set_state('hidden')
    soft_resize_1s()

is_maximized = ->
    return document.body.classList.contains('maximized_app')

maximize = ->
    if not is_maximized()
        toggle_maximized()
        setTimeout(watchCanvasResize, 1000)

cancel_wheel_f = (e) ->
    # Prevent zoom with mac trackpads
    if e.ctrlKey
        e.preventDefault()
    return

trigger_window_resize = ->
    # This just calls all functions attached to the "resize" event
    event = document.createEvent('HTMLEvents')
    event.initEvent('resize', true, false)
    window.dispatchEvent(event)


window?.show_unclassified = ->
    for e in $('[data-visiblename="Unclassified"]')
        e.setAttribute('data-visiblename', '')


window?.vb_debug = -> debugger

one_system_filter = (system) ->
    (d) ->
        for o in d
            if o.type=='MESH' and o.name != 'Skeletal:Femur_cross_section:red_bonemarrow3'
                o.visible = o.properties.system == system
            o

several_systems_filter = (systems) ->
    (d) ->
        for o in d
            # Check Alternatives
            if o.type=='MESH' and o.name != 'Skeletal:Femur_cross_section:red_bonemarrow3'
                o.visible = o.properties.system in systems
            o

# Undo uuid workaround if present
if load_tour_hash? and /^tour\//.test(load_tour_hash)
    window.load_tour_uuid = load_tour_hash[5...]
    window.load_tour_hash = null

get_asset_version_of_linked_tour = (callback) ->
    # Detect if there's a tour to be played, to load the specific assets instead of the default ones.
    version = ASSETS_VERSION

    if load_tour_hash? and load_tour_hash
        set_labels_visible(false)
        request_json 'GET', FILE_SERVER_DOWNLOAD_API + load_tour_hash, (data) ->
            if data.one_system
                MYOU_PARAMS.initial_scene_filter = one_system_filter(data.one_system)
            if data.assets_version
                version = data.assets_version
            callback(version)
    else if load_tour_uuid? and load_tour_uuid
        set_labels_visible(false)
        request_json 'GET', FILE_SERVER_DOWNLOAD_API + 'tour/' + load_tour_uuid, (data) ->
            if data.one_system
                MYOU_PARAMS.initial_scene_filter = one_system_filter(data.one_system)
            if data.assets_version
                version = data.assets_version
            callback(version)
    else if location.hash.startswith('#tour=')
        s = location.hash[6...].split('@')
        if s.length == 2
            request_json 'GET', FILE_SERVER_DOWNLOAD_API + s[1], (data) ->
                if data.one_system
                    MYOU_PARAMS.initial_scene_filter = one_system_filter(data.one_system)
                if data.assets_version
                    version = data.assets_version
                callback(version)
        else
            callback(version)
    else
        if initial_visible_systems?
            MYOU_PARAMS.initial_scene_filter = several_systems_filter(initial_visible_systems)
        if initial_scene_filter?
            MYOU_PARAMS.initial_scene_filter = initial_scene_filter
        callback(version)
        alt_style = '''
        li#search,li#search:hover{
            position:relative;
            z-index:30;
            list-style: none;
            padding: 4px 10px 4px 40px;
            position: relative;
            width: 100%;
            color: #fff;
            text-shadow: 0px 1px 0px rgba(0,0,0,0.35), 0px 0px 4px rgba(0,0,0,0.5);
            word-break: break-word;
            text-align: left;
            border: none;
            border-radius: 3px;
            -webkit-box-shadow: inset 0px 5px 20px rgba(0,0,0,0.5);
            -moz-box-shadow: inset 0px 5px 20px rgba(0,0,0,0.5);
            box-shadow: inset 0px 5px 20px rgba(0,0,0,0.5);
            border-top: 1px solid rgba(0,0,0,0);
            pointer-events: all;}
        '''
        `var searchUpdater = setInterval(function(){
            var search = document.querySelector('li#search')
            if(search){
                search.classList.remove('item')
                var s = document.createElement('style')
                s.textContent = alt_style
                document.body.appendChild(s)
                var last = search.parentElement.scrollTop;
                function updateSearch(){
                    var st = search.parentElement.scrollTop;
                    if(st!=last){
                      search.style.top = search.parentElement.scrollTop-1+'px'
                      search.style.backgroundColor = window.TEST || '#616161'
                      last = st;
                    }
                    requestAnimationFrame(updateSearch)
                }
                requestAnimationFrame(updateSearch);
                clearInterval(searchUpdater);
            }
        }, 500);`
    return
