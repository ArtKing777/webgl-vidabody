

watchCanvasResize = ->
    canvas = document.getElementById('canvas')
    for id in ['lines', 'lines2']
        svg = document.getElementById(id)
        svg.setAttribute('width', canvas.clientWidth)
        svg.setAttribute('height', canvas.clientHeight)

init_lines = ->
    window.addEventListener('resize', watchCanvasResize)
    watchCanvasResize()


class Line
    constructor: (stroke, strokeWidth, shadowStroke, svgId) ->
        @svg = document.getElementById(svgId or 'lines')

        @line = document.createElementNS('http://www.w3.org/2000/svg','line')
        @shadow = document.createElementNS('http://www.w3.org/2000/svg','line')

        @stroke = stroke
        @strokeWidth = strokeWidth

        @show()

        @line.setAttribute('stroke', stroke)
        @shadow.setAttribute('stroke', shadowStroke or '#000000')

        @svg.appendChild(@shadow)
        @svg.appendChild(@line)

        @visible = false


    set: (x1, y1, x2, y2) ->
        @x1 = x1
        @y1 = y1
        @x2 = x2
        @y2 = y2

        # should be svg.getAttribut('width'), but this == what tour_editor uses
        relOffset = 100 * @strokeWidth / document.body.clientWidth

        y1s = y1 + @strokeWidth
        if (y1 + '').substr(-1) == '%'
            y1s = (parseFloat(y1) + relOffset) + '%'

        y2s = y2 + @strokeWidth
        if (y2 + '').substr(-1) == '%'
            y2s = (parseFloat(y2) + relOffset) + '%'

        @line.setAttribute('x1', x1)
        @line.setAttribute('y1', y1)
        @line.setAttribute('x2', x2)
        @line.setAttribute('y2', y2)

        @shadow.setAttribute('x1', x1)
        @shadow.setAttribute('y1', y1s)
        @shadow.setAttribute('x2', x2)
        @shadow.setAttribute('y2', y2s)

        @show()

    setColor: (stroke) ->
        @stroke = stroke
        @line.style.stroke = @stroke

    classList: () ->
        return @line.classList

    hide: () ->
        if @visible
            @line.style['stroke-width'] = '0'
            @shadow.style['stroke-width'] = '0'
        @visible = false

    show: () ->
        if not @visible
            @line.style['stroke-width'] = @strokeWidth
            @shadow.style['stroke-width'] = @strokeWidth
        @visible = true

    remove: () ->
        @svg.removeChild(@line)
        @svg.removeChild(@shadow)


# cubic spline http...//blogs.sitepointstatic.com/examples/tech/svg-curves/cubic-curve.html
class Spline
    constructor: (stroke, strokeWidth, shadowStroke, svgId) ->
        @svgId = svgId or 'lines'

        @path = document.createElementNS('http://www.w3.org/2000/svg','path')
        @shadow = document.createElementNS('http://www.w3.org/2000/svg','path')

        @stroke = stroke
        @strokeWidth = strokeWidth

        @show()

        @path.setAttribute('stroke', stroke)
        @shadow.setAttribute('stroke', shadowStroke or '#000000')

        @path.setAttribute('fill', 'none')
        @shadow.setAttribute('fill', 'none')

        document.getElementById(@svgId).appendChild(@shadow)
        document.getElementById(@svgId).appendChild(@path)

        @visible = false


    set: (x1, y1, x2, y2, x3, y3, x4, y4) ->
        @x1 = x1
        @y1 = y1
        @x2 = x2
        @y2 = y2
        @x3 = x3
        @y3 = y3
        @x4 = x4
        @y4 = y4

        @path.setAttribute('d', 'M' + x1 + ',' + y1 + ' C' + x2 + ',' + y2 + ' ' + x3 + ',' + y3 + ' ' + x4 + ',' + y4)
        @shadow.setAttribute('d', 'M' + x1 + ',' + (y1 + @strokeWidth) + ' C' + x2 + ',' + (y2 + @strokeWidth) + ' ' + x3 + ',' + (y3 + @strokeWidth) + ' ' + x4 + ',' + (y4 + @strokeWidth))

        @show()

    setColor: (stroke) ->
        @stroke = stroke
        @path.style.stroke = @stroke

    classList: () ->
        return @path.classList

    hide: () ->
        if @visible
            @path.style['stroke-width'] = '0'
            @shadow.style['stroke-width'] = '0'
        @visible = false

    show: () ->
        if not @visible
            @path.style['stroke-width'] = @strokeWidth
            @shadow.style['stroke-width'] = @strokeWidth
        @visible = true

    remove: () ->
        document.getElementById(@svgId).removeChild(@path)
        document.getElementById(@svgId).removeChild(@shadow)
