
React = require 'react'

{div, span, p, a, ul, li, img, h1, h2, h3, em, strong
canvas, pre, iframe, br,
form, input, label, button, datalist, option, optgroup,
svg, defs, linearGradient, stop} = React.DOM
cx = require 'classnames'

old_modules = require '../tmp/old_modules'
main_view = require './main_view'

go_to_enabled = [false, false]
show_feedback = [false, false]
go_to_color = ''

exports.old_pos = false

window.show_slide_reference = false

number_of_draws = 0

exports.TourViewerView = ->
    go_to = (id, prefix) ->
        if go_to_enabled[id]
            [
                prefix
                input
                    id: 'tour-position-input'
                    style:
                        backgroundColor: go_to_color
                    onKeyUp: (e) ->
                        value = e.currentTarget.value|0
                        valid = value > 0 and value <= old_modules.user_slides_count(tour_viewer.slides)
                        dismiss = false
                        go_to_color = ''
                        if not valid and e.currentTarget.value!=''
                            go_to_color = '#f99'
                        if e.keyCode == 27
                            dismiss = true
                        if e.keyCode == 13
                            if valid
                                show_feedback[id] = false
                                tour_viewer.is_auto = false
                                tour_viewer.go_to_slide(0, old_modules.user_slide_to_real(tour_viewer.slides, value))
                                dismiss = true
                            else
                                go_to_color = '#f99'
                        if dismiss
                            go_to_enabled[id] = false
                            show_feedback[id] = false
                        main_view.render_all_views()
                    onBlur: ->
                        go_to_color = ''
                        show_feedback[id] = false
                        go_to_enabled[id] = false
                " of #{len}"
                div
                    id: 'tour-position-input-feedback'
                    'Write a number and press enter.'
            ]
        else
            name = tour_viewer.slides[tour_viewer.current_slide].name
            if show_slide_reference
                number = old_modules.real_slide_to_user_with_part(tour_viewer.slides, tour_viewer.current_slide)
                if name
                    slideref = [br(), em({}, name)]
            else
                number = current
            [
                span
                    style:
                        pointerEvents: 'all'
                        cursor: 'pointer'
                    onClick: ->
                        go_to_enabled[id] = true
                        main_view.render_all_views()
                        requestAnimationFrame -> requestAnimationFrame ->
                            document.getElementById('tour-position-input').focus()
                    onMouseEnter: ->
                        show_feedback[id] = true
                        main_view.render_all_views()
                    onMouseLeave: ->
                        show_feedback[id] = false
                        main_view.render_all_views()
                    "#{prefix} #{number} of #{len}"
                slideref
                if show_feedback[id]
                    div
                        id: 'tour-position-input-feedback'
                        'Click to change...'
            ]
    tour_viewer = old_modules.tour_viewer
    if tour_viewer?.viewing
        current = old_modules.real_slide_to_user(tour_viewer.slides, tour_viewer.current_slide)
        len = old_modules.user_slides_count(tour_viewer.slides)
        is_auto = tour_viewer.is_auto
        [
            div
                id: 'tour-name'
                tour_viewer.tour_name
            div
                id: 'tour-slide-number'
                go_to(1, 'Slide ')
            div
                id: 'tour-viewer-controls'
                className: cx
                    old_pos: exports.old_pos
                div
                    id: 'back'
                    title: 'Go to the previous slide'
                    onClick: ->
                        if not tour_viewer.is_auto
                            tour_viewer.previous()
                    style:
                        background: 'url('+vidabody_app_path+'back-next.png) center center no-repeat'
                        backgroundSize: 'contain'
                        opacity: if (current == 1 or is_auto) then 0.2 else 1
                if tour_viewer.modified_view
                    div
                        id: 'restore_slide_view', key: 'restore_slide_view'
                        title: 'Restore view of the slide'
                        style:
                            background: 'url('+vidabody_app_path+'restore_view.png) center center no-repeat'
                            backgroundSize: 'contain'
                        onClick: -> tour_viewer.restore_view()
                else if tour_viewer.paused
                    div
                        id: 'resume'
                        title: 'Resume'
                        style:
                            background: 'url('+vidabody_app_path+'continue.png) center center no-repeat'
                            backgroundSize: 'contain'
                        onClick: -> tour_viewer.resume()
                else if tour_viewer.playing_slide or (is_auto and not current == len)
                    div
                        id: 'pause'
                        title: 'Pause'
                        style:
                            background: 'url('+vidabody_app_path+'pause.png) center center no-repeat'
                            backgroundSize: 'contain'
                        onClick: -> tour_viewer.pause()
                else if current == len
                    div
                        id: 'play_again'
                        title: 'Play again'
                        style:
                            background: 'url('+vidabody_app_path+'play_again.png) center center no-repeat'
                            backgroundSize: 'contain'
                        onClick: ->
                            tour_viewer.go_to_slide(0, 0)
                        # 'Play again'
                else
                    # Empty space, so the "next" button is correctly positioned
                    div
                        style:
                            height: 0
                div
                    id: 'next'
                    title: "Go to the next slide"
                    onClick: ->
                        if not tour_viewer.is_auto
                            tour_viewer.next()
                    style:
                        background: 'url('+vidabody_app_path+'back-next.png) center center no-repeat'
                        backgroundSize: 'contain'
                        opacity: if (current == len or is_auto) then 0.2 else 1
            # div
            #     id: 'tour-position'
            #     title: 'Go to a specific slide number...'
            #     go_to(0)
            if (number_of_draws++) > 4
                div
                    id: 'auto-toggle'
                    className: cx
                        'panel-button': true
                        old_pos: exports.old_pos
                    title: if tour_viewer.is_auto
                        'Stop going to the next slide automatically.'
                    else
                        'Go to the next slide automatically.'
                    style:
                        backgroundImage: if tour_viewer.is_auto
                            'url('+ vidabody_app_path + 'stop.png)'
                        else
                            'url('+ vidabody_app_path + 'play.png)'
                        # avoid an ugly version of the button showing the first time
                        bottom: if tour_viewer.first_load then '-999999px' else ''
                    onClick: (e)->
                        tour_viewer.toggle_auto()
                        main_view.render_all_views()
                    if tour_viewer.is_auto
                        'Stop auto play'
                    else
                        'Start auto play'
            div
                id: 'loading-slide'
                className: if tour_viewer.loading_slide then 'enabled' else ''
                'Loading...'
        ]
    else
        []
