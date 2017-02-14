

# jQuery/Zepto alternative

if not $?
    $ = document?.querySelectorAll.bind(document)

remove_react_ids = (element) ->
    element.removeAttribute('data-reactid')
    for c in element.children
        remove_react_ids(c)

# template(selector) returns a deep copy of an element and adds it to a parent,
# returns an object with the element as 'root'
# and the children as the class name, e.g.
# <div><span class="some-thing"></span></div> becomes
# { 'root': div, 'some_thing': span }
template = (selector, parent) ->
    orig = $(selector)[0]
    element = orig.cloneNode()
    element.removeAttribute('id')
    element.innerHTML = orig.innerHTML
    remove_react_ids(element)
    elements = {'root': element}
    for e in element.querySelectorAll('*')
        c = e.classList.item(0)
        if c
            elements[c.replace('-','_')] = e
    
    parent.appendChild(element)
    
    return elements


class Timer
    constructor: (time, onstart, onfinish) ->
        @time = time
        @onstart = onstart
        @onfinish = onfinish
        @_timer = null
    
    start: () ->
        clearTimeout(@_timer)
        @_timer = setTimeout(@onfinish, @time)
        @onstart()
    
    stop: () ->
        clearTimeout(@_timer)


# The following "modal" functions adds a listener to be used only once,
# stopping all other listeners to run.
# They're meant to be used with the outermost element of the app
# (check event.target to know where the user clicked)

# TODO: deal with multiple callspopup_menu_modal?

exports.modal_mouse_click = modal_mouse_click = (ondown, onmove, onup, target=window) ->
    no_move = (event) ->
        event.preventDefault()
        event.stopPropagation()
    f = (event) ->
        event.preventDefault()
        event.stopPropagation()
        target.removeEventListener('mousemove', no_move, true)
        ondown and ondown(event)
        modal_mouse_drag(event, onmove, onup, target)
    modal_mouse_down(f, target)
    target.addEventListener('mousemove', no_move, true)
    
exports.modal_mouse_down = modal_mouse_down = (ondown, target=window) ->
    f = (event) ->
        event.preventDefault()
        event.stopPropagation()
        target.removeEventListener('mousedown', f, true)
        ondown(event)
    # useCapture=true == the key in these functions
    # make sure you never set useCapture on the target anywhere else
    target.addEventListener('mousedown', f, true)
    
exports.modal_mouse_drag = modal_mouse_drag = (down_event, onmove, onup, target=window) ->
    px = down_event.pageX
    py = down_event.pageY
    move = (event) ->
        
        event.preventDefault()
        event.stopPropagation()
        dx = event.pageX - px
        dy = event.pageY - py
        px = event.pageX
        py = event.pageY
        onmove and onmove(event, dx, dy)
    up = (event) ->
        event.preventDefault()
        event.stopPropagation()
        target.removeEventListener('mousemove', move, true)
        target.removeEventListener('mouseup', up, true)
        onup and onup(event)
    target.addEventListener('mousemove', move, true)
    target.addEventListener('mouseup', up, true)

# TODO: replace by templates or virtual-dom
new_div_class = (class_name, parent=document.body) ->
    div = document.createElement('div')
    div.classList.add(class_name)
    parent.appendChild(div)
    return div


pick_color = ->
    picker = document.getElementById('hidden_color_picker')
    if not picker
        picker = document.createElement('input')
        picker.setAttribute('type', 'color')
        picker.setAttribute('id', 'hidden_color_picker')
        picker.style.position = 'absolute'
        picker.style.top = '-1000px'
        document.body.appendChild(picker)
    picker.click()


on_click_outside = (element, callback, ignoreElement) ->
    watcher = (e) ->
        p = e.target
        while p != document.body
            if p == element
                # the click was not outside
                return true
            if ignoreElement and ignoreElement(p)
                # ignore clicks here
                return true
            p = p.parentNode
        # outside, if here
        if callback
            callback(e)
        # we're done
        document.body.removeEventListener('mousedown', watcher)
        return true
    document.body.addEventListener('mousedown', watcher)

screenshot = ->
    canvas = document.getElementById('canvas')
    w = canvas.width
    h = canvas.height
    return thumbnail_maker.getDataURL(w, h, scene.background_color, 'image/jpeg', { 'progressive' : true })

click_to_add_anchor = (before, during, after) ->
    $('#app')[0].classList.add('annotation_line_hint')

    before()

    mouse_move = (event) -> during event

    mouse_dn = (event) -> event.stopPropagation()

    mouse_up = (event) ->
        $('#app')[0].classList.remove('annotation_line_hint')

        after event

        window.removeEventListener('mousemove', mouse_move, false)
        window.removeEventListener('mousedown', mouse_dn, true)
        window.removeEventListener('mouseup', mouse_up, true)
        event.stopPropagation()

    window.addEventListener('mousemove', mouse_move, false)
    window.addEventListener('mousedown', mouse_dn, true) # must be true to cancel selection events
    window.addEventListener('mouseup', mouse_up, true)
