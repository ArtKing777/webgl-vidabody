

## TODO: Make an animation module based in the old ActionPlayer node

exports.heart = heart = {}
multimesh_animation_objects = []
slider_animations = {}
loop_animations = {}

###
    Animation types:
        action:
            This is a standard animation based on actions exported from blender
            (Armature, transform and shape keys actions).
            Animation modes:
                loop:
                    The animation is played when the owner object is visible.
                    The animation is restarted when it ends.
                slider:
                    You can set the current frame from the RMB context menu
                    clicking on on object that contains that animation mode.
                    The state of the slider animations will be saved on the tour slide.
                    The frame state is transitioned when you change between tour
                    slides using the alpha transition length.
                    
        multimesh:
            Used on baked complex animations (Currently used only on heart animation).
            Those animations have been baked and divided on multiple meshes with shape keys.
            Animation modes:
                Currently none.
                
    Animation parameters:
    Those parameters have been defined on ob.properties (Exported from ob.game.properties from blender)
    
    anim_type -> [STRING] could be "multimesh" or "action"
    anim_mode -> [STRING] could be "loop" or "slider"
    anim_start -> [INT] is the first frame of the animation
    anim_end -> [INT] is the last frame of the animation
    anim_speed -> [FLOAT] is the speed of the animation
    anim_offset -> [FLOAT] is an offset applied to the current frame (used to unsync animations)
###

anim_id_num = 0

exports.init_animations = ->
    heart.heart_beat_speed = 1
    #TODO: Find other solution for this to avoid conflicts with other altmeshes
    #      only heart objects have altmeshes right now, but in the future, it wouldn't be right.
    for o in scene.children
        if o.properties.anim_type == 'multimesh'
            multimesh_animation_objects.append(o)
        for action_name in o.actions
            if action_name not of actions
                throw "Error in assets: action " + action_name + " not found"
            anim_id = o.name+'/'+action_name+'.'+anim_id_num
            while anim_id of o.animations
                anim_id_num += 1
                anim_id = o.name+'/'+action_name+'.'+anim_id_num
            anim = o.add_animation(anim_id,actions[action_name])
            o.animations[anim_id] = anim
            o.slider_animation = anim
            anim.start_frame = o.properties.anim_start or anim.action.markers['start'] or 0
            anim.end_frame = o.properties.anim_end or anim.action.markers['end'] or 40
            anim.offset = o.properties.anim_offset or 0
            anim.loop = false
            anim.is_heart = false
            mode = o.properties.anim_mode or 'loop'
            if mode == 'loop'
                loop_animations[anim_id] = anim
                anim.initial_speed = anim.speed = o.properties.anim_speed or 0.75
                anim.pos = anim.offset
                anim.loop = true
                anim.is_heart = o.properties.system == 'Heart'
            else if mode == 'slider'
                anim.initial_speed = anim.speed = o.properties.anim_speed or 0
                slider_animations[anim_id] = anim
            
            anim.owner.properties.anim_offset or 0
    
    scene.pre_draw_callbacks.append(update_animations)
    

add_animation_debug_gui = (gui) ->
    gui.add(heart, 'heart_beat_speed', 0.1, 3)
    
FLOW_POS = 0
exports.update_animations = update_animations = ->
    
    for ob in multimesh_animation_objects
        if ob.visible
            exports.update_multimesh_shapekeys_animation(ob, heart.heart_beat_speed)
    
    reset = false
    
    for key of loop_animations
        anim = loop_animations[key]
        if not (anim.owner.visible or anim.owner.type == 'ARMATURE')
            continue
        else
            reset = true
        if anim.pos >= anim.end_frame or (anim.is_heart and not heart.enabled_animation)
            anim.pos = anim.start_frame
            if not anim.loop
                anim.speed = 0
        if anim.owner.type == 'ARMATURE'
            FLOW_POS = anim.pos
        
    if reset
        main_loop.reset_timeout()
        
heart.enabled_animation = true


exports.update_multimesh_shapekeys_animation = (ob, speed=1, fps=24, duration=24, t) ->

    if tour_viewer?.is_viewing()
        main_loop.reset_timeout()
        
    t = (FLOW_POS / 40 * 24) + 20
    mesh_l = ob.altmeshes.length
    shapes_per_mesh = ob._shape_names.length
    frame = t % duration
    total_shape_i = Math.floor(frame)
    transition = frame - total_shape_i
    mesh_i = Math.floor(total_shape_i/shapes_per_mesh)
    shape_i = total_shape_i % shapes_per_mesh
    
    # shape_i = number of extra key
    # we have to set shape_i-1 to 1-transition
    # and shape_i to transition
    # and when shape_i is 0, it means not setting shape_i-1
    # which is the base
    
    ob.set_altmesh(mesh_i)
    for k of ob.shapes
        ob.shapes[k] = 0
    ob.shapes[ob._shape_names[shape_i]] = transition
    if shape_i != 0
        ob.shapes[ob._shape_names[shape_i-1]] = 1-transition

    
    
    
