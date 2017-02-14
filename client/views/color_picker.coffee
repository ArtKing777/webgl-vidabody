
main_view = require './main_view'

# Boilerplate
React = require 'react'
{div, img} = React.DOM

colors = null
callback = null
correct_colors = false

show_color_picker = (array_of_colors, on_pick, correct=false) ->
    colors = array_of_colors.slice()
    callback = on_pick
    correct_colors = correct
    main_view.render_all_views()

color_to_css = (i) ->
    r = colors[i][0]
    g = colors[i][1]
    b = colors[i][2]
    if correct_colors
        # make it look more like the shader color
        # the shader is http://i.imgur.com/SqARsWl.png
        tex_r = 0.89
        tex_g = 0.82
        tex_b = 0.76
        f = Math.min(2*(r + g + b) / 3, 1)
        # mix formula is http://i.juick.com/p/1685930-1.png
        mix_r = Math.min(Math.max(tex_r + f * 2 * (r - 0.5), 0), 1)
        mix_g = Math.min(Math.max(tex_g + f * 2 * (g - 0.5), 0), 1)
        mix_b = Math.min(Math.max(tex_b + f * 2 * (b - 0.5), 0), 1)
        r = mix_r
        g = mix_g
        b = mix_b
    'rgb(' + ((255 * r)|0) + ',' + ((255 * g)|0) + ',' + ((255 * b)|0) + ')'

ColorPicker = React.createFactory React.createClass {
    render: ->
        if not (colors and colors.length)
            return div()
        div {className: 'color-picker'},
            for i in [0 ... colors.length]
                div
                    key: i
                    className: 'color'
                    style:
                        backgroundColor: color_to_css(i)
                    title: colors[i][3]
                    onClick: ((i) -> ->
                        callback and callback(colors[i])
                    )(i)

            img
            	className: 'xbtn'
            	src: vidabody_app_path + 'xbtn.png'
            	onClick: =>
            		colors = null
            		@setState({})

}

module.exports = {show_color_picker, ColorPicker}