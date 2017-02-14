
snapshots = []


update_snapshots_list = ->
    if $('#snapshots-view-container')[0]
        React.render SnapshotsListView(), $('#snapshots-view-container')[0]


create_snapshot = ->
    time = new Date()
    name = [('0' + time.getHours()).slice(-2), ('0' + time.getMinutes()).slice(-2), ("0" + time.getSeconds()).slice(-2)].join(':')

    slide = {}
    tour_editor.update_slide(slide, {
        'state' : true,
        'visibility' : true,
        'slices' : true,
        'annotations' : $('#snapshot-annotations')[0]?.checked,
        'media' : $('#snapshot-media')[0]?.checked
    })
    slide.index = 0

    snapshots.push { 'name' : $('#snapshot-name')[0].value or name, 'desc' : $('#snapshot-desc')[0].value or '', 'data' : { 'slides' : [ slide ], 'icon' : thumbnail_maker.getDataURL(20, 16) }}

    document.getElementById('snapshot-popup').style.display = 'none'

    $('#snapshot-name')[0].value = ''
    $('#snapshot-desc')[0].value = ''

    update_snapshots_list()

    # currently saved with private tour tree
    save_tour_tree()


snapshot_event_handlers = (s) -> {
    title: s.desc or '',
    # todo modal_mouse_drag?
    onContextMenu: (event) ->
        event.preventDefault()
        false
    ,
    onMouseUp: (event) ->
        if tour_editor.is_editing()
            
            tour_editor.paste_snapshot(s)
        else if event.button != 2
            tour_viewer.load_slide(s.data.slides[0])
}
