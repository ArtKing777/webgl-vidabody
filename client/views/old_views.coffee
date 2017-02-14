
main_view = require './main_view'
old_modules = require '../tmp/old_modules'
tutorials = {render_tutorial} = require './tutorials'
tour_viewer_view = require './tour_viewer_view'
tour_editor_view = require './tour_editor_view'
organ_tree_view = require './organ_tree_view'
{show_color_picker} = require './color_picker'

React = require 'react'

{div, span, p, a, ul, li, img, h1, h2, h3, em, strong
canvas, pre, iframe, br,
form, input, label, button, datalist, option, optgroup,
svg, defs, linearGradient, stop} = React.DOM

cx = require 'classnames'
{popup_menu} = require '../views/ui_elements'



isMac = navigator.platform.toUpperCase().indexOf('MAC') >= 0
if isMac
    reset_zoom_key = '⌘Cmd and number 0 (the one above the letters)'
else
    reset_zoom_key = 'Ctrl and number 0 (the one above the letters)'

prevent_default = (e) ->
    e.preventDefault()
    return

square_message_dimissed = false
zoom_message_dimissed = false

standard_views = () ->

    set_menu = (e) ->
        r = e.target.getClientRects()[0]
        x = r.left
        y = r.top - 10
        popup_menu(x, y, [
            {
                'text': 'Left',
                'func': old_modules.go_left_view
            },
            {
                'text': 'Right',
                'func': old_modules.go_right_view
            },
            {
                'text': 'Anterior',
                'func': old_modules.go_front_view
            },
            {
                'text': 'Posterior',
                'func': old_modules.go_back_view
            },
            {
                'text': 'Inferior',
                'func': old_modules.go_bottom_view
            },
            {
                'text': 'Superior',
                'func': old_modules.go_up_view
            },
        ])
        requestAnimationFrame ->
            menu = document.querySelector('.popup_menu')
            menu.style.bottom = (document.body.clientHeight - y) + 'px'
            menu.style.top = ''

    div
        id: 'standard_views_button'
        className: cx
            'panel-button': true
            'active': true
        title: 'Standard views'
        style: {backgroundImage: 'url('+ vidabody_app_path + 'cube_ico.png)'}
        onClick: set_menu
        'Views \u25B2'


Labels = React.createFactory React.createClass {
    # http://stackoverflow.com/a/24871991/2207790
    shouldComponentUpdate: -> false
    render: -> div {id: 'labels'}
}

viewing_or_embedded = false

exports.OldViews = ->
    too_small = render_manager?.width < 600
    too_square = objects?.Camera?.aspect_ratio < 1.25
    viewing = old_modules.tour_viewer?.viewing
    viewing_or_embedded = viewing or load_tour_hash? or load_tour_uuid?
    [
        if old_modules.DEBUG_GLRAYTEST
            canvas
                id: 'debug_glraytest'
                style:
                    position: 'absolute'
                    zIndex: 9
                    transform: 'scaleY(-1)'
        div {id: 'splash'},
            div {id: 'progress'}
            p {}, 'loading...'

        div {id: 'canvas_container', 'data-myou-app'},
            canvas {id: 'canvas', 'moz-opaque': 'moz-opaque', opaque: 'opaque', 'data-html2canvas-ignore': true}
            div {id: 'pointer'}
            div {id: 'pan_action', className: 'hidden'}
            div {id: 'zoom_action', className: 'hidden'},
                div {id: 'zoom_slider'}
                div {id: 'zoom_plus'}, '+'
                div {id: 'zoom_minus'}, '-'
            div {id: 'control_toolbar', className: 'hidden'},
                img {className: 'xbtn', src: vidabody_app_path+'xbtn.png', onClick: old_modules.toggle_oscc}
                div {id: 'handle', className: 'controller', title: "Click and drag to move this toolbar."}, '....'
                div {id: 'rotate', className: 'controller', title: "Click and drag to rotate.\nshortcut: Left mouse button"}
                div {id: 'pan', className: 'controller', title: "Click and drag to pan.\nshortcut: Right mouse button"}
                div {id: 'zoom', className: 'controller', title: "Click and drag to zoom.\nshortcuts: Mouse scroll wheel or W/S keys"}
                div {id: 'tilt', className: 'controller', title: "Click and drag to tilt.\nshortcut: Q/E keys"}
                if not viewing
                    div
                        id: 'home',
                        className: 'controller',
                        title: "Home: Restore camera position",
                        onClick: ->
                            time = old_modules.go_home()
                            setTimeout((-> old_modules.tour_editor.save_state()), time + 50)
                render_tutorial("oscc")

        svg {id: 'lines'}
        svg {id: 'lines2'},
            defs {},
                linearGradient {x1: '0%', y1: '0%', x2: '100%', y2: '0%', id: 'readingPanelSpline'},
                    stop {offset:   '0%', style: {stopColor: '#FFFFFF', stopOpacity: 1}}
                    stop {offset: '100%', style: {stopColor: '#FFFFFF', stopOpacity: 0}}
                linearGradient {x1: '0%', y1: '0%', x2: '100%', y2: '0%', id: 'readingPanelSplineShadow'},
                    stop {offset:   '0%', style: {stopColor: '#000000', stopOpacity: 1}}
                    stop {offset: '100%', style: {stopColor: '#000000', stopOpacity: 0}}

        Labels()
        div {id: 'annotations'}

        div {id: 'main_menu', className: 'menu unhidden'},
            div {id: 'menu_logo', className: 'maximize_button'}
            #TODO: remove the '?' when modules no longer expect static elements around
            div
                className: cx {'save_or_exit_button': true, 'hidden': not old_modules.tour_editor?.editing}
                onClick: -> old_modules.tour_editor.save()
                'Save'
            div
                className: cx {'save_or_exit_button': true, 'hidden': not old_modules.tour_editor?.editing}
                onClick: ->
                    old_modules.tour_editor.save()
                    old_modules.tour_editor.stop()
                '< Exit and save'
            div
                className: cx {'save_or_exit_button': true, 'hidden': not old_modules.tour_editor?.editing}
                onClick: ->
                    if old_modules.tour_editor.editing and confirm 'Are you sure you want to discard all unsaved changes?'
                        old_modules.tour_editor.stop_without_saving()
                '< Exit without saving'
            if old_modules.tour_viewer?.is_landing
               div
                   className: cx {'save_or_exit_button': true, 'hidden': not old_modules.tour_viewer?.viewing, 'landing': true}
                   onClick: -> old_modules.tour_viewer.stop()
                   'Click here to explore!'
            else if window.is_pearson
               div
                   className: cx {'exit_tour_button': true, 'hidden': not old_modules.tour_viewer?.viewing, old_pos: tour_viewer_view.old_pos}
                   onClick: -> old_modules.tour_viewer.stop()
                   '< Leave tour'

            tour_editor_view.render_history_tools() # Undo/redo
            ul {className: 'accordion expanded'},
                if not window.vidabody_app_path
                    li {id: 'tours'},
                        div {
                            className: 'expand-accordion heading panel-button', title: "Play tours", onClick: (e) ->
                                if e.target.classList.contains('close')
                                    return
                                tutorials.main_menu_tutorials_controller()
                        },
                            div {style: {'pointer-events': 'none'}},
                                'Tours'
                            div {className: 'buttons', style: {display: if old_modules.auth.can_edit_tours then '' else 'none'}},
                                div {id: 'new_tour', title: "Create a new tour\non the root directory"}
                                div {id: 'new_folder', title: "Create a new folder\non the root directory"}
                            render_tutorial('tours')
                        div {id: 'tour-tree-container', className: 'sub-menu'},
                            ul {className: 'dragonfly-file-tree'},

                # li {id: 'snapshots'},
                #     div
                #         className: 'expand-accordion heading panel-button',
                #         title: "Snapshots"
                #         onClick: tutorials.main_menu_tutorials_controller
                #         'Snapshots'
                #         render_tutorial('snapshots')
                #     div {id: 'snapshots-view-container', className: 'sub-menu'}
                li {id: 'systems', className: 'expanded'},
                    div
                        className: 'expand-accordion heading panel-button'
                        title: "Body systems and parts visibility"
                        onClick: (e) ->
                            console.log(e.target)
                            tutorials.main_menu_tutorials_controller()
                        'Body Systems'
                        render_tutorial('systems')
                    div {id: 'organ-tree-container', className: 'sub-menu menu'},
                        organ_tree_view.render_organ_tree()
                li {id: 'exit_tour'},
                    div
                        className: 'heading panel-button'
                        title: "Back to explore mode"
                        onClick: -> old_modules.tour_viewer.stop()
                        'Leave the tour'
                    div {className: 'sub-menu menu'},
            render_tutorial('main_menu')

        tour_viewer_view.TourViewerView()...
        OldTourEditorView()...

        div
            id: 'reading-panel'
            key: 'reading-panel'
            style: {display: 'none': top:-999999999}
            div {id: 'reading-handle'}
            div {id: 'reading-header'}
            div {id: 'reading-scrolling-tab', className: 'reading-panel-tab'}


        pre {id: 'debug'}
        div {id: 'debug_gui', key: 'debug_gui', style: {display: if old_modules.auth.can_edit_tours then '' else 'none'}}
        pre {id: 'fps', key: 'fps', style: {display: if vidabody_app_path == '' then 'block' else 'none'}}
        div
            id: 'version'
            key: 'version'
            className: 'selectable'
            style:
                display: if vidabody_app_path == '' then 'block' else 'none'
                position: 'absolute'
                bottom: 4
                left: 4
                color: 'white'
                fontSize: '8px'
                cursor: 'text'
            'build '
            VIDA_BODY_COMMIT
            ' - '
            VIDA_BODY_BUILD_DATE
        div {id: 'saving-popup', key: 'saving-popup'}
        div {id: 'warning-popup', key: 'warning-popup'}
        # CreateSnapshotPopup()

        div {id: 'audio-recorder'},
            canvas {id: 'analyser', height: '500', width: '1024'}
            div {id: 'record', className: 'button', onClick: (e) -> toggleRecording(e.target)}, 'Record'

        OldAuthView()...

        div {id: 'templates', key: 'templates', style: {display: 'none'}},
            div {id: 'slice-widget', className: 'slice-widget cke_reset_all cke_top', title: 'drag to move the widget'},
                span {className: 'cke_toolgroup'},
                    a {className: 'slice-rotate cke_button', onDragStart: prevent_default, title: 'drag to rotate the plane'}, 'rotate'
                span {className: 'cke_toolgroup'},
                    a {className: 'slice-move cke_button', onDragStart: prevent_default, title: 'drag to move the plane'}, 'move'

            div {id: 'tour_file', className: 'tour file'},
                label {className: 'label'}

        if document.getElementById('control_toolbar')?.classList.contains('hidden')
            div
                id: 'oscc_toggle', key: 'oscc_toggle', className: cx
                    'panel-button': true
                    viewer: viewing_or_embedded
                    old_pos: tour_viewer_view.old_pos
                type: 'button', onClick: old_modules.toggle_oscc, title: "Toggle on-screen camera controls"

        render_tutorial('oscc_button')
        if window.current_zoom != localStorage.defaultZoom and not zoom_message_dimissed
            div
                id: 'aspect_advice'
                key: 'aspect_advice'
                style:
                    left: if too_small then 300 else ''
                    transform: "scale(#{1/window.current_zoom})"
                    transformOrigin: 'bottom'
                    webkitTransform: "scale(#{1/window.current_zoom})"
                    webkitTransformOrigin: 'bottom'
                "For a better experience, reset the zoom or"
                br()
                "press "+reset_zoom_key
                br()
                input
                    type: 'button'
                    className: 'panel-button'
                    value: 'Got it!'
                    onClick: ->
                        zoom_message_dimissed = true
                        main_view.render_all_views()
        else if (too_small or too_square) and not square_message_dimissed
            div
                id: 'aspect_advice'
                key: 'aspect_advice'
                style:
                    left: if too_small then 300 else ''
                img
                    src: vidabody_app_path + 'wider.png'
                    style:
                        float: 'left'
                "For a better experience, maximize the window or make it wider."
                br()
                "If the window is too tall or narrow, some items may not fit."
                br()
                input
                    type: 'button'
                    className: 'panel-button'
                    value: 'Got it!'
                    onClick: ->
                        square_message_dimissed = true
                        main_view.render_all_views()
        div
            id: 'patents-note'
            style:
                position: 'absolute'
                bottom: 4
                right: 4
                color: 'white'
                fontSize: '8px'
                cursor: 'text'
            'patent pending'
    ]

# TODO REPORT .* " $"

bg_color_click = (e) ->
    base_colors = [
        [0.9,0.9,0.9, 'Grey'],
        [1.0,0.4,0.4, 'Red'],
        [1.0,0.5,0.2, 'Orange'],
        [1.0,1.0,0.4, 'Yellow'],
        [0.4,1.0,0.4, 'Green'],
        [0.4,0.4,1.0, 'Blue']
    ]

    grades = ['Darker ', 'Dark ', '', 'Light ', 'Lighter ']

    colors = []
    for i in [0 ... grades.length]
        s = (i + 1) / grades.length
        for j in [0 ... 6]
            c = base_colors[j].slice()
            for k in [0 ... 3]
                c[k] *= s
            c[3] = grades[i] + c[3]
            colors.push(c)

    efc = e.target.firstChild

    show_color_picker(colors, (color) ->
        color = 'rgb(' + ((255 * color[0])|0) + ',' + ((255 * color[1])|0) + ',' + ((255 * color[2])|0) + ')'
        old_modules.change_bg_color(color, true)
        efc.style.backgroundColor = color
    )

OldTourEditorView = ->[
    tour_editor_view.render_editor_toolbar()
    if old_modules.tour_editor?.editing
        div
            id: 'tour-name'
            key: 'tour-name'
            className: 'editing'
            'Now editing: ' + old_modules.tour_editor.tour_name
    div {id: 'slide-editor', key: 'slide-editor'}

    tour_editor_view.old_slide_properties_panel()...

    if not viewing_or_embedded
      div {id: 'lcs', key: 'lcs'},
        div {className: 'bg-color-input panel-button', onClick: bg_color_click, title: 'Background color'},
            div
                style: { 'background-color': 'rgb(128, 128, 128)' }

        input
            className: 'panel-button', type: 'button', value: 'Labels',
            onClick: -> old_modules.set_labels_visible(not old_modules.labels_visible)
            title: "Labels visibility"
        # input
        #     className: 'panel-button', type: 'button', value: 'Callouts',
        #     onClick: -> old_modules.set_label_callouts(not old_modules.label_callouts)
        #     title: "Labels callouts visibility"
        # input
        #     className: 'panel-button', type: 'button', value: 'Style',
        #     onClick: -> old_modules.set_label_callouts_splines(not old_modules.label_callouts_splines)
        #     title: "Labels callouts style toggle"
        # input
        #     id: 'tempsnapshot'
        #     className: 'panel-button'
        #     type: 'button'
        #     value:'Snapshot'
        #     title: "Take a snapshot"
        #     onClick: ->
        #         if vida_body_auth.logged_in
        #             snapshot_view_options.enabled = true


        standard_views()

    canvas
        id: 'thumbnailer', width: "256", height: "128", key: 'thumbnailer'
        style:
            position: 'absolute'
            top: '-100%'
            width: 256
            height:128

    div {style: { display: 'none'}},
        div {id: 'base-float-edit', className: 'editable-element'},
            div {contentEditable: true}
            div {className: 'resize'}

    div {id: 'slide-prototype', className: 'slide', key: 'slide-prototype'},
        img {className: 'slidethumb'}
        span {className: 'slide-number'}
        img {className: 'speaker hidden', src: vidabody_app_path + 'speaker.png'}
]


OldAuthView = ->
    skip_auth_style = {}
    if (window.vidabody_skip_auth or old_modules.tour_viewer?.viewing) && !old_modules.tour_viewer?.is_landing
        skip_auth_style = {display: 'none', top: -10000}

    _input = (name, caption, type='input') ->
        input {
            className: 'text-input', disabled: true, placeholder: caption,
            id: name, name: name, autoComplete: true, type: type}

    [
        div {id: 'logged_in_panel', key: 'logged_in_panel', className: 'disabled', style: skip_auth_style},
            'Welcome'
            span {id: 'user_name'}
            '|'
            a {id: 'logout'}, 'Logout'
        div {id: 'secondary_login_button', key: 'secondary_login_button', style: skip_auth_style}, 'login'

        div {id: 'close_login_panel', key: 'close_login_panel'}
        ul {id: 'login_panel', key: 'login_panel', className: 'accordion', style: {display: 'none'}},
            li {id: 'register'},
                div {className: 'expand-accordion panel-button'}, 'Register'
                div {className: 'sub-menu'},
                    form {id: 'register_form'},
                        _input('desired_name', 'your name')
                        _input('password', 'password', 'password')
                        _input('password2', 'confirm password', 'password')
                        _input('email_address', 'e-mail address')
                        input {className: 'panel-button', disabled: true, type: 'submit', value: 'register'}
                    div {id: 'register_error'}
            li {id: 'login'},
                div {className: 'expand-accordion panel-button'}, 'I already have an account'
                div {className: 'sub-menu'},
                    form {id: 'login_form', method: 'POST',action: 'blank.html',target: 'login_iframe'},
                        div {id: 'register_success'}
                        _input('email', 'e-mail address')
                        _input('password', 'password', 'password')
                        input {className: 'panel-button', disabled: true, type: 'submit', value: 'log in'}
                        input {id: 'stay_logged_in', className: 'checkbox', disabled: true, type: 'checkbox', name: 'stay_logged_in', defaultChecked: true}
                        label {htmlFor: 'stay_logged_in'}, 'Remember me'
                        a {id: 'forgot'}, 'forgot your password?'

                    div {id: 'login_error'}
                    form {id: 'forgot_form', className: 'hidden'},
                        _input('email', 'e-mail address')
                        input {className: 'panel-button', id: 'resend_pass', disabled: true, type: 'submit', value: 'resend password'}
                        input {className: 'panel-button', id: 'return_to_login', disabled: true, type: 'submit', value: 'return to login'}

        iframe
            id: 'login_iframe', name: 'login_iframe'
            style:
                width: 16
                height:16
                position: 'absolute'
                left: -100
    ]
