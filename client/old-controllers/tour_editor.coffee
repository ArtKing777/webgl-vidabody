
main_view = require '../views/main_view'
{popup_menu} = require '../views/ui_elements'
comments = require '../views/comments'

glraytest = require '../util/gl_ray_test'

TOUR_FORMAT_VERSION = 1

DEFAULT_AUTO_TIME = 10
DEFAULT_TRANS_TIME = 1.2

abs = Math.abs

uuid = require 'node-uuid'
{parseCSSColor} = require 'csscolorparser'


_tour_editor_keydown = (event) ->
    tn = document.activeElement.tagName
    if tn == 'INPUT' or tn == 'TEXTAREA' or \
        document.activeElement.isContentEditable
            return
    switch event.keyCode
        when KEYS.COMMA  # <
            if tour_editor.is_editing()
                tour_editor.previous()
            if tour_viewer.is_viewing()
                tour_viewer.previous()
            event.preventDefault()

        when KEYS.PERIOD # >
            if tour_editor.is_editing()
                tour_editor.next()
            if tour_viewer.is_viewing()
                tour_viewer.next()
            event.preventDefault()

_tour_editor_keyup = (event) ->
    tn = document.activeElement.tagName
    if tn == 'INPUT' or tn == 'TEXTAREA' or \
        document.activeElement.isContentEditable
            return
    tour_editor.save_state(200)

    switch event.keyCode
        when KEYS.F1
            if event.shiftKey and tour_editor.is_editing()
                tour_editor.switch_to_viewer()
                event.preventDefault()
        when KEYS.SPACE
            event.preventDefault()
            # TODO This should not be necessary
            requestAnimationFrame ->
                document.body.scrollTop = 0


bg_color = "#808080"
DEFAULT_BG_COLOR = "#808080"
document?.getElementById('app').style.backgroundColor = DEFAULT_BG_COLOR

exports.change_bg_color = change_bg_color = (color, save_state) ->
    if not color
        return
    c = parseCSSColor(color)
    if not c
        return

    bg_color = color
    bg = scene.background_color
    bg[0] = c[0]/255
    bg[1] = c[1]/255
    bg[2] = c[2]/255
    if save_state
        tour_editor.save_state()
    main_loop.reset_timeout()

    # in case we need to hide canvas (e.g. on error)
    document.getElementById('app').style.backgroundColor = color

exports.real_slide_to_user = (slides, num) ->
    # It used to be just num+1
    out = 1
    for i in [0...num]
        if not (slides[i].play_audio_across_slides or slides[i].force_auto_advance)
            out += 1
    out

exports.real_slide_to_user_with_part = (slides, num) ->
    # It used to be just num+1
    out = 1
    part = 0
    for i in [0...num]
        if not (slides[i].play_audio_across_slides or slides[i].force_auto_advance)
            out += 1
            part = 0
        else
            part += 1
    if (slides[num].play_audio_across_slides or slides[num].force_auto_advance) or part
        out + String.fromCharCode(97+part)
    else
        out

exports.user_slide_to_real = (slides, num) ->
    # It used to be just num-1
    for slide, i in slides
        if not (slides[i].play_audio_across_slides or slides[i].force_auto_advance)
            num -= 1
            if num == 0
                return i
    slides.length - 1

exports.user_slides_count = (slides) ->
    count = 0
    for slide in slides
        if not (slide.play_audio_across_slides or slide.force_auto_advance)
            count += 1
    count

# The "this" object in *_dom methods are the DOM elements, not this class
# (TODO: move them out of the class to make it clear? or inside functions?)

tour_editor = null
init_tour_editor = ->
    tour_editor = exports.tour_editor = new TourEditor()

class TourEditor
    constructor: () ->
        @auto_play_audio = false
        @editing = false
        @win_width = 0
        @win_height = 0
        @tour_name = ''
        @slides = [{}]
        @tour_data = null
        @current_slide = 0
        @current_slide_data = null
        @slide_clipboard = null

        @audio_recorder_enabled = false
        @undo_stack = []
        @redo_stack = []
        @el_slides = null

        @thumb_width_style = null

        # Some actions require saving again after some time
        # such as moving the camera, zooming
        # TODO: to be taken out of the class and use last_action_group instead
        @save_twice_timer = null
        # Some actions are clumped together by type
        @last_action_group

        # constants
        @slide_width = 7 # 7%
        @slide_separation = 0
        @newslide_width = 2
        @stride = @slide_width + @slide_separation
        @newslide_half = (@newslide_width + @slide_separation) * 0.5

        @slide_opacity_start_fade_xpos = 0.28
        @slide_opacity_range_fade_xpos = 0.15


        CKEDITOR?.plugins.add('annotationArrow', {
            'init': (editor) =>
                editor.addCommand( 'insertAnnotationArrow', {
                    'exec': (editor ) =>
                        @add_annotation_arrow(editor.annotationElement)
                })
                editor.ui.addButton( 'AnnotationArrowButton', {
                    'label': 'Add the Arrow to the Annotation',
                    'command': 'insertAnnotationArrow',
                    'icon': 'annotation_line_butt.png'
                })
                editor.addCommand( 'removeAnnotationArrow', {
                    'exec': (editor ) =>
                        @remove_annotation_arrow(editor.annotationElement)
                })
                editor.ui.addButton( 'AnnotationArrowRemovalButton', {
                    'label': 'Remove the Arrow from the Annotation',
                    'command': 'removeAnnotationArrow',
                    'icon': 'annotation_line_kill.png'
                })
        })

        CKEDITOR?.plugins.add('annotationTrash', {
            'init': (editor ) =>
                editor.addCommand( 'insertAnnotationTrash', {
                    'exec': (editor ) =>
                        @remove_annotation(editor.annotationElement)
                })
                editor.ui.addButton( 'AnnotationTrashButton', {
                    'label': 'Delete this Annotation',
                    'command': 'insertAnnotationTrash',
                    'icon': 'trash.png'
                })
        })

        CKEDITOR?.plugins.add('annotationShadow', {
            'init': (editor ) =>
                editor.addCommand( 'toggleAnnotationShadow', {
                    'exec': (editor ) =>
                        @toggle_annotation_shadow(editor.annotationElement, this)
                })
                editor.ui.addButton( 'AnnotationShadowButton', {
                    'label': 'Toggle the Shadow',
                    'command': 'toggleAnnotationShadow',
                    'icon': 'shadow.png'
                })
        })

        # buildPreview() is called every time "size" dropdowm is opened
        CKEDITOR?.style.prototype.buildPreviewOriginal = CKEDITOR.style.prototype.buildPreview
        CKEDITOR?.style.prototype.buildPreview = (label) ->
            result = this.buildPreviewOriginal(label)
            match = /^(.*)font-size:(\d+)vh(.*)$/.exec(result)
            if match
                # apparently ckeditor uses iframe or something that breaks "vh" units
                # we shall use current window height to convert vh to px here
                pixels = Math.round(0.01 * document.body.clientHeight * parseInt (match[2]))
                result = match[1] + 'font-size:' + pixels + 'px' + match[3]
            return result

    is_editing: () ->
        return @editing

    start: (_tour_data, name, slide_num) ->
        if @can_edit_tours()
            for e in $(".only_editor")
                e.classList.remove("hidden")
            if @editing
                @stop()
            if tour_viewer.is_viewing() and not tour_viewer.stop()
                return
            $('#tours')[0].classList.add('hidden')
            tour_data = @tour_data = _tour_data
            tour_data.uuid = tour_data.uuid or uuid.v4()
            # If tour exists but is not loaded,
            # defer loading and call start() again
            if tour_data.hash and not tour_data.slides
                f = (data) =>
                    # Copy data in existing struct which is in the tree
                    for k of data
                        if k != 'hash'
                            tour_data[k] = data[k]
                    tour_data.slides = tour_data.slides or [{}]
                    update_tour_tree_icons()
                    @start(tour_data, name, slide_num)
                error = ->
                    alert("The tour couldn't be retrieved. Check your internet connection and try again.")
                    $('#tours')[0].classList.remove('hidden')
                request_json('GET', FILE_SERVER_DOWNLOAD_API + tour_data.hash, f, error)
                return null

            # TODO: Tentative fix for a bug is disabled because it hasn't be
            # tested enough
            # (bug is, create tour, exit without saving, can't be loaded)
            @old_hash = tour_data.hash # or 'empty'
            @editing = true
            @tour_name = name
            if tour_data.name != name
                tour_data.name = name
                tour_data.hash = ''
                requestAnimationFrame(-> tour_editor.save_state())
            @slides = tour_data.slides = tour_data.slides or [{}]

            slides_changed = migrate_mesh_states(tour_data) > 0

            # TODO: manage versions when version != current
            tour_data.version = TOUR_FORMAT_VERSION

            # change the width of thumbnails on resize, to match aspect
            @thumb_width_style = @thumb_width_style or document.createElement('style')
            window.addEventListener('resize', @_resize_dom, false)
            @_resize_dom()

            @el_slides = $('#slide-editor')[0]
            @el_slides.style.display = 'block'

            set_audio_hash = (num_slide, hash, name) =>
                fmt = name.split('.').slice(-1)[0].toLowerCase()
                @slides[num_slide].audio_hash = hash
                @slides[num_slide].audio_format = fmt
                @slides[num_slide].audio_name = name
                if num_slide == @current_slide
                    @load_audio()
            add_image = (hash, index) =>
                img = new old_modules.TransformableImage()
                img.set_image(hash)
                img.move(index*16, index*16)
                @save_state()
            add_flash = (hash, index) =>
                img = new old_modules.TransformableFlash()
                img.set_flash(hash)
                img.move(index*16, index*16)
                @save_state()


            @audio_player = document.getElementById('vidabody-audio')
            @audio_player.src = ''
            @current_slide = slide_num|0
            @_populate_slides()
            @_go_to_slide slide_num|0, true
            @save_state()
            tour_data.total_quizzes = if tour_data.total_quizzes then tour_data.total_quizzes else 0
            window.addEventListener('keydown', _tour_editor_keydown)
            window.addEventListener('keyup', _tour_editor_keyup)

            reading_panel.setTourName(name)

            # thus migration save is pointless, there is unconditional save just few lines above
            #if slides_changed
            #    @save_state()
            popup_menu()
            main_view.render_all_views()

    save: ->
        if not @editing
            return
        @tour_data.mtime = Date.now()
        for slide in @slides
            slide.uuid = slide.uuid or uuid.v4()
        @old_hash = @tour_data.hash
        save_tour_tree()

    stop_without_saving: ->
        if not @editing
            return
        @stop()
        if @old_hash == 'empty'
            @tour_data.slides = null
            return
        @tour_data.hash = @old_hash or @tour_data.hash or @tour_data.old_hash
        delete @tour_data.slides
        return

    stop: ->
        if @editing
            for e in $(".only_editor")
                e.classList.add("hidden")
            $('#tours')[0].classList.remove('hidden')
            @save_state() # TODO finish transition
            @editing = false
            window.removeEventListener('resize', @_resize_dom, false)
            @el_slides.style.display = 'none'
            $('#tour-name')[0].classList.remove('editing')
            $('#tour-name')[0].style.display = ''
            #$('#lcs')[0].style.display = 'block'
            reading_panel.hide(true)
            @hide_audio_recorder()
            @audio_player.pause()
            @audio_player.ondurationchange = null
            annotations = $('#annotations')[0]
            for e in annotations.children
                if e.editor
                    e.editor.destroy()
                if e.line
                    e.line.remove()
            annotations.innerHTML = ''
            current_annotations.splice(0)
            unquizz_all()
            change_bg_color(DEFAULT_BG_COLOR)
            window.removeEventListener('keydown', _tour_editor_keydown)
            window.removeEventListener('keyup', _tour_editor_keyup)
            slicing_manager.to([])
            go_home(true)
            popup_menu()
            main_view.render_all_views()
            @undo_stack.clear()
            @redo_stack.clear()

    _resize_dom: () ->
        tour_editor.win_width = document.body.clientWidth
        tour_editor.win_height = document.body.clientHeight
        # 100% means 2:1
        w = (tour_editor.win_height/tour_editor.win_width) * 200
        tour_editor.thumb_width_style.textContent = '.slidethumb{width:'+w+'% !important;margin-left:-'+w/2+'%;}'
        document.body.appendChild(tour_editor.thumb_width_style)
        for annotation in $('#annotations')[0].children
            if not annotation.classList.contains('transformable')
                if annotation.line
                    update_annotation_line(annotation)




    _setup_slides_dom: () ->
        num_slides = (@el_slides.children.length/2)|0
        for i in [0... num_slides+1]
            n = @el_slides.children[i*2]
            s = @el_slides.children[i*2+1]
            if s
                s.classList.add('slide')
                s.style.left = @stride*i + '%'
                s.style.top = 0
                s.idx = i
                #s.removeEventListener('click', @_go_to_slide_dom, false)
                #s.addEventListener('click', @_go_to_slide_dom, false)
                mouseenter = ->
                    this.nextSibling.classList.add('slidehover')
                    this.previousSibling.classList.add('slidehover')
                s.onmouseenter = mouseenter

                mouseleave = ->
                    this.nextSibling.classList.remove('slidehover')
                    this.previousSibling.classList.remove('slidehover')
                s.onmouseleave = mouseleave

                e = s.children[1] # span with number of slide
                name = @slides[i].name or ''
                if name
                    name = ' '+name
                e.textContent = exports.real_slide_to_user_with_part(@slides, i)+name

            n.classList.add('newslide')
            n.src = 'old_icons/pinadd.svg'
            n.style.left = @stride*i - @newslide_half + '%'
            n.idx = i
            n.removeEventListener('click', @_new_slide_dom, false)
            n.addEventListener('click', @_new_slide_dom, false)

        @_change_slide_opacities(@el_slides.offsetLeft)

        @_mark_audio_slides()


    _mark_audio_slides: () ->
        speaker_icons = @el_slides.querySelectorAll('.speaker')
        for i in [0... @slides.length]
            speaker_icon = speaker_icons[i]
            if @slides[i].audio_hash and (@slides[i].audio_hash != '')
                speaker_icon.classList.remove('hidden')
            else
                speaker_icon.classList.add('hidden')
            # make sure they have drag handler attached
            speaker_icon.removeEventListener('mousedown', @_start_speaker_drag_dom)
            speaker_icon.addEventListener('mousedown', @_start_speaker_drag_dom)


    _slide_context_menu_functions: (slide_num) ->

        paste_settings = tour_editor.paste_settings or { annotations : 0, camera : 1, meshes : 1, audio : 0 }
        tour_editor.paste_settings = paste_settings

        warn_on_empty_clipboard = ->
            if localStorage.slide_clipboard
                return false
            tour_editor.warning_popup('Nothing was copied to clipboard!')
            return true
        {
        delete_slide : ->
            tour_editor.delete_slide(slide_num)
        copy : ->
            localStorage.slide_clipboard = JSON.stringify(tour_editor.slides[slide_num])
            tour_editor.warning_popup('Slide copied to clipboard!', 1500)
        cut : ->
            localStorage.slide_clipboard = JSON.stringify(tour_editor.slides[slide_num])
            delete_slide()
            tour_editor.warning_popup('Slide cut to clipboard!', 1500)
        paste_before : ->
            if warn_on_empty_clipboard()
                return null
            tour_editor._new_slide(slide_num, false,
                JSON.parse(localStorage.slide_clipboard)
            )
        paste_after : ->
            if warn_on_empty_clipboard()
                return null
            tour_editor._new_slide(slide_num+1, false,
                JSON.parse(localStorage.slide_clipboard)
            )
        duplicate : ->
            tour_editor._new_slide(slide_num+1, false,
                JSON.parse(JSON.stringify(tour_editor.slides[slide_num]))
            )
        go_to : ->
            n = prompt('Slide number?')
            if n
                n = Math.max(0, parseInt(n))
                tour_editor._go_to_slide(exports.user_slide_to_real(tour_editor.slides, n))
        rename: ->
            slide = tour_editor.slides[slide_num]
            name = prompt('New name for this slide?', slide.name or '')
            if name?
                slide.name = name
                tour_editor.save_state()
                tour_editor._setup_slides_dom()
            return

        snapshot_loader : (name, data, silent) ->
            return ->

                localStorage.slide_clipboard = JSON.stringify(data.slides[0])
                if not silent
                    tour_editor.warning_popup('Snapshot ' + name + ' copied to clipboard!', 2000)
        paste_settings : paste_settings
        paste_selected : ->
            if warn_on_empty_clipboard()
                return null

            if not (paste_settings.audio or paste_settings.annotations or paste_settings.camera or paste_settings.meshes)
                tour_editor.warning_popup('Nothing was selected to paste.')
                return null

            if paste_settings.audio
                old_slide = tour_editor.slides[slide_num]
                new_slide = JSON.parse(localStorage.slide_clipboard)
                old_slide.audio_hash = new_slide.audio_hash
                old_slide.audio_format = new_slide.audio_format
                old_slide.audio_name = new_slide.audio_name
                if tour_editor.current_slide == slide_num
                    tour_editor.load_audio()

            if paste_settings.annotations
                clipboard = JSON.parse(localStorage.slide_clipboard)
                annotations = clipboard.annotations
                new_annotations = clipboard.new_annotations
                slide = tour_editor.slides[slide_num]
                if confirm('Remove current annotations before paste?')
                    slide.annotations = []
                    slide.new_annotations = []
                slide.annotations = slide.annotations.concat(annotations)
                slide.new_annotations = slide.new_annotations.concat(new_annotations)
                if tour_editor.current_slide == slide_num
                    tour_editor._go_to_slide(slide_num)
                tour_editor._make_thumbnail(slide_num)

            if paste_settings.camera
                state = JSON.parse(localStorage.slide_clipboard).state
                slide = tour_editor.slides[slide_num]
                slide.state = state
                if tour_editor.current_slide == slide_num
                    tour_editor._go_to_slide(slide_num)
                tour_editor._make_thumbnail(slide_num)

            if paste_settings.meshes
                slide_clipboard = JSON.parse(localStorage.slide_clipboard)
                visibility = slide_clipboard.visibility
                slide = tour_editor.slides[slide_num]
                if slide_clipboard.slices
                    slide.slices = JSON.parse(JSON.stringify(slide_clipboard.slices, (k, v) -> v.nodeType or v))
                slide.visibility = visibility
                if tour_editor.current_slide == slide_num
                    tour_editor._go_to_slide(slide_num)
                tour_editor._make_thumbnail(slide_num)
        }


    _slide_context_menu: (event, slide_num) ->
        fs = @_slide_context_menu_functions(slide_num)

        submenu = []
        for snapshot in snapshots
            submenu.push({
                'text': snapshot.name, 'func': fs.snapshot_loader(snapshot.name, snapshot.data)
            })

        menu = [
            { 'text':'Go to...', 'func': fs.go_to },
            { 'text':'Rename', 'func': fs.rename },
            { 'text':'Cut', 'func': fs.cut },
            { 'text':'Copy', 'func': fs.copy },
            ]
        if submenu.length
            menu.append({ 'text':'Copy snapshot', 'submenu': submenu })

        menu = menu.concat([
            { 'text':'Paste before', 'func': fs.paste_before },
            { 'text':'Paste after', 'func': fs.paste_after },
            {
                type: 'switch',
                text: 'Paste audio',
                states: 2,
                state: fs.paste_settings.audio,
                read: -> fs.paste_settings.audio
                write: (state) -> fs.paste_settings.audio = state
            },
            {
                type: 'switch',
                text: 'Paste annotations',
                states: 2,
                state: fs.paste_settings.annotations,
                read: -> fs.paste_settings.annotations
                write: (state) -> fs.paste_settings.annotations = state
            },
            {
                type: 'switch',
                text: 'Paste camera',
                states: 2,
                state: fs.paste_settings.camera,
                read: -> fs.paste_settings.camera
                write: (state) -> fs.paste_settings.camera = state
            },
            {
                type: 'switch',
                text: 'Paste meshes',
                states: 2,
                state: fs.paste_settings.meshes,
                read: -> fs.paste_settings.meshes
                write: (state) -> fs.paste_settings.meshes = state
            },
            {
                text: 'Paste selected here'
                func: fs.paste_selected
            },
            { 'text':'Duplicate', 'func': fs.duplicate },
            { 'text':'Delete', 'func': fs.delete_slide },
        ])

        popup_menu(event.pageX, event.pageY, menu)


    paste_snapshot: (snapshot) ->
        fs = @_slide_context_menu_functions(@current_slide)

        fs.snapshot_loader(snapshot.name, snapshot.data, true)()
        fs.paste_annotations()
        fs.paste_meshes()


    _slide_mousedown_dom: (event) ->
        init_x = event.pageX
        if event.button==2
            tour_editor._slide_context_menu(event, @idx)
            return null

        @addEventListener('mouseup', tour_editor._go_to_slide_dom, true)  # useCapture true because of a bug in chrome
        tour_editor._start_slide_drag_dom.call(this, event)

    warning_popup: (msg, time) ->
        warning = $('#warning-popup')[0]
        warning.innerHTML = msg
        warning.style.display = 'block'
        hide_warning = ->
            warning.style.display = 'none'
        clearTimeout(@hide_warning_timeout)
        if not time
            time = msg.length * 70
        @hide_warning_timeout = setTimeout(hide_warning, time)


    _start_speaker_drag_dom: (event) ->
        element = this
        # element/this is the speaker

        element_idx = @parentNode.idx
        event.stopPropagation()

        lastPageX = event.pageX
        lastPageY = event.pageY

        rect = @getBoundingClientRect()
        x = rect.left
        y = rect.top

        origX = x
        origY = y
        editor = @parentNode.parentNode
        orig_editorX = editor.offsetLeft
        pos_to_num = 100/(tour_editor.slide_width * tour_editor.win_width)
        scroll_timer = true
        min_scroll = tour_editor.win_width * 0.5 - 1 / pos_to_num
        max_scroll = tour_editor.win_width * 0.5 - tour_editor.slides.length / pos_to_num

        dummy_image = null

        scroll = ->
            if scroll_timer
                requestAnimationFrame(scroll)
            else
                return null

            pcentX = lastPageX / tour_editor.win_width * 100
            # TODO % instead of px
            speed = 0.34*main_loop.frame_duration

            eX = editor.offsetLeft

            if pcentX-50 > (tour_editor.stride*5.5)
                eX = max(max_scroll, editor.offsetLeft - speed)
                editor.style.left = eX + 'px'
                tour_editor._change_slide_opacities(eX)
            else if pcentX-50 < (tour_editor.stride*-5.5)
                eX = min(min_scroll, editor.offsetLeft + speed)
                editor.style.left = eX + 'px'
                tour_editor._change_slide_opacities(eX)

        moved = 0
        move = (event) ->

            event.stopPropagation()
            dx = event.pageX - lastPageX
            dy = event.pageY - lastPageY
            moved += abs(dx) + abs(dy)
            if(moved > 4) and not element.classList.contains('hidden')
                element.classList.add('hidden')
                editor.classList.add('no-transition')
                requestAnimationFrame(scroll)

                # disable rendering
                scene.enabled = false

            if not dummy_image
                dummy_image = document.createElement('img')
                dummy_image.id = 'dummy_image'
                dummy_image.width = 32
                dummy_image.height = 32
                dummy_image.src = vidabody_app_path + 'speaker.png'
                dummy_image.classList.add('speaker-dragged')
                $('#app')[0].appendChild(dummy_image)

            x += dx
            y += dy
            lastPageX = event.pageX
            lastPageY = event.pageY

            dummy_image.style.left = x + 'px'
            dummy_image.style.top = y + 'px'

        mouseup = (event) ->
            scene.enabled = true
            element.classList.remove('hidden')
            editor.classList.remove('no-transition')

            window.removeEventListener('mousemove', move, true)
            window.removeEventListener('mouseup', mouseup, false)

            scroll_timer = false

            event.stopPropagation()

            new_element = if event.target.classList.contains('slide') then event.target else event.target.parentNode
            if new_element.classList?.contains('slide')

                new_idx = new_element.idx

                if dummy_image and (new_idx != element_idx)
                    old_slide = tour_editor.slides[element_idx]
                    new_slide = tour_editor.slides[new_idx]

                    # is this correct ??? user would have to undo twice :(
                    tour_editor._push_undo(old_slide)
                    tour_editor._push_undo(new_slide)

                    old_audio_hash   = old_slide.audio_hash
                    old_audio_format = old_slide.audio_format
                    old_audio_name   = old_slide.audio_name

                    old_slide.audio_hash   = new_slide.audio_hash
                    old_slide.audio_format = new_slide.audio_format
                    old_slide.audio_name   = new_slide.audio_name

                    new_slide.audio_hash   = old_audio_hash
                    new_slide.audio_format = old_audio_format
                    new_slide.audio_name   = old_audio_name

                    if (tour_editor.current_slide == element_idx) or (tour_editor.current_slide == new_idx)
                        tour_editor.load_audio()

                    $('#app')[0].removeChild(dummy_image)
                    dummy_image = null

            tour_editor._mark_audio_slides()


        @parentNode.nextSibling.classList.remove('slidehover')
        @parentNode.previousSibling.classList.remove('slidehover')

        window.addEventListener('mousemove', move, true)
        window.addEventListener('mouseup', mouseup, false)


    _start_slide_drag_dom: (event) ->
        element = this
        # element/this is the slide
        lastPageX = event.pageX
        lastPageY = event.pageY
        x = @offsetLeft
        y = @offsetTop
        origX = x
        origY = y
        editor = @parentNode
        orig_editorX = editor.offsetLeft
        pos_to_num = 100/(tour_editor.slide_width * tour_editor.win_width)
        scroll_timer = true
        min_scroll = tour_editor.win_width * 0.5 - 1 / pos_to_num
        max_scroll = tour_editor.win_width * 0.5 - tour_editor.slides.length / pos_to_num

        scroll = ->
            if scroll_timer
                requestAnimationFrame(scroll)
            else
                return null

            pcentX = lastPageX / tour_editor.win_width * 100
            # TODO % instead of px
            speed = 0.34*main_loop.frame_duration

            eX = editor.offsetLeft

            if pcentX-50 > (tour_editor.stride*5.5)
                x += eX
                eX = max(max_scroll, editor.offsetLeft - speed)
                editor.style.left = eX + 'px'
                x -= eX
                element.style.left = x+'px'
                tour_editor._change_slide_opacities(eX)
            else if pcentX-50 < (tour_editor.stride*-5.5)
                x += eX
                eX = min(min_scroll, editor.offsetLeft + speed)
                editor.style.left = eX + 'px'
                x -= eX
                element.style.left = x+'px'
                tour_editor._change_slide_opacities(eX)

        moved = 0
        move = (event) ->

            event.stopPropagation()
            dx = event.pageX - lastPageX
            dy = event.pageY - lastPageY
            moved += abs(dx) + abs(dy)
            if(moved > 4) and not element.classList.contains('dragging')
                element.classList.add('dragging')
                editor.classList.add('no-transition')
                $('#reading-panel')[0].classList.add('dragging-slide')
                element.removeEventListener('mouseup', tour_editor._go_to_slide_dom, true)
                requestAnimationFrame(scroll)

                # disable rendering
                scene.enabled = false

                tour_editor.warning_popup('Warning: the text in reading panel will not be reordered.', 4000)

            x += dx
            y += dy
            lastPageX = event.pageX
            lastPageY = event.pageY
            element.style.left = x+'px'
            element.style.top = y+'px'
            #element.children[1].innerHTML = 1 + this.idx + (x-origX) * pos_to_num

        mouseup = (event) ->
            scene.enabled = true
            element.classList.remove('dragging')
            editor.classList.remove('no-transition')
            $('#reading-panel')[0].classList.remove('dragging-slide')
            window.removeEventListener('mousemove', move, true)
            window.removeEventListener('mouseup', mouseup, false)

            scroll_timer = false

            new_idx = 1 + element.idx + Math.floor((x-origX) * pos_to_num)
            new_idx = max(0, min(tour_editor.slides.length, new_idx))

            if new_idx != element.idx
                if new_idx == element.idx + 1
                    # not actual move, we're just going to another slide
                    tour_editor.save_state()
                else
                    # actual move
                    tour_editor._push_undo({ action: 'move', idx: element.idx, new_idx: new_idx })
                tour_editor._move_slide(element.idx, new_idx)
            else
                # This happens when you drop the slide in the same position as it was before
                frame = ->
                    element.style.left = origX+'px'
                    element.style.top = 0
                    editor.offsetLeft = orig_editorX
                requestAnimationFrame(frame)

        @nextSibling.classList.remove('slidehover')
        @previousSibling.classList.remove('slidehover')
        @removeEventListener('mousemove', tour_editor._start_slide_drag_dom, false)
        window.addEventListener('mousemove', move, true)
        window.addEventListener('mouseup', mouseup, false)


    _move_slide: (idx, new_idx) ->
        editor = document.getElementById('slide-editor')
        element = null
        for element in editor.querySelectorAll('.slide')
            if element.idx == idx
                break

        new_slide = element.previousSibling
        next = if editor.children[new_idx*2] then editor.children[new_idx*2] else editor.children.lastChild

        editor.insertBefore(new_slide, next)
        editor.insertBefore(element, next)
        if new_idx > element.idx
            new_idx -= 1

        d = tour_editor.slides[tour_editor.current_slide]
        tour_editor.slides.insert(new_idx, tour_editor.slides.splice(element.idx,1)[0])
        tour_editor.current_slide = tour_editor.slides.indexOf(d)

        for i in [0... tour_editor.slides.length]
            tour_editor.slides[i].index = i

        tour_editor._set_element_classes()
        requestAnimationFrame(tour_editor._setup_slides_dom.bind(tour_editor))


    _new_slide_dom: () ->
        tour_editor._new_slide(@idx)

    _new_slide: (idx, go=true, content={}, undoing) ->
        mousedown = (e) ->
            e.preventDefault()

        # slide itself
        proto = document.getElementById('slide-prototype')
        e = proto.cloneNode()
        e.removeAttribute('id')
        e.innerHTML = proto.innerHTML
        remove_react_ids(e)
        e.onmousedown = @_slide_mousedown_dom
        @el_slides.insertBefore(e, @el_slides.children[idx*2])
        # new slide widget
        e = document.createElement('img')
        e.onmousedown = mousedown

        @el_slides.insertBefore(e, @el_slides.children[idx*2])

        @slides.insert(idx, content)
        @_setup_slides_dom()

        if not undoing
            content.action = 'new'
            content.index = idx
            content.go = go
            content.go_from = @current_slide

        if go
            # pass true here to prevent it from saving useless 'slide' action on
            # undo_stack because the slide will be saved with 'new' action below
            @_go_to_slide(idx, true)
            # going to another slide will take up to 300ms
            setTimeout((=> @_make_thumbnail(idx)), 300)
        else
            @_make_thumbnail(idx)

        unquizz_all()
        if not undoing
            @save_state()
        else
            @_update_current_slide()

        # TODO: ask for a slide name and save it
        #prompt("Name of slide")

    _populate_slides: (num_slides) ->
        mousedown = (e) ->
            e.preventDefault()

        reading_panel.reset(@_go_to_slide.bind(this), @_text_edited_dom.bind(this))

        @el_slides.innerHTML = ''
        e = document.createElement('img')
        @el_slides.appendChild(e)
        x = 0

        if @tour_data.reading_texts
            for i in [0... @tour_data.reading_texts.length]
                reading_panel.addSlideText( @tour_data.reading_texts[i] )

        for i in [0... @slides.length]
            s = @slides[i]
            # slide itself
            proto = document.getElementById('slide-prototype')
            e = proto.cloneNode()
            e.removeAttribute('id')
            e.innerHTML = proto.innerHTML
            remove_react_ids(e)
            e.onmousedown = @_slide_mousedown_dom
            @el_slides.appendChild(e)
            # new slide widget
            e = document.createElement('img')
            e.onmousedown = mousedown

            @el_slides.appendChild(e)

            @_make_thumbnail(i)

        @_setup_slides_dom()

        reading_panel.flush()
        reading_panel.show()

    _set_element_classes: () ->
        chidx = @current_slide*2+1
        newright = chidx + 1
        newleft = chidx - 1
        for i in [0... @el_slides.children.length]
            e = @el_slides.children[i]
            c = e.classList
            c.remove('selected')
            c.remove('newright')
            c.remove('newleft')
            c.remove('slidehover')
            if chidx == i
                c.add('selected')
            else if newright == i
                c.add('newright')
            else if newleft == i
                c.add('newleft')

    _push_undo: (action) ->
        #s = (new Error()).stack
        #s = s.substr(s.indexOf('\n') + 1)
        #console.log('saving action ' + action.action + ', slide ' + action.index + ', for undo:', action, '\n' + s)

        action.action = action.action or 'slide'
        @undo_stack.push(JSON.stringify(action))
        @redo_stack.clear()
        main_view.render_all_views()

    _go_to_slide_dom: (event) ->
        tour_editor._go_to_slide(@idx)
        @removeEventListener('mousemove', tour_editor._start_slide_drag_dom, false)

    _go_to_slide: (idx, undoing) ->
        @slides[@current_slide].index = @current_slide
        if not undoing and idx != @current_slide
            @_push_undo(@slides[@current_slide])

        @current_slide = max(0, min(@slides.length - 1, idx))
        @current_slide_data = @slides[@current_slide]

        editor_offset_left = -idx*@stride - @slide_width/2 + 50

        @el_slides.style.left = editor_offset_left + '%'
        # NOTE Delaying this for TWO frames because _setup_slides_dom is executed
        # one frame after dragging a slide(could be done more elegantly)
        requestAnimationFrame(requestAnimationFrame.bind(null,
            @_change_slide_opacities.bind(this, editor_offset_left * 0.01 * @win_width)))
        @_set_element_classes()
        #document.getElementById('wavedisplay').getContext('2d').clearRect(0,0,1024,500)
        @hide_audio_recorder()
        @audio_player.pause()
        @_load_state(300)
        main_loop.reset_timeout()
        comments.grab_thread(@slides[@current_slide].uuid)
        reading_panel.updateSlideIndex(idx)
        main_view.render_all_views()

    _change_slide_opacities: (editor_offset_left) ->
        # we use editor_offset_left instead of @el_slides.offsetLeft because
        # it may be changing due to CSS3 transition
        slides = @el_slides.children
        # x relative to center in widths
        first_slide_x = (editor_offset_left - (@win_width * 0.5)) / @win_width

        if first_slide_x != first_slide_x
            console.log 'ERROR', editor_offset_left, @win_width

        for i in [1... slides.length] by 2
            s = slides[i]
            # distance to center in widths, [0, 0.5] range
            dist_to_center = Math.abs(i*@stride*0.005 + first_slide_x)
            s.style.opacity = 1 - (dist_to_center-@slide_opacity_start_fade_xpos)/@slide_opacity_range_fade_xpos
            #s.innerHTML = o.toFixed(2)


    toggle_audio_recorder: (e) ->
        if @audio_recorder_enabled
            document.getElementById('audio-recorder').style.display = 'none'
            @audio_recorder_enabled = false
            #e.classList.remove('pressed')
        else
            if audioRecorder
                document.getElementById('audio-recorder').style.display = 'block'
                @audio_recorder_enabled = true
                #e.classList.add('pressed')
            else
                handler = ->
                    document.getElementById('audio-recorder').style.display = 'block'
                    @audio_recorder_enabled = true
                    #e.classList.add('pressed')
                initAudio(handler)


    hide_audio_recorder: () ->
        return null # TODO enable
        document.getElementById('audio-recorder').style.display = 'none'
        @audio_recorder_enabled = false


    save_audio: () ->
        slide = @slides[@current_slide]
        document.getElementById('save-audio').style.visibility = 'hidden'

        s = this

        handler = (blob) ->
            filename = s.tour_name+'_'+s.current_slide+'_'+((Math.random()*1000000)|0)+'.wav'
            #slide.audio_file = filename
            # TODO: use new backend

        saveAudio(handler)


    upload_audio_file: (e) ->
        pass
        # TODO: use new backend


    delete_audio: (element) ->
        if not confirm('Delete audio of this slide?')
            return
        @slides[@current_slide].audio_file = ''
        @slides[@current_slide].audio_hash = ''
        @slides[@current_slide].audio_name = ''
        @audio_player.pause()
        #document.getElementById('wavedisplay').getContext('2d').clearRect(0,0,1024,500)
        if element
            element.classList.remove('has-audio')

        @save_state()



    previous: () ->
        if @current_slide != 0
            @_go_to_slide(@current_slide-1)


    next: () ->
        if @current_slide != @slides.length-1
            @_go_to_slide(@current_slide+1)


    delete_slide: (slide_num, undoing) ->
        d = slide_num
        if not undoing
            d = if slide_num then slide_num else @current_slide
            if d == @current_slide
                if @current_slide != @slides.length-1
                    @_go_to_slide(@current_slide+1)
                    @current_slide -= 1
                else if @current_slide != 0
                    @_go_to_slide(@current_slide-1)
                else
                    return null # don't delete the last slide

            goner = @slides[d]
            goner.action = 'delete'
            goner.go = true
            goner.go_from = @current_slide
            @_push_undo(goner)
        else
            @_go_to_slide(@slides[d].go_from, true)

        @slides.splice(d,1)
        @_populate_slides()
        @_set_element_classes()


    _add_annotation: () ->
        n = document.getElementById('base-float-edit').cloneNode()
        n.removeAttribute('id')
        n.innerHTML = document.getElementById('base-float-edit').innerHTML # clone children
        remove_react_ids(n)
        document.getElementById('annotations').appendChild(n)
        n.style.display = 'block'

        editable = n.querySelector('[contentEditable]')
        n.editor = null
        n.delay = 0

        n.add_editor = =>
            set_styles = ->
                # styles hack to make 'size' dropdown smaller
                $('.' + n.editor.id + '.cke_chrome .cke_combo_button')[0].style.width = '50px'
                $('.' + n.editor.id + '.cke_chrome .cke_combo_open')[0].style.marginLeft = '0px'

                # btw set command states
                n.editor.getCommand('toggleAnnotationShadow').setState(if n.classList.contains('annotation_shadow') then CKEDITOR.TRISTATE_ON else CKEDITOR.TRISTATE_OFF)

            n.editor = CKEDITOR.inline(editable, {
                'title': false,
                'contentsLangDirection': 'ltr',
                'startupFocus': true,
                'extraPlugins': 'annotationArrow,annotationTrash,annotationShadow',
                'on': {
                    'paste': (
                        (e) ->
                            if e.data.type == 'html'
                                e.data.dataValue = e.data.dataValue.replace(/style\s?=\s?((".*?")|('.*?'))/gi, '')
                    ),
                    'pluginsLoaded': ((e) -> e.editor.dataProcessor.dataFilter.addRules({ 'comment': () -> false })),
                    'instanceReady': set_styles
                },
                'removePlugins': 'magicline',
                'fontSize_sizes': '1/1vh;2/2vh;3/3vh;4/4vh;5/5vh;6/6vh;7/7vh;8/8vh;',
                'toolbar': [
                    { 'name': 'stuff', 'items': ['Bold', 'Italic', 'Underline', 'TextColor', 'BGColor', 'Link', '-', 'Format', 'FontSize', '-', 'NumberedList', 'BulletedList', '-', 'JustifyLeft', 'JustifyCenter', 'JustifyRight'] },
                    { 'name': 'extra', 'items': ['AnnotationShadowButton', '-', 'AnnotationArrowButton', 'AnnotationArrowRemovalButton', '-', 'AnnotationTrashButton'] }
                ]
            })

            # make it bi-directional
            n.editor.annotationElement = n

            n.editor.on('change', (e) => @save_state(0, e.editor.id))

            close_editor = ->
                if n.editor
                    n.editor.destroy()
                    n.editor = null
                n.children[0].classList.remove('cke_focus')
                n.children[0].blur()
                # AHAHA! this div still will have behaviour of focused element
                # so on key down it will add new characters
                # I found this weird trick to avoid it:
                window.getSelection().removeAllRanges()
                # I found it here: http://stackoverflow.com/a/26890080/512042


            on_click_outside(n.children[0], close_editor, (e) -> (e.className.indexOf('popup_menu_modal') > -1) or (e.className.indexOf('cke_chrome') > -1))

        eresize = n.querySelector('.resize')

        n.lastMouseDown = Date.now()
        moveMousedown = (event) =>
            lastMouseDown = n.lastMouseDown
            n.lastMouseDown = Date.now()

            if n.editor
                # to let them select text, etc
                # also to not add editor twice ;)
                return

            if Date.now() - lastMouseDown < DOUBLE_CLICK_MS
                # "double click"
                n.add_editor()

                return

            x = n.offsetLeft
            y = n.offsetTop
            moved = 0
            event.preventDefault()
            n.classList.add('moving')

            move = (event, dx, dy) ->
                scene.enabled = false
                x += dx
                y += dy
                moved += abs(dx) + abs(dy)
                n.style.left = x+'px'
                n.style.top = y+'px'
                update_annotation_line(n)
            up = (event) =>
                scene.enabled = true
                n.classList.remove('moving')

                # if dragged, the annotation position would be in pixels - convert back to percents here
                if moved > 0
                    n.style.left = 100 * (n.offsetLeft / n.parentNode.offsetWidth) + '%'
                    n.style.top = 100 * (n.offsetTop / n.parentNode.offsetHeight) + '%'

                @save_state()

                if not n.editor and moved < 2
                    popup_menu event.pageX, event.pageY, [
                        {
                            text: 'Edit'
                            func: -> n.add_editor()
                        }
                        {
                            text: 'Set/change lead'
                            func: => @add_annotation_arrow(n)
                        }
                        {
                            text: 'Remove lead'
                            func: => @remove_annotation_arrow(n)
                        }
                        {
                            text: 'Delete annotation'
                            func: => @remove_annotation(n)
                        }
                        {
                            type: 'slider'
                            id: 'delay'
                            text: 'Delay time'
                            title: 'Delay time from beginning of slide until it appears'
                            min: 0
                            max: 15
                            soft_min: 0
                            soft_max: 600
                            unit:'s'
                            read: -> n.delay
                            write: (v) =>
                                n.delay = v
                                @slides[@current_slide].zero_delay_anns = true
                                @save_state()
                                if @audio_player.src and @auto_play_audio
                                    @preview_audio_delay(n.delay)
                            onmove: false
                            onup: true
                        }
                        {
                            type: 'button'
                            text: 'Preview audio from delay'
                            func: => @preview_audio_delay(n.delay)
                        } if @audio_player.src
                    ]
            modal_mouse_drag(event, move, up)

        n.children[0].onmousedown = moveMousedown

        resizeMousedown = (event) =>
            event.preventDefault()
            move = (event, dx, dy) ->
                scene.enabled = false
                n.style.width = n.offsetWidth + dx + 'px'
                update_annotation_line(n)
            up = =>
                scene.enabled = true
                @save_state()
            modal_mouse_drag(event, move, up)
        eresize.onmousedown = resizeMousedown

        return n

    preview_audio_delay: (pos, from_current_slide=false) ->
        idx = @current_slide
        while from_current_slide and (prev_slide = @slides[idx-1])?.play_audio_across_slides
            idx -= 1
            pos += prev_slide.auto_next * 0.001
        @audio_player.currentTime = pos
        @audio_player.play()

    remove_annotation: (annotation) ->
        document.getElementById('annotations').removeChild(annotation)
        if annotation.editor
            annotation.editor.destroy()
        if annotation.line
            annotation.line.remove()
        @save_state(0)


    toggle_annotation_shadow: (annotation, command) ->
        if command.state == CKEDITOR.TRISTATE_ON
            command.setState(CKEDITOR.TRISTATE_OFF)
            annotation.classList.remove('annotation_shadow')
        else
            command.setState(CKEDITOR.TRISTATE_ON)
            annotation.classList.add('annotation_shadow')
        @save_state(0)


    add_annotation_arrow: (annotation) ->

        before = ->
            if annotation.object
                delete annotation.object
                delete annotation.point

            if annotation.line
                annotation.line.remove()

            annotation.line = new Line('#ffffff', 1.5)

        during = (event) =>
            annotation.line.x2 = 100 * (event.pageX / @win_width) + '%'
            annotation.line.y2 = 100 * (event.pageY / @win_height) + '%'
            update_annotation_line(annotation)

        after = (event) =>

            pick = pick_object(event.pageX, event.pageY)
            if pick
                annotation.object = pick.object
                annotation.point = vec4.create()
                vec3.copy(annotation.point, pick.point)
                annotation.point[3] = 1
                @save_state(0)
            else
                annotation.line.remove()
                annotation.line = null
                @warning_popup('You need to click on a structure to anchor the line.')

        click_to_add_anchor before, during, after


    remove_annotation_arrow: (annotation) ->
        if annotation.line
            annotation.line.remove()
            annotation.line = null
        annotation.object = null
        tour_editor.save_state(0)


    add_annotation: (e) ->
        @adding_annotation = true
        main_view.render_all_views()
        style = document.createElement('style')
        document.body.appendChild(style)

        move = (event) ->
                if event.target.id == 'canvas'
                    style.innerHTML = 'body{cursor:crosshair !important}'
                else
                    style.innerHTML = 'body{cursor:not-allowed !important}'

        up = (event) =>
                @adding_annotation = false
                main_view.render_all_views()
                document.body.removeChild(style)
                if (event.target.id == 'canvas') or (event.target.parentElement.id == 'annotations')
                    n = @_add_annotation()
                    n.style.width = '70%' # relative to half width (35%)
                    n.style.left = event.pageX - document.body.clientWidth*0.5 - n.clientWidth*0.5 + 'px'
                    n.style.top = event.pageY - document.body.clientHeight*0.5 - n.clientHeight*0.25 + 'px'
                    n.children[0].innerHTML = ''
                    n.add_editor()
                    document.body.style.cursor = 'auto'

        modal_mouse_click(null, move, up)


    undo: () ->
        @_undo_or_redo(@undo_stack, @redo_stack)


    redo: () ->
        @_undo_or_redo(@redo_stack, @undo_stack)

    can_undo: ->
        @undo_stack.length != 0

    can_redo: ->
        @redo_stack.length != 0

    _undo_or_redo: (pop_stack, push_stack) ->
        if pop_stack.length
            data = JSON.parse(pop_stack.pop())
            action = data.action

            #debug_str = if pop_stack == @undo_stack then 'undoing' else 'redoing'
            #console.log(debug_str + ' action: ' + action + ', data:', data)

            if action == 'slide'
                push_stack.push(JSON.stringify(@slides[@current_slide]))
                @slides[data.index] = data
                @_go_to_slide(data.index, true)
                # going to another slide will take up to 300ms
                setTimeout((=> @_make_thumbnail(data.index)), 300)
            else if action == 'new'
                data.action = 'delete'
                push_stack.push(JSON.stringify(data))
                @delete_slide(data.index, true)
            else if action == 'delete'
                data.action = 'new'
                push_stack.push(JSON.stringify(data))
                @_new_slide(data.index, data.go, data, true)
            else if action == 'move'
                idx = data.idx
                new_idx = data.new_idx
                # http://jsfiddle.net/hr1afr7z/
                if idx < new_idx
                    data.idx = new_idx - 1
                    data.new_idx = idx
                else
                    data.idx = new_idx
                    data.new_idx = idx + 1
                push_stack.push(JSON.stringify(data))
                @_move_slide(data.idx, data.new_idx)
            else
                throw 'Unknown action ' + action

    # saves specified slide information into given object
    update_slide: (slide, options) ->
        slide.action = 'slide'

        if options.state
            state = snap_helper.get_state()
            if slide.turntable_turns != 0 and slide.rotate_around_center
                ob = vb.camera_control.last_ray.object
                if ob
                    point = vec3.clone(ob.position)
                    # get middle of mirrow objects
                    if /_L$|_R$/.test(ob.name)
                        ob1 = objects[ob.name[...-1]+'L']
                        ob2 = objects[ob.name[...-1]+'R']
                        if ob1?.visible and ob2?.visible
                            point[0] = 0

                    # find how far camera target from new object's position
                    diff = vec3.distance(point, state[1])

                    # set camera position to object's position
                    state[1] = point

                    # apply distance diff
                    state[0] += diff

                    # move camera to new position
                    # (make it visual for tour maker)
                    snap_helper.set_state(state, 100)
            slide.state = state

        else
            slide.state = null

        slide.visibility = if options.visibility then get_meshes_state() else null

        # TODO in order to make these optional they need to be nested under {...}
        slide.labels_visible = labels_visible
        slide.label_callouts = label_callouts
        slide.label_callouts_splines = label_callouts_splines
        slide.tmp_enabled_animations = heart.enabled_animation
        slide.tmp_heart_beat_speed = heart.heart_beat_speed
        slide.bg_color = bg_color
        slide.trans_time = if slide.trans_time then slide.trans_time else DEFAULT_TRANS_TIME
        slide.atrans_time = if slide.atrans_time then slide.atrans_time else DEFAULT_TRANS_TIME
        slide.reading_panel_opened = reading_panel.isOpened()

        slide.nerves = if options.nerves then get_nerves() else null
        slide.slices = if options.slices then JSON.parse(JSON.stringify(slicing_manager.slices, (k, v) -> v.nodeType or v)) else null

        slide.annotations = []
        slide.new_annotations = []
        # annotations are not defined outside tour editor
        if @editing and options.annotations
            annotations = $('#annotations')[0].children
            ratio = 100/@win_height

            for anode in annotations
                if not anode.classList.contains('transformable')
                    a = {}
                    a.x = anode.offsetLeft * ratio
                    a.y = anode.offsetTop * ratio
                    a.w = anode.clientWidth * ratio
                    a.h = anode.clientHeight * ratio

                    a.text = if anode.editor then anode.editor.getData() else anode.children[0].innerHTML
                    a.delay = anode.delay
                    if anode.object
                        # 3D anchor
                        a.anchor = { 'name': anode.object.name, 'x': anode.point[0], 'y': anode.point[1], 'z': anode.point[2] }

                    a.shadow = anode.classList.contains('annotation_shadow')

                    slide.annotations.append(a)

            slide.new_annotations = get_annotation_data()

        slide.quizzes = if slide.quizzes then slide.quizzes else []

        if options.media
            # options.media not used by save_state(handled separately in set_audio_hash)
            # so this is only here to grab media information to the snapshot
            current_slide = null

            if @editing
                current_slide = @slides[@current_slide]
            else if tour_viewer.is_viewing()
                current_slide = tour_viewer.slides[tour_viewer.current_slide]

            if current_slide
                slide.audio_hash   = current_slide.audio_hash
                slide.audio_format = current_slide.audio_format
                slide.audio_name   = current_slide.audio_name


    save_state: (save_twice_time, action_group) ->
        if not @editing
            if not tour_viewer.viewing
                explore_mode_undo.save_state(save_twice_time)
            return
        if camera_control.mode == AUTOPILOT
            # TODO: allow saving state of non-camera things
            #console.log('lost save_state call :(', (new Error()).stack)
            return null
        clearTimeout(@save_twice_timer)
        # Some actions require saving later after some idle time
        # such as moving the camera, zooming, and editing text annotations
        # TODO: take this out of here and use action_group for this purpose
        if save_twice_time
            @save_twice_timer = setTimeout((=> @save_state()), save_twice_time)
            return

        if action_group and action_group == @last_action_group
            @undo_stack.pop()
        @last_action_group = action_group

        slide = @slides[@current_slide]

        if slide.index != @current_slide
            console.error ('slide index is not @current_slide') # TODO remove if never happens

        @_push_undo(slide)

        @_update_current_slide()

    _update_current_slide: ->

        slide = @slides[@current_slide]

        tour_data = @tour_data

        tour_data.hash = ''

        @update_slide(slide, {
            'state' : true, 'visibility' : true, 'nerves' : true, 'slices' : true, 'annotations' : true
        })

        tour_data.total_quizzes = tour_data.total_quizzes - slide.quizzes.length
        slide.quizzes.clear()
        for i in [0... quizzed_labels.length]
            q = quizzed_labels[i]
            slide.quizzes.append(JSON.stringify(q.quiz))
            tour_data.total_quizzes += 1

        slide.slider_animations = {}
        for anim_name of slider_animations
            anim = slider_animations[anim_name]
            slide.slider_animations[anim_name] = anim.pos

        f = =>
            @_make_thumbnail(@current_slide)
        requestAnimationFrame(f)

    _load_state: (max_time=Infinity) ->
        slide = @slides[@current_slide]
        clearTimeout(@save_twice_timer)

        annotations = $('#annotations')[0]
        for e in annotations.children
            if e.editor
                e.editor.destroy()
            if e.line
                e.line.remove()
        annotations.innerHTML = ''

        unquizz_all()

        if slide
            actual_trans_time = min(max_time, (if slide.trans_time then slide.trans_time else DEFAULT_TRANS_TIME)*1000)
            if slide.state
                snap_helper.set_state(slide.state, actual_trans_time)

            # it is important to do this before set_meshes_state because (unlike
            # tour viewer) there is no fade-in effect here and it is called only once
            slicing_manager.to(slide.slices or [], actual_trans_time)

            if slide.visibility
                set_meshes_state(slide.visibility, false)
                update_visiblity_tree()

            set_label_callouts_splines(slide.label_callouts_splines)
            set_label_callouts(slide.label_callouts)
            set_labels_visible(slide.labels_visible)
            heart.enabled_animation = slide.tmp_enabled_animations or false
            heart.heart_beat_speed = slide.tmp_heart_beat_speed or 1
            change_bg_color(slide.bg_color or DEFAULT_BG_COLOR)
            @set_trans_time(if slide.trans_time then slide.trans_time else DEFAULT_TRANS_TIME)
            @set_atrans_time(if slide.atrans_time then slide.atrans_time else DEFAULT_TRANS_TIME)
            @set_advance_time(if slide.auto_next then slide.auto_next * 0.001 else DEFAULT_AUTO_TIME)
            @set_turntable_turns(if slide.turntable_turns then slide.turntable_turns else 0)
            @set_turntable_rate(if slide.turntable_rate then slide.turntable_rate else 60)
            turntable_default = (slide.turntable_turns == 100) and(slide.turntable_rate == 5)
            if slide.reading_panel_opened
                reading_panel.show()
            else
                reading_panel.hide(false)

            if slide.new_annotations
                load_annotations_from_data(slide.new_annotations, false)

            if slide.annotations and slide.annotations.length!=0

                for i in [0... slide.annotations.length]
                    a = slide.annotations[i]
                    n = @_add_annotation()

                    n.style.left = a.x*2+'%'
                    n.style.top = a.y*2+'%'
                    n.style.width = a.w*2+'%'
                    n.delay = a.delay or 0

                    if n.editor
                        n.editor.destroy()
                    n.children[0].innerHTML = a.text

                    if a.anchor
                        n.line = new Line('#ffffff', 1.5)
                        n.object = objects[get_migrated_names([a.anchor.name])[0]]
                        n.point = vec4.create()
                        n.point[0] = a.anchor.x
                        n.point[1] = a.anchor.y
                        n.point[2] = a.anchor.z
                        n.point[3] = 1

                    if a.shadow
                        n.classList.add('annotation_shadow')

                update_annotations_when_camera_moves(true)

            if slide.quizzes
                for i in [0... slide.quizzes.length]
                    q = JSON.parse(slide.quizzes[i])
                    window[q.type](null, q)

            if slide.slider_animations
                for anim_name of slide.slider_animations
                    anim = slider_animations[anim_name]
                    if anim
                        anim.pos = slide.slider_animations[anim_name]

            @load_audio()
            @hide_audio_recorder()

            set_nerves(slide.nerves or [])

    load_audio: () ->
        slide = @slides[@current_slide]
        @audio_player.pause()
        if slide
            hash = slide.audio_hash
            @prev_plays_audio_across_slides = false
            prev_slide = @current_slide - 1
            while @slides[prev_slide]?.play_audio_across_slides
                hash = @slides[prev_slide--]?.audio_hash
                @prev_plays_audio_across_slides = true
            audio_path = hash and FILE_SERVER_DOWNLOAD_API+hash
            slide.audio_file = {
                hash : slide.audio_hash
                name: slide.audio_name
                properties:
                    duration:0
                }
            if audio_path
                @audio_player.ondurationchange = =>
                    @slides[@current_slide].audio_file.properties.duration = @audio_player.duration
                    main_view.render_all_views()
                @audio_player.autoplay = @auto_play_audio and not @prev_plays_audio_across_slides
                if @audio_player.src == audio_path and @audio_player.autoplay
                    @audio_player.play()
                else
                    @audio_player.src = audio_path
            else
                @audio_player.ondurationchange = null
                @audio_player.src = ''


    _load_state_instant: (idx) ->
        # Only for generating thumbnails, to be restored to
        # the previous state immediately after
        slide = @slides[idx]
        if slide.state
            snap_helper.set_state_instant(slide.state)
            set_meshes_state(slide.visibility, false)


    _make_thumbnail: (idx, makeNow) ->
        # in case we have just left the editor before getting here
        if not @editing or USE_PHYSICS
            return

        # in case we're too late and this slide was already removed
        if not @el_slides.children[idx*2+1]
            return

        if not makeNow
            # we might be in before of transition
            # transition times are limited to 300ms in _go_to_slide/_load_state
            # let's delay making thumbnail by 300ms
            # and additionally by 50ms per every slide (VB-27)
            setTimeout(@_make_thumbnail.bind(this), 300 + 50 * idx, idx, true)
            return

        # if the slide is not visible yet, wait for it (VB-27)
        if parseFloat(@el_slides.children[idx*2+1].style.opacity) <= 0
            setTimeout(@_make_thumbnail.bind(this), 300, idx, true)
            return

        if @current_slide != idx
            @_load_state_instant(idx)

        dataURL = thumbnail_maker.getDataURL(256, 128)

        if idx == 0
            @tour_data.icon = thumbnail_maker.getDataURL(20, 16)
            update_tour_tree_icons()

        if @current_slide != idx
            @_load_state_instant(@current_slide)
            recalculate_cameras()

        @el_slides.children[idx*2+1].firstChild.src = dataURL


    set_trans_time: (t, save_state) ->
        if @editing
            t = +t
            @slides[@current_slide].trans_time = if t then t else 0
            if save_state
                @save_state(0, 'trans_time')

    set_atrans_time: (t, save_state) ->
        if @editing
            t = +t
            @slides[@current_slide].atrans_time = if t then t else 0
            if save_state
                @save_state(0, 'atrans_time')


    set_advance_time: (t, save_state) ->
        if @editing
            t = +t
            @slides[@current_slide].auto_next = if t then t*1000 else 0
            if save_state
                @save_state(0, 'auto_next')

    set_turntable_turns: (n, save_state) ->
        if @editing
            n = Math.max(0, n)
            @slides[@current_slide].turntable_turns = n
            if save_state
                @save_state(0, 'turntable_turns')

    set_turntable_rate: (r, save_state) ->
        if @editing
            r = parseFloat(r)
            @slides[@current_slide].turntable_rate = r
            if save_state
                @save_state(0, 'turntable_rate')

    set_default_turntable_params: (checked, save_state) ->
        tr = $('#turntable-rate')[0]
        tt = $('#turntable-turns')[0]
        tr.disabled = checked
        tt.disabled = checked
        if checked
            tr.value = 5
            @set_turntable_rate(tr.value, save_state)
            tt.value = 100
            @set_turntable_turns(tt.value, save_state)

    switch_to_viewer: () ->
        @stop()
        save_tour_tree(true)
        tour_viewer.start(@tour_data, @tour_name, @current_slide)


    _text_edited_dom: (texts) ->
        console.log('reading panel edited, saving ' + texts.length + ' slide texts')

        @tour_data.reading_texts = texts

        tour_editor.save_state()

    can_edit_tours: ->
        return vida_body_auth.can_edit_tours

    hide_occluded_meshes: (threshold, alpha_treshold) ->
        visible_objects = glraytest.get_visible_meshes(threshold, alpha_treshold)

        for name, mesh of objects
            is_mesh_on_screen = visible_objects.indexOf(mesh) >= 0
            if mesh.visible and !is_mesh_on_screen
                vb.hide_mesh(null, mesh)
        tour_editor.save_state()

    get_mem_usage: () ->
        get_mesh_size = (mesh) ->
            # first size of mesh itself
            size = mesh.offsets?[mesh.offsets.length - 1] || 0
            # then find sizes of textures
            for material in mesh.materials || []
                for texture in material.textures || []
                    compresed = texture.size
                    # TODO: how to get bpp?
                    bpp = 1
                    # sometimes width and height are not defined
                    # propably texture are not loaded in this case
                    uncompressed = texture.width * texture.height * bpp or 0
                    size += compresed + uncompressed
            return size

        get_slide_meshes = (slide) ->
            meshes = []
            if not slide
                return meshes

            for name, params of slide.visibility
                is_visible = params[4]
                if is_visible
                    mesh = objects[name]
                    if mesh
                        meshes.push(mesh)
            return meshes

        get_meshes_size = (meshes) ->
            size = 0
            for mesh in meshes
                mesh_size = get_mesh_size(mesh)
                size += mesh_size
            return size

        try
          # get list of current meshes
          current_slide_meshes = get_slide_meshes(@slides[@current_slide])
          previous_slide_meshes = get_slide_meshes(@slides[@current_slide - 1])
          transition_meshes = []
          for mesh in current_slide_meshes
              was_loaded = previous_slide_meshes.indexOf(mesh) >= 0
              if not was_loaded
                  transition_meshes.push(mesh)

          current_slide_size = get_meshes_size(current_slide_meshes)
          previous_slide_size = get_meshes_size(previous_slide_meshes)
          transition_size = previous_slide_size + get_meshes_size(transition_meshes)
          return result = { current_slide_size, previous_slide_size, transition_size}

        catch error
            console.error('Error while calculating mem usage', error)
            result = {
                current_slide_size: 0,
                previous_slide_size: 0,
                transition_size: 0
            }

        return result
