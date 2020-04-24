
# basic requires.
$ = window.jQuery = window.$ = require(\jquery)
{ Varying, List, Library, App } = require(\janus)
{ Splash, Global, Glossary, Lookup, Player, Timer, Chapter, Transcript, ExhibitArea, Topic, Exhibit } = require('./model')
{ Conductor } = require('./guide/conductor')
{ from-event } = require(\janus-stdlib).varying

{ defer, hms-to-epoch, hash-to-hms, epoch-to-hms, attach-floating-box, load-assets, is-blank } = require('./util')
{ max, abs } = Math

{ apper, playerer, exhibiter } = require('./package')

# determine application mode, make application.
kiosk-mode = window.location.search is '?kiosk'
exhibit-mode = window.location.search is '?exhibit'
shows-guide = exhibit-mode is false and kiosk-mode is false
app = apper(window.location.href, kiosk-mode, exhibit-mode)
window.app = app

# debugging.
window.tap = (x) -> console.log(x); x

# generate toplevel references.
$document = $(document)
$window = $(window)
global = app.get_(\global)

# get and load player data. TODO: someday maybe merge these for perf?
data-paths = <[ flight-director-loop flight-director-loop.lookup air-ground-loop air-ground-loop.lookup glossary glossary.lookup script ]>
(data) <- load-assets(if exhibit-mode then [] else data-paths)

unless exhibit-mode is true
  player = playerer(data)
  global.set(\player, player)
  window.player = player
  $('#skiplink-start').one(\click, player~play)

unless kiosk-mode is true
  topics = exhibiter()
  exhibit-area = new ExhibitArea({ topics })

if shows-guide is true
  conductor = Conductor.deserialize(data.script)

# wait for document ready.
<- $

# show the splash screen.
if (kiosk-mode is true) or (exhibit-mode is true)
  $('body').removeClass(\init)
  $('html').addClass(\chromeless).toggleClass(\kiosk-mode, kiosk-mode).toggleClass(\exhibit-mode, exhibit-mode)
else
  splash-view = app.view(Splash.initialize())
  $('#splash').append(splash-view.artifact())
  splash-view.wireEvents()

# create and append views.
unless exhibit-mode is true
  player-view = app.view(player)
  $('#player').append(player-view.artifact())

unless kiosk-mode is true
  exhibit-area-view = app.view(exhibit-area)
  $('#exhibits').append(exhibit-area-view.artifact())

if shows-guide is true
  guide-area-view = app.view(conductor)
  $('#guide').append(guide-area-view.artifact())

# wire all events after rendering is done so relayout does not occur.
player-view.wireEvents() unless exhibit-mode is true
exhibit-area-view.wireEvents() unless kiosk-mode is true
guide-area-view.wireEvents() if shows-guide is true

# set initial player height to something sane, if necessary.
if player?
  window-height = $window.height()
  if window-height < 900
    player.set(\height, max(window-height - 550, 250))

# done with expensive loading operations; clear flag.
set-timeout((-> global.set(\loaded, true)), 250)

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
glossary = player?.get_(\glossary)
pop-glossary = (initiator) ->
  term = glossary.get_("lookup.#{initiator.attr(\data-term)}")
  throw new Error("didn't find an expected term!") unless term?

  term-view = app.view(term)
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

# open external links in a new window.
$document.on(\focus, 'a[href]', (event) ->
  $(this).attr(\target, \_blank) if this.host isnt window.location.host
)

# handle timecode hashes.
handle-timecode-hash = (hash) ->
  hms = hash-to-hms(hash)
  return unless hms?
  { hh, mm, ss } = hms
  epoch = hms-to-epoch(hh, mm, ss)

  if (player.get_(\timestamp.epoch) - epoch |> abs) > 90
    # only bookmark for somewhat significant leaps.
    player.bookmark()

  player.epoch(epoch)
  player.get_(\loops.flight).set(\auto_scroll, true)
  player.get_(\loops.air_ground).set(\auto_scroll, true)

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

  for exhibit in exhibit-area.get_(\all_topics).list when exhibit.get_(\lookup) is target-hash
    $('#splash .splash').data(\view)?.subject.destroy()
    global.set(\exhibit, exhibit)
    event?.preventDefault()
    return false

# immediately trigger exhibit navigation if exhibit kiosk mode is on.
handle-exhibit-hash(window.location.hash) if exhibit-mode is true

# actually capture link clicks and pass off to above handlers:
$document.on(\click, 'a:not(".passthrough")', (event) ->
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
global.get(\own_href).react((href) ->
  encoded = encodeURIComponent(href)
  fb-link.attr(\href, "https://www.facebook.com/sharer/sharer.php?u=#encoded")
  twitter-link.attr(\href, "https://twitter.com/home?status=Hear%20Apollo%2013%20happen%20in%20real%20time%3A%20#encoded")
)

# dumbest visual detail i've ever cared about:
is-scrolled = from-event($(document), \scroll, false, (.target.scrollingElement.scrollTop > 30))
global.get(\exhibit)
  .flatMap((exhibit) -> if exhibit? then is-scrolled else false)
  .react(false, -> $('html').toggleClass(\dark-canvas, it))

# navigate to hash and start playing automatically if we are in kiosk mode:
if kiosk-mode is true
  if (hms = hash-to-hms(window.location.hash?.slice(1)))?
    { hh, mm, ss } = hms
    player.epoch(hms-to-epoch(hh, mm, ss))
  player.play()

