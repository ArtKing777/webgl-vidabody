

# This is not react, maybe this should be moved somewhere else...
# TODO: enable it only where we want.

enable_tooltips = ->
    tooltip_div = null
    tooltip_timeout = -1

    window.addEventListener('mouseover', (e) ->
        if e.target.title or e.target.titleCopy

            if e.target.title
                e.target.titleCopy = e.target.title
                e.target.removeAttribute('title')

            rect = e.target.getBoundingClientRect()

            if tooltip_div
                clearTimeout(tooltip_timeout)
            else
                tooltip_div = document.createElement('div')
                tooltip_div.classList.add('ToolTip')

            tooltip_div.innerHTML = '<div><div></div></div>' + e.target.titleCopy
            canvas_container.appendChild(tooltip_div)

            d = e.target.dataset.tooltipDirection or 'dn'
            x = rect.left + 0.5 * rect.width - 0.5 * tooltip_div.clientWidth
            y = rect.top + 0.1 * rect.height - tooltip_div.clientHeight
            switch d
                when 'up'
                    y = rect.bottom - 0.1 * rect.height + 7
                when 'lt'
                    x = rect.left + rect.width + 7
                    y = rect.top + 0.5 * rect.height - 0.5 * tooltip_div.clientHeight
                when 'rt'
                    x = rect.left - 7 - tooltip_div.clientWidth
                    y = rect.top + 0.5 * rect.height - 0.5 * tooltip_div.clientHeight

            tooltip_div.style.left = Math.min(Math.max(7, x|0), document.body.clientWidth  - tooltip_div.clientWidth  - 7) + 'px'
            tooltip_div.style.top  = Math.min(Math.max(7, y|0), document.body.clientHeight - tooltip_div.clientHeight - 7) + 'px'

            tooltip_div.firstChild.classList.add(d)

            tooltip_div.firstChild.style.top = ''
            tooltip_div.firstChild.style.left = ''
            if (d == 'dn') or (d == 'up')
                tooltip_div.firstChild.style.left = Math.min(
                    tooltip_div.clientWidth - 7, Math.max(7,
                        (rect.left + 0.5 * rect.width - parseInt(tooltip_div.style.left) - 7)
                    )
                ) + 'px'

            tooltip_timeout = setTimeout((-> canvas_container.removeChild(tooltip_div)), 1500)
    )
