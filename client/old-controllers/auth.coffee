

socket = io('http://localhost:3030')
# Create a client side Feathers application that uses the socket
# for connecting to services
app = feathers()
    .configure feathers.socketio socket
    .configure feathers.hooks()
    .configure feathers.authentication storage:window.localStorage

window.featherApp = app;

if window?.localStorage
    localStorage = window.localStorage
else
    if not root?
        `var root = {}`
    root.localStorage = localStorage = {}
    root.localStorage.setItem = (id, val) ->
        this[id] = String(val)
    root.localStorage.getItem = (id) ->
        this[id]
    root.localStorage.removeItem = (id) ->
        delete this[id]
    root.localStorage.clear = ->
        for id of this
            delete this[id]


class VidaBodyAuth
    constructor: () ->
        @logged_in = false
        @is_admin = false
        @email = ''
        @token = ''

        # Use listeners like this
        # vida_body_auth.addEventListener('login', callback)
        # or if you want to call the listener only once
        # vida_body_auth.once('login', callback)
        
        # login event: contains an object with user info as argument
        # login_error event: is a string with a descriptive error
        # logout event: listeners are called without event argument
        # register event: listeners are called without event argument on success
        # register_error event: listeners are called with a dict of fields
        #                       and their errors, e.g.
        #                       {'email': 'Invalid e-mail', 'password': 'Too short'}
        #                       For other type of errors: {'error': 'Error message'}
        
        @login_listeners = []
        @logout_listeners = []
        @login_error_listeners = []
        @register_listeners = []
        @register_error_listeners = []
        @call_once = []
    
    load_stored_info: () ->
        # if location.protocol != 'file:'
        #     email = localStorage.getItem(SERVER_BASE + 'email')
        #     token = localStorage.getItem(SERVER_BASE + 'token')
        #     if email and token
        #         @email = email
        #         @token = token
        #         @check_token()
        app.authenticate().then (result) =>
            console.log(result)
            @logged_in = true
            @is_admin = false
            @can_edit_tours = true
            @data_root_hash = ''
            @token = result.token
            @token_details = {
                user_name: result.data.google.name.givenName
                data_root: '',
                email: '',
                is_admin: false,
                privilege: 100
            }
            @trigger('login', @token_details)
        .catch (error) ->
            console.error('can not login', error)
            
    
    login: (email, pw, remember) ->
        # Call this to login with email, password and
        # if remember is true, store session data in localStorage
        # This will trigger the event login or login_error
        fd = new FormData()
        fd.append('email', email)
        fd.append('password', pw)
        fd.append('action', 'authenticate')
        load = (response) =>
            if response.response == 'authentication_accepted'
                @email = email
                @token = response.session_token
                if remember and location.protocol != 'file:'
                    localStorage.setItem(SERVER_BASE + 'email', email)
                    localStorage.setItem(SERVER_BASE + 'token', response.session_token)
                # We're calling check_token because
                # this backend doesn't give some info at login
                @check_token()
            else if response.response == 'server_error'
                @trigger('login_error', 'Server error, try again later')
            else
                @trigger('login_error', 'Wrong e-mail or password')
        error = (err) =>
            @trigger('login_error', 'Connection error. Check your connection and try again.')
        request_json('POST', LOGIN_API, load, error, fd)
    
    check_token: () ->
        request_time = Date.now()
        # Call this function to check the validity of session data
        # and to get more info of the user(user name, privileges...)
        # This will trigger the event login or login_error
        load = (response) =>
            #{"response":"ok","token_details":{"user_name":"aaaaaa","privilege":0, ...},"server_time":12345}
            if 'server_time' of response
                client_time = Math.round(0.5 * (request_time + Date.now()))
                server_time = response.server_time
            
                if not Date.real_now
                    Date.real_now = Date.now
                Date.now = -> Date.real_now() - client_time + server_time

            if response.response == 'ok'
                @logged_in = true
                @is_admin = response.token_details.privilege == 1000 or response.token_details.is_admin
                @can_edit_tours = response.token_details.privilege >= 100
                @data_root_hash = response.token_details.data_root
                @token_details = response.token_details
                @trigger('login', response.token_details)
            else
                @trigger('login_error', 'authentication failed')
        error = (err) =>
            @trigger('login_error', 'Unknown error: ' + err)
        request_json('POST', GETINFO_API, load, error,
                     {'action': 'verify_token', 'session_token': @token})

    logout: () ->
        @logged_in = @can_edit_tours = @is_admin = false
        @email = ''
        @token = ''
        
        app.logout()
        # if location.protocol != 'file:'
        #     localStorage.removeItem(SERVER_BASE + 'email')
        #     localStorage.removeItem(SERVER_BASE + 'token')
        
        
    register: (email, pw, name) ->
        load = (response) =>
            if response.response == 'registration_accepted'
                @trigger('register')
            else
                err = {}
                if response.response == 'invalid_email'
                    err.email = 'Invalid e-mail address'
                if response.response == 'email_exists'
                    err.email = 'E-mail address already in database'
                if response.response == 'invalid_password'
                    err['password'] = 'Invalid password'
                if response.response == 'invalid_email'
                    err.name = 'Invalid name'
                if Object.keys(err).length == 0
                    err.error = 'Server error. Try again later.'
                @trigger('register_error', err)
        error = (err) =>
            @trigger('register_error', {'error': 'Connection error. Check your connection and try again.'})
        
        request_json('POST', REGISTER_API, load, error, {
            'action': 'user_register',
            'desired_name': name,
            'email_address': email,
            'password': pw
        })
    
    addEventListener: (event, listener) ->
        listener_list = this[event+'_listeners']
        if not listener_list?
            throw "Unknown event " + event
        if not listener?
            throw "Not a function when registering " + event
        listener_list.remove(listener)
        listener_list.append(listener)
        
    removeEventListener: (event, listener) ->
        listener_list = this[event+'_listeners']
        listener_list.remove(listener)
        @call_once.remove(listener)
    
    once: (event, listener) ->
        @addEventListener(event, listener)
        @call_once.remove(listener)
        @call_once.append(listener)
        
    trigger: (event, args...) ->
        listener_list = this[event+'_listeners']
        for l in listener_list[...]
            l.apply(null, args)
            if @call_once.indexOf(l) != -1
                @call_once.remove(l)
                listener_list.remove(l)

exports.auth = vida_body_auth = new VidaBodyAuth()



auth_init = ->
    if window.vidabody_skip_auth
        return
    $('#login_form')[0].onsubmit = login_submit
    # Set action to a URL that always gives 200
    $('#login_form')[0].setAttribute('action', SERVER_BASE)
    $('#login_form')[0].action = SERVER_BASE
    $('#register_form')[0].onsubmit = register_submit
    $('#resend_pass')[0].onclick = resend_pass
    $('#logged_in_panel #logout')[0].onclick = logout
    vida_body_auth.addEventListener('login', set_logged_in_status)
    
    vida_body_auth.load_stored_info()


register_error = (msg) ->
    div = $('#register_error')[0]
    #div.style.opacity = 1
    div.style.display = 'block'
    div.innerHTML = msg
    $('#login_panel')[0].classList.add('error')
    return false

remove_error = ->
    div = $('#register_error')[0]
    #div.style.opacity = 0
    div.style.display = 'none'
    div.textContent = ''
    $('#login_panel')[0].classList.remove('error')
    

login_error = (msg) ->
    div = $('#login_error')[0]
    #div.style.opacity = 1
    div.style.display = 'block'
    div.textContent = msg
    $('#login_panel')[0].classList.add('error')
    

remove_login_error = ->
    div = $('#login_error')[0]
    #div.style.opacity = 0
    div.style.display = 'none'
    div.textContent = ''
    $('#login_panel')[0].classList.remove('error')
    

register_success = (msg) ->
    div = $('#register_success')[0]
    #div.style.opacity = 1
    div.style.display = 'block'
    div.style['margin-bottom'] = 0
    div.textContent = msg
    $('#login_panel')[0].classList.add('message')
    

remove_success = ->
    div = $('#register_success')[0]
    #div.style.opacity = 0
    div.style.display = 'none'
    div.style['margin-bottom'] = '-30px'
    div.textContent = ''
    $('#login_panel')[0].classList.remove('message')
    

register_submit = (event) ->
    event.preventDefault()
    remove_error()
    form = $('#register_form')[0]
    name = form.elements['desired_name'].value
    pwd = form.elements['password'].value
    pwd2 = form.elements['password2'].value
    email = form.elements['email_address'].value
    if (name).length == 0
        return register_error('Fill in name field.')
    if (name).length < 3
        return register_error('Name too short, 3 characters minimum.')
    if (pwd).length < 8 or((pwd).length < 20 and not(
        /[a-z]/.test(pwd) and
        /[A-Z]/.test(pwd) and
        /[0-9]/.test(pwd)))
        return register_error('Password should be at least 8 characters long, it should have a lower case letter, an upper case letter and a number.'
            '<div style="font-size:10px;padding-top:4px;">Alternatively make it at least 20 characters long.</div>')
    if pwd != pwd2
        return register_error('Passwords does not match.')
    if not /.*[a-zA-Z0-9].*@.*[a-zA-Z0-9].*\.[a-zA-Z0-9]*/.test(email)
        return register_error('Invalid e-mail address.')
    form.parentNode.parentNode.classList.add('loading')
    
    onregister = ->
        form.parentNode.parentNode.classList.remove('loading')
        $('#login .expand-accordion')[0].click()
        register_success('Thank you for registering. Please log in.')
        $('#login #email')[0].value = email
        vida_body_auth.removeEventListener('register_error', onerror)
    
    onerror = (err) ->
        form.parentNode.parentNode.classList.remove('loading')
        msg = for k of err
            #e = form.elements['k']
            #if e
                #e.classList.add('error')
            err[k]
        register_error(msg.join('\n'))
        vida_body_auth.removeEventListener('register', onregister)
    
    form.parentNode.parentNode.classList.add('loading')
    vida_body_auth.once('register', onregister)
    vida_body_auth.once('register_error', onerror)
    vida_body_auth.register(email, pwd, name)
    return false


login_submit = (event) ->
    remove_login_error()
    remove_success()
    form = $('#login_form')[0]
    email = form.elements['email'].value
    pw = form.elements['password'].value
    remember = not not form.elements['stay_logged_in'].value
    form.parentNode.parentNode.classList.add('loading')
    vida_body_auth.once('login_error', login_error)
    vida_body_auth.login(email, pw, remember)
    # Not preventing submit, the action goes to a hidden iframe which loads a dummy html
    # It's done this way so any browser prompts to save the password
    return true


set_logged_in_status = (details) ->
    $('#login_panel')[0].classList.add('disabled')
    $('#secondary_login_button')[0].classList.add('disabled')
    $('#login_panel')[0].classList.remove('expanded')
    $('#login_panel')[0].classList.remove('expanded_login')
    #$('#login_button')[0].classList.add('disabled')
    $('#logged_in_panel')[0].classList.remove('disabled')
    $('#logged_in_panel #user_name')[0].textContent = details.user_name.split(' ')[0]
    form = $('#login_form')[0]
    form.parentNode.parentNode.classList.remove('loading')
    load_tour_tree()
    # Enable feedback widget if available
    requestAnimationFrame ->
        if enable_feedback?
            enable_feedback(vida_body_auth.email)
            cc = $('#canvas_container')[0]
            uservoice_hack = setInterval( ->
                e = $('.uv-popover-content')[0]
                if e
                    e.onmouseenter = ->
                        cc.style.background = 'url('+screenshot()+')'
                        render_manager.canvas.visibility = 'hidden'
                        window.uservoice_hack = true
                    clearInterval uservoice_hack
            , 3000)
    # Run rest of the modules if they weren't enabled before
    if window.is_pearson and not window.vidabody_app_path
        $('#splash')[0].style.display = ''
        exports.init_rest_of_UI_modules()
    main_view.render_all_views()
    
uservoice_hack = false

resend_pass = (event) ->
    pass


logout = ->
    vida_body_auth.logout()
    $('#login_panel')[0].classList.remove('disabled')
    $('#secondary_login_button')[0].classList.remove('disabled')
    #$('#login_button')[0].classList.remove('disabled')
    $('#logged_in_panel')[0].classList.add('disabled')
    unload_private_tree()
    vida_body_auth.is_admin = false
    main_view.render_all_views()
    
