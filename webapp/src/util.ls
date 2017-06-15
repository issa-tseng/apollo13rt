$ = require(\jquery)

{ Varying } = require(\janus)
{ from-event-now } = require(\janus-stdlib).util.varying


module.exports =
  defer: (f) -> set-timeout(f, 0)
  clamp: (min, max, x) --> if x < min then min else if x > max then max else x
  px: (x) -> "#{x}px"
  pct: (x) -> "#{x * 100}%"
  pad: (x) -> if x < 10 then "0#x" else x
  get-time: -> (new Date()).getTime()
  max-int: Number.MAX_SAFE_INTEGER

  size-of: (selector) ->
    dom = $(selector)
    from-event-now($(window), \resize, -> { width: dom.width(), height: dom.height() })

