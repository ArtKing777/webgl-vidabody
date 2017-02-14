
#OLD_TOURS_URL = "http://myou.cat/tmp/common_vida_body_data/tours.json"
OLD_TOURS_URL = "/tours.json"
#OLD_TOURS_URL = "http://127.0.0.1/tours.json"

uuid = require 'node-uuid'
{close_tutorial} = require '../views/tutorials'
{popup_menu} = require '../views/ui_elements'


# Loaded trees
loaded_public_tree = null
loaded_private_tree = null

# copy-pasting of slides of whole tours
slide_group_clipboard = []

empty_tour_tree = ->
    tree = $('.dragonfly-file-tree')[0]
    if not tree
        return
    e = tree.children[1]
    r = []
    while e
        r.append(e)
        e = e.nextSibling
    for e in r
        tree.removeChild(e)

unload_private_tree = ->
    loaded_private_tree = null
    empty_tour_tree()
    load_public_tree()

remove_landing_tour = ->
    
    window.landing_tour = ''
    alert('Landing tour removed. Save settings to make the change effective.')

add_li_to_removed_uuids = (li) ->
    _uuid = (li.folder_data or li.tour_data).uuid
    parent_ul = li.parentNode
    # This may be also the container div which doesn't have folder_data
    parent_li = parent_ul.parentNode
    # If the parent doesn't have folder_data it's the root
    parent_folder_data = parent_li.folder_data or loaded_private_tree
    parent_folder_data.deleted_times[_uuid] = Date.now()

# To be added as click listener to folder labels
_tour_folder_click = (event) ->
    event.stopPropagation?()
    main_view.pause_render(500)

    # TODO messes with rename?
    event.preventDefault?()
    li = @parentNode
    close_tutorial('tours')
    left = event.button == 0
    middle = event.button == 1 and not event.ctrlKey
    # Mac MMB+ctrl means RMB
    right = event.button == 2 or (event.button == 1 and event.ctrlKey)
    ctrl = event.ctrlKey and not event.button == 1
    # Collapsing
    if left and (event.target.tagName != 'ACTION')
        tree = @tree
        if not tree.parentNode.classList.contains('empty')
            closed = tree.classList.contains('closed')
            if not closed
                tree.orig_height = tree.style.height = tree.clientHeight + 'px'
            else
                tree.style.height = tree.orig_height
            f = ->
                tree.style.height = 'auto'
                if not closed
                    tree.orig_height = tree.clientHeight + 'px'
            setTimeout(f, 500)
            f = ->
                tree.classList.toggle('closed')
                tree.parentNode.classList.toggle('closed')
            setTimeout(f, 16)
    
    # Context menu
    else if right
        main_menu_visibility.block()
        element = @parentNode
        folder = this
        label = @querySelector('label')
        folder.classList.add('selected')
        dimiss = ->
            folder.classList.remove('selected')
            main_menu_visibility.unblock()
        add_folder = ->
            li2 = add_tour_folder('New folder', element, true)
            invoke_rename(li2.querySelector('label'))
            li2.classList.add('closed')
            li2.children[1].classList.add('closed')
            li2.classList.add('empty')
            element.classList.remove('closed')
            element.classList.remove('empty')
            save_tour_tree()
        add_tour = ->
            element.classList.remove('closed')
            element.classList.remove('empty')
            add_tour_and_edit(element)
        remove = ->
            main_menu_visibility.unblock()
            add_li_to_removed_uuids(element)
            parent = element.parentNode
            parent.removeChild(element)
            if not parent.children.length
                li2 = parent.parentNode
                li2.querySelector('label').click()
                li2.classList.add('empty')
            save_tour_tree()
        options = [
            {
                'text':'Add new tour',
                'func': add_tour
            },
            {
                'text':'Add sub-folder',
                'func': add_folder
            },
            {
                'text':'Rename',
                'func':() -> invoke_rename(label)
            },
            {
                'icon':'icon_trash.png',
                'text':'Delete',
                'func': remove
            }
        ]
        set_public = ->
            item = li.folder_data or li.tour_data
            item.is_public = true
            item.mtime = Date.now()
            save_tour_tree()
        set_private = ->
            item = li.folder_data or li.tour_data
            item.is_public = false
            item.mtime = Date.now()
            save_tour_tree()
        if vida_body_auth.is_admin and li.parentElement.classList.contains('dragonfly-file-tree')
            if (li.folder_data or li.tour_data).is_public
                options.append({
                    'text':'Remove from public (set private)',
                    'func': set_private
                })
            else
                options.append({
                    'text':'Set as public',
                    'func': set_public
                })
        if tour_editor.can_edit_tours()

            for option in options
                option?.custom_classes = ['icon', 'icon16']

            popup_menu(event.pageX, event.pageY, options, dimiss)

_tour_element_mousedown = (event) ->
    event.stopPropagation and event.stopPropagation()
    close_tutorial('tours')
    
    li = @parentNode
    tour = this
    label = tour.querySelector('label')
    if label.classList.contains('renaming')
        return
    
    li.parentNode.style.overflow = 'visible'
    is_actions = event.target.classList.contains('actions')
    x = y = 0
    
    move = (event, dx, dy) ->
        x += dx
        y += dy
        tour.style.top = y+'px'
        tour.style.left = x+'px'
        # This is added only when dragging
        # so the native menu can be properly prevented
        if dx or dy
            tour.classList.add('no-events')
        
    up = (event) ->
        tour.classList.remove('no-events')
        li.parentNode.style.overflow = ''
        tour.style.top = tour.style.left = 0
        tgt = event.target
        if tgt.tagName == 'ACTION'
            tgt = tgt.parentNode
        if tgt.tagName == 'LABEL' or tgt.classList.contains('actions')
            tgt = tgt.parentNode
        if tgt != tour
            # Dragged and dropped
            old_folder_ul = li.parentNode
            if tgt.classList.contains('tour')
                ul = tgt.parentNode.parentNode
                before = tgt.parentNode
            else if tgt.classList.contains('folder')
                ul = tgt.nextSibling
                before = ul.children[0]
            else
                throw 'Unexpected code path'
            if ul != old_folder_ul
                add_li_to_removed_uuids li
                # The order of the target folder has changed, so we update mtime
                parent_li = ul.parentNode
                if parent_li.folder_data?
                    parent_li.folder_data.mtime = Date.now()
                # The order of the old folder hasn't changed, it just has one less item
            (li.folder_data or li.tour_data).mtime = Date.now()
            ul.insertBefore(li, before)
            ul.parentElement.classList.remove('empty')
            ul.parentElement.classList.remove('closed')
            if old_folder_ul.children.length == 0
                old_folder_ul.parentElement.classList.add('empty')
                old_folder_ul.parentElement.classList.add('closed')
            save_tour_tree()
        else if li.tour_data
            label = li.querySelector('label')
            switch event.target.className
                when 'play'
                    tour_viewer.start(li.tour_data, label.textContent, 0)
                when 'edit'
                    tour_editor.start(li.tour_data, label.textContent)
                when 'menu'
                    _tour_popup_menu(li, tour, event)
            
    modal_mouse_drag(event, move, up)

_tour_popup_menu = (li, tour, event) ->
    main_menu_visibility.block()
    tour.classList.add('selected')
    label = li.querySelector('label')
    dimiss = ->
        tour?.classList.remove('selected')
        if not(tour_viewer.is_viewing() or tour_editor.is_editing())
            main_menu_visibility.unblock()
    remove = ->
        main_menu_visibility.unblock()
        e = tour.parentNode
        add_li_to_removed_uuids li
        parent = e.parentNode
        parent.removeChild(e)
        if not parent.children.length
            li2 = parent.parentNode
            li2.classList.add('empty')
        save_tour_tree()
    edit = ->
        tour?.classList.remove('selected')
        main_menu_visibility.unblock()
        tour_editor.start(li.tour_data, label.textContent)
    view = ->
        tour?.classList.remove('selected')
        main_menu_visibility.unblock()
        tour_viewer.start(li.tour_data, label.textContent)
    search_api_url = ->
        return SEARCH_API + vida_body_auth.email + '/' + li.tour_data.hash + '?token=' + vida_body_auth.token
    add_to_index = ->
        success = ->
            li.tour_data.is_indexed = true
        request('PUT', search_api_url(), success, null,
                {'token': vida_body_auth.token, 'name':label.textContent})
    remove_from_index = ->
        success = ->
            li.tour_data.is_indexed = false
        request('DELETE', search_api_url(), success, null)
    set_as_landing = ->
        
        hash = li.tour_data.hash
        window.landing_tour = hash
        alert('Done. Save settings to make the change effective. You need to do this step again if you modify the tour.')
    options = [
        {
            'icon':'icon_play.png',
            'text':'Play',
            'func': view
        }
    ]
    if tour_editor.can_edit_tours()
        options.append({
            'icon': 'icon_edit.png',
            'text': 'Edit',
            'func': edit
        },
        {
            'text': 'Duplicate',
            'func':() -> copy_tour(li)
        },
        {
            'icon': 'icon_copy.png',
            'text': 'Copy tour slides',
            'func': ->
                slide_group_clipboard = []
                copy_slides = (err, tour_data) ->
                    if err
                        return alert err
                    if (not tour_data.slides) or tour_data.slides.length < 1
                        alert("The tour does not have any slides.")
                        return null
                    slide_group_clipboard = JSON.parse(JSON.stringify(tour_data.slides))
                tour_viewer.load_tour(li.tour_data, copy_slides)
        },
        {
            'text': 'Paste '+slide_group_clipboard.length+' tour slides at the end',
            'func': ->
                paste_slides = (err, tour_data) ->
                    if err
                        return alert err
                    tour_data.slides = tour_data.slides.concat(JSON.parse(JSON.stringify(slide_group_clipboard)))
                    tour_data.hash = ''
                    save_tour_tree()
                tour_viewer.load_tour(li.tour_data, paste_slides)
        } if slide_group_clipboard.length
        {
            'text': 'Rename',
            'func':() -> invoke_rename(label)
        },
        {
            'icon':'icon_trash.png',
            'text': 'Delete',
            'func': remove
        })

    if vida_body_auth.is_admin and li.tour_data.hash
        if not li.tour_data.is_indexed
            options.append({
                'text':'Add to search index',
                'func': add_to_index
            })
        else
            options.append({
                'text':'Remove from search index',
                'func': remove_from_index
            })
        options.append({
            'text':'Set as landing page tour',
            'func': set_as_landing
        })

    for option in options
        option?.custom_classes = ['icon', 'icon16']

    popup_menu(event.pageX, event.pageY, options, dimiss)
    

_root_click = (event) ->
    # Mac ctrl+tap means RMB
    right = event.button == 2 or (event.button == 0 and event.ctrlKey)
    #console.log('_right?', right, event.target, this)

    if event.target == this and right and tour_editor.can_edit_tours()
        main_menu_visibility.block()
        dimiss = ->
            main_menu_visibility.unblock()
        add = ->
            li = add_tour_folder('New folder')
            invoke_rename(li.querySelector('label'))
            li.classList.add('closed')
            li.classList.add('empty')
            li.children[1].classList.add('closed')
            document.getElementById('tour-tree-container').scrollTop = 1000000
            save_tour_tree()

        popup_menu(event.pageX, event.pageY,[
            {
                'text':'Add new tour',
                'func': () -> add_tour_and_edit(null)
            },
            {
                'text':'Add folder',
                'func': add
            }
        ], dimiss)

copy_tour = (li) ->
    parent = li.parentNode
    li2 = li.cloneNode()
    li2.innerHTML = li.innerHTML
    remove_react_ids(li2)
    li2.tour_data = JSON.parse(JSON.stringify(li.tour_data))
    li2.tour_data.uuid = uuid.v4()
    parent.insertBefore(li2, li)
    label = li.querySelector('label')
    label.textContent += ' (copy)'
    invoke_rename(label)
    



init_tour_tree = ->
    tree_root = $('.dragonfly-file-tree')[0]
    if not tree_root
        return
    tree_root.addEventListener('click', _root_click)
    tree_root.addEventListener('contextmenu', _root_click)
    $('#new_tour')[0].addEventListener('click', (() -> add_tour_and_edit()), false)
    $('#new_folder')[0].onclick = click_on_new_folder


# Parent can be a li(which has .folder and ul) or none
# returns new li
add_tour_element = (name, parent) ->
    ul = (parent and parent.children[1]) or document.querySelector('#tour-tree-container > ul')
    ul.parentNode.classList.remove('empty')
    li = document.createElement('li')
    ul.appendChild(li)
    tour = document.createElement('div')
    tour.classList.add('file')
    tour.classList.add('tour')
    label = document.createElement('label')
    tour.appendChild(label)
    label.textContent = name
    actions = document.createElement('actions')
    actions.classList.add('actions')
    tour.appendChild(actions)

    action_play = document.createElement('action')
    action_play.classList.add('play')
    action_play.setAttribute('title', 'play the tour')
    actions.appendChild(action_play)

    action_edit = document.createElement('action')
    action_edit.classList.add('edit')
    action_edit.setAttribute('title', 'edit the tour')
    actions.appendChild(action_edit)

    action_menu = document.createElement('action')
    action_menu.classList.add('menu')
    action_menu.setAttribute('title', 'tour menu')
    actions.appendChild(action_menu)
                
    tour.addEventListener('contextmenu', ((e) -> e.preventDefault()), false)
    tour.addEventListener('mousedown', _tour_element_mousedown, false)
    tour.addEventListener('mousedown', -> close_tutorial('tours'))
    li.appendChild(tour)
    return li

add_tour_and_edit = (parent) ->
    main_menu_visibility.block()
    # Update mtime of parent folder
    (parent?.folder_data or loaded_private_tree).mtime = Date.now()
    li = add_tour_element("New tour", parent)
    li.parentNode.insertBefore(li, li.parentNode.children[1])
    li.tour_data = tour_item()
    tour = li.querySelector('.tour')
    label = tour.querySelector('label')
    f = ->
        tour_editor.start(li.tour_data, label.textContent, 0)
    invoke_rename(label, f)

add_tour_folder = (name, parent, insert = false) ->
    # parent is li
    ul = (parent and parent.children[1]) or document.querySelector('#tour-tree-container > ul')
    ul.parentNode.classList.remove('empty')
    if not ul
        throw "Tour tree not found"
    if ul.tagName != 'UL'
        throw "Parent != a tree"
    li = document.createElement('li')
    if insert
        ul.insertBefore(li, ul.children[1])
    else
        ul.appendChild(li)
    folder = document.createElement('div')
    folder.classList.add('file')
    folder.classList.add('folder')
    li.classList.add('closed')
    label = document.createElement('label')
    folder.appendChild(label)
    label.textContent = name
    actions = document.createElement('actions')
    actions.classList.add('actions')
    folder.appendChild(actions)

    action_menu = document.createElement('action')
    action_menu.classList.add('menu')
    action_menu.setAttribute('title', 'folder menu')
    actions.appendChild(action_menu)

    action_menu.onclick = (event) ->
        event.stopPropagation()
        _tour_folder_click.call(folder, {
            'button': 2,
            'pageX': event.pageX,
            'pageY': event.pageY,
        })
        
    new_ul = document.createElement('ul')
    new_ul.classList.add('closed')
    li.appendChild(folder)
    li.appendChild(new_ul)
    li.folder_data = tour_folder_item()
    folder.tree = new_ul
    folder.addEventListener('mousedown', _tour_folder_click)
    folder.addEventListener('mousedown', -> close_tutorial('tours'))

    folder.addEventListener('contextmenu', ((e) -> e.preventDefault()), false)
    return li


invoke_rename = (element, post_rename_callback) ->
    element.classList.add('renaming')
    old_content = element.textContent
    element.innerHTML = '<div contenteditable="true"></div>'
    element.firstChild.textContent = old_content
    
    finish_rename = ->
        element.classList.remove('renaming')
        element.contentEditable = false
        element.textContent = element.textContent or old_content
        window.getSelection().removeAllRanges()
        element.removeEventListener('click', stop_propagation, true)
        element.removeEventListener('contextmenu', stop_propagation, true)
        element.removeEventListener('keydown', keydown)
        element.removeEventListener('keyup', keydown)
        post_rename_callback and post_rename_callback(element)
        main_menu_visibility.unblock()
        save_tour_tree()
        document.body.removeEventListener('mousedown', out_mousedown, true)
        document.body.removeEventListener('mouseup', out_mouseup, true)
        
    keydown = (event) ->
        if event.keyCode == 13 # Enter
            event.preventDefault()
            finish_rename()
        else if event.keyCode == 27 # Esc
            element.textContent = old_content
            finish_rename()
    
    stop_propagation = (event) ->
        event.stopPropagation()
    
    out_mousedown = (event) ->
        #event.preventDefault()
        event.stopPropagation()

    out_mouseup = (event) ->
        if event.target != element and event.target.parentNode != element
            finish_rename()
        #event.preventDefault()
        event.stopPropagation()
        
    
    document.body.addEventListener('mousedown', out_mousedown, true)
    document.body.addEventListener('mouseup', out_mouseup, true)
    element.addEventListener('click', stop_propagation, true)
    element.addEventListener('contextmenu', stop_propagation, true)
    element.addEventListener('keydown', keydown)
    element.addEventListener('keyup', keydown)
    r = document.createRange()
    r.selectNodeContents(element.firstChild)
    s = window.getSelection()
    s.removeAllRanges()
    s.addRange(r)
    element.firstChild.focus()
    


click_on_new_folder = (event) ->
    tour_tree_container = document.getElementById('tour-tree-container')
    nf = add_tour_folder('New Folder', null, true)
    nf.classList.add('empty')
    invoke_rename(nf.querySelector('label'))
    nful = nf.children[1]
    nf.classList.add('closed')
    nful.classList.add('closed')
    tour_tree_container.scrollTop = 0
    


save_tour_tree = (->
  all_finished = null
  (only_tours, callback) ->
    if not vida_body_auth.logged_in
        file_manager.set_message('Warning: tours are not saved unless you log in')
        file_manager.show_popup(true)
        file_manager.hide_delayed(4000)
        # TODO
        # * store data in localStorage, restore on load
        # * improve warning
        # * when user logs in, execute save_tour_tree()
        # * delete localStorage or flag it as user backup
        return
    # loop for saving unsaved tours
    # then callback of all finished, use serialize_tour_tree
    tour_elements = document.querySelectorAll('#tour-tree-container .tour')
    any_modified_tour = false
    for tour in tour_elements
        li = tour.parentNode
        if not li.tour_data.hash
            f = (tour_data) ->
                mtime = tour_data.mtime
                return (hash_obj) ->
                    # If it was saved twice and this was the old one, ignore
                    if tour_data.mtime > mtime
                        return
                    
                    # Set old_hash as well to make "exit without saving" work
                    # in the case the editor was re-entered before it finished saving
                    tour_data.hash = tour_data.old_hash = hash_obj.hash
                    
                    # if this tour has an icon, copy it to local storage
                    if tour_data.icon
                        icons = JSON.parse(localStorage.getItem('tour-icons') or '{}')
                        icons[tour_data.hash] = tour_data.icon
                        localStorage.setItem('tour-icons', JSON.stringify(icons))

            li.tour_data.path = li.textContent
            file_manager.save_tour(li.tour_data, f(li.tour_data))
            any_modified_tour = true
    if any_modified_tour or not only_tours
        if all_finished
            file_manager.remove_finished_listener(all_finished)
        all_finished = ->
            loaded_private_tree.children = serialize_tour_tree()
            file_manager.upload_data_root({'private_tours': loaded_private_tree, 'snapshots': snapshots})
            #file_manager.add_finished_listener ->
            #    request('POST', SERVER_BASE + 'public_tree/rebuild', (->), null, {token: vida_body_auth.token})
            if tour_viewer.viewing and tour_viewer.tour_data.hash
                hash = '#tour='+tour_viewer.tour_data.name.replace(/@/g,'')\
                .replace(/\x20/g,'%20')\
                +'@'+tour_viewer.tour_data.hash
                if history.replaceState then history.replaceState('','',hash) else location.hash = hash
                window.prev_hash = location.hash
        if any_modified_tour
            file_manager.add_finished_listener(all_finished)
        else
            all_finished()
    # else: no need to save anything
)()

load_tour_tree = (hash=vida_body_auth.data_root_hash) ->
    # This hash is sha256 for "{}", which used to be the default value in the DB
    if hash == '44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a' or hash == ''
        loaded_private_tree = {}
        console.log "There's no user data yet."
        return
    load = (data) ->
        if data

            if data.private_tours
                loaded_private_tree = convert_tour_tree data.private_tours
                update_tour_tree()
            else
                loaded_private_tree = tour_folder_item()
            if data.snapshots
                window.snapshots = data.snapshots
                update_snapshots_list()
    error = (xhr) ->
        console.log "Unexpected error when loading tour list:", xhr.status, xhr.response
    request_json('GET', FILE_SERVER_DOWNLOAD_API + hash, load, error)


load_public_tree = ->
    # load_public_tree and load_tour_tree can be called
    # any number of times in any order
    # in any case they will merge
    # as long as there's a loaded_private_tree
    load = (data) ->
        if data
            data = JSON.parse(data)
            if data.type == 'folder'
                loaded_public_tree = data
                update_tour_tree()
            else
                console.error 'Incorrect public tour tree format'
    error = (xhr) ->
        console.log "Unexpected error when loading tour list:", xhr.status, xhr.response
    request('GET', FILE_SERVER_DOWNLOAD_API + 'public_tree?' + Math.random(), load, error)

update_tour_tree = ->
    empty_tour_tree()
    deserialize_tour_tree(merge_tour_trees(loaded_public_tree, loaded_private_tree))
    update_tour_tree_icons()

serialize_tour_tree = (ul=document.querySelector('#tour-tree-container > .dragonfly-file-tree')) ->
    ret = []
    for li in ul.children
        fc = li.firstElementChild
        if li.tagName != 'LI'
            # FIXME: the <ul> shouldn't have non <li> children
            continue
        if fc.classList.contains('tour')
            li.tour_data.name = li.textContent
            ret.append(get_tour_item_without_data(li.tour_data))
        else if fc.classList.contains('folder')
            li.folder_data = tour_folder_item(li.folder_data)
            li.folder_data.name = fc.textContent
            e = li.folder_data
            e.children = serialize_tour_tree(fc.nextSibling)
            ret.append e
        else
            throw "Error"
    return ret

deserialize_tour_tree = (data, parent_li=null) ->
    if not data.children?
        data.children = []
    for e in data.children
        e.uuid = e.uuid or uuid.v4()
        e.mtime = e.mtime or Date.now()
        if e.type=='tour'
            li = add_tour_element(e.name, parent_li)
            li.tour_data = e
        else if e.type=='folder'
            li = add_tour_folder(e.name, parent_li)
            li.folder_data = e
            deserialize_tour_tree(e, li)
            if e.children.length == 0
                li.classList.add 'empty'
        else
            throw "Error "+e.type


update_tour_tree_icons = ->
    ul = document.querySelector('#tour-tree-container > ul')

    for li in ul.querySelectorAll('li')
        if li.tour_data
            div = li.children[0]
            icon = li.tour_data.icon
            if not icon
                icon = (JSON.parse(localStorage.getItem('tour-icons') or '{}'))[li.tour_data.hash]

            div.style.backgroundImage = if icon then 'url(' + icon + ')' else ''

copy_tree = ->
    prompt('Please copy the tree hash', vida_body_auth.data_root_hash)

paste_tree = ->
    hash = prompt('Paste the tree hash here')
    if hash
        request_json 'GET', FILE_SERVER_DOWNLOAD_API + hash, (data) ->
            loaded_private_tree.children = serialize_tour_tree()
            loaded_private_tree = merge_tour_trees(loaded_private_tree, data.private_tours)
            update_tour_tree()


tour_tree_functions = {remove_landing_tour, copy_tree, paste_tree, add_tour_element}

for k,v of tour_tree_functions
    exports[k] = v
