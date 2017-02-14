
React = require 'react'

{div, span, p, a, ul, li, img, h1, h2, h3, em, strong, br} = React.DOM

snapshot_view_options =
    enabled: false

SnapshotsListView = ->
    ul {className: 'dragonfly-tree'},
        for s in snapshots
            li (snapshot_event_handlers s), s.name


CreateSnapshotPopup = ->
    if not snapshot_view_options.enabled
        return
    div {id: 'snapshot-popup'},
        if tour_editor?.is_editing() or tour_viewer?.is_viewing()
            [
                input {id: 'snapshot-annotations', type: 'checkbox', checked: 'checked', onChange: (->)}
                'Annotations'
                br()
                input {id: 'snapshot-media', type: 'checkbox', checked: 'checked', onChange: (->)}
                'Other media'
                br()
                br()
            ]
        'Name:'
        br()
        input {id: 'snapshot-name'}
        'Description:'
        br()
        input {id: 'snapshot-desc'}
        br()
        br()
        input {type: 'button', value: 'Save the snapshot', onClick: create_snapshot}
        input {
            type: 'button', value: 'Cancel',
            onClick: (e) ->
                e.target.parentNode.style.display = "none"
        }
