
main_view = require '../views/main_view'
{popup_menu} = require '../views/ui_elements'
comments = require '../views/comments'

setInterval ->
    if exports.tour_viewer?.viewing and tour_viewer.tour_data.slides[tour_viewer.current_slide].no_sleep
        main_loop.reset_timeout()
, 3500

window?.addEventListener 'keydown', ->
    f = (e) ->
        if e.keyCode == KEYS.ESC
            if tour_viewer.is_viewing()
                tour_viewer.stop()
            else if tour_editor.is_editing()
                tour_editor.stop()
                save_tour_tree()


_tour_viewer_keydown = (event) ->
    tn = document.activeElement.tagName
    if tn == 'INPUT' or tn == 'TEXTAREA' or \
        document.activeElement.isContentEditable
            return
    k = event.keyCode
    switch true
        when k==KEYS.COMMA or # <
             k==KEYS.LEFT_ARROW
            if tour_editor.is_editing()
                tour_editor.previous()
            if tour_viewer.is_viewing()
                tour_viewer.previous()
            event.preventDefault()

        when k==KEYS.PERIOD or # >
             k==KEYS.RIGHT_ARROW
            if tour_editor.is_editing()
                tour_editor.next()
            if tour_viewer.is_viewing()
                tour_viewer.next()
            event.preventDefault()

        when k==KEYS.PAGE_UP
            if not window.is_pearson
                for e in $('''#main_menu, #tour-name, #tour-slide-number,
                        #oscc_toggle, #tour-viewer-controls, #auto-toggle,
                        #version, #fps, #patents-note''')
                    if e.oldDisplay?
                        return
                    [e.oldDisplay, e.style.display] = [e.style.display, 'none']

        when k==KEYS.PAGE_DOWN
            if not window.is_pearson
                for e in $('''#main_menu, #tour-name, #tour-slide-number,
                        #oscc_toggle, #tour-viewer-controls, #auto-toggle,
                        #version, #fps, #patents-note''')
                    e.style.display = if e.oldDisplay? then e.oldDisplay else e.style.display
                    e.oldDisplay = null

        when k==KEYS.F10
            window.show_slide_reference = true
            main_view.render_all_views()
    return

_tour_viewer_keyup = (event) ->
    tn = document.activeElement.tagName
    if tn == 'INPUT' or tn == 'TEXTAREA' or \
        document.activeElement.isContentEditable
            return
    switch event.keyCode
        when KEYS.F1
            if event.shiftKey and tour_viewer.is_viewing()
                if not tour_editor.can_edit_tours()
                    return alert 'That functionality is only available to authors.'
                tour_viewer.switch_to_editor()
                event.preventDefault()
                event.preventDefault()
        when KEYS.SPACE
            if tour_viewer.paused
                tour_viewer.resume()
            else
                tour_viewer.pause()
            # TODO This should not be necessary
            requestAnimationFrame ->
                document.body.scrollTop = 0
    return

tour_viewer = null
init_tour_viewer = ->
    tour_viewer = exports.tour_viewer = new TourViewer()

class TourViewer
    constructor: () ->
        ##
        @viewing = false
        @is_auto = false
        @auto_timer = 0
        @annotation_timer = 0
        @tour_name = ''
        @current_slide = -1
        @slides = []
        @audio_player = null
        @audio_progress_bar_position = 0
        @last_mouse_position = 0
        @reading_panel_is_empty = true
        @init_timeout_timer()
        @loading_slide = false
        @play_audio_time = 0
        @current_animations = []
        @animations_timeout = null

    is_viewing: () ->
        return @viewing

    save_quiz_state: (parsed_quiz) ->
        @answering_quizzes[parsed_quiz.label_id] = JSON.stringify(parsed_quiz)
        if parsed_quiz.done
            @remaining_quizzes -= 1
            @slides[@current_slide].remaining_quizzes -= 1

    load_quiz_state: (slide) ->
        if slide.quizzes
            for i in [0... slide.quizzes.length]
                q = JSON.parse(slide.quizzes[i])
                id = q.label_id
                if id of @answering_quizzes
                    window[q.type](null, JSON.parse(@answering_quizzes[id]))
                else
                    window[q.type](null, q)

    load_tour: (tour_data, callback) ->
        # For just loading tour data without playing or anything
        # Used when copying slides of a tour that is not in memory
        if tour_data.hash and not tour_data.slides
            f = (data) ->
                # Copy data in existing struct which is in the tree
                for k of data
                    if k!='hash'
                        tour_data[k] = data[k]
                tour_data
                callback(null, tour_data)
            error = ->
                callback("The tour couldn't be retrieved. Check your internet connection and try again.")
            request_json('GET', FILE_SERVER_DOWNLOAD_API+tour_data.hash, f, error)
        else
            callback(null, tour_data)

    start: (_tour_data, name, slide_num, is_landing, skip_preload) ->

        if tour_editor.is_editing()
            tour_editor.stop()

        $('#splash')[0].style.display = 'block'

        @audio_player = document.getElementById('vidabody-audio')

        if window.is_pearson or is_landing
            main_menu_visibility.set_state('hidden')
        else
            main_menu_visibility.set_state('semihidden2')
        main_menu_visibility.block()
        tour_data = @tour_data = _tour_data
        # If tour exists but is not loaded,
        # defer loading and call start() again
        tour_loaded = (data) ->
            # Copy data in existing struct which is in the tree
            for k of data
                if k!='hash' or not tour_data['hash']
                    tour_data[k] = data[k]
            tour_viewer.start(tour_data, name, slide_num, is_landing)
        error = ->
            if is_landing
                console.error("Couldn't load landing tour")
            else
                alert("The tour couldn't be retrieved. Check your internet connection and try again.")
            main_menu_visibility.unblock()
            main_menu_visibility.set_state('semihidden')
            $('#splash')[0].style.display = 'none'
        if tour_data.hash and not tour_data.slides
            request_json('GET', FILE_SERVER_DOWNLOAD_API+tour_data.hash, tour_loaded, error)
            return null
        else if tour_data.uuid and not tour_data.hash and not tour_data.slides
            request_json('GET', FILE_SERVER_DOWNLOAD_API+'tour/'+tour_data.uuid, tour_loaded, error)
            return null

        if (not tour_data.slides) or tour_data.slides.length < 1
            alert("The tour does not have any slides.")
            main_menu_visibility.unblock()
            main_menu_visibility.set_state('semihidden')
            return null

        # Migrate mesh names
        migrate_mesh_states(tour_data)

        if not skip_preload
            # Preload meshes of first slides
            names = for oname, state of tour_data.slides[0].visibility
                if not state[4]
                    continue
                oname
            @preload_slide tour_data.slides[0], =>
                tour_viewer.start(tour_data, name, slide_num, is_landing, true)
                second_slide = tour_data.slides[1]
                if second_slide
                    @preload_slide second_slide
            # load_meshes names, tour_data.slides[0].lod_filter, ->
                # tour_viewer.start(tour_data, name, slide_num, is_landing, true)

            return null

        @previous_labels_visible = labels_visible
        @previous_label_callouts = label_callouts
        @previous_label_callouts_splines = label_callouts_splines
        @previous_enabled_animations = exports.heart.enabled_animation
        @previous_heart_beat_speed = exports.heart.heart_beat_speed
        if window.is_pearson
            set_labels_visible(false)

        name = name or tour_data.name

        reading_panel.reset(if is_landing then (() -> 0) else @go_to_slide.bind(this))
        reading_panel.setTourName(name)

        @remaining_quizzes = @total_quizzes = tour_data.total_quizzes
        @tour_name = name

        @reading_panel_is_empty = true
        if tour_data.reading_texts
            for i in [0... tour_data.reading_texts.length]
                is_empty_reading_text = reading_panel.addSlideText( tour_data.reading_texts[i] )
                @reading_panel_is_empty = @reading_panel_is_empty and is_empty_reading_text

        @slides = tour_data.slides
        for s in @slides
            if s.quizzes
                s.remaining_quizzes = (s.quizzes).length

        @viewing = true
        @modified_view = false
        @answering_quizzes = {}

        reading_panel.flush()
        if not @reading_panel_is_empty
            reading_panel.show()

        window.addEventListener('keydown', _tour_viewer_keydown)
        window.addEventListener('keyup', _tour_viewer_keyup)
        @is_landing = is_landing
        if is_landing
            @is_auto = true
        else
            @is_auto = false
        $('#annotations')[0].classList.add('viewer')
        @current_slide = -1
        @go_to_slide(null, slide_num or 0)
        if tour_data.hash and not is_landing and not load_tour_hash? and not load_tour_uuid?
            hash = '#tour='+name.replace(/@/g,'')\
                                         .replace(/\x20/g,'%20')\
                                    +'@'+tour_data.hash
            if history.replaceState then history.replaceState('','',hash) else location.hash = hash
            window.prev_hash = location.hash
        popup_menu()
        main_view.render_all_views()
        $('#splash')[0].style.display = 'none'
        @oscc_was_hidden = camera_control.oscc.classList.contains('hidden')
        camera_control.oscc.classList.add('hidden')

    stop: (avoid_user_confirmation=false) ->
        scene.enabled = true
        can_stop = true
        if not avoid_user_confirmation and @remaining_quizzes
            can_stop = confirm("If you leave this tour, The unanswered quizzes will be failed.\nDo you want to leave this tour?")
        if not can_stop
            return false

        @fail_all_quizzes()
        if @remaining_quizzes
            for s in [0...@slides.length][1...].concat([0])
                @go_to_slide(null, s, true)

            window.alert("You failed the unanswered quizzes on this tour")
        @viewing = false

        @audio_player.pause()
        @audio_player.autoplay = false
        @audio_player.src = ''
        @audio_player.onplay = null
        @audio_player.onended = null

        annotations = $('#annotations')[0]
        for e in annotations.children
            if e.line
                e.line.remove()
        annotations.innerHTML = ''

        @clear_timeout(@auto_timer)
        @clear_timeout(@annotation_timer)
        @clear_timeout(@start_auto_rotation_timer)
        @clear_timeout(@animations_timeout)
        cancelAnimationFrame(@alpha_transition_timer)
        for ani in @current_animations
            ani.loop = false
        @current_animations = []
        reading_panel.hide(true)
        unquizz_all()
        change_bg_color(DEFAULT_BG_COLOR)
        main_menu_visibility.unblock()
        main_menu_visibility.set_state('semihidden')
        $('#annotations')[0].classList.remove('viewer')
        $('#annotations')[0].style.opacity = ''
        window.removeEventListener('keydown', _tour_viewer_keydown)
        window.removeEventListener('keyup', _tour_viewer_keyup)

        set_labels_visible(@previous_labels_visible)
        window.label_callouts = @previous_label_callouts
        window.label_callouts_splines = @previous_label_callouts_splines
        exports.heart.enabled_animation = @previous_enabled_animations
        exports.heart.heart_beat_speed = @previous_heart_beat_speed
        trigger_tutorials = true  # after exiting landing tour we can then show tutorials
        maximize() # and ensure we're maximized

        if history.replaceState then history.replaceState('','','#') else location.hash = ''
        window.prev_hash = location.hash

        if @oscc_was_hidden
            camera_control.oscc.classList.add('hidden')
        else
            camera_control.oscc.classList.remove('hidden')

        slicing_manager.to([])
        go_home(true)
        popup_menu()
        main_view.render_all_views()
        on_tour_exit?()
        disable_all_curves()
        return true

    fail_all_quizzes: () ->
        for l in quizzed_labels
            if l.quiz.done == false
                l.quiz.score = 0
                unhide_quiz(l)
                done_quiz(l, false)
                @save_quiz_state(l.quiz)
                l.update_orig_size()


    go_to_slide: (evt, idx, avoid_user_confirmation=false, is_auto_or_fake_auto) ->
        if @current_slide == idx
            return
        can_change = true
        last_slide = @slides[@current_slide]
        if not avoid_user_confirmation and last_slide and last_slide.remaining_quizzes
            can_change = confirm("If you leave this slide, The unanswered quizzes will be failed.\nDo you want to leave this slide?")
        if can_change and last_slide and last_slide.remaining_quizzes
            @fail_all_quizzes()
            if not avoid_user_confirmation
                window.alert("You failed the unanswered quizzes on this slide")

        if not can_change
            return


        @current_slide = idx
        slide = @slides[idx]
        if not is_auto_or_fake_auto
            prev_slide = @slides[idx-1]
            prev_forces_auto_advance = prev_slide?.force_auto_advance or prev_slide?.play_audio_across_slides
            while prev_forces_auto_advance
                idx -= 1
                @current_slide = idx
                slide = @slides[idx]
                prev_slide = @slides[idx-1]
                prev_forces_auto_advance = prev_slide?.force_auto_advance or prev_slide?.play_audio_across_slides
        @modified_view = false
        @playing_slide = true
        @paused = camera_control.paused = false
        unselect_all()
        popup_menu()
        @loading_slide = true
        main_view.render_all_views()
        # Stop all (like pause)
        camera_control.mode = IDLE
        if not last_slide?.play_audio_across_slides
            @audio_player.pause()
        # Preload meshes
        meshes = for oname, vis of slide.visibility when vis[4]
            oname
        # Preload meshes of next slide if they're force_auto_advance
        force_auto_advance = slide.force_auto_advance or slide.play_audio_across_slides
        next_slide = @slides[idx+1]
        while force_auto_advance and next_slide
            for oname, vis of next_slide.visibility when vis[4]
                meshes.push oname
            force_auto_advance = next_slide.force_auto_advance
            next_slide = @slides[@slides.indexOf(next_slide)+1]
        if @current_animations.length != 0
            scene.enabled = false
        requestAnimationFrame => requestAnimationFrame =>
            if @current_slide == idx
                now = performance.now()
                load_meshes meshes, slide.lod_filter, =>
                    # Wait at least 0.4s before playing the slide
                    # to make loading times less noticeable
                    remaining = 400 - (performance.now() - now)
                    if @is_auto or slide.force_auto_advance or slide.play_audio_across_slides
                        remaining = 0
                    setTimeout(=>
                        if @current_slide == idx
                            scene.enabled = true
                            @load_slide(slide, true)
                            # preload next meshes
                            if next_slide
                                @preload_slide(next_slide)

                    , Math.max(remaining, 0))

    preload_slide: (slide, cb) ->
        meshes = for oname, vis of slide.visibility when vis[4]
            oname
        load_meshes meshes, slide.lod_filter, ->
            cb?()

    load_slide: (slide, is_tour=false) ->
        @loading_slide = false
        main_view.render_all_views()
        trans_time = if slide.trans_time then slide.trans_time else DEFAULT_TRANS_TIME
        trans_time *= 1000 #ms

        slices = JSON.parse(JSON.stringify(slide.slices or []))
        for slice in slices
            slice.widget = null
        slicing_manager.to(slices, trans_time)

        audio_offset = 0
        set_all_state = =>
            set_nerves(slide.nerves or [])
            snap_helper.set_state_legacy(slide.state, trans_time, false, slide.visibility)
            @clear_timeout(@start_auto_rotation_timer)
            @start_auto_rotation_timer = @set_timeout =>
                requestAnimationFrame =>
                    # if turntable motion is defined for this slide, now it's the time to start it
                    if(slide.turntable_turns > 0) and(slide.turntable_rate != 0)
                        state = snap_helper.get_state()
                        # rpm -> ms per turn quarter
                        quarterTime = 60000 / (4 * slide.turntable_rate)
                        # turns -> number of quarter turns
                        quarterNumber = slide.turntable_turns * 4
                        current_slide = @current_slide
                        nextQuarter = =>
                            if @viewing and @current_slide == current_slide and quarterNumber > 0
                                amount = Math.min(quarterNumber, 1.0)
                                direction = if(quarterTime > 0) then 1.0 else -1.0

                                # rotate state by 1 quarter or less
                                quat.rotateY(state[2], state[2], direction * amount * Math.PI * 0.5)

                                quarterNumber -= amount
                                snap_helper.set_state_callback(state, amount * Math.abs(quarterTime), nextQuarter)
                        nextQuarter()
            , trans_time

            # TODO: use the slide state when previous state has finished
            # and @modified_view is false
            old_state = get_meshes_state()
            # This sets all the states except transitioning ones
            transition_meshes = set_meshes_state(slide.visibility, true, slide.lod_filter)
            # Presort meshes
            # TODO: Instead of sorting these,
            # sort the most prominent ones in the final camera state
            # that are not opaque at some point
            final_cam_rot = slide.state[2]
            sort_meshes(transition_meshes, final_cam_rot)

            initial_slider_animations = {}
            for anim_name of slider_animations
                anim = slider_animations[anim_name]
                initial_slider_animations[anim_name] = anim.pos

            cancelAnimationFrame(@alpha_transition_timer)
            atrans_init = performance.now()
            prev_time = atrans_init
            duration = slide.atrans_time * 1000
            atransition = () =>#animation and alpha transitions
                time = performance.now()
                t = time - atrans_init
                delta = time - prev_time
                prev_time = time
                if @paused
                    atrans_init += delta
                    requestAnimationFrame(atransition)
                    return
                #Slider animation (action transition)
                finished_anims = false
                if slide.slider_animations
                    total_anims = Object.keys(slide.slider_animations).length
                    n_finished_anims = 0
                    for anim_name of slide.slider_animations
                        anim = slider_animations[anim_name]
                        if anim
                            initial = initial_slider_animations[anim_name]
                            final = slide.slider_animations[anim_name]
                            factor = Math.min(1, t/duration)
                            # lerp
                            anim_length = final - initial
                            anim.pos = initial + factor * anim_length
                            if factor >= 1
                                anim.pos = final
                                finished_anims += 1
                        else
                            finished_anims += 1
                    if n_finished_anims == total_anims
                        finished_anims = true

                finished = transition_state(old_state, slide.visibility,
                    transition_meshes, duration, t, audio_offset+trans_time) and finished_anims
                if not finished
                    @alpha_transition_timer = requestAnimationFrame(atransition)
                    main_loop.reset_timeout()
                else
                    # finally make sure last state is applied
                    set_meshes_state(slide.visibility, slide.lod_filter)
                    ensure_invisible_meshes_are_hidden(transition_meshes)
            atransition()

            for ani in @current_animations
                ani.loop = false
                if ani.sync
                    ani.speed = ani.orig_speed or ani.speed
            @current_animations = []
            @clear_timeout @animations_timeout
            @animations_timeout = @set_timeout =>
                ### vb.tour_editor.current_slide_data.actions = [{object: 'Skeletal_armature',
                anim_id: 'Skeletal_armature/muscle_test.0', speed: 1, start_frame: 0, end_frame: 40}]
                vb.tour_editor.save_state() ###
                if slide.actions
                    for action in slide.actions
                        ob = objects[action.object]
                        anim = ob?.animations[action.anim_id]
                        if anim
                            anim.loop = if action.loop? then action.loop else true
                            anim.sync = action.sync # bool to determine whether to pause with slide
                            anim.speed = action.speed
                            anim.start_frame = action.start_frame
                            anim.end_frame = action.end_frame
                            if anim.pos >= anim.end_frame or anim.pos < anim.start_frame
                                anim.pos = anim.start_frame
                            @current_animations.push anim
                        else
                            console.warn "Can't find animation #{action.anim_id} in #{action.object}"
            , duration
        if is_tour
            reading_panel.updateSlideIndex(@slides.indexOf(slide))

        # By default, annotations will show after the camera has finished moving
        # Unless you change the delay of any annotation, then it will count
        # from the moment the user changes the slide
        show_annotations_time = trans_time
        if slide.zero_delay_anns
            show_annotations_time = 0

        anns = @hide_annotations()
        if not @modified_view
            $('#lines')[0].style.opacity = 1
        @clear_timeout(@annotation_timer)
        @annotations_are_shown = false
        show_annotations = =>
            for e in anns.children by -1
                if not e.classList.contains('transformable')
                    anns.removeChild(e)
            if not @modified_view
                anns.style.opacity = 1
            @annotations_are_shown = true
            play_audio_time = @play_audio_time
            if @reading_panel_is_empty
                reading_panel.hide(true)
            else
                if slide.reading_panel_opened
                    reading_panel.show()
                else
                    reading_panel.hide(false)

            if slide.annotations and slide.annotations.length > 0
                for i in [0... slide.annotations.length]
                    a = slide.annotations[i]
                    n = document.createElement('p')
                    n.style.left = a.x*2+'%'
                    n.style.top = a.y*2+'%'
                    n.style.width = a.w*2+'%'
                    n.style.height = a.h*2+'%'
                    n.innerHTML = a.text

                    if a.anchor
                        n.line = new Line('#ffffff', 1.5)
                        n.line.line.classList.add('fade-in-start')
                        n.line.shadow.classList.add('fade-in-start')
                        n.object = objects[get_migrated_names([a.anchor.name])[0]]
                        n.point = vec4.create()
                        n.point[0] = a.anchor.x
                        n.point[1] = a.anchor.y
                        n.point[2] = a.anchor.z
                        n.point[3] = 1

                    if a.shadow
                        n.classList.add('annotation_shadow')

                    n.style.opacity = 0
                    delay = a.delay*1000 or show_annotations_time
                    @set_timeout ( do (n, a) -> ->
                        n.style.opacity = 1
                        n.line?.line.classList.add('fade-in-end')
                        n.line?.shadow.classList.add('fade-in-end')
                    ), max(delay - play_audio_time, 0)

                    anns.appendChild(n)

                update_annotations_when_camera_moves(true)


            # Reverse order because before label visibility wasn't enforced
            # when enabling callouts
            if not window.is_pearson
                set_label_callouts_splines(slide.label_callouts_splines)
                set_label_callouts(slide.label_callouts)
                set_labels_visible(slide.labels_visible)
        heart.enabled_animation = slide.tmp_enabled_animations or false
        heart.heart_beat_speed = slide.tmp_heart_beat_speed or 1

        if not window.is_pearson
            set_labels_visible(false)

        onplay = =>
            if (show_annotations)
                # assigning outer variable that is used inside atransition()
                audio_offset = @play_audio_time
                set_all_state()
                @clear_timeout(@annotation_timer)
                audio_time = @audio_player.currentTime
                if not @audio_player.src
                    audio_time = 0
                @annotation_timer = @set_timeout(show_annotations, max(0, show_annotations_time - audio_time))
                if slide.new_annotations
                    load_annotations_from_data(slide.new_annotations, true, (f,t) =>
                        @set_timeout f, t - @play_audio_time
                    )
            show_annotations = null # onplay may run more than once

        change_bg_color(slide.bg_color or DEFAULT_BG_COLOR)
        unquizz_all()
        @load_quiz_state(slide)

        @clear_timeout(@auto_timer)
        onend = =>
            # TODO: set this to false after both audio and delays have finished
            # (for now we assume audio always finishes the last)
            @playing_slide = slide.force_auto_advance or slide.play_audio_across_slides
            main_view.render_all_views()
            if (@is_auto or slide.force_auto_advance or slide.play_audio_across_slides) and is_tour
                time = if slide.auto_next then slide.auto_next else DEFAULT_AUTO_TIME * 1000
                if not @audio_player.src
                    time = max(trans_time, time - trans_time)
                if time != -1 # -1 means manual
                    @auto_timer = @set_timeout =>
                        if @current_slide != @slides.length-1
                            @go_to_slide(0, @current_slide+1, null, true)
                        else if @is_landing
                            @go_to_slide(0, 0, null, true)
                    , time

        @load_audio(onplay, onend)

        main_loop.reset_timeout()

        comments.grab_thread(slide.uuid)

    set_modified_view: ->
        # Important! if you use set_state, do it after calling this!
        # (or after it has finished)
        if @viewing and not @modified_view and camera_control.mode != AUTOPILOT
            $('#annotations')[0].style.opacity = 0
            $('#lines')[0].style.opacity = 0
            @modified_view = true
            main_view.render_all_views()

    restore_view: ->
        if not @viewing or not @modified_view
            return
        slide = @slides[@current_slide]
        if @paused
            snap_helper.set_state(@paused_state, 700)
            set_meshes_state(@paused_mesh_state, false, slide.lod_filter)
        else
            snap_helper.set_state(slide.state, 700)
            set_meshes_state(slide.visibility, false, slide.lod_filter)
        @modified_view = false
        main_view.render_all_views()
        if @annotations_are_shown
            # Delay for fake masks
            # TODO: remove delay if masks are replaced by true 3D ones
            setTimeout ->
                if not @modified_view
                    $('#annotations')[0].style.opacity = 1
                    $('#lines')[0].style.opacity = 1
            , 400

    pause: ->
        current = @current_slide + 1
        slide = @slides[@current_slide]
        len = @slides.length
        is_auto = @is_auto or slide.force_auto_advance or slide.play_audio_across_slides
        if not @paused and (@playing_slide or (is_auto and not current == len))
            @paused = true
            camera_control.pause()
            @audio_player.pause()
            if camera_control.mode == AUTOPILOT or camera_control.mode == AUTO_BREAKABLE
                @paused_state = snap_helper.get_state()
            else
                @paused_state = slide.state
            if camera_control.mode == AUTOPILOT
                @paused_mesh_state = get_meshes_state()
            else
                @paused_mesh_state = slide.visibility
            for anim in @current_animations
                if anim.sync
                    anim.orig_speed = anim.speed
                    anim.speed = 0
            main_view.render_all_views()

    resume: ->
        if @paused
            camera_control.resume()
            if (@audio_player.duration - 0.01) > @audio_player.currentTime
                @audio_player.play()
            @modified_view = false
            # Restore camera if the mode was not autopilot
            if not (camera_control.mode == AUTOPILOT or camera_control.mode == AUTO_BREAKABLE)
                snap_helper.set_state(@paused_state, 700)
                set_meshes_state(@paused_mesh_state, false, @slides[@current_slide].lod_filter)
            for anim in @current_animations
                if anim.sync
                    anim.speed = anim.orig_speed or anim.speed
            @paused = false
            main_view.render_all_views()

    previous: () ->
        if @current_slide != 0
            @is_auto = false
            idx = @current_slide-1
            current_slide = @slides[idx]
            while (current_slide.force_auto_advance or current_slide.play_audio_across_slides) \
                    and idx != 0
                idx -= 1
                current_slide = @slides[idx]
            @go_to_slide(0, idx, false)

    next: (auto=false) ->
        if @current_slide != @slides.length-1
            @is_auto = auto
            idx = @current_slide
            current_slide = @slides[idx]
            while not auto and (current_slide.force_auto_advance or current_slide.play_audio_across_slides) \
                    and idx != @slides.length-1
                idx += 1
                current_slide = @slides[idx]
            @go_to_slide(0, idx+1, null, auto)
        else if @is_landing
            @go_to_slide(0, 0, null, auto)

    switch_to_editor: () ->
        if not tour_editor.can_edit_tours()
            return alert "You don't have permission to edit tours."
        if @tour_data.from_link
            if confirm('This tour has been opened from a link. Do you want to import it to be able to edit it?') and @stop()
                add_tour_element(@tour_name).tour_data = @tour_data
                @tour_data.uuid = uuid.v4()
                delete @tour_data.from_link
            else
                return
        tour_editor.start(@tour_data, @tour_name, @current_slide)

    load_audio: (onplay, onend) ->
        slide = @slides[@current_slide]
        if not slide
            return
        prefix = if slide.audio_format == 'mp3' then 'mp3/' else ''
        audio_path = slide.audio_hash and FILE_SERVER_DOWNLOAD_API+prefix+slide.audio_hash

        if audio_path?.charAt(audio_path.length-1) == '/'
            audio_path = ''

        if audio_path
            @audio_player.pause()
            @audio_player.autoplay = true
            @audio_player.src = audio_path
            if slide.play_audio_across_slides
                @audio_player.onplay = =>
                    @play_audio_time = 0
                    onplay()
                    onend()
                @audio_player.onended = undefined
            else
                @audio_player.onplay = =>
                    @play_audio_time = 0
                    onplay()
                @audio_player.onended = onend
        else # no audio in current slide
            last_slide = @slides[@current_slide-1]
            last_paas = last_slide?.play_audio_across_slides
            if not last_paas
                @audio_player.pause()
                @audio_player.src = audio_path = ''
            onplay()
            if (last_paas and slide.play_audio_across_slides) or not last_paas
                onend()
            else
                @audio_player.onended = onend
        return

    toggle_auto: ->
        @is_auto = not @is_auto
        slide = @slides[@current_slide]
        if not (slide.force_auto_advance or slide.play_audio_across_slides)
            @clear_timeout(@auto_timer)
        if @is_auto
            if @paused
                @resume()
            else if not @playing_slide
                @next(true)

    set_auto: ->
        @is_auto = true
        @next(true)

    clear_auto: ->
        @is_auto = false
        slide = @slides[@current_slide]
        if not (slide.force_auto_advance or slide.play_audio_across_slides)
            @clear_timeout(@auto_timer)
        if @audio_player
            @audio_player.pause()
        main_view.render_all_views()

    current_slide_is_automatic: () ->
        return @is_auto and @slides[@current_slide].auto_next != -1

    hide_annotations: () ->
        anns = $('#annotations')[0]
        anns.style.opacity = 0
        for e in anns.children
            if e.line
                e.line.remove()
                delete e.line
        anns

    init_timeout_timer: ->
        @timers = {}
        @next_timer_id = 0
        prev_time = performance.now()
        timer_tick = =>
            requestAnimationFrame(timer_tick)
            if @paused or @loading_slide
                prev_time = performance.now()
            else
                time = performance.now()
                t = time - prev_time
                prev_time = time
                @play_audio_time += t
                for id, timer of @timers
                    if (timer.time -= t) <= 0
                        delete @timers[id]
                        timer.func()
        timer_tick()

    set_timeout: (func, time) ->
        id = ++@next_timer_id
        @timers[id] = {time, func}
        id

    clear_timeout: (id) ->
        delete @timers[id]
