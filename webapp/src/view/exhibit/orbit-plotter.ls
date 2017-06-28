{ sqrt, cos, sin, atan, abs, ceil } = Math
pi = Math.PI
square = (x) -> Math.pow(x, 2)
cube = (x) -> Math.pow(x, 3)
mag = (x, y) -> sqrt(square(x) + square(y))
earthRadius = 6378137
earthMu = 3.986004418e14

########
# MATH

# r and v are cartesian vectors; r in m; v in m/s
# returns tuple [ focus, d(theta) ]
vectorsToRPhi = (mu, r, v) ->
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


plotOrbit = (r0, v0, n = 128) ->
  r = vectorsToRPhi(earthMu, r0, v0)
  points = [ [ phi, r(phi) ] for phi from 0 to (2 * pi) by (2 * pi / n) ]
  trim = r0[0] - points[0][1]
  [ [ cos(theta) * d + trim, sin(theta) * d ] for [ theta, d ] in points ]

########
# DRAW

clear = (canvas) -> canvas.getContext('2d').clearRect(0, 0, canvas.clientWidth, canvas.clientHeight)

renderBody = (canvas, scaler, radius) ->
  ctx = canvas.getContext('2d')
  ctx.fillStyle = '#ccc'
  ctx.beginPath()
  ctx.ellipse(scaler.x(0), scaler.y(0), scaler.x(earthRadius) - scaler.x(0), scaler.y(earthRadius) - scaler.y(0), 0, 0, 2 * pi)
  ctx.fill()

renderPath = (canvas, scaler, points, color, width = 1) ->
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

genScaler = (hlimits, canvas) ->
  factor = canvas.clientWidth / (abs(hlimits[0]) + abs(hlimits[1]))
  ymin = canvas.clientHeight / 2 / -factor
  {
    x: (x) -> (x - hlimits[0]) * factor
    y: (y) -> (y - ymin) * factor
  }

########
# GLUE

example = (target, r0, v0, dv, duration, limits) ->
  scaler = genScaler(limits, target)
  timer = v = ticksLeft = null

  points0 = plotOrbit(r0, v0)
  numTicks = ceil(duration * 1000 / 40)
  dvD = [ dv[0] / numTicks, dv[1] / numTicks ]

  base = ->
    clear(target)
    renderBody(target, scaler, earthRadius)
    renderPath(target, scaler, points0, '#666')
  base()

  tick = ->
    v[0] += dvD[0]
    v[1] += dvD[1]
    points = plotOrbit(r0, v)

    base()
    renderPath(target, scaler, points, 'rgba(247, 247, 247, 0.8)', 4)
    renderPath(target, scaler, points, '#8c8', 2)
    if (ticksLeft -= 1) > 0
      timer = setTimeout(tick, 40)
    else
      $(target).removeClass('burning')

  ->
    clearTimeout(timer) if timer?
    $(target).addClass('burning')
    v = v0.slice()
    ticksLeft = numTicks
    tick()

#$(document).on('click', example([earthRadius + 185200, 0], [0, 7797], [ 1500, 0 ], 2, [ -9000000, 12000000 ]))
#$(document).on('click', example([earthRadius + 185200, 0], [0, 7797], [ 0, 1500 ], 2, [ -18000000, 9000000 ]))
#$(document).on('click', example([earthRadius + 185200, 0], [0, 7797], [ 0, -1500 ], 2, [ -8000000, 8000000 ]))

module.exports = { example }

