
###
    Current format:
    
    Private user data (hash is data_root in the database) is an object with
    an attribute called 'private_tours' which is a folder.
    
    A folder object has the following attributes:
        type: 'folder'
        uuid: 'uuid'
        name: name
        children: [list of children elements]
        deleted_times: {
            'uuid': time at which the item with that uuid was deleted
        }
        mtime: last time folder was renamed, moved, order of children changed
               or sharing state changed.
               The following things count:
                * Order of children changed
                * New child item
               The following thigns don't count:
                * Changes in children themselves
                * Removing children items
        is_public: whether to merge it in the public tree or not
        special_type: 'trash' or ''
    
    A tour object has the following attributes:
        type: 'tour
        uuid: 'uuid'
        name: name
        hash: tour hash
        icon: hash of thumbnail image, or data: uri
        mtime: last time it was modified, renamed, moved
               or sharing state changed

    Times are in the format given by Date.now() (i.e. milliseconds since epoch)
###

uuid = require 'node-uuid'


tour_folder_item = (initial={}) ->
    initial.type = 'folder'
    initial.uuid = initial.uuid or uuid.v4()
    initial.name = initial.name or ''
    initial.children = initial.children or []
    initial.deleted_times = initial.deleted_times or {}
    initial.mtime = initial.mtime or Date.now()
    initial.special_type = initial.special_type or ''
    return initial

tour_item = (initial={}) ->
    initial.type = 'tour'
    initial.uuid = initial.uuid or uuid.v4()
    initial.name = initial.name or ''
    initial.hash = initial.hash or ''
    initial.mtime = initial.mtime or Date.now()
    return initial

get_tour_item_without_data = (tour_data) ->
    {
        type: 'tour'
        uuid: tour_data.uuid or uuid.v4()
        name: tour_data.name or ''
        hash: tour_data.hash or ''
        thumbnail: tour_data.thumbnail or ''
        mtime: tour_data.mtime or Date.now()
        num_slides: tour_data.num_slides or tour_data.slides?.length or 0
    }

get_migrated_names = (old_names, skip) ->
    r = []
    for o in old_names when o!=skip
        new_names = migrations[o]
        if new_names
            r = r.concat(get_migrated_names(new_names, o))
        else
            r.push(o)
    r

# Migrate mesh names and other quirks
migrate_mesh_states = (tour_data) ->
    changes = 0
    for slide, i in tour_data.slides
        if not slide.visibility
            continue
        for oldName of slide.visibility
            new_names = migrations[oldName]
            if new_names
                # add new names
                for newName in get_migrated_names(new_names)
                    if not slide.visibility[newName]
                        changes++
                        slide.visibility[newName] = slide.visibility[oldName].concat()
            # else if not objects[oldName]
            #     console.warn 'Object not found: '+oldName
    # Old fg/bg objects should have alpha 1
    if tour_data.mtime < 1430770583678
        for slide in tour_data.slides
            for v of slide.visibility
                if (v[3] or v[8]) and v[7] != 1
                    v[7] = 1
                    changes += 1
    changes

exports.test_migrations = (old_organ_tree_url='old_organ_tree.json', ignore_names=[]) ->

    get_json = (url, successHandler) ->
        xhr = new XMLHttpRequest()
        xhr.open('get', url, true)
        xhr.setRequestHeader("Authorization", vb.auth.token);
        xhr.onreadystatechange = () ->
            if (xhr.readyState == 4) and (xhr.status == 200)
                successHandler(JSON.parse(xhr.responseText))
        xhr.send()

    get_json(old_organ_tree_url, (data) ->
        names = []
        No = { migrations : [], objects : [] }
        collect = (o) ->
            if o.objnames
                for n in o.objnames
                    names.push(n)
            if o.children
                for c in o.children
                    collect(c)
        data.children = data.tree
        collect(data)

        if not added_implicit_migrations
            migrate_mesh_states({ slides : [] })
        
        for n in names
            if ignore_names.indexOf(n) > -1
                continue

            if not objects[n]
                new_names = get_migrated_names([n])
                if not new_names.length
                    #console.log('no migrations for ' + n)
                    No.migrations.push(n)
                else
                    for new_n in new_names

                        if ignore_names.indexOf(new_n) > -1
                            continue

                        if not objects[new_n]
                            #console.log('no object for ' + new_n)
                            No.objects.push(new_n)

        #w = window.open()
        #w.document.write(JSON.stringify(No))
        console.log(No)
    )


# This accepts a tree in any of the known formats
# and converts it to the last format
convert_tour_tree = (data) ->
    last = data[data.length-1]
    if last? and last[0]?
        data = convert_children(data)
    # If it's not a folder it means it's a list of children,
    # it's an old format converted with the line above
    if data.type != 'folder'
        # see util_tours.coffee for more information on the format
        data =
            type: 'folder'
            uuid: uuid.v4()
            name: ''
            children: data
            deleted_times: {}
            mtime: Date.now()
    return ensure_format_has_all_fields(data)

# this shouldn't be needed
# (except for a future version mismatch check)
ensure_format_has_all_fields = (item) ->
    if item.type == 'folder'
        item.children = for c in item.children or []
            c = ensure_format_has_all_fields(c)
            if not c?
                continue
            c
        return tour_folder_item(item)
    else if item.type == 'tour'
        return tour_item(item)
    else
        return


# This converts a list-based old tree with a list of objects
# equivalent to .children of a folder
convert_children = (children) ->
    for branch in children
        type = branch[0]
        if typeof type != 'string'
            continue
        # ['folder', children, name]
        # ['tour', hash, name]
        # This 'if' adds the item to the result of the for loop
        # except when 'continue' is executed
        if type == 'folder'
            tour_folder_item {
                name: branch[2]
                children: convert_tour_tree(branch[1])
            }
        else if type == 'tour'
            tour_item {
                name: branch[2]
                hash: branch[1]
            }
        else
            continue

# mtime for tours is the time the tour was modified
# mtime for folders is the time it was renamed
# (changes inside folder don't affect its mtime)
# shared folders and root have a history of deleted uuids + deletion time

# * When you move a tour, it's copied and the old entry is marked as deleted
# * Merge is done folder by folder (root is like another folder)
# * For items with same UUID, the one with latest mtime is chosen

merge_tour_trees = (older, newer) ->
    if not (older and newer)
        return convert_tour_tree(older or newer or tour_folder_item())
    
    # step 1: convert trees into separate independent folders
    shallow_copy = (obj) ->
        r = {}
        for k, v of obj
            r[k] = v
        r
    
    get_folders = (out, folder, uuid='root') ->
        if not folder.children
            folder.children = []
        for e in folder.children when e.type == 'folder'
            get_folders(out, e, e.uuid)
        out[uuid] = copied = shallow_copy folder
        # this loop is not necessary but helps finding bugs
        for e in copied.children when e.type == 'folder'
            e.children = null
        out
        
    folders_a = get_folders {}, older
    folders_b = get_folders {}, newer
    
    # step 2: merge folders present in both
    merged = {}
    for _uuid of folders_a
        merged[_uuid] = null
    for _uuid of folders_b
        merged[_uuid] = null
    for _uuid of merged
        a = folders_a[_uuid]
        b = folders_b[_uuid]
        if a and b
            if a.mtime < b.mtime
                m = shallow_copy b
                m.children = merge_folder_children(a.children, b.children, true)
                dt = m.deleted_times = shallow_copy a.deleted_times
                for k, v of b.deleted_times
                    dt[k] = v
            else
                m = shallow_copy a
                m.children = merge_folder_children(b.children, a.children, false)
                dt = m.deleted_times = shallow_copy b.deleted_times
                for k, v of a.deleted_times
                    dt[k] = v
        else
            m = shallow_copy a or b
        merged[_uuid] = m
    
    # step 3: delete elements
    for _, folder of merged
        folder.children = \
            for e in folder.children
                # when not deleted
                deleted = (e.mtime or 1) < (folder.deleted_times[e.uuid] or 0)
                if deleted
                    continue
                e
    
    # step 4: build tree from references
    dereference = (folder) ->
        folder.children = for e in folder.children
            if e.type == 'folder'
                e = dereference merged[e.uuid]
            e
        folder
    return dereference(merged['root'])


merge_folder_children = (older=[], newer=[], old_unresolved_on_top) ->
    # Get items of newer by uuid
    nmap = {}
    for item in newer
        nmap[item.uuid] = item
    
    # put all new items into result
    result = newer[...]
    remap_indices = ->
        i = 0
        for item in result
            item._idx = i++
        return
    remap_indices()
    
    # iterate all old items repeatedly, placing items with known position
    # until no item can be allocated
    allocated = {}
    loop
        any_allocated = false
        i = 0
        for item in older when item.uuid not of allocated
            nitem = nmap[item.uuid]
            # If the item is already in result
            if nitem?
                if nitem.mtime < item.mtime
                    item._idx = nitem._idx
                    result[nitem._idx] = nmap[item.uuid] = item
                allocated[item.uuid] = any_allocated = true
                continue
            # If the previous item is in result
            prev = result[older[i-1]?.uuid]
            if prev?
                result.insert(prev._idx+1, item)
                nmap[item.uuid] = item
                remap_indices()
                allocated[item.uuid] = any_allocated = true
                continue
            # If the next item is in result
            next = result[older[i+1]?.uuid]
            if next?
                result.insert(next._idx, item)
                nmap[item.uuid] = item
                remap_indices()
                allocated[item.uuid] = any_allocated = true
                continue
        if not any_allocated
            break
    
    # remove _idx
    for item in result
        delete item._idx
    
    # add remaining items at the beginning or end of results
    remaining = for item in older when item.uuid not of allocated
        item
    
    return if old_unresolved_on_top
        remaining.concat(result)
    else
        result.concat(remaining)


merge_tour_trees_test = () ->
    older = tour_folder_item {
        children: [tour_item()]
    }
    newer = JSON.parse(JSON.stringify(older))
    newer.children.push(tour_item())

    result = merge_tour_trees older, newer
    # result should have 2 tours
    console.log result

exports.tour_folder_item = tour_folder_item
exports.merge_tour_trees = merge_tour_trees
exports.migrate_mesh_states = migrate_mesh_states


# merge_tour_trees_test()
