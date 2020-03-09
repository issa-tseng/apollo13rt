$ = require(\jquery)
{ Model, bind, from, List, DomView, template, find } = require(\janus)

################################################################################
# STATIC DATA
# TODO: theoretically we should probably load all of this from elsewhere but.. whatever.

speaker-map = {
  FLIGHT: 'FLIGHT',
  'FLIGHT (off loop)': 'FLIGHT',
  CAPCOM: 'CAPCOM',
  'CAPCOM (off loop)': 'CAPCOM',
  EECOM: 'EECOM',
  'Maroon EECOM': 'EECOM',
  GNC: 'GNC',
  INCO: 'INCO',
  TELMU: 'TELMU',
  'Gold TELMU': 'TELMU',
  CONTROL: 'CONTROL',
  GUIDO: 'GUIDO',
  'Other GUIDO': 'GUIDO',
  'GUIDO (off loop)': 'GUIDO',
  FDO: 'FDO',
  RETRO: 'RETRO',
  FAO: 'FAO',
  PROCEDURES: 'PROCEDURES',
  AFD: 'AFD',
  'AFD (off loop)': 'AFD',
  NETWORK: 'NETWORK',
  SURGEON: 'SURGEON'
}

class Group extends Model
class Speaker extends Model
air-ground-speakers = new List([
  new Group({
    name: \spacecraft
    speakers: new List([
      new Speaker({ id: \CDR }), new Speaker({ id: \CMP }), new Speaker({ id: \CDR })
    ])
  })
  new Group({
    name: \none
    speakers: new List([ new Speaker({ id: \CAPCOM }) ])
  })
])
flight-director-speakers = new List([
  new Group({
    name: \none
    speakers: new List([ new Speaker({ id: \FLIGHT }), new Speaker({ id: \CAPCOM }) ])
  })
  new Group({
    name: \cm
    speakers: new List([ new Speaker({ id: \EECOM }), new Speaker({ id: \GNC }) ])
  })
  new Group({
    name: \lm
    speakers: new List([ new Speaker({ id: \TELMU }), new Speaker({ id: \CONTROL }) ])
  })
  new Group({
    name: \comms
    speakers: new List([ new Speaker({ id: \INCO }), new Speaker({ id: \NETWORK, +hidden }) ])
  })
  new Group({
    name: \trajectory
    speakers: new List([
      new Speaker({ id: \GUIDO }), new Speaker({ id: \FDO, +hidden }), new Speaker({ id: \RETRO, +hidden })
    ])
  })
  new Group({
    name: \none
    speakers: new List([
      new Speaker({ id: \FAO, +hidden })
      new Speaker({ id: \PROCEDURES, +hidden })
      new Speaker({ id: \AFD, +hidden })
      new Speaker({ id: \NETWORK, +hidden })
      new Speaker({ id: \SURGEON, +hidden })
    ])
  })
])


################################################################################
# MODELS

class CommsDisplay extends Model.build(
  bind(\active, from(\transcript).get(\active-ids)
    .and(\transcript).get(\lookup)
    .all.map((ids, lookup) ->
      result = new Set()
      return unless ids?
      for id of ids
        for term in lookup.get_(id).list
          source = speaker-map[term]
          result.add(source) if source?
      result
    )
  )
)
  @AirGroundLoop = air-ground-speakers
  @FlightDirectorLoop = flight-director-speakers


################################################################################
# VIEWS

class CommsView extends DomView.build($('
  <div class="comms">
    <h2>Communications</h2>
    <div class="comms-groups"/>
  </div>
  '),
  find('.comms-groups').render(from(\groups))
)

class GroupView extends DomView.build(
  $('<div class="speaker-group"/>'),
  find('div')
    .classGroup(\group-, from(\name))
    .render(from(\speakers))
)

class SpeakerView extends DomView.build(Model.build(
  bind(\comms, from(\view).map((v) -> v.closest_(CommsDisplay).subject))
  bind(\transcript, from(\comms).get(\transcript))
  bind(\active, from(\comms).get(\active).and.subject(\id)
    .all.map((active, speaker) -> active?.has(speaker)))
  bind(\visible, from.subject(\hidden).and.subject(\id).and(\transcript)
    .all.flatMap((hidden, speaker, transcript) ->
      return true unless hidden
      lines = transcript.get_(\lines).list
      transcript.get(\target_idx).map((idx) ->
        misses = 0
        while misses < 4 and idx < lines.length
          line = lines[idx + misses]
          return true if speaker-map[line.get_(\source)] is speaker
          misses += 1
        return false
      )
    ))
), $('
  <div class="speaker">
    <span class="name"/>
    <span class="icon-1"/>
    <span class="icon-2"/>
    <span class="icon-3"/>
  </div>
'), template(
  find('.speaker')
    .classGroup(\speaker-, from(\id))
    .classed(\active, from.vm(\active))
    .classed(\visible, from.vm(\visible))
  find('.name').text(from(\id))
))

module.exports = {
  Group, Speaker, CommsDisplay, CommsView, GroupView, SpeakerView
  registerWith: (library) ->
    library.register(CommsDisplay, CommsView)
    library.register(Group, GroupView)
    library.register(Speaker, SpeakerView)
}

