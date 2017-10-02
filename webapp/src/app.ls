
# basic requires.
$ = window.jQuery = window.$ = require(\jquery)
{ Varying, List } = require(\janus)
{ Library, App } = require(\janus).application
stdlib = require(\janus-stdlib)
{ Splash, Global, Glossary, Lookup, Player, Timer, Chapter, Transcript, ExhibitArea, Topic, Exhibit } = require('./model')
{ from-event } = require(\janus-stdlib).util.varying

{ defer, hms-to-epoch, hash-to-hms, epoch-to-hms, attach-floating-box, load-assets, is-blank } = require('./util')
{ max, abs } = Math

# determine application mode.
kiosk-mode = window.location.search is '?kiosk'
exhibit-mode = window.location.search is '?exhibit'

# generate toplevel references.
$document = $(document)
$window = $(window)

# basic app setup.
views = new Library()
stdlib.view.registerWith(views)
require('./view/splash').registerWith(views)
require('./view/player').registerWith(views)
require('./view/transcript').registerWith(views)
require('./view/glossary').registerWith(views)
require('./view/exhibit').registerWith(views)
require('./view/exhibit/package').registerWith(views)
stores = new Library()
require('./model').registerWith(stores)
global = new Global( own_href: window.location.href, mode: { kiosk: kiosk-mode, exhibit: exhibit-mode } )
app = new App({ views, stores, global })

# render splash screen.
$ ->
  if (kiosk-mode is true) or (exhibit-mode is true)
    $('body').removeClass(\init)
    $('html').addClass(\chromeless).toggleClass(\kiosk-mode, kiosk-mode).toggleClass(\exhibit-mode, exhibit-mode)
  else
    splash-view = app.vendView(Splash.initialize())
    $('#splash').append(splash-view.artifact())
    splash-view.wireEvents()

# get and load player data. TODO: someday maybe merge these for perf?
data-paths = <[ flight-director-loop flight-director-loop.lookup air-ground-loop air-ground-loop.lookup glossary glossary.lookup ]>
(data) <- load-assets(if exhibit-mode then [] else data-paths)

unless exhibit-mode is true
  player = new Player(
    loops:
      flight: Transcript.deserialize( lines: data['flight-director-loop'], markup: \#script-flight-director-loop, name: 'Flight Director\'s Loop', edit_url: 'https://github.com/clint-tseng/apollo13rt/edit/master/script/flight-director-loop.txt', lookup: Lookup.deserialize(data['flight-director-loop.lookup']) )
      air_ground: Transcript.deserialize( lines: data['air-ground-loop'], markup: \#script-air-ground-loop, name: 'Air-Ground Loop', edit_url: 'https://github.com/clint-tseng/apollo13rt/edit/master/script/air-ground-loop.txt', lookup: Lookup.deserialize(data['air-ground-loop.lookup']) )
    glossary: Glossary.deserialize(data.glossary, data['glossary.lookup'])
    audio: { src: 'assets/full.m4a' }
    timestamp: { offset: 200_774 }
    accident: { epoch: 201_293 }
    timers: new List([
      new Timer( start: 204_519, zero: 211_359, end: 206_650, caption: 'Predicted fuel cell depletion', hot: new List([ new Timer( start: 206_648, end: 206_650 ) ]) ),
      new Timer( start: 206_650, zero: 209_050, end: 206_942, caption: 'Predicted fuel cell depletion', hot: new List([ new Timer( start: 206_650, end: 206_654 ) ])
      ),
      new Timer( start: 206_942, zero: 208_022, end: 207_917, caption: 'Predicted fuel cell depletion', hot: new List([ new Timer( start: 206_941, end: 206_945 ) ]) ),
      new Timer( start: 207_917, zero: 208_157, end: 209_031, caption: 'Predicted fuel cell depletion', hot: new List([ new Timer( start: 207_917, end: 207_921 ), new Timer( start: 208_097, end: 209_030 ) ]) ),

      new Timer( start: 217_527, zero: 221_388, end: 221_422, caption: 'Free-return trajectory engine burn', hot: new List([ new Timer( start: 221_328, end: 221_419 ) ]) )
    ]),
    chapters: new List([
      new Chapter( start: 200_774, end: 204_143, title: 'A problem', description: 'The crew and the flight controllers scramble to stabilize a mysteriously misbehaving spacecraft while attempting to locate the source of their problems.' ),
      new Chapter( start: 204_144, end: 207_692, title: 'Bleeding', description: 'Odyssey has settled down, but continues to lose critical oxygen. Attention turns to diagnosing and stemming the bleeding in order to save the spacecraft, mission, and crew.' ),
      new Chapter( start: 207_693, end: 210_898, title: 'Aquarius', description: 'It is now clear that Odyssey is damaged beyond repair, with little life left. All efforts turn to getting the Lunar Module powered up in literal record time to serve as a lifeboat.' ),
      new Chapter( start: 210_899, end: 214_611, title: 'Planning', description: 'With the Command Module completely dark and Aquarius running hot, considerations begin on how to stretch the Lunar Module\'s limited power and coolant supplies several times longer than their designed limit.' ),
      new Chapter( start: 214_612, end: 217_367, title: 'Static', description: 'Communications problems that have been brewing for an hour culminate in a complete loss of contact with Aquarius.' ),
      new Chapter( start: 217_368, end: 221_471, title: 'Free-return', description: 'With communications restored, the crew must complete a 2-hour burn preparation in half that time to get the spacecraft on a course home.' ),
      new Chapter( start: 221_472, end: 223_323, title: 'Epilogue', description: 'Apollo 13 is headed home. But how will the crew survive and re-enter?' )
    ])
  )
  global.set(\player, player)
  window.player = player

# set up exhibit data.
unless kiosk-mode is true
  topics = new List([
    new Topic( title: 'primer', exhibits: new List([
      new Exhibit( lookup: \primer-intro, title: 'Apollo 13 Real-time', description: 'Get an overview of the real-time experience.' ),
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

# create and append views.
unless exhibit-mode is true
  player-view = app.vendView(player)
  $('#player').append(player-view.artifact())

unless kiosk-mode is true
  exhibit-area-view = app.vendView(exhibit-area)
  $('#exhibits').append(exhibit-area-view.artifact())

# wire all events after rendering is done so relayout does not occur.
player-view.wireEvents() unless exhibit-mode is true
exhibit-area-view.wireEvents() unless kiosk-mode is true

# set initial player height to something sane, if necessary.
if player?
  window-height = $window.height()
  if window-height < 900
    player.set(\height, max(window-height - 550, 250))

# other generic actions:
# automatically tooltip if a title is hovered.
tooltip = $('#tooltip')
$document.on(\mouseenter, '[title]', ->
  target = $(this)
  offset = target.offset()
  outer-width = target.outerWidth()
  text = target.attr(\title)

  tooltip.removeClass('mirrored dropped fading')
  tooltip.css(\left, offset.left + (outer-width / 2))
  tooltip.css(\top, offset.top)
  tooltip.text(text)
  tooltip.show()

  # reflect if necessary. detect because it has wrapped.
  if target.hasClass(\reverse-tooltip) or (tooltip.height() > 16)
    tooltip.addClass(\mirrored)
    tooltip.css(\left, 0) # move away for full measurement.
    tooltip.css(\left, offset.left + (outer-width / 2) - tooltip.outerWidth())

  # drop if necessary.
  if offset.top < 25
    tooltip.addClass(\dropped)
    tooltip.css(\top, offset.top + target.outerHeight())

  target.attr(\title, '')
  target.one(\mouseleave, ->
    tooltip.hide()
    target.attr(\title, text) unless target.attr(\title) isnt ''
  )
)

# automatically define if a term is hovered.
glossary = player?.get(\glossary)
pop-glossary = (initiator) ->
  term = glossary.get("lookup.#{initiator.attr(\data-term)}")
  throw new Error("didn't find an expected term!") unless term?

  term-view = app.vendView(term)
  attach-floating-box(initiator, term-view)
  term-view.wireEvents()

$document.on(\mouseenter, '.glossary-term:not(.active)', -> pop-glossary($(this)))
$document.on(\touchstart, '.glossary-term', (event) ->
  event.stopPropagation()
  event.preventDefault()

  initiator = $(this)
  pop-glossary(initiator)
  initiator.one(\touchend, (event) ->
    event.stopPropagation()
    event.preventDefault()
  )
)

# handle timecode hashes.
handle-timecode-hash = (hash) ->
  hms = hash-to-hms(hash)
  return unless hms?
  { hh, mm, ss } = hms
  epoch = hms-to-epoch(hh, mm, ss)

  if (player.get(\timestamp.epoch) - epoch |> abs) > 90
    # only bookmark for somewhat significant leaps.
    player.bookmark()

  player.epoch(epoch)
  player.get(\loops.flight).set(\auto_scroll, true)
  player.get(\loops.air_ground).set(\auto_scroll, true)

# handle hash changes.
$window.on(\hashchange, (event) ->
  # first update our notion of what our own page url is.
  global.set(\own_href, window.location.href)

  # now see if we have some timecode navigation to do, and do it.
  return if exhibit-mode is true
  handle-timecode-hash(window.location.hash)
)

# handle internal exhibit links.
handle-exhibit-hash = (hash, event) ->
  target-hash = hash?.slice(1)
  return if is-blank(target-hash)

  for exhibit in exhibit-area.get(\all_topics).list when exhibit.get(\lookup) is target-hash
    $('#splash .splash').data(\view)?.subject.destroy()
    global.set(\exhibit, exhibit)
    event?.preventDefault()
    return false

# immediately trigger exhibit navigation if exhibit kiosk mode is on.
handle-exhibit-hash(window.location.hash) if exhibit-mode is true

# actually capture link clicks and pass off to above handlers:
$document.on(\click, 'a', (event) ->
  if this.host is window.location.host
    if this.hash is window.location.hash
      handle-timecode-hash(this.hash)
    else
      handle-exhibit-hash(this.hash, event)
)

# toplevel layout actions:
# update social media links.
fb-link = $('#share-fb')
twitter-link = $('#share-twitter')
global.watch(\own_href).react((href) ->
  encoded = encodeURIComponent(href)
  fb-link.attr(\href, "https://www.facebook.com/sharer/sharer.php?u=#encoded")
  twitter-link.attr(\href, "https://twitter.com/home?status=Hear%20Apollo%2013%20happen%20in%20real%20time%3A%20#encoded")
)

# dumbest visual detail i've ever cared about:
is-scrolled = from-event($(document), \scroll, (.target.scrollingElement.scrollTop > 30))
global.watch(\exhibit)
  .flatMap((exhibit) -> if exhibit? then is-scrolled else false)
  .reactLater(-> $('html').toggleClass(\dark-canvas, it))

# navigate to hash and start playing automatically if we are in kiosk mode:
if kiosk-mode is true
  if (hms = hash-to-hms(window.location.hash?.slice(1)))?
    { hh, mm, ss } = hms
    player.epoch(hms-to-epoch(hh, mm, ss))
  player.play()

