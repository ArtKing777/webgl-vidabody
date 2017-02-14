
{popup_menu} = require '../views/ui_elements'
main_view = require '../views/main_view'

# These don't include text annotations, which are added in tour_editor._add_annotation

current_annotations = []

class Transformable

    constructor: (read_only) ->
        self = this
        current_annotations.append(this)
        parent = document.getElementById('annotations')
        e = @element = new_div_class('transformable', parent)
        e.classList.add('transformable-'+@type)
        @hflip = false
        @vflip = false
        @read_only = read_only
        @delay = 0
        if read_only
            e.classList.add('read-only')
            @w = 0
            @h = 0
            e.style.opacity = 0
            # Opacity is to be set on set_data
            return
        nw = @resizeNW = new_div_class('resize', e)
        ne = @resizeNE = new_div_class('resize', e)
        se = @resizeSE = new_div_class('resize', e)
        sw = @resizeSW = new_div_class('resize', e)
        new_div_class('border', e)
        nw.move_x = sw.move_x = true
        nw.move_y = ne.move_y = true

        @y = e.offsetTop
        @x = e.offsetLeft
        @w = e.offsetWidth
        @h = e.offsetHeight

        # Resizing
        nw.onmousedown = ne.onmousedown = \
        se.onmousedown = sw.onmousedown = (event) ->
            event.stopPropagation()
            event.preventDefault()
            e.classList.add('resizing')
            move_x = this.move_x
            move_y = this.move_y
            move = (event, dx, dy) ->
                self.w += dx
                self.h += dy
                if move_x
                    self.w -= dx + dx
                    self.x += dx
                if move_y
                    self.h -= dy + dy
                    self.y += dy
                if self.w < 0
                    self.x += self.w
                    self.w = -self.w
                    move_x = not move_x
                    self.hflip = not self.hflip
                if self.h < 0
                    self.y += self.h
                    self.h = -self.h
                    move_y = not move_y
                    self.vflip = not self.vflip
                e.style.left = self.x+'px'
                e.style.top = self.y+'px'
                e.style.width = self.w+'px'
                e.style.height = self.h+'px'
                self.redraw and self.redraw()
            up = =>
                e.classList.remove('resizing')
                self.onresize and self.onresize()
                self.convert_to_percents()
                tour_editor.save_state()

            self.convert_to_pixels()
            modal_mouse_drag(event, move, up)

        # Moving
        e.onmousedown = (event) ->
            if event.target != this
                return
            event.stopPropagation()
            event.preventDefault()
            move = (event, dx, dy) ->
                self.x += dx
                self.y += dy
                e.style.left = self.x+'px'
                e.style.top = self.y+'px'
            up = ->
                self.convert_to_percents()
                tour_editor.save_state()

            # Mac ctrl+tap means RMB
            left = event.button == 0 and not event.ctrlKey
            right = event.button == 2 or (event.button == 0 and event.ctrlKey)
            #console.log('right?', right)
            if left
                self.convert_to_pixels()
                modal_mouse_drag(event, move, up)

                # select
                if not event.ctrlKey or event.shiftKey
                    for c in parent.children
                        c.classList.remove('selected')
                this.classList.add('selected')
            else if right and tour_editor.editing
                popup_menu(event.pageX, event.pageY, self.menu, null, 'transformable_delete_menu')

        @menu = [
            {
                'text':'Enter delay time',
                'func': => @delay = +prompt('Delay?')
            }
            {
                type: 'slider'
                id: 'delay'
                text: 'Delay time'
                title: 'Delay time from beginning of slide until it appears'
                min: 0
                max: 15
                soft_min: 0
                soft_max: 600
                unit:'s'
                read: => @delay
                write: (v) =>
                    @delay = v
                    tour_editor.slides[tour_editor.current_slide].zero_delay_anns = true
                    tour_editor.save_state()
                    if tour_editor.audio_player and tour_editor.auto_play_audio
                        tour_editor.preview_audio_delay(v)
                onmove: false
                onup: true
            }
            {
                type: 'button'
                text: 'Preview audio from delay'
                func: => tour_editor.preview_audio_delay(@delay)
            } if tour_editor.audio_player
            {
                text: 'Stroke'
                submenu: [
                    { text: 'Solid', func: () -> self.set_stroke('solid');tour_editor.save_state() }
                    { text: 'Dashed', func: () -> self.set_stroke('dashed');tour_editor.save_state() }
                    { text: 'Dotted', func: () -> self.set_stroke('dotted');tour_editor.save_state() }
                    { text: 'Double', func: () -> self.set_stroke('double');tour_editor.save_state() }
                    { text: 'Groove', func: () -> self.set_stroke('groove');tour_editor.save_state() }
                    { text: 'Ridge', func: () -> self.set_stroke('ridge');tour_editor.save_state() }
                    { text: 'Inset', func: () -> self.set_stroke('inset');tour_editor.save_state() }
                    { text: 'Outset', func: () -> self.set_stroke('outset');tour_editor.save_state() }
                ]
            } if this.set_stroke
            {
                type: 'slider'
                id: 'thickness'
                text: 'Thickness'
                title: 'Shape stroke thickness'
                min: 0
                max: 15
                value_type: 'int'
                unit: 'px'
                read: => parseInt(@thickness)
                write: (v) -> self.set_thickness(v + 'px'); tour_editor.save_state()
                onmove: false
                onup: true
            } if this.set_thickness
            {
                text: 'Outline color'
                func: ->
                    picker = $('#editor-color-input')[0]
                    picker.onchange = (e) -> self.set_color(e.target.value); tour_editor.save_state()
                    picker.click()
            } if this.set_color
            {
                text: 'Fill color'
                func: ->
                    picker = $('#editor-color-input')[0]
                    picker.onchange = (e) -> self.set_fill(e.target.value); tour_editor.save_state()
                    picker.click()
            } if this.set_fill
            {
                text: 'Remove fill'
                func: -> self.set_fill(''); tour_editor.save_state()
            } if this.set_fill
            {
                text: 'Bring to front'
                func: =>
                    p = @element.parentElement
                    if p.children.length > 1
                        p.removeChild(@element)
                        p.appendChild(@element)
                        current_annotations.splice(current_annotations.indexOf(this), 1)
                        current_annotations.push(this)
                        tour_editor.save_state()
            }
            {
                text: 'Send to back'
                func: =>
                    p = @element.parentElement
                    if p.children.length > 1
                        p.removeChild(@element)
                        p.insertBefore(@element, current_annotations[0].element)
                        current_annotations.splice(current_annotations.indexOf(this), 1)
                        current_annotations.unshift(this)
                        tour_editor.save_state()
            }
            {
                'text':'Delete',
                'func': () -> self.destroy()
            }
        ]
        @convert_to_percents()
        @redraw and @redraw()

    destroy: () ->
        current_annotations.remove(this)
        @element.parentNode.removeChild(@element)
        tour_editor.save_state()

    convert_to_pixels: () ->
        e = @element
        @x = parseFloat(e.style.left) * 0.01 * e.parentNode.offsetWidth
        @y = parseFloat(e.style.top) * 0.01 * e.parentNode.offsetHeight
        @w = parseFloat(e.style.width) * 0.01 * e.parentNode.offsetWidth
        @h = parseFloat(e.style.height) * 0.01 * e.parentNode.offsetHeight

    convert_to_percents: () ->
        e = @element
        e.style.left = 100 * (@x / e.parentNode.offsetWidth) + '%'
        e.style.top = 100 * (@y / e.parentNode.offsetHeight) + '%'
        e.style.width = 100 * (@w / e.parentNode.offsetWidth) + '%'
        e.style.height = 100 * (@h / e.parentNode.offsetHeight) + '%'

    get_data: () ->
        vh = 1/render_manager.canvas.clientHeight
        r = {
            'type': @type,
            'x': @x * vh,
            'y': @y * vh,
            'w': @w * vh,
            'h': @h * vh,
            'delay': @delay,
        }
        for a in @attribs
            r[a] = this[a]
        return r

    set_data: (data, set_timeout=setTimeout) ->
        vh = render_manager.canvas.clientHeight
        x = @x = data.x * vh
        y = @y = data.y * vh
        w = @w = data.w * vh
        h = @h = data.h * vh
        @convert_to_percents()
        @delay = data.delay or 0.2
        for a in @attribs
            this[a] = data[a]
        @restore()
        if @read_only
            set_timeout ( =>
                @element.style.opacity = 1
            ), @delay * 1000

    move: (x, y) ->
        @x += x
        @y += y
        s = @element.style
        s.top = @y + 'px'
        s.left = @x + 'px'


class TransformableImage extends Transformable
    constructor: (read_only) ->
        @type = 'image'
        @attribs = ['url', 'color']

        super(read_only)

    set_image: (url) ->
        @url = full_url = url
        if not full_url.startswith('data')
            if not full_url.startswith('http')
                full_url = FILE_SERVER_DOWNLOAD_API+url
            if (location.protocol == 'https:') and not full_url.startswith('https')
                # try to avoid mixed content warning by upgrading url to https
                https_url = 'https' + full_url.substr(4)
                image = new Image()
                image.onerror = =>
                    @element.style['background-image'] = 'url('+full_url+')'
                image.onload = =>
                    @element.style['background-image'] = 'url('+https_url+')'
                image.src = https_url
                return this
        @element.style['background-image'] = 'url(\''+full_url+'\')'
        return this

    set_fill: (color) ->
        if color != undefined
            @color = color
            if @url.indexOf('data:image/svg+xml;utf8,') == 0
                # our brackets, etc
                @set_image(@url.split(/fill="[^"]+"/).join('fill="' + (if (color == '') then 'white' else color) + '"'))
            else
                # generic image
                @element.style['background-color'] = color
                @element.style['background-blend-mode'] = if (color == '') then '' else 'multiply'
        else
            @element.style['background-color'] = ''
            @element.style['background-blend-mode'] = ''

        return this

    restore: () ->
        @set_image(@url)
        @set_fill(@color)

class TransformableFlash extends Transformable
    constructor: (read_only) ->
        @type = 'flash'
        @attribs = ['url']

        super(read_only)

    set_flash: (url) ->
        @url = full_url = url
        if not full_url.startswith('http')
            full_url = FILE_SERVER_DOWNLOAD_API+url
        flash = @element.querySelector('object')
        if not flash
            flash = document.createElement('object')
            if not @read_only
                flash.classList.add('no-events')
            @element.appendChild(flash)
        flash.setAttribute('width', @w)
        flash.setAttribute('height', @h)
        flash.setAttribute('type', 'application/x-shockwave-flash')
        flash.setAttribute('data', full_url)
        flash.setAttribute('wmode', 'transparent')
        return this

    onresize: () ->
        @set_flash(@url)

    restore: () ->
        @set_flash(@url)


class TransformableShape extends Transformable
    constructor: (read_only) ->
        @type = 'shape'
        @attribs = ['shape', 'thickness', 'color', 'stroke', 'fill']

        super(read_only)
        @shape_border = new_div_class('shape_border', @element)


    set_shape: (shape) ->
        @shape = shape
        if shape=='square'
            @shape_border.style['border-radius'] = '0'
        else if shape=='ellipse'
            @shape_border.style['border-radius'] = '100%'
        return this

    set_thickness: (thickness) ->
        @thickness = thickness
        @shape_border.style['border-width'] = thickness
        return this

    set_color: (color) ->
        @color = color
        @shape_border.style['border-color'] = color
        return this

    set_stroke: (stroke) ->
        @stroke = stroke
        @shape_border.style['border-style'] = stroke
        return this

    set_fill: (fill) ->
        @fill = fill
        @shape_border.style['background-color'] = fill
        return this

    restore: () ->
        @set_shape(@shape)
        @set_thickness(@thickness)
        @set_color(@color)
        @set_stroke(@stroke)
        @set_fill(@fill)


class TransformableArrow extends Transformable
    constructor: (read_only) ->
        @type = 'arrow'
        @attribs = ['hflip', 'vflip', 'color', 'fill']

        super(read_only)

    set_arrow: (hflip, vflip) ->
        svg = @element.querySelector('svg')
        if svg
            svg.parentNode.removeChild(svg)

        div = document.createElement('div')
        div.innerHTML = '''<svg>
                        <defs>
                <marker refX="0" refY="0" orient="auto" id="arrow_start" style="overflow:visible">
                    <path d="M 0,0 5,-5 -12.5,0 5,5 0,0 z" transform="matrix(0.8,0,0,0.8,0,0)" style="fill-rule:evenodd; stroke:#000000;stroke-width:1pt"></path>
                </marker>
                <marker refX="0" refY="0" orient="auto" id="arrow_end_black" style="overflow:visible" markerUnits="userSpaceOnUse">
                    <path d="M 0,0 5,-5 -12.5,0 5,5 0,0 z" transform="matrix(-0.8,0,0,-0.8,0,0)" style="fill-rule:evenodd; stroke:#555;stroke-width:12px"></path>
                </marker>
                <marker refX="0" refY="0" orient="auto" id="arrow_end_white" style="overflow:visible" markerUnits="userSpaceOnUse">
                    <path d="M 0,0 5,-5 -12.5,0 5,5 0,0 z" transform="matrix(-0.8,0,0,-0.8,0,0)" style="fill-rule:evenodd; stroke:#FFFFFF;stroke-width:8px;fill:#FFFFFF" class="fill"></path>
                </marker>
            </defs>
            <g>
                <path d="M 0,0 100,100" style="fill:none; stroke:#555; stroke-width:12px; stroke-linecap:square; stroke-linejoin:miter; stroke-opacity:1;marker-end:url(#arrow_end_black);"></path>
                <path d="M 0,0 100,100" style="fill:none; stroke:#FFFFFF; stroke-width:8px; stroke-linecap:square; stroke-linejoin:miter; stroke-opacity:1;marker-end:url(#arrow_end_white);" class="fill"></path>
            </g>
            </svg>'''
        svg = div.removeChild(div.firstChild)
        svg.classList.add('no-events')
        @element.appendChild(svg)
        w = @w
        h = @h
        svg.style.top = svg.style.left = '-32px'
        svg.style.position = 'absolute'
        x1 = if hflip then w+32 else 32
        y1 = if vflip then h+32 else 32
        x2 = if hflip then 32 else w+32
        y2 = if vflip then 32 else h+32
        # shortening
        angle = Math.atan2(x2-x1, y2-y1)
        x2 -= 22 * Math.sin(angle)
        y2 -= 22 * Math.cos(angle)
        svg.setAttribute('width', @w+64)
        svg.setAttribute('height', @h+64)
        path = svg.querySelectorAll('g path')
        path[0].setAttribute('d', 'M '+x1+','+y1+' '+x2+','+y2)
        path[1].setAttribute('d', 'M '+x1+','+y1+' '+x2+','+y2)
        return this

    set_color: (color) ->
        @color = color
        if color
            paths = @element.querySelectorAll('path')
            for p in paths
                if not p.classList.contains('fill')
                    p.style.stroke = color

    set_fill: (fill) ->
        @fill = fill
        paths = @element.querySelectorAll('path')
        for p in paths
            if p.classList.contains('fill')
                p.style.stroke = if (fill) then fill else 'white'

    restore: () ->
        @set_arrow(@hflip, @vflip)
        @set_color(@color)
        @set_fill(@fill)

    redraw: () ->
        @set_arrow(@hflip, @vflip)
        @set_color(@color)
        @set_fill(@fill)


class TransformableLShape extends Transformable
    constructor: (read_only) ->
        @type = 'lshape'
        @attribs = ['hflip', 'vflip', 'color']

        super(read_only)

    set_lshape: (hflip, vflip) ->
        svgs = @element.querySelectorAll('svg')
        if svgs.length
            for svg in svgs
                svg.parentNode.removeChild(svg)

        div = document.createElement('div')
        div.innerHTML = '''<svg style="z-index: 2;">
            <g>
                <path d="M 0,0  0,100 100,100" style="fill:none; stroke:#FFFFFF; stroke-width:2px; stroke-linecap:square; stroke-linejoin:miter; stroke-opacity:1;"></path>
            </g>
            </svg>
            <svg>
                <g>
                    <path class="shadow" d="M 0,0  0,100 100,100" style="fill:none; stroke:black; stroke-width:2px; stroke-linecap:square; stroke-linejoin:miter; stroke-opacity:0.8;"></path>
                </g>
                </svg>
            '''
        svgs = div.querySelectorAll('svg')
        svg_shape = svgs[0]
        svg_shadow = svgs[1]
        svg_shape.classList.add('no-events')
        svg_shadow.classList.add('no-events')
        @element.appendChild(svg_shadow)
        @element.appendChild(svg_shape)
        w = @w
        h = @h
        svg_shape.style.top = svg_shape.style.left = '-5px'
        svg_shape.style.position = 'absolute'

        svg_shadow.style.top = svg_shadow.style.left = '-5px'
        svg_shadow.style.position = 'absolute'
        x1 = if hflip then w+5 else 5
        y1 = if vflip then h+5 else 5
        x2 = if hflip then 5 else w+5
        y2 = if vflip then 5 else h+5
        # shortening
        angle = Math.atan2(x2-x1, y2-y1)
        x2 -= 5 * Math.sin(angle)
        y2 -= 5 * Math.cos(angle)

        svg_shape.setAttribute('width', @w+10)
        svg_shape.setAttribute('height', @h+10)
        path = svg_shape.querySelectorAll('g path')
        path[0].setAttribute('d', 'M '+x1+','+y1+' '+' '+x1+','+ y2+' '+x2+','+y2)


        y1s = y1 + 1
        y2s = y2 + 1
        x1s = x1 + 1
        x2s = x2 + 1


        svg_shadow.setAttribute('width', @w+10)
        svg_shadow.setAttribute('height', @h+10)
        path = svg_shadow.querySelectorAll('g path')
        path[0].setAttribute('d', 'M '+x1s+','+y1s+' '+' '+x1s+','+ y2s+' '+x2s+','+y2s)
        return this

    set_color: (color) ->
        @color = color
        if color
            paths = @element.querySelectorAll('path')
            for p in paths
                if not p.classList.contains('fill') and not p.classList.contains('shadow')
                    p.style.stroke = color

    set_fill: (fill) ->
        @fill = fill
        paths = @element.querySelectorAll('path')
        for p in paths
            if p.classList.contains('fill')
                p.style.stroke = if (fill) then fill else 'white'

    restore: () ->
        @set_lshape(@hflip, @vflip)
        @set_color(@color)
        @set_fill(@fill)

    redraw: () ->
        @set_lshape(@hflip, @vflip)
        @set_color(@color)
        @set_fill(@fill)


class TransformableYoutube extends Transformable
    constructor: (read_only) ->
        @type = 'youtube'
        @attribs = ['code']

        super(read_only)

    set_video: (code) ->
        @code = code
        src = '//www.youtube.com/embed/' + code
        iframe = @element.querySelector('iframe')
        if not iframe
            iframe = document.createElement('iframe')
            iframe.src = src
            iframe.setAttribute('frameborder', 0)
            iframe.setAttribute('allowfullscreen', true)
            if @read_only
                # doing the opposite
                iframe.classList.add('have-events')
            else
                iframe.classList.add('no-events')
            @element.appendChild(iframe)
        if iframe.src != src
            iframe.src = src

        return this

    restore: () ->
        @set_video(@code)



load_annotations_from_data = (data_list, read_only, set_timeout) ->
    current_annotations.clear()
    document.getElementById('annotations').innerHTML = ''
    for data in data_list
        type = data.type
        if type == 'image'
            (new TransformableImage(read_only)).set_data(data, set_timeout)
        else if type == 'flash'
            (new TransformableFlash(read_only)).set_data(data, set_timeout)
        else if type == 'shape'
            (new TransformableShape(read_only)).set_data(data, set_timeout)
        else if type == 'arrow'
            (new TransformableArrow(read_only)).set_data(data, set_timeout)
        else if type == 'lshape'
            (new TransformableLShape(read_only)).set_data(data, set_timeout)
        else if type == 'youtube'
            (new TransformableYoutube(read_only)).set_data(data, set_timeout)
        else
            console.error('Unknown annotation type: '+type)

get_annotation_data = ->
    data_list = []
    for a in current_annotations
        data_list.append(a.get_data())
    return data_list

add_image_transformable = ->
    url = prompt('Image URL?')
    if url
        (new TransformableImage()).set_image(url)
    tour_editor.save_state()


add_rectangle = ->
    (new TransformableShape()).set_shape('square').set_thickness('3px').set_stroke('solid').set_fill('')
    tour_editor.save_state()

add_ellipse = ->
    (new TransformableShape()).set_shape('ellipse').set_thickness('3px').set_stroke('solid').set_fill('')
    tour_editor.save_state()

add_arrow = ->
    (new TransformableArrow())
    tour_editor.save_state()

add_lshape = ->
    (new TransformableLShape())
    tour_editor.save_state()

add_left_bracket = ->
    (new TransformableImage()).set_image('data:image/svg+xml;utf8,' +
        '<svg width="128pt" height="429pt" viewBox="0 0 128 429" version="1.1" xmlns="http://www.w3.org/2000/svg"><path fill="white" d=" M 85.20 12.15 C 91.84 10.20 98.62 8.49 105.56 8.13 C 105.85 11.59 105.84 15.06 105.48 18.50 C 100.85 20.78 95.88 22.50 91.85 25.81 C 85.93 30.65 80.74 36.62 77.72 43.71 C 72.80 55.46 71.94 68.40 71.88 81.00 C 71.87 99.67 71.87 118.33 71.88 137.00 C 71.82 150.94 71.33 165.09 67.55 178.59 C 65.69 185.49 61.78 191.71 56.68 196.67 C 48.30 204.65 37.65 209.73 26.92 213.75 C 36.47 216.28 46.45 219.15 53.74 226.23 C 62.66 234.69 66.99 246.77 69.46 258.55 C 73.01 274.80 71.45 291.51 71.99 308.00 C 72.49 325.27 71.63 342.58 72.57 359.85 C 73.80 372.87 77.12 386.78 86.77 396.24 C 91.95 401.53 98.92 404.28 105.36 407.65 C 105.90 411.29 105.87 414.97 105.51 418.62 C 93.05 418.60 80.04 414.91 70.93 406.06 C 62.76 398.86 58.31 388.46 55.98 378.03 C 52.72 362.92 53.06 347.36 52.98 332.00 C 52.87 311.98 53.23 291.96 52.79 271.94 C 52.41 258.07 49.20 243.11 38.97 233.04 C 33.76 227.64 26.60 225.07 20.10 221.65 C 19.41 215.95 19.37 210.17 20.18 204.48 C 26.97 202.06 34.18 199.68 39.13 194.13 C 48.30 184.27 51.07 170.35 52.33 157.37 C 53.48 139.61 52.78 121.79 53.00 104.00 C 53.19 84.79 52.04 65.28 56.40 46.41 C 58.54 37.65 61.96 28.88 68.15 22.16 C 72.73 17.28 78.82 14.03 85.20 12.15 Z" /></svg>')
    tour_editor.save_state()

add_right_bracket = ->
    (new TransformableImage()).set_image('data:image/svg+xml;utf8,' +
        '<svg width="128pt" height="429pt" viewBox="0 0 128 429" version="1.1" xmlns="http://www.w3.org/2000/svg"><path transform="matrix(-1,0,0,1,128,0)" fill="white" d=" M 85.20 12.15 C 91.84 10.20 98.62 8.49 105.56 8.13 C 105.85 11.59 105.84 15.06 105.48 18.50 C 100.85 20.78 95.88 22.50 91.85 25.81 C 85.93 30.65 80.74 36.62 77.72 43.71 C 72.80 55.46 71.94 68.40 71.88 81.00 C 71.87 99.67 71.87 118.33 71.88 137.00 C 71.82 150.94 71.33 165.09 67.55 178.59 C 65.69 185.49 61.78 191.71 56.68 196.67 C 48.30 204.65 37.65 209.73 26.92 213.75 C 36.47 216.28 46.45 219.15 53.74 226.23 C 62.66 234.69 66.99 246.77 69.46 258.55 C 73.01 274.80 71.45 291.51 71.99 308.00 C 72.49 325.27 71.63 342.58 72.57 359.85 C 73.80 372.87 77.12 386.78 86.77 396.24 C 91.95 401.53 98.92 404.28 105.36 407.65 C 105.90 411.29 105.87 414.97 105.51 418.62 C 93.05 418.60 80.04 414.91 70.93 406.06 C 62.76 398.86 58.31 388.46 55.98 378.03 C 52.72 362.92 53.06 347.36 52.98 332.00 C 52.87 311.98 53.23 291.96 52.79 271.94 C 52.41 258.07 49.20 243.11 38.97 233.04 C 33.76 227.64 26.60 225.07 20.10 221.65 C 19.41 215.95 19.37 210.17 20.18 204.48 C 26.97 202.06 34.18 199.68 39.13 194.13 C 48.30 184.27 51.07 170.35 52.33 157.37 C 53.48 139.61 52.78 121.79 53.00 104.00 C 53.19 84.79 52.04 65.28 56.40 46.41 C 58.54 37.65 61.96 28.88 68.15 22.16 C 72.73 17.28 78.82 14.03 85.20 12.15 Z" /></svg>')
    tour_editor.save_state()

add_youtube = ->
    url = prompt('Youtube URL?')
    if url
        code = get_video_code(url)
        if code
            (new TransformableYoutube()).set_video(code)
            tour_editor.save_state()
        else
            alert('Invalid URL')



# Function by Pol
get_video_code = (url) ->
    regExp = /^.*(youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=|\&v=)([^#\&\?]*)([^"]*).*/
    match = url.match(regExp)
    if match and match[2].length == 11
        if /embed./.test match[1]
            return match[2]+match[3].replace(/&amp;/g,'&')
        return match[2]
    return ''


element_closest_point = (element, x1, y1) ->
    rect = element.getBoundingClientRect()

    x2 = rect.left
    if x2 < x1
        x2 = x1
        if x2 > rect.right
            x2 = rect.right
    y2 = rect.top
    if y2 < y1
        y2 = y1
        if y2 > rect.bottom
            y2 = rect.bottom

    return { 'x': x2, 'y': y2 }


update_annotation_line = (annotation) ->
    if annotation.line
        # assuming line.x2/y2 are in %-s
        x = parseFloat(annotation.line.x2) * 0.01 * document.body.clientWidth
        y = parseFloat(annotation.line.y2) * 0.01 * document.body.clientHeight
        p = element_closest_point(annotation, x, y)
        annotation.line.set(p.x, p.y, annotation.line.x2, annotation.line.y2)


init_annotations_with_3D_anchors = ->
    scr = vec4.create()
    mat = mat4.create()
    cam = scene.active_camera
    w2s = cam.world_to_screen_matrix

    update_annotations_when_camera_moves = window.update_annotations_when_camera_moves = () ->
        resize = (arguments.length == 1)
        if resize or not mat4_equal(mat, cam.world_matrix)

            # update annotations with 3D anchors
            if tour_editor.editing or tour_viewer.viewing
                annotations = $('#annotations')[0]
                for e in annotations.children
                    if e.line and e.point
                        # todo point to world coords 1st??
                        vec4.transformMat4(scr, e.point, w2s)
                        if scr[3] > 0
                            e.line.x2 = ((1+scr[0]/scr[3])*50) + '%'
                            e.line.y2 = ((1-scr[1]/scr[3])*50) + '%'
                            update_annotation_line(e)
                        else
                            e.line.hide()

            # hide annotations in viewer
            if tour_viewer.viewing and not resize and (camera_control.is_user_moving_camera() or camera_control.is_user_zooming())
                tour_viewer.set_modified_view()

            mat4.copy(mat, cam.world_matrix)

    scene.post_draw_callbacks.append(update_annotations_when_camera_moves)
    window.addEventListener('resize', () -> requestAnimationFrame(update_annotations_when_camera_moves))

for k,v of {TransformableShape, TransformableYoutube, TransformableArrow, TransformableLShape, TransformableImage, TransformableFlash,
			add_youtube, add_arrow, add_lshape, add_left_bracket, add_right_bracket, add_ellipse, add_rectangle, add_image_transformable	}
	exports[k] = v
