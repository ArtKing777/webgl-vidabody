
React = require 'react'

{div, span, p, a, ul, li, img, h1, h2, h3, em, strong
canvas, pre, iframe, br,
form, input, label, button, datalist, option, optgroup,
svg, defs, linearGradient, stop} = React.DOM


# legacy format
OrganTreeLegacy = React.createFactory React.createClass {
    draw_children: (children) ->
        for c in children
            attribs = {'data-oname': c.objnames[0] if c.objnames, 'data-visiblename': c.name}
            if c.children? and c.children.length
                li attribs,
                    div {className: 'checkbox'}
                    label null, c.name
                    ul null, @draw_children(c.children)
            else
                li attribs,
                    div {className: 'checkbox'}
                    c.name
    render: ->
        ul {className: 'dragonfly-tree'}, @draw_children(@props.tree)
}

# (WIP) new format has label always and is a bit shorter:
OrganTree = React.createFactory React.createClass {
    draw_children: (children) ->
        for c in children
            li {onclick: do (c)-> -> console.log(c.name)},
                label null, c.name
                if c.children?
                    ul null, @draw_children(c.children)
    render: ->
        ul null, @draw_children(@props.tree)
}


# request_json('GET', '../scripts/organ_tree.json', load)


find_name_in_list = (name, list) ->
    for l in list
        if l.name == name
            return l
    l = {name: name, children: []}
    list.push(l)
    l


parse_tree = (d, mesh_list)->
    tree = []
    lines = d.split('\n')
    synonyms = []
    present = {}
    not_found = []
    mesh_list = mesh_list.mesh_names[...]
    i = 0
    for line in lines
        i += 1 # line number
        line = line.replace(/^\s*/, '')
        if not line or line[0] == '#'
            continue
        [line, objname...] = line.split('(')
        objname = objname[0] and objname[0].split(')')[0].replace(/\s/g, '')
        mirror = /\[(L\/R|R\/L)\]\s*$/.test line
        line = line.replace(/\s*\[(L\/R|R\/L)\]\s*/g, '').replace(/_/g, ' ').replace(/\.\s*$/g, '\u200B\u200B\u200B')
        line = line.split('/')
        line_no_syms = []
        list = tree
        for e in line
            e = e.replace(/^\s*/, '').replace(/\s*$/, '').replace(/\s*:\s*/g, ':').replace(/\s+/g, ' ').replace(/\[/g, '(').replace(/\]/g, ')').replace(/\\/g, '/')
            names = e.split(':')
            line_no_syms.push names[0]
            obj = find_name_in_list(names[0], list)
            alts = synonyms[names[0]] = synonyms[names[0]] or []
            for name in names[1...]
                if name not in alts
                    alts.push(name)
            list = obj.children
        if objname?
            if obj.objnames?
                console.log 'WARNING: This line is duplicated:'
                console.log i+':'+line_no_syms.join('/')+' ('+objname+')'
            obj.objnames = [objname]
            if mirror
                mirror_name = objname.replace(/_L$/,'_R').replace(/_Left$/,'_Right').replace(/_Left_exterior$/,'_Right_exterior').replace(/_left$/,'_right')
                if objname != mirror_name
                    obj.objnames = [objname, mirror_name]
                else
                    console.log 'WARNING: This object has no mirror:'
                    console.log line_no_syms.join('/')+' ('+objname+')'
            for o in obj.objnames
                idx = mesh_list.indexOf(o)
                if idx == -1 and not present[o]
                    not_found.push i+':'+line_no_syms.join('/')+' ('+o+')'
                else if not present[o]
                    present[o] = 1
                    mesh_list.splice(idx, 1)
        else if mirror
            console.log 'WARNING: This mirrored line has no object:'
            console.log line_no_syms.join('/')
    
    {tree: tree, synonyms: synonyms, not_found: not_found, unused: mesh_list}
    # React.renderComponent OrganTree({tree: ts.tree}), document.body.children[1]

build_organ_tree = ->
    fs = eval("require('fs')")
    tree = fs.readFileSync(__dirname+'/../../organ_tree.txt').toString()
    while (/^\$.*/m).test tree
        tree = tree.replace /^\$.*/m, (f, f2, f3) ->
            fs.readFileSync(__dirname+'/../../'+f[1...]).toString()
    mesh_list = JSON.parse(fs.readFileSync(__dirname+'/../../build/assetver/dev/mesh_list.json'))
    ts = parse_tree tree, mesh_list
    rendered = React.renderToStaticMarkup OrganTreeLegacy({tree: ts.tree})
    fs.writeFileSync(__dirname+'/../../build/assetver/dev/organ_tree.html', rendered)
    fs.writeFileSync(__dirname+'/../../build/assetver/dev/organ_tree.json', JSON.stringify({tree: ts.tree, synonyms: ts.synonyms}))
    console.log '\nnot_found:'
    console.log ts.not_found[...500]
    if ts.not_found.length > 500
        console.log '(list too long to show here)'
    console.log '\nunused:'
    unused = mesh_list.by_system
    for k,v of unused
        unused[k] = for n in v when n in ts.unused
            n
    console.log unused
    
if process? and not window?
    build_organ_tree()
else
    window.build_organ_tree = build_organ_tree
