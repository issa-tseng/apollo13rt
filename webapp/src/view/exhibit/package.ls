
{ Orbit, OrbitView, earth-radius } = require('./orbit-plotter')

get-exhibit-model = -> switch(it)
| \orbits-fail => new Orbit( r: [ earth-radius + 185200, 0 ], v: [ 0, 7797 ], dv: [ 1500, 0 ], t: 2, hlimits: [ -12000000, 18000000 ], caption: { number: 1, text: 'pointing where we want to go and burning.' }, moon: true )
| \orbits-prograde => new Orbit( r: [ earth-radius + 185200, 0 ], v: [ 0, 7797 ], dv: [ 0, 1500 ], t: 2, hlimits: [ -18000000, 10000000 ], caption: { number: 2, text: 'burning in our direction of travel.' } )
| \orbits-retrograde => new Orbit( r: [ earth-radius + 185200, 0 ], v: [ 0, 7797 ], dv: [ 0, -1500 ], t: 2, hlimits: [ -11000000, 11000000 ], caption: { number: 3, text: 'burning opposite our direction of travel.' } )

module.exports = {
  get-exhibit-model
  registerWith: (library) ->
    library.register(Orbit, OrbitView)
    #library.register(Image, ImageView)
}

