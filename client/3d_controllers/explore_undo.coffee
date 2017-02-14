
EXPLORE_UNDO_LIMIT = 10

exports.explore_mode_undo = explore_mode_undo =
    _undo_stack: []
    _redo_stack: []
    save_state: (save_twice_time, save_stack=@_undo_stack, clear_stack=@_redo_stack) ->
        state = JSON.stringify
            meshes: get_meshes_state()
            camera: snap_helper.get_state()
        if save_stack[save_stack.length-1] != state
            save_stack.push state
            save_stack.splice(0, save_stack.length - EXPLORE_UNDO_LIMIT)
            clear_stack?.splice(0)
            main_view.render_all_views()
        clearTimeout @save_twice_timer
        if save_twice_time
            @save_twice_timer = setTimeout =>
                save_stack.pop()
                @save_state(0, save_stack, clear_stack)
            , save_twice_time
        return
    undo: ->
        @_undo_or_redo @_undo_stack, @_redo_stack
    redo: ->
        @_undo_or_redo @_redo_stack, @_undo_stack
    can_undo: ->
        @_undo_stack.length > 1
    can_redo: ->
        @_redo_stack.length > 0
    _undo_or_redo: (pop_stack, push_stack) ->
        state = pop_stack.pop()
        if state
            # In any direction, the current state
            # is the last one in the undo stack
            if not @_undo_stack.length
                # So if we just popped it, push it back
                @_undo_stack.push state
                return
            push_stack.push state
            {meshes, camera} = JSON.parse @_undo_stack[@_undo_stack.length-1]
            set_meshes_state meshes
            snap_helper.set_state camera, 300
        main_view.render_all_views()
        main_loop.reset_timeout()
        return
