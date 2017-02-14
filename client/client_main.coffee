
old_modules = require './tmp/old_modules'
window.addEventListener('DOMContentLoaded', old_modules.on_page_load)

window.vb = module.exports = old_modules
old_modules.main_view = require './views/main_view'
old_modules.error_screens = require './views/error_screens'
old_modules.old_views = require './views/old_views'
old_modules.organ_tree_view = require './views/organ_tree_view'
old_modules.tour_editor_view = require './views/tour_editor_view'
old_modules.tour_viewer_view = require './views/tour_viewer_view'
old_modules.tutorials = require './views/tutorials'
old_modules.ui_elements = require './views/ui_elements'
