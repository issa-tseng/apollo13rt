
# basic requires.
$ = window.jQuery = window.$ = require(\jquery)
{ Varying, List } = require(\janus)
{ Library, App } = require(\janus).application
stdlib = require(\janus-stdlib)
{ Global, Glossary, Lookup, Player, Transcript, ExhibitArea, Topic, Exhibit } = require('./model')
{ from-event } = require(\janus-stdlib).util.varying

{ defer, hms-to-epoch, attach-floating-box, load-assets } = require('./util')

# basic app setup.
views = new Library()
stdlib.view.registerWith(views)
require('./view/player').registerWith(views)
require('./view/transcript').registerWith(views)
require('./view/glossary').registerWith(views)
require('./view/exhibit').registerWith(views)
require('./view/exhibit/package').registerWith(views)
stores = new Library()
require('./model').registerWith(stores)
global = new Global()
app = new App({ views, stores, global })

# get and load player data. TODO: someday maybe merge these for perf?
data-paths = <[ flight-director-loop flight-director-loop.lookup air-ground-loop air-ground-loop.lookup glossary glossary.lookup]>
(data) <- load-assets(data-paths)

player = new Player(
  loops:
    flight: Transcript.deserialize( lines: data['flight-director-loop'], name: 'Flight Director\'s Loop', edit_url: 'https://github.com/clint-tseng/apollo13rt/edit/master/script/flight-director-loop.txt', lookup: Lookup.deserialize(data['flight-director-loop.lookup']) )
    air_ground: Transcript.deserialize( lines: data['air-ground-loop'], name: 'Air-Ground Loop', edit_url: 'https://github.com/clint-tseng/apollo13rt/edit/master/script/air-ground-loop.txt', lookup: Lookup.deserialize(data['air-ground-loop.lookup']) )
  glossary: Glossary.deserialize(data.glossary, data['glossary.lookup'])
  audio: { src: 'assets/full.m4a' }
  timestamp: { offset: 200774 }
  accident: { epoch: 201293 }
)
global.set(\player, player)
window.player = player

# set up exhibit data.
topics = new List([
  new Topic( title: 'primer', exhibits: new List([
    new Exhibit( lookup: \primer-a13rt, title: 'Apollo 13 Real-time', description: 'Get an overview of the real-time experience.' ),
    new Exhibit( lookup: \primer-spaceflight, title: 'Spaceflight 101', description: 'Learn the basics of spaceflight and orbital mechanics.' ),
    new Exhibit( lookup: \primer-apollo, title: 'Apollo Architecture', description: 'See how Apollo got to the Moon and back.' ),
    new Exhibit( lookup: \primer-accident, title: 'The Accident', description: 'There\'s more to the story than "Houston, we\'ve had a problem."' )
  ])),
  new Topic( title: 'overview', exhibits: new List([
    new Exhibit( lookup: \overview-propulsion, title: 'Getting to the Moon', description: 'A walkthrough of the propulsion and maneuvering systems.' ),
    new Exhibit( lookup: \overview-navigation, title: 'Navigating the Stars', description: 'An introduction to the navigation systems and processes.' ),
    new Exhibit( lookup: \overview-power, title: 'Powering the Spacecraft', description: 'A look at the electrical systems that become critical on 13.' ),
    new Exhibit( lookup: \overview-personnel, title: 'The Flight Controllers', description: 'An overview of relevant flight controller positions in Mission Control.' )
  ])),
  new Topic( title: 'reference', exhibits: new List([
    new Exhibit( lookup: \ref-panel-cm-mdc, title: 'Command Module Main Display Console', description: 'High-resolution diagram of the main CM control panel.', reference: true ),
    new Exhibit( lookup: \ref-panel-cm-aux, title: 'Command Module Auxiliary Panels', description: 'High-resolution diagram of additional CM panels.', reference: true ),
    new Exhibit( lookup: \ref-panel-lm, title: 'Lunar Module Control Panels', description: 'High-resolution diagram of the Lunar Module panels.', reference: true ),
    new Exhibit( lookup: \ref-panel-eps, title: 'Fuel Cell Systems', description: 'Annotated diagram of the EPS fuel cell systems.', reference: true ),
    new Exhibit( lookup: \ref-panel-o2, title: 'Oxygen Subsystem', description: 'Annotated combined diagram of the EPS/ECS oxygen subsystems.', reference: true )
  ]))
])
exhibit-area = new ExhibitArea({ topics })

# wait for document ready.
<- $
<- defer # because jquery does weird shit with exceptions.

# create and append views.
player-view = app.vendView(player)
$('#player').append(player-view.artifact())

exhibit-area-view = app.vendView(exhibit-area)
$('#exhibits').append(exhibit-area-view.artifact())

# wire all events after rendering is done so relayout does not occur.
player-view.wireEvents()
exhibit-area-view.wireEvents()

# other generic actions:
$document = $(document)
$window = $(window)

# automatically tooltip if a title is hovered.
tooltip = $('#tooltip')
$document.on(\mouseenter, '[title]', ->
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
$document.on(\mouseenter, '.glossary-term:not(.active)', ->
  initiator = $(this)
  term = glossary.get("lookup.#{initiator.attr(\data-term)}")
  throw new Error("didn't find an expected term!") unless term?

  term-view = app.vendView(term)
  attach-floating-box(initiator, term-view)
  term-view.wireEvents()
)

# handle hash changes.
$window.on(\hashchange, (event) ->
  new-hash = window.location.hash?.slice(1)
  return unless new-hash?

  hms = /^(..):(..):(..)$/.exec(new-hash)
  if hms?
    [ _, hh, mm, ss ] = [ parse-int(x) for x in hms ]
    player.bookmark()
    player.epoch(hms-to-epoch(hh, mm, ss))
    player.get(\loops.flight).set(\auto_scroll, true)
    player.get(\loops.air_ground).set(\auto_scroll, true)
  else
    for exhibit in exhibit-area.get(\all_topics).list when exhibit.get(\lookup) is new-hash
      return global.set(\exhibit, exhibit)
)

# dumbest visual detail i've ever cared about:
is-scrolled = from-event($(document), \scroll, (.target.scrollingElement.scrollTop > 30))
global.watch(\exhibit)
  .flatMap((exhibit) -> if exhibit? then is-scrolled else false)
  .reactLater(-> $('html').toggleClass(\dark-canvas, it))

