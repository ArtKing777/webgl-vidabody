
load_meshes = (mesh_names, lod_filter='^$', on_finish) ->
    re = new RegExp(lod_filter)
    any_pending = false
    for name in mesh_names
        ob = objects[name]
        if ob and not ob.data
            lod = if re.test(name) then 0.2 else 1
            if ob.scene.loader.load_mesh_data(ob, lod)
                any_pending = true
    if any_pending
        # assuming all objects use the same loader
        loaded = ->
            scene.loader.remove_queue_listener 0, loaded
            on_finish?()
            on_finish = null #for the hack below
        scene.loader.add_queue_listener 0, loaded
        # Sometimes the callback is not called, so...
        hack = ->
            if scene.loader.remaining_tasks[0] == 0
                loaded()
            else
                setTimeout hack, 200
        hack()
    else
        on_finish?()
    return
