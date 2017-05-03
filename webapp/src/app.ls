
# basic requires.
$ = window.jQuery = window.$ = require(\jquery)
{ Library, App } = require(\janus).application
stdlib = require(\janus-stdlib)
{ Player, Transcript } = require('./model')

# basic app setup.
views = new Library()
stdlib.view.registerWith(views)
require('./view').registerWith(views)
app = new App({ views })

# get and load data.
(flight-loop) <- $.getJSON('/assets/flight-director-loop.json')
player = new Player( loops: { flight: Transcript.deserialize( lines: flight-loop ) } )
window.player = player

# create and append views.
<- $
flight-transcript-view = app.getView(player.get(\loops.flight))
$('#flight-loop').append(flight-transcript-view.artifact())
flight-transcript-view.wireEvents()

