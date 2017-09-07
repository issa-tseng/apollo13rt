$ = require(\jquery)

{ Varying } = require(\janus)
stdlib = require(\janus-stdlib)
{ from-event-now } = stdlib.util.varying
{ min, max, floor } = Math


module.exports = util =
  defer: (f) -> set-timeout(f, 0)
  wait: (time, f) -> set-timeout(f, time)
  clamp: (min, max, x) --> if x < min then min else if x > max then max else x
  px: (x) -> "#{x}px"
  pct: (x) -> "#{x * 100}%"
  pad: (x) -> if x < 10 then "0#x" else x
  get-time: -> (new Date()).getTime()
  max-int: Number.MAX_SAFE_INTEGER

  nonextant: (x) -> !x?
  is-blank: (x) -> !x? or (x is '') or Number.isNaN(x)
  if-extant: (f) -> (x) -> f(x) if x?

  hms-to-epoch: (hh, mm, ss) -> (hh * 60 * 60) + (mm * 60) + ss
  epoch-to-hms: (epoch) -> {
    hh: epoch / 3600 |> floor
    mm: epoch % 3600 / 60 |> floor
    ss: epoch % 60
  }
  hash-to-hms: (hash) ->
    if (hms = /^(..):(..):(..)$/.exec(hash))?
      [ _, hh, mm, ss ] = [ parse-int(x) for x in hms ]
      { hh, mm, ss }
    else
      null

  size-of: (selector) ->
    dom = $(selector)
    from-event-now($(window), \resize, -> { width: dom.width(), height: dom.height() })

  bump: (varying) ->
    varying.set(true)
    <- util.defer
    varying.set(false)

  attach-floating-box: (initiator, view, box-class = 'floating-box') ->
    box = $('<div/>').addClass(box-class)
    box.append(view.artifact())

    box.appendTo($('body'))
    target-offset = initiator.offset()
    box.css(\left, max(0, target-offset.left - box.outerWidth()))
    box.css(\top, min($(window).height() - box.outerHeight(), target-offset.top))

    initiator.addClass(\active)
    is-hovered = new Varying(true)
    targets = initiator.add(box)
    targets.on(\mouseenter, -> is-hovered.set(true))
    targets.on(\mouseleave, -> is-hovered.set(false))
    initiator.on(\mousedown, -> is-hovered.set(false))
    stdlib.util.varying.sticky(is-hovered, { true: 100 }).reactLater((hovered) ->
      if !hovered
        initiator.removeClass(\active)
        view.destroy()
        box.remove()
        this.stop()
    )

  load-assets: (assets, done) ->
    done() if !assets? or assets.length is 0

    result = {}
    completed = 0

    for let asset in assets
      (asset-data) <- $.getJSON("/assets/#asset.json")
      completed += 1
      result[asset] = asset-data
      done(result) if completed is assets.length

