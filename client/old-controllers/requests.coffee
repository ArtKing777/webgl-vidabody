

# XHR helper functions for easier error management.

# form_data can be a FormData object or a plain dict

request = (method, url, onload, onerror, form_data, tries=6, retry_time=1) ->
    retry = ->
        setTimeout ->
            request(method, url, onload, onerror, form_data, tries-1, retry_time*2)
        , retry_time*1000
    xhr = new XMLHttpRequest
    xhr.open(method, url, true)
    xhr.setRequestHeader("Authorization", vb.auth.token);
    xhr.timeout = 30000
    xhr.onreadystatechange = ->
        if xhr.readyState == 4
            if xhr.status != 200
                console.error('Error '+xhr.status+' '+xhr.statusText+' when requesting '+url)
    xhr.onload = ->
        if xhr.status == 200 or xhr.status == 0
            onload(xhr.response)
        else if tries
            retry()
        else if onerror
            onerror(xhr)
        else
            console.error('Error '+xhr.status+' when requesting '+url+':\n'+xhr.response)
    xhr.onerror = xhr.ontimeout = ->
        if tries
            retry()
        else if onerror
            onerror(xhr)
        else
            console.error('Error '+xhr.status+' when requesting '+url+':\n'+xhr.response)
    if form_data
        if isinstance(form_data, FormData)
            fd = form_data
        else
            fd = new FormData
            for k, v of form_data
                fd.append(k, v)
        xhr.send(fd)
    else
        xhr.send()
    
request_json = (method, url, onload, onerror, form_data) ->
    load = (data) ->
        try
            data = JSON.parse(data)
        catch e
            if onerror
                onerror({'status': 0, 'exception': e})
            else
                console.error('Error when parsing response of '+url+':\n'+data)
            return
        onload(data)
    request(method, url, load, onerror, form_data)

if not XMLHttpRequest?
    eval("var req = require('request')")  # This way webpack doesn't try to pack the module
    request = (method, url, onload, onerror, form_data) ->
        options = {
            method: method,
            uri: url, gzip: true
        }
        if form_data
            options.formData = form_data # TODO correct format? https://github.com/request/request#forms
        req(options, (error, response, body) ->
            if not error and (response.statusCode == 200)
                onload(body)
            else if onerror
                console.log(error)
                onerror({
                    status: response.statusCode,
                    response: body
                })
        )
    process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0'

exports.request = request
exports.request_json = request_json
