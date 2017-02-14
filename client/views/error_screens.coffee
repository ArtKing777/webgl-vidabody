
main_view = require './main_view'
React = require 'react'

{div, span, p, a, ol, ul, li, img, h1, h2, h3, em, strong
canvas, pre, iframe, br,
form, input, label, button, datalist, option, optgroup,
svg, defs, linearGradient, stop} = React.DOM

errors_visible =
    low_memory: false
    context_lost: false
    blacklisted: false
    unsupported: false
    disabled_in_safari: false

exports.ErrorScreens = -> [
    if errors_visible.low_memory
        div {id: 'error_low_memory', className: 'error_screen'},
            img {src: vidabody_app_path + 'sad.png'}
            div {className: 'message'},
                h1 {}, 'Rats!'
                span {}, "Couldn't reserve enough memory. Try restarting the browser, closing other applications, restarting the PC or using a different browser."

    if errors_visible.context_lost
        div {id: 'error_context_lost', className: 'error_screen'},
            img {src: vidabody_app_path + 'sad.png'}
            div {className: 'message'},
                h1 {}, 'Rats!'
                span {}, 'There was a problem with graphics, please wait a moment...'

    if errors_visible.disabled_in_safari
        div {id: 'error_disabled_in_safari', className: 'error_screen'},
            img {src: vidabody_app_path + 'sad.png'}
            div {className: 'message'},
                h1 {}, 'WebGL is disabled'
                span {}, 'Please follow these steps to enable WebGL in Safari:'
                ol {},
                    li {}, 'open the Safari menu and select Preferences'
                    li {}, 'click the Advanced tab in the Preferences window'
                    li {}, 'at the bottom of the window, check the Show Develop menu in menu bar checkbox'
                    li {}, 'open the Develop menu in the menu bar and select Enable WebGL'
                    li {}, 'restart the application'

    if errors_visible.blacklisted
        div {id: 'error_blacklisted', className: 'error_screen'},
            img {src: vidabody_app_path + 'sad.png'}
            div {className: 'message'},
                h1 {}, 'Rats!'
                span {}, 'It looks like your video card drivers could use some update. Please click on one of the buttons below to update the drivers for your hardware.'
                div {className: 'buttons'},
                    a {href: 'http://support.amd.com/en-us/download'},
                        img {src: vidabody_app_path + 'logos/amd.png'}
                    a {href: 'http://www.intel.com/p/en_US/support/detect'},
                        img {src: vidabody_app_path + 'logos/intel.png'}
                    a {href: 'http://www.nvidia.com/Download/index.aspx?lang=en-us'},
                        img {src: vidabody_app_path + 'logos/nvidia.png'}

    if errors_visible.unsupported
        div {id: 'error_unsupported', className: 'error_screen'},
            img {src: vidabody_app_path + 'sad.png'}
            div {className: 'message'},
                h1 {}, 'Rats!'
                span {}, 'It looks like your web browser could use some update. Please click on one of the buttons below to download an up-to-date web browser.'
                div {className: 'buttons'},
                    a {href: 'https://www.google.com/chrome/browser/desktop/'},
                        img {src: vidabody_app_path + 'logos/chrome.png'}
                    a {href: 'https://www.mozilla.org/en-US/firefox/new/'},
                        img {src: vidabody_app_path + 'logos/firefox.png'}
                    if /MSIE /.test(navigator.userAgent)
                        a {href: 'http://windows.microsoft.com/en-us/internet-explorer/download-ie'},
                            img {src: vidabody_app_path + 'logos/msie.png'}
]

# TODO: Change style of elements in the react views instead of using the DOM API

exports.show_context_lost_error = ->
    errors_visible.context_lost = true
    main_view.render_all_views()
    document.getElementById('canvas_container').style.background = '#606060'
    document.getElementById('splash').style.display = 'none'
    document.getElementById('canvas').style.visibility = 'hidden'

exports.hide_context_lost_error = ->
    errors_visible.context_lost = false
    main_view.render_all_views()
    document.getElementById('canvas_container').style.background = 'none'
    if not camera_control?
        document.getElementById('splash').style.display = ''
    else
        document.getElementById('canvas').style.visibility = 'visible'

exports.show_webgl_failed_error = ->
    if window.WebGLRenderingContext?

        userAgent = navigator.userAgent
        # http://www.useragentstring.com/pages/Safari/
        safari = /version\/([^\s]+)\ssafari/i.exec(userAgent)
        if safari and (parseInt(safari[1]) < 8) and not /iP(ad|od|hone)/.test(userAgent)
            errors_visible.disabled_in_safari = true
        else
            errors_visible.blacklisted = true
    else
        errors_visible.unsupported = true
    main_view.render_all_views()
    document.getElementById('canvas_container').style.background = ''
    document.getElementById('splash').style.display = 'none'

exports.show_low_memory_error = ->
    errors_visible.low_memory = true
    main_view.render_all_views()
    document.getElementById('canvas_container').style.background = ''
    document.getElementById('splash').style.display = 'none'
