
# basic requires.
$ = window.jQuery = window.$ = require(\jquery)
{ Library, App } = require(\janus).application
stdlib = require(\janus-stdlib)
{ Global, Glossary, Lookup, Player, Transcript } = require('./model')

# util.
defer = (f) -> set-timeout(f, 0)

# basic app setup.
views = new Library()
stdlib.view.registerWith(views)
require('./view').registerWith(views)
global = new Global()
app = new App({ views, global })

# get and load data.
(flight-loop) <- $.getJSON('/assets/flight-director-loop.json')
(flight-loop-lookup) <- $.getJSON('/assets/flight-director-loop.lookup.json')
(air-ground-loop) <- $.getJSON('/assets/air-ground-loop.json')
(air-ground-loop-lookup) <- $.getJSON('/assets/air-ground-loop.lookup.json')
(glossary) <- $.getJSON('/assets/glossary.json')
(glossary-lookup) <- $.getJSON('/assets/glossary.lookup.json')
player = new Player(
  loops:
    flight: Transcript.deserialize( lines: flight-loop, name: 'Flight Director\'s Loop', edit_url: 'https://github.com/clint-tseng/apollo13rt/edit/master/script/flight-director-loop.txt', lookup: Lookup.deserialize(flight-loop-lookup) )
    air_ground: Transcript.deserialize( lines: air-ground-loop, name: 'Air-Ground Loop', edit_url: 'https://github.com/clint-tseng/apollo13rt/edit/master/script/air-ground-loop.txt', lookup: Lookup.deserialize(air-ground-loop-lookup) )
  glossary: Glossary.deserialize(glossary, glossary-lookup)
  audio: { src: 'assets/full.m4a' }
  timestamp: { offset: 200774 }
  accident: { epoch: 201293 }
)
global.set(\player, player)
window.player = player

# wait for document ready.
<- $
<- defer # because jquery does weird shit with exceptions.

# create and append views.
player-view = app.getView(player)
$('#player').append(player-view.artifact())
player-view.wireEvents()

# other generic actions:
# automatically tooltip if a title is hovered.
tooltip = $('#tooltip')
$(document).on(\mouseenter, '[title]', ->
  target = $(this)
  offset = target.offset()
  outer-width = target.outerWidth()
  text = target.attr(\title)

  tooltip.removeClass(\mirrored)
  tooltip.css(\left, offset.left + (outer-width / 2))
  tooltip.css(\top, offset.top)
  tooltip.text(text)
  tooltip.show()

  # reflect if necessary. detect because it has wrapped.
  if tooltip.height() > 13
    tooltip.addClass(\mirrored)
    tooltip.css(\left, 0) # move away for full measurement.
    tooltip.css(\left, offset.left + (outer-width / 2) - tooltip.outerWidth())

  target.attr(\title, '')
  target.one(\mouseleave, ->
    tooltip.hide()
    target.attr(\title, text) unless target.attr(\title) isnt ''
  )
)

# automatically define if a term is hovered.
glossary = player.get(\glossary)
floating-glossary = $('#floating-glossary')
$(document).on(\mouseenter, '.glossary-term', ->
  initiator = $(this)
  term = glossary.get("lookup.#{initiator.attr(\data-term)}")
  throw new Error("didn't find an expected term!") unless term?

  term-view = app.getView(term)
  floating-glossary.append(term-view.artifact())
  term-view.wireEvents()

  floating-glossary.show()
  target-offset = initiator.closest('p').offset()
  floating-glossary.css(\left, target-offset.left - floating-glossary.outerWidth())
  floating-glossary.css(\top, target-offset.top)

  initiator.on(\mouseleave, ->
    term-view.destroy()
    floating-glossary.hide()
    floating-glossary.empty()
  )
)

