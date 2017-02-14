ui_elements = require './ui_elements'
old_modules = require '../tmp/old_modules'
main_view = require './main_view'
ORGAN_TREE_MENU = ORGAN_TREE_MENU = {}
SYNONYMS = SYNONYMS = {}
init_organ_tree = ->
    xhr = new XMLHttpRequest
    xhr.open('GET', old_modules.ASSETS_BASE + old_modules.ASSETS_VERSION + '/organ_tree.json', true)
    xhr.onload = ->
        otjson = JSON.parse(xhr.response)
        if explore_mode_systems?.length
            alts = []
            otjson.tree = for e in otjson.tree
                if e.name in explore_mode_systems
                    e
                else
                    alts.push e
                    continue
            otjson.tree.push {name: 'Alternatives', children: alts}
        ORGAN_TREE = ot = otjson.tree
        SYNONYMS = otjson.synonyms
        convert_to_menu = (tree, parent_item)->
            menu = {}
            menu.type = 'foldable_tree'
            menu.unfolded = false
            menu.parent_item = parent_item
            menu.parent_menu = null
            if parent_item
                menu.parent_menu = parent_item.parent_menu
                menu.id = parent_item.id
            else
                menu.id = 'ORGAN_TREE'
            menu.items = []
            for i in tree
                item = {}
                item.text = item.orig_text = i.name
                item.id = menu.id + '/' + item.text
                item.title = item.id.replace('ORGAN_TREE/','')
                item.type = 'organ'
                item.parent_menu = menu
                item.parent_item = parent_item
                item.visibility_state = 0
                item.icon_unfolded = "colapsable.png"
                item.icon_folded = "expandible.png"
                item.action = do (item)-> ->
                    s = {
                        type: 'switch',
                        states : 3,
                        state: 0,
                        id:'visibility_state',
                        read: do(item)-> ->read_item_visibility_state(item)
                        write: do(item)->(v)->write_item_visibility_state(item,v)
                        title: 'Click to change visibility'
                        }
                    ui_elements.render_switch(s)

                item.dbclick_func = do (item)-> (e)->
                    if not old_modules.tour_editor.is_editing()
                        organs = get_filtered_organs(item)
                        if organs.length
                            norgans = for o in organs then o.name
                            old_modules.go_here(norgans)

                if i.children.length
                    item.submenu = convert_to_menu(i.children,item)
                item.objnames = i.objnames or []
                item.func = do (item)-> (e)->
                    # When it has submenu, this function is not called with button 1 anyway
                    # Mac ctrl+tap means RMB
                    right = e.button == 2 or (e.button == 0 and e.ctrlKey)
                    if right
                        ui_elements.popup_menu(e.pageX, e.pageY, old_modules.selection_menu(get_filtered_organs(item)))

                for oname in item.objnames
                    visible_name = item.text.replace('- ', '')
                    existing_vis_name = old_modules.ORGAN_VISIBLE_NAMES[oname]
                    if not existing_vis_name
                        old_modules.ORGAN_LIST.append(oname)
                    else if existing_vis_name != visible_name
                        console.error 'Different names: '+existing_vis_name+', '+visible_name
                    old_modules.ORGAN_VISIBLE_NAMES[oname] = visible_name
                menu.items.append(item)
            if menu.items.length
                return menu
        ORGAN_TREE_MENU = convert_to_menu(ot)
#         sort_alphabetically(ORGAN_TREE_MENU)
        ORGAN_TREE_MENU.items.insert(0, {
            avoid_filter:true
            id:'search'
            default_text:'Search...'
            title:"Search any body part"
            auto_complete: false
            write:(v)->
                ORGAN_TREE_MENU.filter = v
#                 if not v
#                     ui_elements.close_all_submenus(ORGAN_TREE_MENU)
            icon:'search_icon.png'
            type:'text_input'
            backgroundPositionY: 11
            })
    xhr.send()

read_item_visibility_state = (item)->
    v = 0
    organs = get_organs(item)
    alternatives = get_alternative_organs(item)
    if not old_modules.tour_editor.editing
        organs = for o in organs when o not in alternatives then o
    visible_organs = 0
    for o in organs when o.visible
        visible_organs++
    if visible_organs
        v = 1
        if visible_organs >= organs.length
            v = 2
    else
        v = 0
    item.visibility_state = v
    if item.submenu and old_modules.tour_editor.editing
        item.text = '(' + visible_organs + '/' + organs.length + ') ' + item.orig_text
    else
        item.text = item.orig_text
    if item.visibility_state != v
        item.visibility_state = v
        requestAnimationFrame(main_view.render_all_views)
    return v

write_item_visibility_state = (item, v)->
    organs = get_organs(item)
    alternatives = get_alternative_organs(item)
    filtered_organs = for o in organs when o not in alternatives then o
    if not filtered_organs.length
        filtered_organs = for o in item.objnames or []
            continue if not ob = objects[o]
            ob

    visible_organs = for o in filtered_organs when o?.visible then o
    v = visible_organs.length/filtered_organs.length
    if v < 1
        for o in filtered_organs
            old_modules.show_mesh(o.name)
    else
        for o in organs
            old_modules.hide_mesh(o.name)

    if not (old_modules.tour_editor.is_editing() or old_modules.tour_viewer.is_viewing())
        old_modules.update_visible_area()
        min3 = old_modules.visible_area.min
        max3 = old_modules.visible_area.max
        if min3[0] < max3[0]
            # see if current camera direction is close to the box
            cam = old_modules.camera_control.current_camera_state.camera
            ray = old_modules.camera_control.last_ray

            ab = vec3.create()
            vec3.sub(ab, ray.point, cam.position)
            vec3.normalize(ab, ab)
            ac = vec3.create()
            vec3.sub(ac, old_modules.visible_area.center, cam.position)
            vec3.scale(ab, ab, vec3.dot(ab, ac))

            # b is now point on ab closest to c (to visible area center)
            dist = vec3.dist(ab, ac)
            if dist > (max3[0] - min3[0] + max3[1] - min3[1] + max3[2] - min3[2]) / 6
                # not looking at the visible stuff - do look
                old_modules.go_front_view()
                # go_front_view will automatically save state
                # so we need to prevent overwrite timeout
                state_saved = true

    if not state_saved
        old_modules.tour_editor.save_state()
    if not old_modules.tour_viewer.modified_view
        old_modules.tour_viewer.set_modified_view()
    read_item_visibility_state(item) #to update visibility state before rendering

get_filtered_organs = (item)->
    organs = get_organs(item)
    alternatives = get_alternative_organs(item)
    filtered_organs = for o in organs when o not in alternatives then o
    if not filtered_organs.length
        filtered_organs = for o in item.objnames or []
            continue if not ob = objects[o]
            ob
    return filtered_organs

sort_alphabetically = (menu)->
    menu.items = menu.items.sort(
        (a,b)->
            if a.orig_text < b.orig_text
                return -1
            if a.orig_text > b.orig_text
                return 1
            return 0
    )
    for i in menu.items
        if i.submenu
            sort_alphabetically(i.submenu)

get_organs = (item, force_recalc)->
    objs = []
    for o in item.objnames or []
        ob = objects[o]
        if ob
            objs.push ob
    if not item.submenu
        return objs
    for i in ui_elements.get_all_children(item, force_recalc) when i.objnames
        for o in i.objnames
            ob = objects[o]
            if ob
                objs.push ob
    objs

get_alternative_organs = (item, force_recalc) ->
    # DISABLE cache as this function can be called BEFORE scene is loaded
    # in this case cache will be wrong

    # if item.alternative_organs? and not force_recalc
    #     return item.alternative_organs
    alternative_organs = []
    if item.submenu
        for i in item.submenu.items
            if i.submenu
                if i.orig_text == 'Alternatives'
                    alternative_organs = alternative_organs.concat(get_organs(i,force_recalc))
                else
                    alternative_organs = alternative_organs.concat(get_alternative_organs(i,force_recalc))
    item.alternative_organs = alternative_organs
    return alternative_organs

render_organ_tree = ->
    if not ORGAN_TREE_MENU.items
        return
    ui_elements.render_menu(ORGAN_TREE_MENU)

module.exports = {init_organ_tree, render_organ_tree, get_organs, ORGAN_TREE_MENU, SYNONYMS}
