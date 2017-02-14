

CKEDITOR?.disableAutoInline = true

reading_panel = null

reading_panel_init = ->
    CKEDITOR?.plugins.add('slideSeparator', {
        'init': (editor) ->
            editor.addCommand( 'insertSlideSeparator', {
                'exec': (editor) ->
                    editor.insertHtml( '<hr /><br />' )
            })
            editor.ui.addButton( 'SlideSeparatorButton', {
                'label': 'Insert Slide Separator',
                'command': 'insertSlideSeparator',
                'icon': 'page_break.png'
            })
    })

    remove_spline = (span) ->
        if span.spline
            span.spline.remove()
            delete span.spline

    draw_spline = (span, x, y, frame_rect) ->
        span_point = element_closest_point(span, x, y)

        # decide span visibility
        span_visible = (span_point.x > 0) or (span_point.y > 0)

        if span_visible
            if frame_rect
                # we're in the frame
                if (span_point.y < 0) or (span_point.y > frame_rect.bottom - frame_rect.top)
                    span_visible = false
                else
                    span_point.x += frame_rect.left
                    span_point.y += frame_rect.top
            else
                # we're in the main document
                tab_rect = $('#reading-scrolling-tab')[0].getBoundingClientRect()
                if (span_point.y < tab_rect.top) or (span_point.y > tab_rect.bottom)
                    span_visible = false

        if span_visible
            span.spline = span.spline or new Spline('url(#readingPanelSpline)', 1.5, 'url(#readingPanelSplineShadow)', 'lines2')
            mid_x = 0.5 * (span_point.x + x)
            # prevent 0px spline bounding box (causes spline to disappear when using %-based gradients)
            if span_point.y == y
                span_point.y++
            span.spline.set(span_point.x, span_point.y, mid_x, span_point.y, mid_x, y, x, y)
        else
            remove_spline(span)

    CKEDITOR?.plugins.add('splineConnector', {
        'init': (editor) ->
            editor.addCommand( 'insertSplineConnector', {
                'exec': (editor) ->
                    text = editor.getSelection().getSelectedText()
                    span = new CKEDITOR?.dom.element('span')
                    span.setAttributes({class: 'reading-panel-anchored-text'})
                    span.setText(text)
                    editor.insertElement(span)

                    spline = new Spline('url(#readingPanelSpline)', 1.5, 'url(#readingPanelSplineShadow)', 'lines2')
                    before = -> 0
                    during = (event) ->
                        draw_spline(span.$, event.pageX, event.pageY, $('.cke_wysiwyg_frame')[0].getBoundingClientRect())
                    after = (event) ->
                        pick = pick_object(event.pageX, event.pageY)
                        p = pick.point
                        if pick
                            span.setAttribute('data-anchor', JSON.stringify({
                                name: pick.object.name, x: p[0], y: p[1], z: p[2]
                            }))
                            # and from this point on, span is tracked by the function returned from reading_panel_init()
                        else
                            remove_spline(span.$)
                            span.remove(true)

                        editor.fire('change')

                    click_to_add_anchor before, during, after

            })
            editor.ui.addButton( 'SplineConnectorButton', {
                'label': 'Connect selected text to body part',
                'command': 'insertSplineConnector',
                'icon': 'reading_spline_butt.png'
            })
    })
    
    reading_panel = new ReadingPanel()

    scr = vec4.create()
    mat = mat4.create()

    process_span = (span, frame_rect) ->
        if span.dataset.anchor
            # cache JSON.parse
            span.anchor = span.anchor or JSON.parse(span.dataset.anchor)

            anchor = span.anchor

            scr[0] = anchor.x
            scr[1] = anchor.y
            scr[2] = anchor.z
            scr[3] = 1
            # todo point to world coords 1st??
            vec4.transformMat4(scr, scr, mat)
            if scr[3] > 0
                x = scr[0]/scr[3]
                y = scr[1]/scr[3]
                if (x > -1) and (x < +1) and (y > -1) and (y < +1) # frustum culling
                    draw_spline(span,
                        (1 + x) * 0.5 * document.body.clientWidth,
                        (1 - y) * 0.5 * document.body.clientHeight,
                        frame_rect
                    )
                    return
            # if here, spline endpoint is culled - remove the spline
            remove_spline(span)

    #scene.post_draw_callbacks.append(->
    window.spline_tracker = ->
        # mat4.invert(mat, scene.active_camera.world_matrix)
        # mat4.mul(mat, scene.active_camera.projection_matrix, mat)
        #
        # for span in $('.reading-panel-anchored-text')
        #     process_span(span)
        #
        # frame_rect = $('.cke_wysiwyg_frame')[0].getBoundingClientRect()
        # for span in $('.cke_wysiwyg_frame')[0].contentDocument.body.querySelectorAll('.reading-panel-anchored-text')
        #     process_span(span, frame_rect)
    

class ReadingPanel

    constructor: () ->
        @panel = document.getElementById('reading-panel')
        @handle = document.getElementById('reading-handle')
        @scrollingTab = document.getElementById('reading-scrolling-tab')

        add_styles = (doc) ->
            # inverted colors for anchored text
            style = doc.createElement('style')
            style.innerHTML = '.reading-panel-anchored-text { background-color: #333; color: #fff }'
            doc.head.appendChild(style)

        add_styles(document)

        @scrollingTab.innerHTML = '<div id="scrollingTabEditor"></div>'
        @editor = CKEDITOR?.replace('scrollingTabEditor', {
            'extraPlugins': 'slideSeparator,splineConnector',
            'extraAllowedContent': 'hr; span[data-*]; span(*)',
            'on': {
                'change': (
                    -> spline_tracker()
                ),
                'contentDom': (
                    (e) -> add_styles(e.editor.document.$)
                ),
                'pluginsLoaded':
                    (e) -> e.editor.dataProcessor.dataFilter.addRules({
                        'comment': () -> false
                    })
            },
            'toolbar': [
                { 'name': 'row1', 'items': ['Bold', 'Italic', 'Underline', 'Strike', 'Format', 'FontSize' ] },
                { 'name': 'row2a', 'items': [ 'TextColor', 'BGColor' ] },
                { 'name': 'row2b', 'items': [ 'JustifyLeft', 'JustifyCenter', 'JustifyRight', 'JustifyBlock' ] },
                { 'name': 'row2c', 'items': [ 'Link', '-', 'Image', '-', 'SplineConnectorButton' ] },
                { 'name': 'row3', 'items': ['Undo', 'Redo', '-', 'Find', 'Replace', '-', 'NumberedList', 'BulletedList', '-', 'Outdent', 'Indent', '-', 'SlideSeparatorButton' ] }
            ],
            'removePlugins': 'elementspath'
        })

        @reset(true)

        @preventScrollEvent = false

        @openedState = 0

        # TODO retrieve from dom??
        @headerHeight = 75

    removeClassesFromPanel: () ->
        for c in ['opened', 'opened-medium', 'opened-wide']
            @panel.classList.remove(c)

    isOpened: () ->
        return(@panel.className.indexOf('opened') > -1)

    show: () ->
        @removeClassesFromPanel()

        @panel.style.display = 'block'
        @panel.classList.add('opened')
        @openedState = 1

    hide: (totally) ->
        @removeClassesFromPanel()

        if totally
            @panel.style.display = 'none'
        @openedState = 0

    click: (e) ->
        @removeClassesFromPanel()

        classes = ['', 'opened', 'opened-medium', 'opened-wide']

        if e.layerY < e.target.clientHeight * 0.5
            # upper "button": shrink
            if @openedState > 0
                @openedState -= 1
        else
            # lower "button": grow
            if @openedState < classes.length - 1
                @openedState += 1

        if @openedState > 0
            @panel.classList.add(classes[@openedState])

    getCurrentScrollingIndex: () ->
        current = 0
        scrollTop = @scrollingTab.scrollTop
        for i in [0... @tourSlides]
            slide_div = document.getElementById('slide-' + i)
            if slide_div and (scrollTop >= slide_div.offsetTop - @headerHeight)
                current = i
        return current

    # user scrolls panel -> we update tour viewer or editor
    scroll: () ->
        if @preventScrollEvent
            # animated scroll should reset this to false on animation completion
            @preventScrollEvent = false
            return null

        current = @getCurrentScrollingIndex()
        if (@currentSlide != current) and not (/^\s*$/g.test(document.getElementById('slide-' + current).textContent))
            @currentSlide = current
            console.log 'viewer should change to:', current
            @slideChangeHandler(null, current)

        spline_tracker()

    tree2array: (node, array, allNodes) ->
        if not node
            return null
        if allNodes or(node.nodeType == Node.ELEMENT_NODE)
            array.push(node)
        for child in node.childNodes
            @tree2array(child, array, allNodes)

    getCurrentEditorIndex: () ->
        try
            ranges = @editor.getSelection().getRanges()
        catch e
            console.error 'Ckeditor error'
        if not ranges?[0]
            # editor is empty if here...
            return 0

        element = ranges[0].startContainer.$
        if element.nodeType == Node.ELEMENT_NODE
            element = element.childNodes[ranges[0].startOffset]

        if not element
            # firefox: startOffset does not seem to point to valid node before user selects anything
            return 0

        current = 0
        # we need to cound how many <hr>-s are before current selection
        nodes = []
        @tree2array(@editor.document.$.body, nodes, true)
        nodes.shift() # discard <body>
        for node in nodes
            if node == element
                break
            if node.nodeName == 'HR'
                current += 1

        return current

    keyup: () ->
        current = @getCurrentEditorIndex()
        if @currentSlide != current
            @currentSlide = current
            @slideChangeHandler(current)

    # user selects another slide in tour viewer or editor -> we scroll the panel / update editor selection
    updateSlideIndex: (index) ->
        if @editorMode

            current = @getCurrentEditorIndex()
            if current != index
                current = 0
                # we need to find first element after index <hr>-s
                nodes = []
                @tree2array(@editor.document.$.body, nodes, false)
                nodes.shift() # discard <body>
                for node in nodes
                    if node.nodeName == 'HR'
                        current += 1
                    else if current == index
                        console.log('found:', node)
                        element = new CKEDITOR?.dom.node(node)
                        @editor.getSelection().selectElement(element)
                        @editor.document.getWindow().$.scroll(0, element.$.offsetTop)
                        break

            return null

        current = @getCurrentScrollingIndex()
        if current != index
            # need to scroll to index
            slide_div = document.getElementById('slide-' + index)
            if slide_div
                @scrollingTab.scrollTop = slide_div.offsetTop - @headerHeight
                # wait for Alberto's verison of $.animate()
                @preventScrollEvent = true
        if @currentSlide != index
            @currentSlide = index

    reset: (slideChangeHandler, saveHandler) ->
        @currentSlide = 0
        @tourSlides = 0

        @scrollingTab.scrollTop = 0

        editorElement = document.getElementById('cke_scrollingTabEditor')
        if editorElement
            editorElement.style.display = if saveHandler then '' else 'none'

        # remove viewer slide divs if any
        for slide_div in document.querySelectorAll('#reading-panel .slide-div')
            slide_div.parentNode.removeChild(slide_div)

        @handle.removeEventListener('click', @handle.clickHandler)
        @scrollingTab.removeEventListener('scroll', @scrollingTab.scrollHandler)

        s = this
        @handle.clickHandler = (e) -> s.click(e)
        @scrollingTab.scrollHandler = (e) -> s.scroll(e)

        @handle.addEventListener('click', @handle.clickHandler, false)

        if saveHandler
            # watch for user editing the thing
            @editor.removeListener('selectionChange', @editor.keyHandler)
            @editor.removeListener('change', @editor.saveHandler)

            @editor.keyHandler = (e) -> s.keyup(e)
            @editor.on('selectionChange', @editor.keyHandler)

            @editor.saveHandler = (e) -> saveHandler(s.editor.getData().split('<hr />'))
            @editor.on('change', @editor.saveHandler)

            @panel.classList.add('editmode')
        else
            # watch for user scrolling the thing
            @scrollingTab.addEventListener('scroll', @scrollingTab.scrollHandler, false)

            @panel.classList.remove('editmode')

        @editorMode = not not saveHandler
        @slideChangeHandler = slideChangeHandler


    setTourName: (name) ->
        $('#reading-header')[0].innerHTML = name


    addSlideText: (text) ->
        result = false
        if @editorMode
            # editor mode - just collect the data
            if @editorData
                @editorData += '<hr />' + text
            else
                @editorData = text
        else
            # viewer mode
            slide_div = document.createElement('div')
            slide_div.setAttribute('id', 'slide-' + @tourSlides)
            slide_div.setAttribute('class', 'slide-div')
            slide_div.innerHTML = text
            @scrollingTab.appendChild(slide_div)

            # in viewer mode, return true if the text is "empty"
            result = /^\s*$/.test(slide_div.textContent)

        @tourSlides++

        result

    flush: () ->
        if @editorMode
            try
                @editor.setData(@editorData)
            catch e
                console.error('CKEDITOR ERROR')
            @editorData = null
        else
            # allow last slide to be scrolled all the way to the top
            id = 'slide_div_spacer'
            spacer = $('#' + id)[0]
            if spacer
                spacer.parentNode.removeChild(spacer)
            spacer = document.createElement('div')
            spacer.id = id
            spacer.style.height = '100%'
            @scrollingTab.appendChild(spacer)
