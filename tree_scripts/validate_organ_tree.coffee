chalk = require 'chalk'

organ_tree = require('../build/assetver/dev/organ_tree.json')
mesh_list = require('../build/assetver/dev/mesh_list.json')

mesh_names_in_scene = mesh_list.mesh_names
mesh_names_in_organ_tree = []

log = (message) ->
  console.log chalk.red('Error: ') + ' ' + message


process_organ_tree_branch = (branch, path = '') ->
  # make sure we have name
  if not branch.name
    log "Branch #{chalk.yellow(path)} has no name"

  # make sure that item with no children has objnames
  if not branch.children?.length and not branch.objnames?.length
    log "Branch #{branch.name} has no children
                  and has no objnames. See #{chalk.yellow(path)}"

  # make sure objnames are presented in scene (mesh_list)
  if branch.objnames?.length
    for objname in branch.objnames
      if mesh_names_in_scene.indexOf(objname) == -1
        log "Mesh #{chalk.green(objname)} exists in
                      organ_tree.json but not in scene. It is in " +
                      chalk.yellow(path)
      else
        mesh_names_in_organ_tree.push(objname)

  # go deep
  path += " (#{branch.name}) -> "
  for child, i in branch.children
    subpath = path + " child ##{i}"
    process_organ_tree_branch(child, subpath)



for branch in organ_tree.tree
  process_organ_tree_branch(branch)


# make sure all meshes in scene are presented in organ_tree.json
for mesh_name in mesh_names_in_scene
  if mesh_names_in_organ_tree.indexOf(mesh_name) == -1
    log "Mesh #{chalk.green(mesh_name)} exists in scene,
                  but not in organ_tree.json"
