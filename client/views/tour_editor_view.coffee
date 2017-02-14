
ui_elements = require './ui_elements'
old_modules = require '../tmp/old_modules'
{popup_menu} = require '../views/ui_elements'
React = require 'react'

{div, span, p, a, ul, li, img, h1, h2, h3, em, strong
canvas, pre, iframe, br,
form, input, label, button, datalist, option, optgroup,
svg, defs, linearGradient, stop} = React.DOM
cx = require 'classnames'

exports.render_editor_toolbar = ->
    MIN_WIDTH = 1320
    window_width = render_manager?.width

    selected_objects = old_modules.selected_objects
    tour_editor = old_modules.tour_editor
    if not tour_editor?.toolbar_state
        tour_editor?.toolbar_state = {'active':null}

    mem_usage = vb?.tour_editor?.get_mem_usage()

    current_usage = mem_usage?.current_slide_size / 1000 / 1000 or 0
    previous_usage = mem_usage?.previous_slide_size / 1000 / 1000 or 0
    transition_usage = mem_usage?.transition_size / 1000 / 1000 or 0

    menus =
        insert_stuff:[
            {text:'Shape', custom_classes:['icon', 'icon32'], icon:'shapes_ico.png', submenu:[
                {text:'Rectangle', func: old_modules.add_rectangle}
                {text:'Ellipse', func: old_modules.add_ellipse}
                {text:'Arrow', func: old_modules.add_arrow}
                {text:'L - Shape', func: old_modules.add_lshape}
                {text:'Left Bracket', func: old_modules.add_left_bracket}
                {text:'Right Bracket', func: old_modules.add_right_bracket}
            ]}
            {text:'Annotation', custom_classes:['icon', 'icon32'], icon:'annotation_ico.png', func: (-> tour_editor?.add_annotation())}
            {text:'Image', custom_classes:['icon', 'icon32'], icon:'image_ico.png', submenu: [
                {text:'From url', func: old_modules.add_image_transformable}
                {
                    type : 'file_input'
                    file_type : 'image'
                    state : 2
                    load: ui_elements.load_file_on_tour
                }
            ]}
            {text:'Video', custom_classes:['icon', 'icon32'], icon:'video_ico.png', func: old_modules.add_youtube}
        ]
        audio_menu: [
            if not tour_editor?.prev_plays_audio_across_slides then {
                type : 'file_input'
                file_type : 'audio'
                state : 2
                read: -> tour_editor?.slides[tour_editor.current_slide].audio_file
                delete_file: -> tour_editor.delete_audio()
                load: ui_elements.load_file_on_tour
            }
            {
                type: 'switch',
                states : 2,
                state: 0,
                id:'auto_play_audio',
                text:'Auto preview',
                read: -> tour_editor.auto_play_audio
                write: (state)-> tour_editor.auto_play_audio = state
            }
            {
                type: 'switch',
                states : 2,
                state: 1,
                id: 'play_audio_across_slides',
                text: 'Play audio across slides',
                title: 'Advance time is defined from the beginning of audio if this is enabled'
                # old behavior is to wait (default)
                read: ->
                    slide = tour_editor.slides[tour_editor.current_slide]
                    if slide.play_audio_across_slides then 1 else 0
                write: (state)->
                    slide = tour_editor.slides[tour_editor.current_slide]
                    slide.play_audio_across_slides = !!state
                    tour_editor.save_state()
            }
        ]
        selection_menu: old_modules.selection_menu()
        slide_properties:[
            {
                type:'slider'
                id:'auto_advance'
                text:'Auto advance'
                title:'Auto advance time (from end of audio, or beginning if "Play audio across slides" is enabled)'
                min:0.01
                max:60
                soft_min:0.01
                soft_max:600
                unit:'s'
                read: -> tour_editor?.slides[tour_editor.current_slide].auto_next/1000
                write: (v)->
                    tour_editor.set_advance_time(v,true)
                    if tour_editor.current_slide_data.play_audio_across_slides and
                            tour_editor.audio_player and tour_editor.auto_play_audio
                        tour_editor.preview_audio_delay(v, true)
                onmove: false
                onup: true
            },
            if not tour_editor?.current_slide_data?.play_audio_across_slides then {
                type: 'switch',
                states : 2,
                state: 1,
                id:'force_auto_advance',
                text:'Force auto advance',
                # old behavior is to wait (default)
                read: ->
                    tour_editor.slides[tour_editor.current_slide].force_auto_advance|0
                write: (state)->
                    slide = tour_editor.slides[tour_editor.current_slide]
                    slide.force_auto_advance = !!state
                    tour_editor.save_state()
            },
            {
            text:'Transition'
            submenu: [
                {
                    type:'slider'
                    id:'cam_trans'
                    text:'Camera'
                    title:'Camera transition'
                    min:0.1
                    max:10
                    soft_min:null
                    soft_max:60
                    unit:'s'
                    read: -> tour_editor?.slides[tour_editor.current_slide].trans_time
                    write: (v)-> tour_editor.set_trans_time(v,true)
                    onmove: false
                    onup: true
                },
                {
                    type:'slider'
                    id:'transp_transition'
                    text:'Opacity'
                    title:'Opacity transition'
                    min:0.1
                    max:10
                    soft_min:null
                    soft_max:60
                    unit:'s'
                    read: -> tour_editor?.slides[tour_editor.current_slide].atrans_time
                    write: (v)-> tour_editor.set_atrans_time(v,true)
                    onmove: false
                    onup: true
                },
                ]
            },

            {
            text:'Auto-Rotation'
            submenu:[
                {
                    type:'slider'
                    id:'turns'
                    text:'Cycles'
                    title:'Number of turns'
                    min:0
                    max:10
                    soft_min:null
                    soft_max:100
                    unit:''
                    read: -> tour_editor?.slides[tour_editor.current_slide].turntable_turns or 0
                    write: (v)->
                        tour_editor?.slides[tour_editor.current_slide].turntable_turns = v
                        tour_editor?.save_state(0, 'turntable_turns')

                    onmove: false
                    onup: true
                    step: 0.25
                    digits: 2
                },
                {
                    type:'slider'
                    id:'rotation_speed'
                    text:'Cycle duration'
                    title:'Cycle duration'
                    min:0.25
                    max:60
                    soft_min:-120
                    soft_max:120
                    unit:'s'
                    read: -> 60/tour_editor.slides[tour_editor.current_slide].turntable_rate

                    write: (v)->
                        direction = tour_editor.rotation_direction
                        tour_editor.slides[tour_editor.current_slide].turntable_rate = max(min((60/v),240),-240)
                        tour_editor.save_state(0, 'turntable_rate')
                    onmove: false
                    onup: true

                },
                {
                    type: 'switch',
                    states : 2,
                    state: 1,
                    id:'rotate_around_center',
                    text:'Rotate around object`s center',
                    read: ->
                        tour_editor.slides[tour_editor.current_slide].rotate_around_center|0
                    write: (state)->
                        slide = tour_editor.slides[tour_editor.current_slide]
                        slide.rotate_around_center = !!state
                        tour_editor.save_state()
                }
                ]
            },
        ]
        misc_menu: [
            # {
            #     type:'text_input'
            #     id:'sub_uuid'
            #     text:'UUID'
            #     title:'UUID'
            #     read: -> tour_editor?.tour_data.uuid
            #     write: (v)-> tour_editor?.tour_data.uuid = v
            # }
            {text:'Hide invisible organs', func: -> vb.tour_editor.hide_occluded_meshes()}
            {text:'Mem usage', submenu: [
                {   text: "curr slide: #{current_usage.toFixed(1)} mb", min_width: 180
                },
                {   text: "prev slide: #{previous_usage.toFixed(1)} mb"
                },
                {   text: "transition: #{transition_usage.toFixed(1)} mb"
                }
            ]}
        ]


    toolbar_button = (id, text, icon=null, onClick, active=false, disable=false, drop=false) ->

        if window_width < MIN_WIDTH
            button_text = ''
            title = text
        else
            title = ''
            button_text = text

        #TODO:implement drag and drop tools
#         modal_mouse_drag(event, onmove, onup)

        div
            id:id + '_button'
            className: cx
                'panel-button':true
                'disabled':disable
                'no_icon':not icon
                'active': active

            title:title
            style: if icon then {backgroundImage: 'url('+ vidabody_app_path + icon + ')'} else {backgroundImage: 'none'}
            onClick: (e)->
                tour_editor.toolbar_state.active = null
                popup_menu()
                onClick(e)
            button_text


    toolbar_menu = (id, text, icon=null, disable=false) ->

        set_menu = (e, id)->
            if tour_editor.toolbar_state.active == id
                popup_menu()
                tour_editor.toolbar_state.active = null
                return
            menu = menus[id]
            tour_editor.toolbar_state.active = id
            r = e.target.getClientRects()[0]
            x = r.left
            y = r.top + r.height + 10
            exit_func = ->
                tour_editor.toolbar_state.active = null
            popup_menu(x, y, menu, exit_func, id)

        if render_manager?.width < MIN_WIDTH
            button_text = ''
            title = text
        else
            title = ''
            button_text = text

        div
            id:id + '_button'
            className: cx
                'panel-button': true
                'active': tour_editor?.toolbar_state?.active == id
                'disabled': disable
                'no_icon': not icon
            title:title
            style: if icon then {backgroundImage: 'url('+ vidabody_app_path + icon + ')'} else {backgroundImage: 'none'}
            onClick: do (menus)-> (e)-> set_menu(e, id)
            button_text + ' \u25BC'

    selection_name = ->
        l = selected_objects?.length
        if l == 1
            n = old_modules.ORGAN_VISIBLE_NAMES[selected_objects[0].name]
            if n.length > 15
                name = 'Selected: ' + n[0...12] + '...'
            else
                name = 'Selected: ' + n
        else
            name = 'Selected: (' + l + ')'

        return name

    div
        id: 'editor-toolbar',
        className: cx
            'hidden':not tour_editor?.editing
        input
            id: 'editor-color-input'
            className: 'offscreen'
            type: 'color'
        div
            id: 'editor-toolbar-inner'
            toolbar_menu('slide_properties','Slide times','transition_ico.png')
            '|'
            toolbar_menu('audio_menu','Slide audio','audio_ico.png')
            '|'
            toolbar_menu('insert_stuff','Insert', 'insert_ico.png')
            '|'
            tour_editor?.editing and toolbar_menu(
                'selection_menu',
                selection_name(),
                'selection_ico.png',
                not selected_objects.length
                )
            tour_editor?.editing and '|'
            tour_editor?.editing and toolbar_menu(
                'misc_menu',
                'Misc',
                'cube_ico.png'
                )


exports.render_history_tools = React.createFactory React.createClass
  render: ->
    tour_editor = old_modules.tour_editor
    undo_singleton = if tour_editor?.editing
        tour_editor
    else if not old_modules.tour_viewer?.viewing
        old_modules.explore_mode_undo
    div
        id: 'history_tools'
        className: cx
            hidden: not undo_singleton?
        div
            id:'undo'
            className: cx
                    button: true
                    hidden: not undo_singleton?.can_undo()
            title: 'undo'
            onClick: -> undo_singleton.undo()
        div
            id:'redo'
            className: cx
                    button: true
                    hidden: not undo_singleton?.can_redo()
            title: 'redo'
            onClick:-> undo_singleton.redo()


exports.old_slide_properties_panel = -> [
    div
        id: 'edit-box-toggle',
        className: cx {'hidden':not old_modules.tour_editor?.is_editing()}
        title: 'Show/hide the "Slide properties" panel'
        onClick: (e)-> old_modules.tour_editor._slide_context_menu(e, old_modules.tour_editor.current_slide)
        '···'
    div
        id: 'slide-ui-toggle',
        className: cx {'hidden':not old_modules.tour_editor?.is_editing()}
        title: 'Show/hide slide thumbnails'
        onClick: (e)->
            e.target.classList.toggle('up')
            ui = document.querySelector('#slide-editor')
            eb = document.querySelector('#edit-box-toggle')
            if  ui.style.visibility
                ui.style.visibility=''
                eb.style.visibility=''
            else
                ui.style.visibility='hidden'
                eb.style.visibility='hidden'
    div {id: 'edit-box'},

]
