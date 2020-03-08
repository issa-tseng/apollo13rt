{ Library, App, List } = require(\janus)
stdlib = require(\janus-stdlib)
{ Global, Player, Transcript, Lookup, Glossary, Timer, Chapter } = require('./model')

# determine application mode.
kiosk-mode = window.location.search is '?kiosk'
exhibit-mode = window.location.search is '?exhibit'

# basic app setup.
apper = (href, kiosk, exhibit) ->
  views = new Library()
  stdlib.view($).registerWith(views)
  require('./view/splash').registerWith(views)
  require('./view/player').registerWith(views)
  require('./view/transcript').registerWith(views)
  require('./view/glossary').registerWith(views)
  require('./view/exhibit').registerWith(views)
  require('./view/exhibit/package').registerWith(views)
  resolvers = new Library()
  require('./model').registerWith(resolvers)
  global = new Global( own_href: href, mode: { kiosk, exhibit } )
  new App({ views, resolvers, global })

# player with seed data.
playerer = (data) ->
  new Player(
    loops:
      flight: Transcript.deserialize( lines: data['flight-director-loop'], markup: \#script-flight-director-loop, name: 'Flight Director\'s Loop', edit_url: 'https://github.com/issa-tseng/apollo13rt/edit/master/script/flight-director-loop.txt', lookup: Lookup.deserialize(data['flight-director-loop.lookup']) )
      air_ground: Transcript.deserialize( lines: data['air-ground-loop'], markup: \#script-air-ground-loop, name: 'Air-Ground Loop', edit_url: 'https://github.com/issa-tseng/apollo13rt/edit/master/script/air-ground-loop.txt', lookup: Lookup.deserialize(data['air-ground-loop.lookup']) )
    glossary: Glossary.deserialize(data.glossary, data['glossary.lookup'])
    #audio: { src: 'assets/full.m4a' }
    audio: { src: 'assets/mixdown.aac' }
    timestamp: { offset: 200_771 }
    accident: { epoch: 201_293 }
    timers: new List([
      new Timer( start: 204_519, zero: 211_359, end: 206_650, caption: 'Predicted fuel cell depletion', hot: new List([ new Timer( start: 206_648, end: 206_650 ) ]) ),
      new Timer( start: 206_650, zero: 209_050, end: 206_942, caption: 'Predicted fuel cell depletion', hot: new List([ new Timer( start: 206_650, end: 206_654 ), new Timer( start: 206_940, end: 206_943 ) ])
      ),
      new Timer( start: 206_942, zero: 208_022, end: 207_178, caption: 'Predicted fuel cell depletion', hot: new List([ new Timer( start: 206_941, end: 206_945 ) ]) ),
      new Timer( start: 207_178, zero: 208_258, end: 207_917, caption: 'Predicted fuel cell depletion', hot: new List([ new Timer( start: 207_178, end: 207_182 ), new Timer( start: 207_362, end: 207_366 ) ]) ),
      new Timer( start: 207_917, zero: 208_157, end: 209_042, caption: 'Predicted fuel cell depletion', hot: new List([ new Timer( start: 207_917, end: 207_921 ), new Timer( start: 208_097, end: 209_040 ) ]) ),

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

module.exports = { apper, playerer }

