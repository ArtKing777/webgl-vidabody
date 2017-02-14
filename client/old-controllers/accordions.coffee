

# DOM structure
# TODO: state classes?

#ul.accordion
#       li
#            .expand-accordion.panel-button
#            .sub-menu
#       li
#            .expand-accordion.panel-button
#            .sub-menu

#main_menu_visibility

main_accordion = null

class MainMenuVisibilityStatesMachine
    blocked = false
    constructor: () ->
        main_accordion.classList.add('hidden')
        main_accordion.style.display = 'none'
        @_state = 'hidden'

        _hidden = () ->
            main_accordion.classList.add('hidden')
            main_accordion.classList.remove('semihidden')
            main_accordion.classList.remove('semihidden2')
            @_state = 'hidden'
            delay_display_none = =>
                if @_state == 'hidden'
                    main_accordion.style.display = 'none'
            #is delayed to wait to transitions
            window.setTimeout(delay_display_none,500)

        _semihidden = () ->
            @_state = 'semihidden'
            main_accordion.style.display = 'block'
            main_accordion.classList.remove('hidden')
            main_accordion.classList.add('semihidden')
            main_accordion.classList.remove('semihidden2')

        _semihidden2 = () ->
            @_state = '_semihidden2'
            _semihidden()
            main_accordion.classList.add('semihidden2')
            fold_accordion(main_accordion)

        _unhidden = () ->
            @_state = 'unhidden'
            main_accordion.style.display = 'block'
            main_accordion.classList.remove('hidden')
            main_accordion.classList.remove('semihidden')
            main_accordion.classList.remove('semihidden2')
        @_states = {
            'hidden' : _hidden,
            'semihidden': _semihidden,
            'semihidden2': _semihidden2,
            'unhidden': _unhidden,
            }

    set_state: (state) ->
        if not @blocked
            @_states[state]()
    get_state: () ->
        return @_state
    block: () ->
        @blocked = true
    unblock: () ->
        @blocked = false

main_menu_visibility = null

init_all_accordions = ->
    main_accordion = main_menu.querySelector('.accordion')
    main_menu_visibility = new MainMenuVisibilityStatesMachine()

    #common
    for e in document.getElementsByClassName('expand-accordion')
        e.addEventListener('click', accordion_click)

        li2 = e.parentElement
        if li2.classList.contains('default')
            accordion_toggle(li2)

    #Login panel
    login_panel = document.getElementById('login_panel')
    login_panel.closed = true
    close_login_panel_button = document.querySelector('#close_login_panel')

    login_button = document.querySelector('#login > .expand-accordion')
    register_button = document.querySelector('#register > .expand-accordion')
    login_form = document.getElementById('login_form')
    forgot_form = document.getElementById('forgot_form')
    secondary_login_button = document.querySelector('#secondary_login_button')

    close_login_panel = ->
        fold_accordion(login_panel)
        close_login_panel_button.classList.remove('expanded')
        secondary_login_button.classList.remove('hidden')
        login_panel.closed = true
        main_view.pause_render(500)


    register_click = (event) ->
        close_login_panel_button.classList.add('expanded')
        $('#control_toolbar')[0].classList.add('hidden')
        if login_panel.classList.contains('expanded')
            login_panel.closed = false
            close_login_panel_button.classList.add('expanded')
            secondary_login_button.classList.add('hidden')
        else
            login_panel.closed = true
            close_login_panel_button.classList.remove('expanded')
            secondary_login_button.classList.remove('hidden')
        achievements['login_panel'] = true

    window.signup = ->
        accordion_toggle($('#register')[0])
        register_click()

    login_click = (event) ->
        main_view.pause_render(500)
        login_form.classList.remove('hidden')
        forgot_form.classList.add('hidden')
        if login_panel.classList.contains('expanded')
            login_panel.closed = false
            close_login_panel_button.classList.add('expanded')
            secondary_login_button.classList.add('hidden')
        else
            login_panel.closed = true
            close_login_panel_button.classList.remove('expanded')
            secondary_login_button.classList.remove('hidden')
        achievements['login_panel'] = true

    window.login = ->
        accordion_toggle($('#login')[0])
        login_click()

    secondary_login_button_click = (event) ->
        #accordion_toggle(login_button.parentElement)
        #register_click(event)
        window.location.href = '/auth/google'
        # accordion_toggle(register_button.parentElement)
        # setTimeout((() -> accordion_toggle(login_button.parentElement)), 300)
        # main_view.pause_render(500)
        # login_click(event)

        # secondary_login_button.classList.add('hidden')

    toggle_login_forgot = (event) ->
        event.preventDefault()
        login_form.classList.toggle('hidden')
        forgot_form.classList.toggle('hidden')
        main_view.pause_render(500)

    main_accordion_click = (event) ->
        # achievements['main_menu'] = true

    for b in document.querySelectorAll("#main_menu .expand-accordion")
        b.addEventListener('click', main_accordion_click)

    document.getElementById('forgot').onclick = toggle_login_forgot
    document.getElementById('return_to_login').onclick = toggle_login_forgot

    close_login_panel_button.onclick = close_login_panel
    vida_body_auth.addEventListener('login', close_login_panel)
    login_button.addEventListener('click', login_click)
    secondary_login_button.addEventListener('click',secondary_login_button_click)
    register_button.addEventListener('click', register_click)


    for li2 in document.querySelector('#main_menu .accordion').children
        li2.children[0].addEventListener('click', () -> (main_menu_visibility.set_state('unhidden')))


mark_clicked = (li) ->
    for c in li.parentNode.querySelectorAll('li')
        c.classList.remove('clicked')
    li.classList.add('clicked')
    li.classList.remove('pending')

fold_accordion = (accordion) ->
    for li in accordion.children
        accordion.classList.remove('expanded')
        li.classList.remove('expanded')
        sub_menu = li.querySelector('.sub-menu')
        for e in sub_menu.querySelectorAll('input')
            e.disabled = true
    accordion.classList.remove('expanded')

accordion_expand = (li) ->
    accordion = li.parentElement
    elements = accordion.children
    for element in accordion.children
        if element != li
            element.classList.remove('expanded')
            e_sub_menu = element.querySelector('.sub-menu')
            for e in e_sub_menu.querySelectorAll('input')
                e.disabled = true

    accordion.classList.add('expanded')
    li.classList.add('expanded')
    sub_menu = li.querySelector('.sub-menu')
    for e in sub_menu.querySelectorAll('input')
        e.disabled = false

accordion_toggle = (li) ->
    if li.classList.contains('expanded')
        fold_accordion(li.parentElement)
    else
        accordion_expand(li)

accordion_click = (event) ->
    t = event.target
    # WORKAROUND FIXME until accordions are ported to react
    if t == this or (t.tagName=='SPAN' and t.parentElement == this)
        accordion_toggle(this.parentElement)
    main_view.pause_render(500)
