{ Library, App, List } = require(\janus)
stdlib = require(\janus-stdlib)
{ Global, Player, Transcript, Lookup, Glossary, Timer, Chapter, Topic, Exhibit } = require('./model')

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
  require('./guide/conductor').registerWith(views)
  require('./guide/narration').registerWith(views)
  resolvers = new Library()
  require('./model').registerWith(resolvers)
  global = new Global({ own_href: href, mode: { kiosk, exhibit }, +guide })
  new App({ views, resolvers, global })

# player with seed data.
playerer = (data) ->
  new Player(
    loops:
      flight: Transcript.deserialize( lines: data['flight-director-loop'], markup: \#script-flight-director-loop, name: 'Flight Director\'s Loop', edit_url: 'https://github.com/issa-tseng/apollo13rt/edit/master/script/flight-director-loop.txt', lookup: Lookup.deserialize(data['flight-director-loop.lookup']) )
      air_ground: Transcript.deserialize( lines: data['air-ground-loop'], markup: \#script-air-ground-loop, name: 'Air-Ground Loop', edit_url: 'https://github.com/issa-tseng/apollo13rt/edit/master/script/air-ground-loop.txt', lookup: Lookup.deserialize(data['air-ground-loop.lookup']) )
    glossary: Glossary.deserialize(data.glossary, data['glossary.lookup'])
    audio: { src: 'assets/mixdown.m4a' }
    timestamp: { offset: 200_771 }
    accident: { epoch: 201_293 }
    timers: new List([
      new Timer( start: 204_517, zero: 211_357, end: 206_649, caption: 'Predicted fuel cell depletion', hot: new List([ new Timer( start: 206_647, end: 206_650 ) ]) ),
      new Timer( start: 206_649, zero: 209_049, end: 206_942, caption: 'Predicted fuel cell depletion', hot: new List([ new Timer( start: 206_649, end: 206_653 ), new Timer( start: 206_938, end: 206_943 ) ])
      ),
      new Timer( start: 206_942, zero: 208_022, end: 207_178, caption: 'Predicted fuel cell depletion', hot: new List([ new Timer( start: 206_941, end: 206_945 ) ]) ),
      new Timer( start: 207_178, zero: 208_258, end: 207_914, caption: 'Predicted fuel cell depletion', hot: new List([ new Timer( start: 207_178, end: 207_182 ), new Timer( start: 207_362, end: 207_366 ) ]) ),
      new Timer( start: 207_914, zero: 208_154, end: 209_042, caption: 'Predicted fuel cell depletion', hot: new List([ new Timer( start: 207_914, end: 207_917 ), new Timer( start: 208_094, end: 209_040 ) ]) ),

      new Timer( start: 217_527, zero: 221_388, end: 221_423, caption: 'Free-return trajectory engine burn', hot: new List([ new Timer( start: 221_328, end: 221_419 ) ]) )
    ]),
    chapters: new List([
      new Chapter( start: 200_774, end: 204_143, title: 'A problem', description: 'The crew and the flight controllers scramble to stabilize a mysteriously misbehaving spacecraft while attempting to locate the source of their problems.' ),
      new Chapter( start: 204_144, end: 207_692, title: 'Bleeding', description: 'Odyssey has settled down, but continues to lose critical oxygen. Attention turns to diagnosing and stemming the bleeding in order to save the spacecraft, mission, and crew.' ),
      new Chapter( start: 207_693, end: 210_898, title: 'Aquarius', description: 'It is now clear that Odyssey is damaged beyond repair, with little life left. All efforts turn to getting the Lunar Module powered up in literal record time to serve as a lifeboat.' ),
      new Chapter( start: 210_899, end: 214_611, title: 'Planning', description: 'With the Command Module completely dark and Aquarius running hot, considerations begin on how to stretch the Lunar Module\'s limited power and coolant supplies several times longer than their designed limit.' ),
      new Chapter( start: 214_612, end: 217_367, title: 'Static', description: 'Communications problems that have been brewing for an hour culminate in a complete loss of contact with Aquarius.' ),
      new Chapter( start: 217_368, end: 221_471, title: 'Free-return', description: 'With communications restored, the crew must complete a 2-hour burn preparation in half that time to get the spacecraft on a course home.' ),
      new Chapter( start: 221_472, end: 223_620, title: 'Epilogue', description: 'Apollo 13 is headed home. But how will the crew survive and re-enter?' )
    ])
  )

# fixed list of exhibit topics for the toc.
exhibiter = ->
  new List([
    new Topic( title: 'primer', exhibits: new List([
      new Exhibit( lookup: \primer-intro, title: 'Apollo 13 Real-time', description: 'Get an overview of the real-time experience.' ),
      new Exhibit( lookup: \primer-spaceflight, title: 'Spaceflight 101', description: 'Learn the basics of spaceflight and orbital mechanics.' ),
      new Exhibit( lookup: \primer-apollo, title: 'Apollo Architecture', description: 'See how Apollo got to the Moon and back.' ),
      new Exhibit( lookup: \primer-accident, title: 'The Accident', description: 'There\'s more to the story than "Houston, we\'ve had a problem."' )
    ])),
    new Topic( title: 'overview', exhibits: new List([
      new Exhibit( lookup: \overview-propulsion, title: 'Getting to the Moon', description: 'A walkthrough of the propulsion and maneuvering systems.' ),
      new Exhibit( lookup: \overview-navigation, title: 'Navigating the Stars', description: 'An introduction to the navigation systems and processes.' ),
      new Exhibit( lookup: \overview-power, title: 'Powering the Spacecraft', description: 'A look at the electrical systems that become critical on 13.' ),
      new Exhibit( lookup: \overview-personnel, title: 'The Flight Controllers', description: 'An overview of relevant flight controller positions in Mission Control.' )
      new Exhibit( lookup: \overview-reading, title: 'Further Reading', description: 'Books, video, and interactive resources for further exploration.' )
    ])),
    new Topic( title: 'reference', exhibits: new List([
      new Exhibit( lookup: \ref-panel-cm-mdc, title: 'Command Module Main Display Console', description: 'High-resolution diagram of the main CM control panel.', reference: true ),
      new Exhibit( lookup: \ref-panel-cm-aux, title: 'Command Module Auxiliary Panels', description: 'High-resolution diagram of additional CM panels.', reference: true ),
      new Exhibit( lookup: \ref-panel-lm, title: 'Lunar Module Control Panels', description: 'High-resolution diagram of the Lunar Module panels.', reference: true ),
      new Exhibit( lookup: \ref-panel-eps, title: 'Fuel Cell Systems', description: 'Annotated diagram of the EPS fuel cell systems.', reference: true ),
      new Exhibit( lookup: \ref-panel-o2, title: 'Oxygen Subsystem', description: 'Annotated combined diagram of the EPS/ECS oxygen subsystems.', reference: true )
    ]))
  ])


module.exports = { apper, playerer, exhibiter }

