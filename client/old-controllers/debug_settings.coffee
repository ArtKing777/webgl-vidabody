if /#landing/.test(location.hash)
    document.body.classList.add('landing')

add_fps_counter = (gui) ->
    if window.vidabody_app_path
        return
    MYOU_PARAMS.fps_counter = true
    gui.add(MYOU_PARAMS, 'fps_counter')
    fps = document.getElementById('fps')
    fps.style.color = 'white'
    f = ->
        if MYOU_PARAMS.fps_counter and not fps.oldDisplay
            duration = 0
            for fd in main_loop.last_frame_durations
                duration += fd
            fps.innerHTML = (1000*main_loop.last_frame_durations.length/duration).toFixed(2)
            fps.style.display = 'block'
        else
            fps.style.display = 'none'
    setInterval(f, 1000)


request_debug_settings = ->
    
    load = (data) ->
        # Place hidden dat.gui
        gui = window.gui = new dat.GUI({'autoPlace': false, 'load': data.settings or data })
        debug_gui = document.getElementById("debug_gui")
        debug_gui.appendChild(gui.domElement)
        debug_gui.onmousemove = ->
            main_loop.reset_timeout()
        gui.close()
        
        ts = gui.addFolder('Tour actions')
        ts.add(tour_tree_functions, 'remove_landing_tour')
        ts.add(require('../views/tutorials'), 'reset_tutorials')
        ts.add(tour_tree_functions, 'copy_tree')
        ts.add({add_tour_to_tree: ->
            link = prompt 'paste tour link or hash'
            if link
                hash = link.split('@').pop()
                if /^[0-9a-z]+$/.test hash
                    if /#tour=/.test link
                        name = link.split('#tour=').pop().split('@')[0].replace(/%20/g,' ')
                    else
                        name = prompt 'Tour name?'
                    add_tour_element name, {hash: hash}
                    alert 'Added successfully'
                else
                    alert 'Invalid hash or link'
            else
                alert 'To use this option, load a tour from a link'
        }, 'add_tour_to_tree')
        
        gui.add(alpha_sort_options, 'sort_sq_threshold', 0, 4)
        gui.add(alpha_sort_options, 'max_indices_per_frame', 1000, 100000)
        add_label_settings(gui)
        camera_control.add_camera_settings(gui)
        add_fps_counter(gui)
        add_animation_debug_gui(gui)
        
        gui.add(heart, 'enabled_animation')
        # gui.add(window, 'load_public_tree')
        gui.add({test_lose_context: ->
            MYOU_PARAMS.on_context_lost = ->
                show_context_lost_error()
                requestAnimationFrame ->
                    render_manager.extensions.lose_context.restoreContext()
            render_manager.extensions.lose_context.loseContext()
        }, 'test_lose_context')
        gui.add(require('../views/tour_viewer_view'), 'old_pos').onChange ->
            require('../views/main_view').render_all_views()
        
        if data.labels
            labels_from_JSON(data.labels)
        else
            autogenerate_part_labels()
        
        if data.landing_tour and /#landing/.test(location.hash)
            window.landing_tour = data.landing_tour
            # add landing style for UI variations
            document.body.classList.add('landing')
            # TODO: launch viewer with some GUI variations
            if landing_tour and not location.hash.startswith('#tour=') and not load_tour_hash?
                tour_viewer.start({'hash': landing_tour}, '', 0, true)
        else if load_tour_hash?
            document.body.classList.remove('landing')
            tour_viewer.start({'hash': load_tour_hash}, '', 0, false)
        else if load_tour_uuid?
            document.body.classList.remove('landing')
            tour_viewer.start({'uuid': load_tour_uuid}, '', 0, false)
        
        save = exports.save_settings = ->
            f = ->
                if vida_body_auth.logged_in and vida_body_auth.is_admin
                    data = {
                        'settings': gui.getSaveObject(),
                        'labels': labels_to_JSON(),
                        'landing_tour': landing_tour
                    }
                    file_manager.upload_settings(JSON.stringify(data))
                else
                    alert('You must be logged in as administrator')
            # Executing this delayed, because DOM spec doesn't
            # ensure that this will be executed after the other save event
            setTimeout(f, 200)

        $('#debug_gui .save')[0].addEventListener('click', save)
        $('#debug_gui .save-as')[0].addEventListener('click', save)

        #vida_body_auth.is_admin = true

    error = ->
        load({})
    
    request_json('GET', FILE_SERVER_DOWNLOAD_API + 'settings?' + Math.random(), load, error)
