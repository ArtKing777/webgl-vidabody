    

shuffle = (o) ->
    i = o.length
    while i
        j = Math.floor(Math.random() * i)
        i -= 1
        x = o[i]
        o[i] = o[j]
        o[j] = x
    return o

quizzed_labels = []

show_label_based_quiz = (l, quiz, title, show_score=true) ->
    l.elm.textContent = null
    qb = document.createElement('div')
    qb.classList.add('quiz_box')
    qb.textContent = title
    exit = (event) ->
        event.stopPropagation()
        hide_quiz(l)
    arrow = document.createElement('div')
    qb.appendChild(arrow)
    arrow.classList.add('popup_arrow')
    qb.appendChild(quiz)
    if show_score
        quiz_score = document.createElement('label')
        quiz_score.classList.add('score')
        quiz_score.textContent = 'score: +' + get_score_as_string(l) + 'pts'
        qb.appendChild(quiz_score)
    l.elm.onclick = null
    l.elm.appendChild(qb)
    l.elm.classList.add('has-quiz-box')
    l.update_orig_size()

hide_quiz = (l) ->
    if l.quiz and not l.quiz.done
        if l.quiz.editing
            unquizz(l)
        l.quiz.hide = true
            
        l.elm.classList.remove('has-quiz-box')
        l.elm.classList.add('hide')
        l.innerHTML = null
        l.elm.textContent = ''
        l.update_orig_size()
        l.elm.onclick = () -> unhide_quiz(l)
        l.update_orig_size()

unhide_quiz = (l) ->
    hide_quizzes()
    if l.quiz and not tour_editor.is_editing()
        l.quiz.hide = false
        f = window[l.quiz.type](l)
        l.elm.classList.remove('hide')
        l.elm.onclick = null
        l.update_orig_size()
        
hide_quizzes = ->
    for q in quizzed_labels
        hide_quiz(q)

get_score_as_string = (l) ->
    s = l.quiz.score
    if s
        return s.toFixed(2).replace('.00','')


question_quiz = (l, parsed_quiz, obj, point, normal) ->
    create_question_quiz = (l) ->
        keydown = (event) ->
            if event.keyCode == 13 # Enter
                event.preventDefault()
                submit_answer(quiz)
        
        submit_answer = (form) ->
            #TODO:send the answer to tour owner
            done_quiz(l,true)
            l.elm.textContent = 'Submitted'
            l.update_orig_size()
            tour_viewer.save_quiz_state(l.quiz)

        quiz = document.createElement('form')
        quiz.classList.add('question_quiz')
        answer = document.createElement('textarea')
        answer.classList.add('text-input')
        answer.classList.add('answer')
        answer.id = 'answer'
        answer.placeholder = 'Write you answer'
        answer.addEventListener('keydown', keydown)
        quiz.appendChild(answer)
        submit_button = document.createElement('div')
        submit_button.classList.add('panel-button')
        submit_button.textContent = 'Submit'
        quiz.appendChild(submit_button)
        submit_button.onclick = () -> submit_answer(quiz)
        show_label_based_quiz(l, quiz, l.quiz.question, false)
        quizzed_labels.push(l)

    if not l
        if parsed_quiz
            point = parsed_quiz.point
            obj = objects[parsed_quiz.obj]
            unselect_all()
            text = 'quiz'
            id = parsed_quiz.label_id
            l = create_label(obj and obj.name, point, text, true, 0, id)
            l.quiz = parsed_quiz
        else
            vec3.scale(normal, normal, 0.001)
            vec3.add(point, point, normal)
            unselect_all()
            text = 'quiz'
            l = create_label(obj and obj.name, point, text, true)
            question = prompt('Write the question:')
            l.quiz = {
                'type':'question_quiz',
                'done':false,
                'hide':true,
                'question':question,
                'answer':'',
                'point':point,
                'obj':obj.name
            }            

    l.delete_on_unquizz = true
    if l.quiz.question
        create_question_quiz(l)
    else
        delete_label(l)
    
    if l.quiz.done
        done_quiz(l,true)
        l.elm.textContent = 'Answer sent'
        l.update_orig_size()
    
    if l.quiz.hide
        hide_quiz(l)
    
    if tour_editor.is_editing()
        tour_editor.save_state()
    
    
    
write_name_quiz = (l=null, parsed_quiz=null) ->
    if not l and parsed_quiz
        l = labels_by_id[parsed_quiz['label_id']]
        l.quiz = parsed_quiz
        
    if not l.quiz
        l.quiz = {
            'label_id':l.id,
            'type':'write_name_quiz',
            'score':1,
            'done':false,
            'hide':true,
            'question':'',
            'last_answer':'',
            'failed':0,
            }
    
    keydown = (event) ->
        if event.keyCode == 13 # Enter
            event.preventDefault()
            submit_answer(quiz)
    
    submit_answer = (form) ->
        a = form.elements['answer'].value.upper().replace(',','').replace('.', '').replace(' ','')
        c = l.elm.real_text.upper().replace(',',' ').replace('.', ' ').replace(' ','')
        
        if a == c or a of l.alternative_names
            done_quiz(l,true)
        else
            l.quiz.score -= 0.25
            l.elm.querySelector('.score').textContent = 'score: +' + get_score_as_string(l) + 'pts'
            form.elements['answer'].value = null
        if l.quiz.score < 0.001
            l.quiz.done = true
            done_quiz(l,false)
        
        tour_viewer.save_quiz_state(l.quiz)

    quiz = document.createElement('form')
    quiz.classList.add('question_quiz')
    answer = document.createElement('textarea')
    answer.classList.add('text-input')
    answer.classList.add('answer')
    answer.id = 'answer'
    answer.placeholder = 'Write you answer'
    answer.addEventListener('keydown', keydown)
    quiz.appendChild(answer)
    submit_button = document.createElement('div')
    submit_button.classList.add('panel-button')
    submit_button.textContent = 'submit'
    quiz.appendChild(submit_button)
    submit_button.onclick = () -> submit_answer(quiz)
    
    show_label_based_quiz(l, quiz, 'Name the part')
    quizzed_labels.push(l)

    l.elm.querySelector('.score').textContent = 'score: +' + get_score_as_string(l) + 'pts'

    if l.quiz.done
        if l.quiz.score == 0
            done_quiz(l,false)
        else
            done_quiz(l,true)

    if l.quiz.hide
        hide_quiz(l)
        
    if tour_editor.is_editing()
        tour_editor.save_state()

custom_choose_answer_quiz = (parsed_quiz, obj, point, normal) ->
    unselect_all()
    text = 'quiz'
    if parsed_quiz
        point = parsed_quiz.point
        obj = objects[parsed_quiz.obj]
    else
        vec3.scale(normal, normal, 0.001)
        vec3.add(point, point, normal)
        
    l = create_label(obj and obj.name, point, text, true)
    l.delete_on_unquizz = true
    choose_answer_quiz(l, null, true, obj, point, normal)

choose_answer_quiz = (l, parsed_quiz, edit=false, obj, point, normal) ->
    if not l and parsed_quiz
        if parsed_quiz.label_id of labels_by_id
            l = labels_by_id[parsed_quiz.label_id]
        else
            unselect_all()
            text = 'quiz'
            point = parsed_quiz.point
            obj = objects[parsed_quiz.obj]
            id = parsed_quiz.label_id
            l = create_label(obj and obj.name, point, text, true, 0, id)
            l.delete_on_unquizz = true
        l.quiz = parsed_quiz
    
    if not l.quiz
        if obj
            o = obj.name
        else
            o = null
        l.quiz = {
            'label_id': l.id,
            'type':'choose_answer_quiz',
            'score':1,
            'done':false,
            'hide':true,
            'answer_ids':[],
            'answers':[],
            'failed':[],
            'question': null,
            'correct': -1,
            'obj':o,
            'point':point,
            }
    
    if edit
        quiz = document.createElement('form')
    else
        quiz = document.createElement('ul')
        
    quiz.classList.add('choose_answer_quiz')

    success = (element) ->
        l.quiz.done = true
        done_quiz(l,true)
        tour_viewer.save_quiz_state(l.quiz)
        
    fail = (element) ->
        element.classList.add('fail')
        l.quiz.failed.append(element.order)
        l.quiz.score -= 1/(answers.length-1)
        l.elm.querySelector('.score').textContent = 'score: +' + get_score_as_string(l) + 'pts'

        if l.quiz.score < 0.001
            l.quiz.done = true
            done_quiz(l,false)
            
        tour_viewer.save_quiz_state(l.quiz)

    if l.quiz.question
        answers = l.quiz.answers
        question = l.quiz.question
        correct = answers[l.quiz.correct]
    else
        answers = []
        question = 'Select the correct name'
        if not l.quiz.answer_ids.length
            p = l.point
            answer_labels = label_list[...]
            for a in answer_labels
                a._dist = vec3.sqrDist(p, a.point)
            answer_labels.sort((a,b) ->a._dist - b._dist)
            for a in quizzed_labels
                answer_labels.remove(a)
            answer_labels = shuffle(answer_labels[...5])
            for a in answer_labels
                l.quiz.answer_ids.append(a.id)
                answers.append(a.elm.real_text)
        else
            for id in l.quiz.answer_ids
                answers.append(labels_by_id[id].elm.real_text)
        correct = l.elm.real_text
    
    if edit
        question = ''

        check_can_save = ->
            s.classList.remove('disabled')
            for e in quiz.elements
                if(e.id.startswith('A') or e.id =='q') and not e.value
                    s.classList.add('disabled')
                    
        save_quiz = (event) ->
            event.stopPropagation()
            l.quiz.type = 'choose_answer_quiz'
            l.quiz.question = quiz.elements['q'].value
            for n in [0...quiz.children.length-2]
                ind = n+1
                l.quiz.answers.append(quiz.elements['Answer ' + ind].value)
                if quiz.elements['CB ' + ind].checked
                    l.quiz.correct = n
            hide_quiz(l)
            if tour_editor.is_editing()
                tour_editor.save_state()
                
        checkbox_click = (event) ->
            event.preventDefault
            cbs = quiz.querySelectorAll('.checkbox')
            for cb in cbs
                cb.checked = false
            this.checked = true
            
        remove_answer = (event) ->
            add_b.classList.remove('disabled')
            if quiz.children.length > 4
                to_remove = reversed(quiz.children)[0]
                if to_remove.children[1].checked
                    quiz.elements['CB 1'].checked = true
                quiz.removeChild(to_remove)
                if quiz.children.length == 4
                    remove_b.classList.add('disabled')
                check_can_save()
                
        add_answer = (event) ->
            s.classList.add('disabled')
            remove_b.classList.remove('disabled')
            if quiz.children.length < 10
                i = quiz.children.length - 1
                li = document.createElement('li')
                inp = document.createElement('textarea')
                inp.id = 'Answer '+ (i)
                inp.placeholder = 'Answer '+ (i)
                inp.classList.add('answer')
                inp.classList.add('text-input')
                inp.order = i
                inp.onkeyup = check_can_save
                cb = document.createElement('input')
                cb.id = 'CB '+ (i)
                cb.type = 'checkbox'
                cb.classList.add('checkbox')
                cb.onclick = checkbox_click
                cb.order = i
                li.appendChild(inp)
                li.appendChild(cb)
                quiz.appendChild(li)
                if quiz.children.length == 10
                    add_b.classList.add('disabled')
        
        li = document.createElement('li')
        q = document.createElement('textarea')
        q.classList.add('text-input')
        q.id = 'q'
        q.onkeyup = check_can_save
        q.placeholder = 'question'
        quiz.appendChild(q)
        li.appendChild(q)
        s = document.createElement('div')
        s.classList.add('panel-button')
        s.classList.add('disabled')
        s.textContent = 'done'
        s.id = 's'
        s.onclick = save_quiz
        li.appendChild(s)
        quiz.appendChild(li)
        lib = document.createElement('li')
        add_b = document.createElement('div')
        add_b.classList.add('panel-button')
        add_b.textContent = 'add answer'
        add_b.onclick = add_answer
        remove_b = document.createElement('div')
        remove_b.classList.add('panel-button')
        remove_b.textContent = 'remove answer'
        remove_b.onclick = remove_answer
        lib.appendChild(add_b)
        lib.appendChild(remove_b)
        quiz.appendChild(lib)
        add_b.onclick()
        add_b.onclick()
        remove_b.classList.add('disabled')
        quiz.querySelector('.checkbox').checked = true
        
    else
        i = 0
        for a in answers
            li = document.createElement('li')
            li.textContent = a
            li.classList.add('panel-button')
            li.classList.add('answer')
            li.order = i
            if a != correct
                li.addEventListener('click', () ->fail())
            else
                li.addEventListener('click', () ->success())
            i += 1
            quiz.appendChild(li)
        
    show_label_based_quiz(l, quiz, question, not edit)
    quizzed_labels.push(l)
    
    for a in l.quiz.failed
        quiz.children[a].classList.add('fail')
    l.elm.querySelector('.score').textContent = 'score: +' + get_score_as_string(l) + 'pts'

    if l.quiz.done
        if l.quiz.score < 0.001
            done_quiz(l,false)
        else
            done_quiz(l,true)

    if l.quiz.hide
        hide_quiz(l)
        
    if tour_editor.is_editing() and not edit
        tour_editor.save_state()

done_quiz = (l,success) ->
    l.quiz.done = true
    if l.quiz.score
        l.elm.textContent = l.elm.real_text + ' +' +get_score_as_string(l) 
        l.elm.classList.add('success')
    else
        l.elm.textContent = l.elm.real_text + ' FAILED'
        l.elm.classList.add('fail')
    l.update_orig_size()

unquizz = (l) ->
    if l.quiz
        if l.delete_on_unquizz
            label_list.remove(l)
            labels_div.removeChild(l.elm)
            delete labels_by_id[l.id]
        l.quiz = null
        l.elm.onmouseup = null
        l.elm.textContent = l.elm.real_text
        l.elm.classList.remove('success')
        l.elm.classList.remove('fail')
        l.elm.classList.remove('hide')
        l.elm.style.webkitTransition = 'none'
        delete_transition = ->
            l.elm.style.webkitTransition = ''
            
        window.setTimeout(delete_transition, 1000)
        l.update_orig_size()
    quizzed_labels.remove(l)
    
unquizz_all = ->
    for l in quizzed_labels[...]
        unquizz(l)







    
