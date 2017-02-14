
main_view = require './main_view'

# Boilerplate
React = require 'react'
{div, ul, li} = React.DOM


# This is a model

example_model = [
    {name: 'one'}
    {name: 'two'}
    {name: 'three', color: 'green'}
    {name: 'four'}
    {name: 'five'}
]

# This is a view (that goes here, in views)
# Try modifying anything and saving while the application is running

ExampleView = React.createFactory React.createClass {
    render: ->
        div {className: 'ExampleView'},
            div {}, 'Click to delete an element'
            ul {},
                for element in example_model
                    li
                        # Guess what happens when we remove the "do ->"
                        onClick: do (element) -> ->
                            example_delete_element(example_model, element)
                        style:
                            color: element.color or ''
                        element.name
}

# This is a controller

example_delete_element = (model, element) ->
    model.splice(model.indexOf(element), 1)
    main_view.render_all_views()

# We need to export the things we use outside

module.exports = {ExampleView}
