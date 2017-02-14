
# Seconds before the "Saving..." popup appears
# NOTE: put a higher number after it saves automatically and it works
NOTIFY_TIME = 0.1
# Time before next retry
RETRY_TIME = 10

# TODO: move this lib
LZ4 = require '../../server/libs/lz4/lib/lz4.js'

class FileManager
    constructor: ->
        @pending_tasks = 0
        @notify_timer = null
        @_finished_listeners = []
        @has_error = false

    save_tour: (tour, cb) ->
        @upload_text(JSON.stringify(tour), cb)

    upload_text: (text, cb) ->
        compressed_arraybuffer = LZ4.encode(new Buffer(text)).buffer
        blob = new Blob([compressed_arraybuffer])
        @_upload_to_uri(UPLOAD_API, blob, cb, {is_compressed: true})

    upload_blob: (blob, cb) ->
        # The .slice(0) makes sure a file is converted to blob
        @_upload_to_uri(UPLOAD_API, blob.slice(0), cb)
    
    upload_data_root: (data) ->
        # TODO: compress this one too
        blob = new Blob([JSON.stringify(data)])
        extra_data =
            'replace_root': vida_body_auth.data_root_hash
            'user_email': vida_body_auth.email
        finish = (response) =>
            if response.error == 'root_mismatch'
                console.error(response)
                if confirm 'Warning! Tree has changed since this page was loaded. Ovewrite?'
                    extra_data.replace_root = response.data_root
                    @_upload_to_uri(UPLOAD_API, blob, finish, extra_data)
            else
                if response.hash
                    vida_body_auth.data_root_hash = response.hash
        @_upload_to_uri UPLOAD_API, blob, finish, extra_data
    
    upload_settings: (data) ->
        #console.log( 'upload_settings' )
        blob = new Blob([data])
        finish = (response) =>
            if response.response != 'ok' and @_error_can_retry()
                console.error(response)
                setTimeout(=>
                    @_upload_to_uri(UPLOAD_SETTINGS_API, blob, finish)
                RETRY_TIME * 1000)
        @_upload_to_uri(UPLOAD_SETTINGS_API, blob, finish)
    
    upload_assets: (blob) ->
        @_upload_to_uri(SERVER_BASE + 'upload_assets/', blob.slice(0))
    
    add_finished_listener: (func) ->
        @_finished_listeners.append(func)
    
    remove_finished_listener: (func) ->
        @_finished_listeners.remove(func)

    _upload_to_uri: (uri, blob, cb, extra_data) ->
        # blob can also be input_field.files[0]
        if @pending_tasks == 0
            @set_message("Saving...")
            @_show_popup_delayed()
        @pending_tasks += 1
        form_data = new FormData
        form_data.append('upload', blob)
        form_data.append('size', blob.size)
        form_data.append('token', vida_body_auth.token)
        if extra_data
            for k of extra_data
                form_data.append(k, extra_data[k])
        xhr = new XMLHttpRequest
        xhr.open("POST", uri)
        xhr.setRequestHeader("Authorization", vida_body_auth.token);
        console.log 'Requesting upload to ' + uri
        xhr.onload = =>
            if xhr.status == 200 or xhr.status== 0
                cb and cb(JSON.parse(xhr.response))
                @pending_tasks -= 1
                console.log "onload, remaining", @pending_tasks
                if @pending_tasks == 0
                    @finish()
            else
                console.log "Error:", xhr.response
                if @_error_can_retry()
                    setTimeout(=>
                            @_upload_to_uri(uri, blob, cb, extra_data)
                        RETRY_TIME * 1000)
                @pending_tasks -= 1
                
        xhr.onerror = =>
            console.log 'error', xhr.response
            if @_error_can_retry()
                setTimeout(=>
                    @_upload_to_uri(uri, blob, cb, extra_data)
                    RETRY_TIME * 1000)
            @pending_tasks -= 1
        xhr.send(form_data)
        return
    
    _show_popup_delayed: ->
        clearTimeout(@notify_timer)
        @notify_timer = setTimeout(@show_popup, (NOTIFY_TIME * 1000))

    set_message: (message) ->
        $('#saving-popup')[0].textContent = message
    
    show_popup: (red=false) ->
        p = $('#saving-popup')[0]
        p.classList.remove('red')
        if red
            p.classList.add('red')
        p.style.display = 'block'
    
    hide_popup: ->
        $('#saving-popup')[0].style.display = 'none'
    
    hide_delayed: (time=1000) ->
        clearTimeout(@notify_timer)
        @notify_timer = setTimeout(@hide_popup, time)
    
    _error_can_retry: ->
        # TODO: this function should return false when
        #       a maximum amount of attempts == reached
        p = $('#saving-popup')[0]
        p.classList.add('red')
        p.textContent = 'There was an error, retrying...'
        p.style.display = 'block'
        has_error = true
        return true
    
    finish: () ->
        # pending tasks == 0 at this point
        # we'll execute the listeners and check if it's still 0 tasks
        for f in @_finished_listeners
            f()
        @_finished_listeners.clear()
        if @pending_tasks == 0
            clearTimeout(@notify_timer)
            @notify_timer = setTimeout(@hide_popup, 1000)
            @set_message("Saved!")
            @has_error = false


file_manager = new FileManager()
exports.file_manager = file_manager
