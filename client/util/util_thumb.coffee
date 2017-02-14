class ThumbnailMaker
    constructor: () ->
        @width = -1
        @height = -1

    getDataURL: (width, height, bgcolr, type, encoderOptions) ->
        gl = render_manager.gl

        if (@width != width) or (@height != height)
            # only do this when required dimensions change
            @thumbnail_fb = Framebuffer(width, height, gl.UNSIGNED_BYTE);

            @thumbnailer = document.getElementById('thumbnailer')
            @thumbnailer.width = width
            @thumbnailer.height = height
            @thctx = @thumbnailer.getContext('2d')
            @imagedata = @thctx.createImageData(width, height)

            @width = width
            @height = height

        cc = scene.background_color
        scene.background_color = bgcolr or [0.95,0.95,0.95]

        for thumbnail_vp in render_manager.viewports
            thumbnail_vp.dest_buffer = @thumbnail_fb
            thumbnail_vp.recalc_aspect()

        render_manager.draw_all()

        for thumbnail_vp in render_manager.viewports
            thumbnail_vp.dest_buffer = render_manager.main_fb
            thumbnail_vp.recalc_aspect()

        scene.background_color = cc

        gl.readPixels(0, 0, width, height, gl.RGBA, gl.UNSIGNED_BYTE, new Uint8Array(@imagedata.data.buffer))
        # flip vertically
        stride = width * 4
        line = new Uint8ClampedArray(stride)
        d = @imagedata.data
        for i in [0... height / 2]
            line.set(d.subarray(i*stride, (i+1)*stride))
            s2 = d.subarray((height-i-1)*stride, (height-i)*stride)
            d.set(s2, i*stride)
            s2.set(line)

        @thctx.putImageData(@imagedata, 0, 0)
        @thumbnailer.toDataURL(type, encoderOptions)

thumbnail_maker = new ThumbnailMaker()
