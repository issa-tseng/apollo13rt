
{ Graphic } = require('../../model')
{ Orbit, OrbitView, earth-radius } = require('./orbit-plotter')
{ GraphicView } = require('./graphic')

get-exhibit-model = -> switch(it)
| \orbits-fail => new Orbit( r: [ earth-radius + 185200, 0 ], v: [ 0, 7797 ], dv: [ 1500, 0 ], t: 2, hlimits: [ -12000000, 18000000 ], caption: { number: 1, text: 'pointing where we want to go and burning.' }, moon: true )
| \orbits-prograde => new Orbit( r: [ earth-radius + 185200, 0 ], v: [ 0, 7797 ], dv: [ 0, 1500 ], t: 2, hlimits: [ -18000000, 10000000 ], caption: { number: 2, text: 'burning in our direction of travel.' } )
| \orbits-retrograde => new Orbit( r: [ earth-radius + 185200, 0 ], v: [ 0, 7797 ], dv: [ 0, -1500 ], t: 2, hlimits: [ -11000000, 11000000 ], caption: { number: 3, text: 'burning opposite our direction of travel.' } )
| \orbits-subtle => new Orbit( r: [ 384402000, 0 ], v: [ 0, 200 ], dv: [ 0, -20 ], t: 0.4, hlimits: [ -13000000, 400000000 ], caption: { number: 4, text: 'a tiny but fatal adjustment near the Moon. Earth is to the left.' }, earth: false )
| \arch-csm => new Graphic( src: 'assets/arch-csm.svg', height: 188 )
| \arch-lm => new Graphic( src: 'assets/arch-lm.svg', height: 126 )
| \arch-sivb => new Graphic( src: 'assets/arch-sivb.svg', height: 368 )
| \arch-lv => new Graphic( src: 'assets/arch-lv.svg', height: 1380 )

module.exports = {
  get-exhibit-model
  registerWith: (library) ->
    library.register(Orbit, OrbitView)
    library.register(Graphic, GraphicView)
}

