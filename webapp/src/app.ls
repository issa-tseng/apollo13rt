
# basic requires.
$ = window.jQuery = window.$ = require(\jquery)
{ Varying, List } = require(\janus)
{ Library, App } = require(\janus).application
stdlib = require(\janus-stdlib)
{ Global, Glossary, Lookup, Player, Transcript, ExhibitArea, Topic, Exhibit } = require('./model')
{ from-event } = require(\janus-stdlib).util.varying

# util.
defer = (f) -> set-timeout(f, 0)

# basic app setup.
views = new Library()
stdlib.view.registerWith(views)
require('./view/player').registerWith(views)
require('./view/transcript').registerWith(views)
require('./view/glossary').registerWith(views)
require('./view/exhibit').registerWith(views)
require('./view/exhibit/package').registerWith(views)
global = new Global()
app = new App({ views, global })

# get and load player data.
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

# set up exhibit data.
topics = new List([
  new Topic( title: 'primer', exhibits: new List([
    new Exhibit( lookup: \primer-a13rt, title: 'Apollo 13 Real-time', description: 'Get an overview of the real-time experience.' ),
    new Exhibit( lookup: \primer-spaceflight101, title: 'Spaceflight 101', description: 'Learn the basics of spaceflight and orbital mechanics.' ),
    new Exhibit( lookup: \primer-apollo, title: 'Apollo Architecture', description: 'See how Apollo got to the Moon and back.' ),
    new Exhibit( lookup: \primer-accident, title: 'The Accident', description: 'There\'s more to the story than "Houston, we\'ve had a problem."' )
  ])),
  new Topic( title: 'overview', exhibits: new List([
    new Exhibit( title: 'Getting to the Moon', description: 'A walkthrough of the propulsion and maneuvering systems.' ),
    new Exhibit( title: 'Navigating the Stars', description: 'An introduction to the navigation systems and processes.' ),
    new Exhibit( title: 'Powering the Spacecraft', description: 'A look at the electrical systems that become critical on 13.' ),
    new Exhibit( title: 'Communicating with Apollo', description: 'A brief look at how ground communication and tracking was done.' ),
    new Exhibit( title: 'The Flight Controllers', description: 'An overview of each flight controller position in Mission Control.' )
  ])),
  new Topic( title: 'reference', exhibits: new List([
    new Exhibit( lookup: \ref-panel-cm-mdc, title: 'Command Module Main Display Console', description: 'Annotated diagram of the main CM control panel.', reference: true ),
    new Exhibit( lookup: \ref-panel-cm-aux, title: 'Command Module Auxiliary Panels', description: 'Annotated diagram of additional CM panels.', reference: true ),
    new Exhibit( title: 'Electrical Systems', description: 'High-resolution recreations of the EPS system diagrams.', reference: true ),
    new Exhibit( title: 'Environmental Systems', description: 'High-resolution recreations of the ECS system diagrams.', reference: true )
  ]))
])
viewer = new ExhibitArea({ topics })

# wait for document ready.
<- $
<- defer # because jquery does weird shit with exceptions.

# create and append views.
player-view = app.getView(player)
$('#player').append(player-view.artifact())
player-view.wireEvents()

exhibit-area = app.getView(viewer)
$('#exhibits').append(exhibit-area.artifact())
exhibit-area.wireEvents()

# other generic actions:
$document = $(document)

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

  floating-glossary = $('<div class="floating-glossary"/>')
  term-view = app.getView(term)
  floating-glossary.append(term-view.artifact())
  term-view.wireEvents()

  floating-glossary.appendTo($('body'))
  target-offset = initiator.offset()
  floating-glossary.css(\left, Math.max(0, target-offset.left - floating-glossary.outerWidth()))
  floating-glossary.css(\top, target-offset.top)

  initiator.addClass(\active)
  is-hovered = new Varying(true)
  targets = initiator.add(floating-glossary)
  targets.on(\mouseenter, -> is-hovered.set(true))
  targets.on(\mouseleave, -> is-hovered.set(false))
  stdlib.util.varying.sticky(is-hovered, { true: 100 }).react((hovered) ->
    if !hovered
      initiator.removeClass(\active)
      term-view.destroy()
      floating-glossary.remove()
      this.stop()
  )
)

# dumbest visual detail i've ever cared about:
is-scrolled = from-event($(document), \scroll, (.target.scrollingElement.scrollTop > 20))
global.watch(\exhibit)
  .flatMap((exhibit) -> if exhibit? then is-scrolled else false)
  .react(-> $('html').toggleClass(\dark-canvas, it))

