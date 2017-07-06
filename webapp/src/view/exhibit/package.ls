
{ Orbit, OrbitView, earth-radius } = require('./orbit-plotter')

get-exhibit-model = -> switch(it)
| \orbits-fail => new Orbit( r: [ earth-radius + 185200, 0 ], v: [ 0, 7797 ], dv: [ 1500, 0 ], t: 2, hlimits: [ -12000000, 16000000 ], moon: true )
| \orbits-prograde => new Orbit( r: [ earth-radius + 185200, 0 ], v: [ 0, 7797 ], dv: [ 0, 1500 ], t: 2, hlimits: [ -18000000, 9000000 ] )
| \orbits-retrograde => new Orbit( r: [ earth-radius + 185200, 0 ], v: [ 0, 7797 ], dv: [ 0, -1500 ], t: 2, hlimits: [ -10000000, 10000000 ] )

module.exports = {
  get-exhibit-model
  registerWith: (library) ->
    library.register(Orbit, OrbitView)
    #library.register(Image, ImageView)
}

