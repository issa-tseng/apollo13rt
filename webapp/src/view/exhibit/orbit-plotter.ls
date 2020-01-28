{ DomView, template, find, from, Model, initial, bind } = require(\janus)
{ px } = require('../../util')


{ sqrt, cos, sin, atan, atan2, abs, ceil } = Math
pi = Math.PI
square = (x) -> Math.pow(x, 2)
cube = (x) -> Math.pow(x, 3)
mag = (x, y) -> sqrt(square(x) + square(y))
earth-radius = 6378137
earth-mu = 3.986004418e14

########
# MATH

# r and v are cartesian vectors; r in m; v in m/s
# returns tuple [ focus, d(theta) ]
vectors-to-RPhi = (mu, r, v) ->
  [ x, y ] = r
  [ vx, vy ] = v
  rmag = mag(x, y)
  hmag = x * vy - y * vx
  ex = vy * hmag / mu - x / rmag
  ey = -vx * hmag / mu - y / rmag
  e = mag(ex, ey)
  a = square(hmag) / mu / (1 - square(e))
  omega = atan(ey / ex)

  (phi) -> a * (1 - square(e)) / (1 + e * cos(phi + omega))


plot-orbit = (r0, v0, n = 256) ->
  r = vectors-to-RPhi(earthMu, r0, v0)
  points = [ [ phi, r(phi) ] for phi from 0 to (2 * pi) by (2 * pi / n) ]
  trim = r0.0 - points[0].1
  [ [ cos(theta) * d + trim, sin(theta) * d ] for [ theta, d ] in points ]

########
# DRAW

clear = (canvas) -> canvas.getContext('2d').clearRect(0, 0, canvas.clientWidth, canvas.clientHeight)

render-body = (canvas, scaler, radius) ->
  ctx = canvas.getContext('2d')
  ctx.fillStyle = '#ccc'
  ctx.beginPath()
  ctx.ellipse(scaler.x(0), scaler.y(0), scaler.x(earth-radius) - scaler.x(0), scaler.y(earth-radius) - scaler.y(0), 0, 0, 2 * pi)
  ctx.fill()

render-path = (canvas, scaler, points, color, width = 1) ->
  ctx = canvas.getContext('2d')
  ctx.strokeStyle = color
  ctx.lineWidth = width
  ctx.beginPath()
  ctx.moveTo(scaler.x(points[0]), scaler.y(points[1]))
  for [ x, y ] in points
    ctx.lineTo(scaler.x(x), scaler.y(y))
  ctx.closePath()
  ctx.stroke()

  null

gen-scaler = (hlimits, width, height) ->
  factor = width / (abs(hlimits[0]) + abs(hlimits[1]))
  ymin = height / 2 / -factor
  {
    x: (x) -> (x - hlimits.0) * factor
    y: (y) -> (y - ymin) * factor
  }

########
# GLUE

example = (target, r0, v0, dv, duration, limits) ->
  $target = $(target)
  scaler = gen-scaler(limits, $target.width(), $target.height())
  timer = v = ticks-left = null

  points0 = plot-orbit(r0, v0)
  num-ticks = ceil(duration * 1000 / 40)
  dvD = [ dv.0 / num-ticks, dv[1] / num-ticks ]

  base = ->
    clear(target)
    renderBody(target, scaler, earth-radius)
    renderPath(target, scaler, points0, '#666')
  base()

  tick = ->
    v.0 += dvD.0
    v.1 += dvD.1
    points = plot-orbit(r0, v)

    base()
    render-path(target, scaler, points, 'rgba(247, 247, 247, 0.8)', 4)
    render-path(target, scaler, points, '#8c8', 2)
    if (ticks-left -= 1) > 0
      timer := set-timeout(tick, 40)
    else
      $(target).removeClass('burning')

  ->
    clear-timeout(timer) if timer?
    $(target).addClass('burning')
    v := v0.slice()
    ticks-left := num-ticks
    tick()


########
# VIEW

class Orbit extends Model.build(
  initial(\width, 300)
  initial(\height, 150)

  initial(\earth, true)
  initial(\moon, false)

  bind(\scaler, from(\hlimits).and(\width).and(\height).all.map(gen-scaler))
)

class OrbitView extends DomView.build($('
    <div class="orbit">
      <canvas/>
      <div class="orbit-ship"/>
      <div class="orbit-playpause"/>
      <div class="orbit-earth orbit-label">Earth</div>
      <div class="orbit-travel orbit-label">Travel</div>
      <div class="orbit-moon orbit-label">Moon</div>
      <p class="orbit-caption">
        <strong>Figure <span class="orbit-caption-number"/></strong>: 
        <span class="orbit-caption-text"/>
      </p>
    </div>
  '), template(
    find('canvas').css(\width, from(\width).map(px))
    find('canvas').css(\height, from(\height).map(px))

    find('.orbit-ship').css(\left, from(\r).and(\scaler.x).all.map((r, scaler) -> scaler(r.0) |> px))
    find('.orbit-ship').css(\top, from(\r).and(\scaler.y).all.map((r, scaler) -> scaler(r.1) |> px))
    find('.orbit-ship').css(\transform, from(\dv).all.map((dv) -> "rotate(#{atan2(-1 * dv.1, dv.0) + (pi / 2)}rad)"))

    find('.orbit-earth').classed(\hide, from(\earth).map (not))
    find('.orbit-earth').css(\left, from(\scaler.x).all.map((scaler) -> scaler(0) |> px))
    find('.orbit-earth').css(\top, from(\scaler.y).all.map((scaler) -> scaler(0) |> px))

    find('.orbit-travel').css(\left, from(\r).and(\scaler.x).all.map((r, scaler) -> scaler(r.0) |> px))
    find('.orbit-travel').css(\top, from(\r).and(\scaler.y).all.map((r, scaler) -> scaler(r.1) |> px))

    find('.orbit-moon').classed(\hide, from(\moon).map (not))

    find('.orbit-caption-number').text(from(\caption.number))
    find('.orbit-caption-text').text(from(\caption.text))
))
  _wireEvents: ->
    dom = this.artifact()
    orbit = this.subject

    dom.find('.orbit-playpause').on(\click, example(dom.find('canvas')[0], orbit.get_(\r), orbit.get_(\v), orbit.get_(\dv), orbit.get_(\t), orbit.get_(\hlimits)))


module.exports = { Orbit, OrbitView, earth-radius }

