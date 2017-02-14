
old_views = require './old_views'
error_screens = require './error_screens'
ui_elements = require './ui_elements'
comments = require './comments'
color_picker = require './color_picker'
# example = require './example'
React = require 'react'

{div, span, p, a, ul, li, img, h1, h2, h3, em, strong
canvas, pre, iframe, br, audio,
form, input, label, button, datalist, option, optgroup,
svg, defs, linearGradient, stop} = React.DOM

# classSet addon is deprecated, using classNames instead
cx = require 'classnames'

# Read this
# https://bitbucket.org/excarabajo/vidabody-wiki/wiki/architecture/usageOfReactJs
MainView = React.createFactory React.createClass {
    render: ->
        div {className: 'MainView'},
            old_views.OldViews() # This returns a list
            error_screens.ErrorScreens()
            ui_elements.render_popup_menu()
            audio {id: 'vidabody-audio'}
            comments.CommentsView()
            color_picker.ColorPicker()
            exports.extra_views()
            # example.ExampleView()
}

exports.render_all_views = ->
    React.render MainView(), document.getElementById('app')
exports.pause_render = (time = 500)->
    if scene and scene.enabled
        scene.enabled = false
        setTimeout((-> scene.enabled = true),time)

exports.extra_views = (->)
