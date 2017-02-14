uri = 'https://docs.google.com/spreadsheets/d/1tqfxgzv7x4Lu5Us4_ZDPtZF1XROagsK7Jb7QcM5BOdE/pubhtml'

if process.argv[2]
    uri = process.argv[2].split('/')[...6].join('/')+'/pubhtml'
    console.log 'Using uri:', uri

https = require 'https'
fs = require 'fs'
htmlparser = require 'htmlparser'
sys = require 'util'


findIndex = (array, func) ->
  for item, index in array
    if func(item, index)
      return index

last  = (array) ->
  return array[array.length - 1]


download = (url, cb) ->
  request = https.get url, (response) ->
    data = ''
    response.setEncoding 'utf8'
    response.on 'data', (chunk) ->
      data += chunk
    response.on 'end', ->
      cb null, data
  request.on 'error', (err)->
    cb err


dom_element_to_text = (element) ->
  if not element?
    return ''
  if element.type == 'text'
    return element.data
  r = ''
  if element.children
    for child in element.children
      r += dom_element_to_text(child)
  return r

parse_html = (data) ->
  handler = new htmlparser.DefaultHandler(null, {verbose:false})
  parser = new htmlparser.Parser(handler)
  parser.parseComplete(data)
  return handler.dom[1]


check_left_right = (item) ->
  if item.name.indexOf('(R/L)') isnt -1 or item.name.indexOf('(L/R)') isnt -1
    item.name = item.name.replace(' (R/L)', '').replace(' (L/R)', '').trim()
    if item.objnames
      objname = item.objnames[0]
      n = objname.lastIndexOf('_Left')
      if n isnt -1
        objname = objname.slice(0, n) + objname.slice(n).replace('_Left', '_Right')
      else
        n = objname.lastIndexOf('_L')
        if n isnt -1
          objname = objname.slice(0, n) + objname.slice(n).replace('_L', '_R')
        else
          n = objname.lastIndexOf('_left')
          if n isnt -1
            objname = objname.slice(0, n) + objname.slice(n).replace('_left', '_right')
      if objname isnt item.objnames[0]
        item.objnames.push(objname)


console.log('downloading shreadsheet')
download uri, (err, data) ->
  console.log('parsing dom')
  html = parse_html(data)
  if not html.children?
      throw "The document is not published as HTML. Please publish it as HTML."

  console.log('converting dom into json')
  body = html.children[1]

  data =
    tree: []
    synonyms: []

  for page, i in body.children[1].children
    table_tree =
      name: '',
      children: []

    table_name = dom_element_to_text body.children[0].children[1].children[i]
    table_tree.name = table_name

    dom_table = page.children[0].children[0]
    tbody = dom_table.children[1]

    for tr in tbody.children
      item =
        name: ''
        children: []

      # find columnd with organ (or system) name
      col_index = findIndex tr.children, (item, i) ->
        if i is 0 then return false
        return dom_element_to_text(item) isnt ''

      # skip empty rows
      if col_index == undefined
        continue

      # replace [R/L] with (R,L)
      item.name =
        dom_element_to_text(tr.children[col_index])
        .split('[').join('(')
        .split(']').join(')')


      last_col = tr.children[13]
      objnames = dom_element_to_text(last_col)
      if objnames
        item.objnames = [objnames]


      parent = table_tree
      level = col_index
      stopped = false
      while (--level)
        if not parent.children
          console.error "Misalign in tab #{table_name}. Take a look into #{parent.name} -> #{item.name}"
          stopped = true
          break
        parent = last(parent.children)
        if not parent
          console.error "Misalign in tab #{table_name}. Take a look into #{item.name}"
          stopped = true
          break

      if stopped
        continue

      check_left_right(item)
      parent.children.push(item)

    data.tree.push(table_tree)



  fs.writeFile __dirname+'/../build/assetver/dev/organ_tree.json', JSON.stringify(data), ->
    console.log('Complete!')

    # This code is for testing.
    # Do you want to refactor this script?
    # make sure it will not change previously generated json
    # fs.readFile 'organ_tree_final.json', (err, final_data) ->
    #   fs.readFile 'organ_tree.json', (err, new_data) ->
    #     console.log('is same:', final_data.toString() == new_data.toString())
