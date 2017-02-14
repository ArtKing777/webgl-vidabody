
React = require 'react'

{div, span, p, a, ul, li, img, h1, h2, h3, em, strong
canvas, pre, iframe, br,
form, input, label, button, datalist, option, optgroup,
svg, defs, linearGradient, stop} = React.DOM
cx = require 'classnames'

old_modules = require '../tmp/old_modules'
DOUBLE_CLICK_MS = 300
# main_view is required at the end of the file to avoid
# cyclic dependency shenanigans

# NOTE: popup_menu could be modified to use the modal_* functions
# instead of #popup_menu_modal

ppm = {
    items:[]
    x:0
    y:0
    dimiss_func:null
    id:''
    time: 0
    }

popup_menu = (x=0, y=0, items=[], dimiss_func=null, id='')->
    id = id + Math.random()
    # Avoid re-drawing when there are no menus
    if ppm.items.length == 0 and items.length == 0
        return
    ppm = {items, x, y, dimiss_func, id, time: Date.now()}
    requestAnimationFrame(main_view.render_all_views)
    requestAnimationFrame(main_view.render_all_views)

render_menu = (menu, filter=menu.filter) ->
    render_item = true
    filter = filter?.toLowerCase().replace(/\W/g, ' ').replace(/^ +/, '').replace(/ +$/, '')
    for i in menu.items
        if not i or i.text == "Unclassified" or (not old_modules.tour_editor?.editing and i.orig_text == 'Alternatives')
            continue
        if filter and not i.avoid_filter
            render_item = false
            if i.text.toLowerCase().replace(/\W/g, ' ').indexOf(filter) != -1
                render_item = true
            for c in get_all_children(i)
                text = c.text.toLowerCase().replace(/\W/g, ' ')
                if render_item
                    break
                if text.indexOf(filter) != -1
                    render_item = true
        if render_item
            render_menu_item(i,filter)
        else
            continue

get_base_children = (item,force_recalc)->
    if item.base_children? and not force_recalc
        return item.base_children
    children = []
    if item.submenu
        for i in item.submenu.items
            if i.submenu
                children = children.concat(get_base_children(i,force_recalc))
            else
                children.append(i)
    item.base_children = children
    return children

get_all_children = (item, force_recalc) ->
    if item.all_children? and not force_recalc
        return item.all_children
    children = []
    if item.submenu?
        children = children.concat(item.submenu.items)
        for i in item.submenu.items
            children = children.concat(get_all_children(i, force_recalc))
    item.all_children = children
    return children

close_all_submenus = (menu)->
    if not menu.items?
        return
    for i in menu.items
        i.submenu?.unfolded = false
        i.unfolded = false
        for c in get_all_children(i)
            c.submenu?.unfolded = false
            c.unfolded = false

render_menu_item = (i,filter)->
    #Common item things:
    properties={
        id: i.id or 'item' + Math.random()
        className: cx
            'item':true
            'icon':i.icon
            'disabled':i.disabled
        style: if i.icon
                backgroundImage: 'url('+ vidabody_app_path + i.icon + ')'
                backgroundSize: i.backgroundSize or ''
                backgroundPositionX: i.backgroundPositionX or ''
                backgroundPositionY: i.backgroundPositionY or ''
            else
                backgroundImage: 'none'
    }
    if 'title' of i
        properties.title = i.title
    if "custom_classes" of i
        for c in i.custom_classes
            properties.className += " " + c
    content=[]
    if i.action
        a = i.action
        a_properties = {className: 'action'}
        a_content = []
        if typeof(a) == 'function'
            a_properties.style = backgroundImage: 'None'
            a_content = a()
        else
            a_properties.id = a.id
            a_properties.title = a.title
            a_properties.onMouseUp = (e)->
                e.stopPropagation()
                a.func(e)
            a_properties.style = {backgroundImage:'url('+vidabody_app_path+a.icon+')'}
        content.append(div(a_properties, a_content))

    #Rendering item using its related rendering functions
    if i.max_width
        properties.style['max-width'] = i.max_width
    if i.min_width
        properties.style['min-width'] = i.min_width

    if i.type == 'slider'
        content.append(render_slider(i))
    else if i.type == 'switch'
        content.append(render_switch(i))
    else if i.type == 'file_input'
        content.append(render_file_input(i))
    else if i.type == 'text_input'
        content.append(render_text_input(i))
        properties.className += ' text_input_item'

    #Rendering items with particularities of the popup_menus
    else if i.parent_menu?.type == 'popup_menu'
        render_popup_menu_item(content,properties, i, filter)

    #Rendering standard item
    else
        text = i.text
        properties.onMouseUp = (e)->
            # Mac ctrl+tap means RMB
            right = e.button == 2 or (e.button == 0 and e.ctrlKey)
            if right
                i.func(e)
            else if 'dbclick_func' of i
                f = ->
                    i.func(e)
                    i.mu_timeout = null
                    requestAnimationFrame(main_view.render_all_views)
                if i.mu_timeout
                    clearTimeout(i.mu_timeout)
                    i.mu_timeout = null
                    i.dbclick_func(e)
                    requestAnimationFrame(main_view.render_all_views)

                else
                    i.mu_timeout = setTimeout(f, DOUBLE_CLICK_MS)
            else
                i.func(e)
            e.stopPropagation()
        properties.className += ' ' + i.type
        if i.submenu
            do (i)->
                properties.onMouseUp = (e)->
                    # Mac ctrl+tap means RMB
                    right = e.button == 2 or (e.button == 0 and e.ctrlKey)
                    if right
                        i.func(e)
                    else if 'dbclick_func' of i
                        f = do(i)->->
                            i.unfolded = not i.unfolded
                            main_view.pause_render(500)
                            i.mu_timeout = null
                            requestAnimationFrame(main_view.render_all_views)

                        if i.mu_timeout
                            clearTimeout(i.mu_timeout)
                            i.mu_timeout = null
                            i.dbclick_func(e)
                            requestAnimationFrame(main_view.render_all_views)
                        else
                            i.mu_timeout = setTimeout(f, DOUBLE_CLICK_MS)
                    else
                        i.unfolded = not i.unfolded
                        main_view.pause_render(500)
                        requestAnimationFrame(main_view.render_all_views)
                    e.stopPropagation()

            if i.unfolded
                content.append(div({className:'item_name', id:i.id+'#name'},text))
                menu = render_menu(i.submenu, filter)
                if menu.length == 0
                    menu = render_menu(i.submenu, '')
                content.append(ul({className:'menu submenu unfolded', id:i.id+'#submenu'}, [menu]))
                properties.className += ' unfolded'
                properties.style.backgroundImage = 'url('+vidabody_app_path+i.icon_unfolded+')'
            else
                content.append(div({className:'item_name', id:i.id+'#name'},text))
                content.append(ul({className:'menu submenu', id:i.id+'#submenu'}))
                properties.style.backgroundImage = 'url('+vidabody_app_path+i.icon_folded+')'
        else
            content.append(div({className:'item_name'},text))
        if i.disabled
            properties.onMouseUp = (e)-> e.stopPropagation()

    return li(properties,content)

render_popup_menu_item = (content, properties, i, filter)->
    #content and properties are common to all items
    content.append(i.text)
    if not i.submenu?
        do (i) ->
            click_closure = null
            properties.onMouseUp = (e) ->
                if click_closure
                    click_closure(e)
            properties.onMouseDown = ->
                if not click_closure
                    click_closure = (e) ->
                        i.func?(e)
                        if not i.prevent_default
                            popup_menu()
        if i.disabled
            properties.onMouseUp = (e)-> e.stopPropagation()
        return li(properties, content)

    item_mouse_enter = (item)->
        if item.parent_menu?.main_menu.blocked
            return
        for i in item.parent_menu.items
            if i
                i.unfolded = false
        item.unfolded = true
        requestAnimationFrame(main_view.render_all_views)
        requestAnimationFrame(main_view.render_all_views)

    properties.className += ' submenu'
    properties.onMouseUp = (e)->
        e.stopPropagation()
    properties.onMouseEnter = do (i) -> -> item_mouse_enter(i)
    if i.icon_unfolded
        properties.style.backgroundImage = 'url(' + i.icon_unfolded + ')'
        if not i.icon_folded
            throw("icon_folded isn't specified")
    if i.unfolded
        if not i.popup_submenu?
            i.popup_submenu = {
                items:i.submenu
                x:0
                y:0
                dimiss_func: null
                parent_menu:i.parent_menu
                parent_item:i
                id:i.parent_menu.id + '/' + i.id or i.text
            }
        content.append(render_popup_menu(i.popup_submenu, filter))
    if i.disabled
        properties.onMouseUp = (e)-> e.stopPropagation()
    return li(properties,content)

render_popup_menu = (menu=ppm, filter=ppm.filter)->
    menu.type = 'popup_menu'
    if not menu.items.length
        return

    if menu.parent_menu
        menu.main_menu = menu.parent_menu.main_menu
    else
        menu.main_menu = menu

    dimiss = (e) ->
        e.preventDefault()

        if e.target != e.currentTarget
            return
        ppm.dimiss_func?()
        popup_menu()

    element = document.getElementById(menu.id)
    if element? and not menu.relocated
        sx = document.body.clientWidth
        sy = document.body.clientHeight
        menu.width = w = element.clientWidth
        parent_menu = menu.parent_menu
        if parent_menu?
            menu.x += parent_menu.width
        h = element.clientHeight
        l = element.getClientRects()[0].left
        t = element.getClientRects()[0].top
        if (l+w) > sx
            menu.x = - menu.x
        if (t+h) > sy
            menu.y += sy - (t + h)
        menu.relocated = true

    # workaround for chrome css issue
    requestAnimationFrame ->
        for s in document.querySelectorAll('.switch')
            s.style.width = 'auto'
    for i in menu.items
        if not i
            continue
        i.parent_menu = menu
    div
        className: 'popup_menu_modal'
        onMouseUp: if not menu.parent_item? then dimiss else null
        onContextMenu: (e) ->
            e.preventDefault()
            return
        style:if menu.parent_item? then {'width':'0px','heigth':'0px'}
        ul
            className:'menu popup_menu'
            id:menu.id
            style:
                position:'absolute'
                left: menu.x
                top: menu.y


            render_menu(menu, filter)




render_slider = (slider)->
    error = false
    if not slider.moving and slider.read
        slider.value = slider.read()
        if slider.value !=0 and not slider.value
            error = true

    text = ''
    if slider.text
        text = slider.text + ': '

    v = if not error then slider.value else 0
    if slider.value_type == 'int'
        v = Math.floor(v)
        value_text = text + v + ' ' + slider.unit
    else if slider.digits
        value_text = text + v?.toFixed(slider.digits) + ' ' + slider.unit
    else
        value_text = text + v?.toFixed(1) + ' ' + slider.unit

    div
        id: slider.id
        title: value_text
        className: cx
            'slider':true
            'disabled':error or slider.disabled
        div {className: 'value-box' },
            span {className:'value'}, value_text
        div
            className: 'sensor',
            onMouseDown: (event)-> slider_controller(event, slider)
            div {className: 'container'},
                div {className: 'progress', style: width: v * 100 / slider.max + '%'}
                div {className: 'handle'}


slider_controller = (event, slider)->
    rect = event.target.getClientRects()[0]
    d_factor = slider.max/rect.width
    event.target.block_onup = false

    constraint = (slider)->
        if slider.soft_max?
            slider.value = Math.min(slider.value, slider.soft_max)
        else
            slider.value = Math.min(slider.value, slider.max)
        if slider.soft_min?
            slider.value = Math.max(slider.value, slider.soft_min)
        else
            slider.value = Math.max(slider.value, slider.min)

    onup = (event)->
        event.stopPropagation()
        if not slider.moving
            slider.value = (event.pageX - rect.left)*d_factor or 0
            constraint(slider)
        if slider.onup
            if slider.value_type == 'int'
                slider.write?(Math.floor(slider.value))

            else
                slider.write?(slider.value)
        if slider.onup_func
            slider.onup_func()
        slider.parent_menu.main_menu.blocked = false
        slider.moving = false
        main_view.render_all_views()
        main_loop.reset_timeout()

    onmove = (event, x, y)->
        event.stopPropagation()
        slider.parent_menu.main_menu.blocked = true
        slider.moving = true
        slow = if keys_pressed[KEYS.SHIFT] then 0.1 else 1
        slider.value += x * d_factor * slow
        slider.value = slider.value or 0
        if slider.step
            # we can not round value by step directly
            # because d_factor may not apply (always rounded my step)
            # so I am using real_value for storing not rounded value
            slider.real_value = slider.real_value or slider.value
            slider.real_value += x * d_factor * slow
            slider.value = Math.round(slider.real_value / slider.step) * slider.step
        constraint(slider)
        if slider.onmove
            if slider.value_type == 'int'
                v = Math.floor(slider.value)
                if v != slider.last_value
                    slider.write?(v)
                    slider.last_value = v
            else
                slider.write?(slider.value)

        main_view.render_all_views()
        main_loop.reset_timeout()

    old_modules.modal_mouse_drag(event, onmove, onup)


load_file_on_tour = (e)->

    aui = e.currentTarget
    if aui != e.target
        return
    tour_editor = old_modules.tour_editor

    set_audio_hash = (num_slide, hash, name) =>
        fmt = name.split('.').slice(-1)[0].toLowerCase()
        tour_editor.slides[num_slide].audio_hash = hash
        tour_editor.slides[num_slide].audio_format = fmt
        tour_editor.slides[num_slide].audio_name = name
        if num_slide == tour_editor.current_slide
            tour_editor.load_audio()

    add_image = (hash, index) =>
        loc_img = new old_modules.TransformableImage()
        loc_img.set_image(hash)
        loc_img.move(index*16, index*16)
        tour_editor.save_state()

    add_flash = (hash, index) =>
        loc_img = new old_modules.TransformableFlash()
        loc_img.set_flash(hash)
        loc_img.move(index*16, index*16)
        tour_editor.save_state()

    for file in aui.files
        if file.size > 20971518 and not file.name.toLowerCase().endswith('.assets')
            if aui.files.length > 1
                msg = 'One of the files is too big.'
            else
                msg = 'The file is too big.'
            alert msg + ' Max file size is 20 MB.'
            return

    if aui.files.length and aui.files[0].type.startswith('image')
        for i in [0...aui.files.length]
            old_modules.file_manager.upload_blob(aui.files[i],
                ((i) -> (h) -> add_image(h.hash, i))(i)
            )
    else if aui.files.length and aui.files[0].name.toLowerCase().endswith('.assets') and old_modules.auth.is_admin
        # Uploading an .assets file, it assumes it contains a folder with assets
        # with the same name as the file, LOWER CASE!
        for file in aui.files when file.name.toLowerCase().endswith('.assets')
            old_modules.file_manager.upload_assets(file)
        if aui.files.length == 1
            old_modules.file_manager.add_finished_listener ->
                tour_editor.tour_data.assets_version = aui.files[0].name.toLowerCase()[...-7]
                tour_editor.tour_data.hash = ''
    else if aui.files.length and aui.files[0].name.toLowerCase().endswith('.swf')
        for i in [0...aui.files.length]
            old_modules.file_manager.upload_blob(aui.files[i],
                ((i) -> (h) -> add_flash(h.hash, i))(i)
            )
    else if aui.files.length == 1
        name = aui.files[0].name
        current = tour_editor.current_slide
        old_modules.file_manager.upload_blob(aui.files[0],
            (h) -> set_audio_hash(current, h.hash, name))

    else if aui.files.length
        current = tour_editor.current_slide
        num_slides = tour_editor.slides.length
        limit = Math.min(current + aui.files.length, num_slides)
        upload_all = (replace) ->
            files = list(aui.files)
            compare = (a,b) ->
                if a.name < b.name
                    return -1
                if a.name > b.name
                    return 1
                return 0
            files = files.sort(compare)
            for i in [current... limit]
                name = files[i-current].name
                old_modules.file_manager.upload_blob(files[i-current],
                    ((i,name) -> (h) -> set_audio_hash(i, h.hash, name))(i,name)
                )
        popup_menu(mouse.page_x, mouse.page_y, [
            {'text':'Set each audio file in sucessive slides(replace existing)',
            'func': () -> upload_all(true)},
            #{'text':'Set each audio file in sucessive slides(skip existing)',
            #'func': () -> upload_all(false)},
            {'text':'Cancel',
            'func': () -> 0},
        ])
    main_view.render_all_views()

render_text_input = (item)->
    item.id = item.id or 'text_input'+Math.random()
    clear = (target)->
        target.value = ''
        item.show_clear_button = false
        item.write('')
        if item.write_timeout
            clearTimeout(item.write_timeout)
            item.write_timeout = null
        item.write_timeout = setTimeout(main_view.render_all_views, 200)

    div {id: item.id,className: 'text_input'},
        input {
            id: item.id+'#input'
            title: item.title
            placeholder: item.default_text or ''
            autoComplete: (item.autocomplete and 'on') or 'off'
            onChange: (e)->
                if item.write_timeout
                    clearTimeout(item.write_timeout)
                    item.write_timeout = null

                item.write(e.currentTarget.value)
                if e.currentTarget.value
                    item.show_clear_button = true
                else
                    item.show_clear_button = false
                item.write_timeout = setTimeout(main_view.render_all_views, 200)
                e.stopPropagation()
                e.preventDefault()
            onKeyUp: (e)->
                if e.keyCode == 27
                    clear(e.currentTarget)
                e.stopPropagation()
                e.preventDefault()
            },



        img
            className:cx
                clear_button:true
                show_clear_button:item.show_clear_button
            id:input.id+'#clear_button'
            src: vidabody_app_path+"x-mark.png"
            title: 'Clear text'
            onMouseUp: (e)->
                box = e.currentTarget.parentElement.children[0]
                clear(box)
                box.focus()


render_file_input = (file)->
    d = (e)->
        e.stopPropagation()
        file.delete_file()
        main_view.render_all_views()

    if file.file_type == 'image'
        div {className: 'file-input', key:'b'},
            input {type: 'file', multiple: 'multiple', onChange:file.load}

    else if file.file_type == 'audio'
        data = file.read()
        name = data?.name
        if data?.hash
            duration = data?.properties.duration
            if not duration?
                duration = '-'
            else
                duration += 's'

            if name
                if name.length > 25
                    title = name
                    name = name[0...17] + '...' +name.split('.').pop()
                else:
                    title = ''
            else
                title = ''
                name = 'No Audio File'
            div {className: 'file-input', key:'a'},


                input {className: 'panel-button', type: 'button', value: 'X', onClick: d, title: "Delete audio file"}
                div {className: 'audio-props', title:title},
                    'Name: '
                    span {className:'data', id: 'audio-name'}, name
                    br()
                    'Duration: '
                    span {className:'data', id: 'audio-length'}, duration
        else

            div {className: 'file-input', key:'b'},
                input {type: 'file', multiple: 'multiple', onChange:file.load}

test_state = 0


render_switch = (switch_) ->
    if switch_.read
        switch_.state = switch_.read()
    div
        className: cx
            'switch':true
            'non-labeled':not switch_.text
        id: switch_.id
        onMouseUp: (e)-> switch_controller(switch_,e)
        title: switch_.title or switch_.text
        div {className: 'container'},
            div
                className: 'button'
                style:
                    marginLeft: (switch_.state*(100/(switch_.states-1)))*0.5 - 50 + '%'
                div {className: 'handle'}
        if switch_.text
            div {className: 'text'},switch_.text

switch_controller = (switch_,e)->
    e.stopPropagation()
    if switch_.read
        switch_.state = switch_.read()
    switch_.state +=1
    if switch_.state > switch_.states - 1
        switch_.state = 0
    switch_.write?(switch_.state)
    main_view.render_all_views()

module.exports = {popup_menu, render_popup_menu, load_file_on_tour, render_menu_item, render_menu, render_switch, render_slider, close_all_submenus, get_base_children, get_all_children}

main_view = require './main_view'
