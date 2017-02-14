
main_view = require './main_view'
old_modules = require '../tmp/old_modules'
moment = require 'moment'

React = require 'react'
{div, ul, li, input, textarea, br} = React.DOM

# Example:
# thread =
#     uuid: '4c0d3840-5680-461c-860a-7ffffb11ffee',
#     children: [
#         {
#             author_name: 'Me'
#             body: 'The nose is too nosy'
#             date: Date.now() - 1209800000
#             cid: '0'
#             children: []
#         }
#     ]

ENABLE_COMMENTS = false

thread = null
show_comments = true

two_weeks_ago = Date.now() - 1209600000

find_cid = (thread, cid) ->
    for comment in thread.children
        if comment.cid = cid
            return comment
        found = find_cid(comment, cid)
        return found if found
    return null

grab_thread = (uuid) ->
    if not uuid or not ENABLE_COMMENTS
        thread = null
        return
    old_modules.request_json 'GET', old_modules.FILE_SERVER_DOWNLOAD_API+'uuid/comments/'+uuid, (data) ->
        thread = data
        main_view.render_all_views()
    , ->
        thread = {uuid, children: []}
        main_view.render_all_views()


add_comment = (thread, parent, body, cb) ->
    cid = parent.cid + '.' + (parent.children?.length or 0)
    old_modules.request_json 'POST', old_modules.SERVER_BASE+'uuid/lock/comments/'+thread.uuid, (data) ->
        if data.response == 'ok'
            old_modules.request_json 'GET', old_modules.FILE_SERVER_DOWNLOAD_API+'uuid/comments/'+thread.uuid, (data) ->
                thread = data
                parent = find_cid(thread, parent.cid)
                if not parent
                    alert('Parent is missing')
                    return cb()
                # Now "parent" is the original parent but with the newest data
                parent.children = parent.children or []
                parent.children.push
                    author_name: 'Me'
                    body: text
                    date: Date.now()
                    cid: cid
                old_modules.request_json 'POST', old_modules.SERVER_BASE+'uuid/put/comments/'+thread.uuid, (data) ->
                    cb()
                    main_view.render_all_views()
                , (-> cb('Error uploading data')), {token: old_modules.auth.token, unlock: true}
            , -> cb('Error downloading data')
    , (-> cb('Error acquiring lock')), {token: old_modules.auth.token}


CommentsView = React.createFactory React.createClass {
    render: ->
        tour_editor = old_modules.tour_editor
        tour_viewer = old_modules.tour_viewer
        tour_data = (tour_editor?.editing and tour_editor.tour_data) or
            (tour_viewer?.viewing and tour_viewer.tour_data)
        if not tour_data or not thread or not show_comments or not ENABLE_COMMENTS
            return div()
        div {className: 'CommentsView'},
            div
                className: 'header'
                onMouseDown: (e) ->
                    floating = e.currentTarget.parentNode
                    old_modules.modal_mouse_drag e, (event, dx, dy) ->
                        floating.style.left = floating.offsetLeft + dx + 'px'
                        floating.style.top = floating.offsetTop + dy + 'px'
                'Slide comments'
            div {className: 'scrollable'},
                ThreadView(thread)
                add_a_comment(thread, "Add a comment", "Add a comment to this slide")
            div
                className: 'resizable-handle'
                onMouseDown: (e) ->
                    floating = e.currentTarget.parentNode
                    old_modules.modal_mouse_drag e, (event, dx, dy) ->
                        floating.style.width = floating.offsetWidth + dx + 'px'
                        floating.style.height = floating.offsetHeight + dy + 'px'
                
            
}

ThreadView = (thread) ->
    ul {},
        for comment in thread.children
            do (comment) -> li {},
                div {className: "comment-body"}, comment.body
                div {className: "comment-info"},
                    "By #{comment.author_name}, "
                    if comment.date < two_weeks_ago
                        moment(comment.date).format("ddd, MMMM Do YYYY, h:mm a");
                    else
                        moment(comment.date).fromNow()
                div {className: "comment-controls"},
                    add_a_comment(comment, "Reply", "Reply to this comment")
                    if comment.children?.length
                        ThreadView(comment)
                        
                

add_a_comment = (parent, button_text, title) ->
    # Parent can be a comment or an array
    if not parent._editing
        [
            input
                className: 'panel-button', type: 'button', value: button_text, title: title,
                onClick: ->
                    # Setting a function instead of "true" to avoid being encoded in JSON
                    parent._editing = (->)
                    main_view.render_all_views()
        ]
    else
        div {},
            textarea()
            br()
            input
                className: 'panel-button', type: 'button', value: 'Send', title: "Send to this comment",
                onClick: (e) ->
                    text = e.currentTarget.parentNode.firstChild.value
                    if text
                        add_comment thread, parent, text, (err) ->
                            if err
                                console.error err
                            delete parent._editing
                            main_view.render_all_views()
                    else
                        alert('Comment is empty')
            input
                className: 'panel-button', type: 'button', value: 'Cancel', title: "Cancel reply",
                onClick: (e) ->
                    text = e.currentTarget.parentNode.firstChild.value
                    if (not text) or confirm('Are you sure you want to discard your comment?')
                        delete parent._editing
                        main_view.render_all_views()


                

# This is a controller

example_delete_element = (model, element) ->
    model.splice(model.indexOf(element), 1)
    main_view.render_all_views()

# We need to export the things we use outside

module.exports = {CommentsView, grab_thread}
