
# basic requires.
$ = window.jQuery = window.$ = require(\jquery)
{ Library, App } = require(\janus).application
stdlib = require(\janus-stdlib)
{ Global, Player, Transcript } = require('./model')

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
player = new Player(
  loops: { flight: Transcript.deserialize( lines: flight-loop, name: 'Flight Director\'s Loop' ) }
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

# other generic actions.
tooltip = $('#tooltip')
$(document).on(\mouseenter, '[title]', ->
  target = $(this)
  offset = target.offset()

  tooltip.css(\left, offset.left + (target.outerWidth() / 2))
  tooltip.css(\top, offset.top)
  tooltip.text(target.attr(\title))
  tooltip.show()

  target.one(\mouseleave, -> tooltip.hide())
)

