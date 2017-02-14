



tilt_widget_check = (event) ->
    pos = [event.pageX, event.pageY]
    
    clicking_tilt = false
    for box in document.querySelectorAll('.tilt_box')
        bb = box.getBoundingClientRect()
        box_pos = [
            bb.left + bb.width*0.5,
            bb.top + bb.height*0.5]
        radius = box.offsetWidth * Math.SQRT1_2
        if vec2.dist(pos, box_pos) < radius
            clicking_tilt = true
    
    objects.Camera.properties.tilting = clicking_tilt
    # this only changes on mousedown
    
    return clicking_tilt


