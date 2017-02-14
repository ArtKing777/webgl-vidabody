
main_view = require './main_view'
old_modules = require '../tmp/old_modules'
React = require 'react'

{div, span, p, a, ul, li, img, h1, h2, h3, em, strong
canvas, pre, iframe, br,
form, input, label, button, datalist, option, optgroup,
svg, defs, linearGradient, stop} = React.DOM
cx = require 'classnames'

window.TUTORIALS = {}
TUTORIALS_URL = (window?.vidabody_app_path or '') + 'tutorials.json'
SKIP_CACHE = '?'+ Math.random()

load_tutorials = ->
    if load_tour_hash?
        return
    try
        localStorage.test = 1
    catch e
        return
    shown_by_default = ['oscc_button','oscc']
    f = (data) ->
        for k,t of data
            TUTORIALS[k] = t
            t['hidden'] = true
        for k in shown_by_default
            TUTORIALS[k].hidden = false

        main_view.render_all_views()
    old_modules.request_json('GET', TUTORIALS_URL+SKIP_CACHE, f)

reset_tutorials = ->
    for t of TUTORIALS
        localStorage.removeItem('no-tutorial-'+t)

show_tutorial = (id) ->
    if TUTORIALS[id] and TUTORIALS[id].hidden == true
        TUTORIALS[id].hidden = false
        main_view.render_all_views()

hide_tutorial = (id) ->
    if TUTORIALS[id] and TUTORIALS[id].hidden == false
        TUTORIALS[id].hidden = true
        achievements[id] = true
        main_view.render_all_views()

close_tutorial = (id) ->
    if TUTORIALS[id] and TUTORIALS[id].hidden == false
        TUTORIALS[id].hidden = true
        achievements[id] = true
        main_view.render_all_views()
        add_to_local_storage = -> localStorage.setItem('no-tutorial-'+id, true)
        setTimeout(add_to_local_storage, 200)

render_tutorial = (id) ->
    tutorial = TUTORIALS[id]

    if not tutorial? or localStorage.getItem('no-tutorial-'+id)
        return

    div
        className: 'tutorial-balloon'
        div {className: 'focus hidden'}
        div
            className: cx
                'body': true
                'hidden': tutorial.hidden
            style:
                top: tutorial.top
                left: tutorial.left
                right: tutorial.right
                bottom: tutorial.bottom
            div {className: 'title'}, tutorial.title
            div {className: 'content'}, tutorial.content
            div
                className: 'close panel-button'
                onClick: -> close_tutorial(id)
                'Got it!'

# This is an abomination. Kill it with fire. (moved here from old_views)
main_menu_tutorials_controller =  ->
    TUTORIALS.systems?.hidden = not document.querySelector('#systems')?.classList.contains('expanded')
    TUTORIALS.tours?.hidden = not document.querySelector('#tours')?.classList.contains('expanded')
    TUTORIALS.snapshots?.hidden = not document.querySelector('#snapshots')?.classList.contains('expanded')
    main_view.render_all_views()


module.exports = {load_tutorials, reset_tutorials, show_tutorial,
    hide_tutorial, close_tutorial, render_tutorial, main_menu_tutorials_controller, TUTORIALS}
