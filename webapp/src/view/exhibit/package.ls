
{ Graphic } = require('../../model')
{ Orbit, OrbitView, earth-radius } = require('./orbit-plotter')
{ GraphicView } = require('./graphic')

get-exhibit-model = -> switch(it)
| \orbits-fail => new Orbit( r: [ earth-radius + 185200, 0 ], v: [ 0, 7797 ], dv: [ 1500, 0 ], t: 2, hlimits: [ -12000000, 18000000 ], caption: { number: 1, text: 'pointing where we want to go and burning.' }, moon: true )
| \orbits-prograde => new Orbit( r: [ earth-radius + 185200, 0 ], v: [ 0, 7797 ], dv: [ 0, 1500 ], t: 2, hlimits: [ -18000000, 10000000 ], caption: { number: 2, text: 'burning in our direction of travel.' } )
| \orbits-retrograde => new Orbit( r: [ earth-radius + 185200, 0 ], v: [ 0, 7797 ], dv: [ 0, -1500 ], t: 2, hlimits: [ -11000000, 11000000 ], caption: { number: 3, text: 'burning opposite our direction of travel.' } )
| \orbits-subtle => new Orbit( r: [ 384402000, 0 ], v: [ 0, 200 ], dv: [ 0, -20 ], t: 0.4, hlimits: [ -13000000, 400000000 ], caption: { number: 4, text: 'a tiny but fatal adjustment near the Moon. Earth is to the left.' }, earth: false )
| \lifecycle => new Graphic( src: 'assets/lifecycle.svg', height: 700, caption_number: 1, caption: 'Apollo lifecycle. The S-IVB is still attached in Earth orbit (1), and is jettisoned once the spacecraft is in trans-lunar coast (2). Once in lunar orbit (3), the CM waits in orbit while LM is sent and returns before it is dropped for trans-earth phase. The SM is ditched (4) just before entry interface.' )
| \arch-csm => new Graphic( src: 'assets/arch-csm.svg', height: 188 )
| \arch-lm => new Graphic( src: 'assets/arch-lm.svg', height: 126 )
| \arch-sivb => new Graphic( src: 'assets/arch-sivb.svg', height: 368 )
| \arch-lv => new Graphic( src: 'assets/arch-lv.svg', height: 1380 )
| \o2-tank => new Graphic( src: 'assets/o2-tank.svg', height: 365, caption_number: 1, caption: 'A cutaway view of an Apollo 13-era cryogenic oxygen tank. Later versions were modified to, among other things, reduce the exposed wiring and remove the fans entirely.' )
| \eps-thumbnail => new Graphic( src: 'assets/eps-fuelcells.svg', height: 215, caption_number: 1, caption: 'A highly detailed system diagram of the overall fuel cell system is available [here](#ref-panel-eps).' )
| \o2-thumbnail => new Graphic( src: 'assets/o2-subsystem.svg', height: 127, caption_number: 2, caption: 'A highly detailed system diagram of the overall cryogenic oxygen subsystem is available [here](#ref-panel-o2).' )
| \ac-phases => new Graphic( src: 'assets/ac-phases.svg', height: 240, down: true, caption_number: 3, caption: 'Above is a two-phase alternating current system showing current or voltage over time. Below is a three-phase system; note how the wavelengths are the same but with an additional phase they are packed closer together.' )
| \rcs => new Graphic( src: 'assets/rcs.svg', height: 140, down: true, caption_number: 1, caption: 'RCS thruster and package locations on board the combined Command/Service Module.', expandable: true )
| \burn-profile => new Graphic( src: 'assets/burn-profile.svg', height: 100, down: true, caption_number: 2, caption: 'A not-to-scale drawing of the typical scheduled burns of an Apollo mission. A: TLI, B: MCC, C: LOI, D: TEI, E: MCC.' )
| \pad => new Graphic( src: 'assets/pad.svg', height: 524, down: true, caption_number: 3, caption: 'A sample PAD form in which burn parameters would be read to the crew and transcribed. The N numbers on the right indicate computer program nouns, and the thick boxes indicated a +/- sign symbol.' )
| \imu => new Graphic( src: 'assets/imu.svg', height: 400, caption_number: 1, caption: 'A cutaway view of the active components of the Inertial Measurement Unit. The cylinders inside the central Stable Member were an assortment of gyroscopes and accelerometers.' )
| \msfn-sites => new Graphic( src: 'assets/msfn-sites.svg', height: 199, down: true, caption_number: 2, caption: 'A reproduction of a map of MSFN sites around the world, including mobile air and sea sites, around the Apollo era.', expandable: true )
| \aot-starchart => new Graphic( src: 'assets/aot-starchart.svg', height: 191, caption_number: 3, caption: 'An example star chart used with the AOT on the LM. The number below each marked star is the number the computer recognizes the star by.', expandable: true )
| \mocr => new Graphic( src: 'assets/mocr.svg', height: 175, caption_number: 1, caption: 'Floor plan layout of the various flight controller consoles within the MOCR.', expandable: true )

module.exports = {
  get-exhibit-model
  registerWith: (library) ->
    library.register(Orbit, OrbitView)
    library.register(Graphic, GraphicView)
}

