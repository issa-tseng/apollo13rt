{ Model, attribute, from, List } = require(\janus)
{ floor, abs } = Math

# util.
defer = (f) -> set-timeout(f, 0)


class Global extends Model
  shadow: -> this

class Line extends Model
  @bind(\start.hh, from(\start.epoch).map ((/ 3600) >> floor))
  @bind(\start.mm, from(\start.epoch).map ((% 3600 / 60) >> floor))
  @bind(\start.ss, from(\start.epoch).map (% 60))

  @deserialize = (data) ->
    data.start = { epoch: data.start }
    data.end = { epoch: data.end }
    super(data)

  contains: (epoch) ->
    (start-epoch = this.get(\start.epoch))? and (start-epoch <= epoch) and (this.get(\end.epoch) >= epoch)

class LineVM extends Model
  @bind(\active, from(\player).watch(\timestamp.epoch).and(\line).all.map((epoch, line) ->
    line.contains(epoch)
  ))

class Lines extends List
  @modelClass = Line

class Transcript extends Model
  @attribute(\lines, class extends attribute.CollectionAttribute
    @collectionClass = Lines
    default: -> new Lines()
  )

  @attribute(\auto_scroll, class extends attribute.BooleanAttribute
    default: -> true
  )

  @bind(\line_vms, from(\lines).and(\player).and.self().all.map((rl, player, transcript) ->
    rl.map((line) -> new LineVM({ line, player, transcript })) if rl? and player?
  ))

  @bind(\active_lines, from(\line_vms).map((lvms) -> lvms?.filter((lvm) -> lvm.watch(\active))))
  @bind(\active_ids, from(\active_lines).map((active) -> active?.map((lvm) -> lvm.get(\line).get(\id)))) # these never change so we just get.

  @bind(\top_line, from(\active_lines).flatMap((active) -> active?.watchAt(0)))

  _initialize: ->
    transcript = this

  bindToPlayer: (player) -> this.set(\player, player)

class Player extends Model
  @attribute(\base_height, class extends attribute.NumberAttribute
    default: -> 350
  )

  @bind(\timestamp.epoch, from(\timestamp.timecode).and(\timestamp.offset).all.map (+))
  @bind(\timestamp.hh, from(\timestamp.epoch).map ((/ 3600) >> floor))
  @bind(\timestamp.mm, from(\timestamp.epoch).map ((% 3600 / 60) >> floor))
  @bind(\timestamp.ss, from(\timestamp.epoch).map (% 60))

  @bind(\accident.delta, from(\timestamp.epoch).and(\accident.epoch).all.map ((-) >> abs))
  @bind(\accident.occurred, from(\timestamp.epoch).and(\accident.epoch).all.map (>=))
  @bind(\accident.delta_hh, from(\accident.delta).map ((/ 3600) >> floor))
  @bind(\accident.delta_mm, from(\accident.delta).map ((% 3600 / 60) >> floor))
  @bind(\accident.delta_ss, from(\accident.delta).map (% 60))

  @bind(\scrubber.mouse.timecode, from(\scrubber.mouse.at).and(\audio.length).all.map ((*) >> floor))
  @bind(\scrubber.mouse.epoch, from(\scrubber.mouse.timecode).and(\timestamp.offset).all.map (+))
  @bind(\scrubber.mouse.hh, from(\scrubber.mouse.epoch).map ((/ 3600) >> floor))
  @bind(\scrubber.mouse.mm, from(\scrubber.mouse.epoch).map ((% 3600 / 60) >> floor))
  @bind(\scrubber.mouse.ss, from(\scrubber.mouse.epoch).map (% 60))

  @bind(\resize.mouse.delta, from(\resize.mouse.y).and(\resize.mouse.start).all.map (-))
  @bind(\height, from(\base_height).and(\resize.mouse.clicking).and(\resize.mouse.delta).all.map((base-height, clicking, delta) ->
    if clicking is true then base-height + delta else base-height
  ))

  _initialize: ->
    player = this

    # bind audio player properties back into the model.
    player.watch(\audio.player).react((dom) ->
      dom-raw = dom.get(0)
      dom.on(\playing, -> player.set(\audio.playing, true))
      dom.on(\pause, -> player.set(\audio.playing, false))
      dom.on(\durationchange, -> player.set(\audio.length, dom-raw.duration))

      last-timecode = 0
      dom.on(\timeupdate, ->
        timecode = (dom-raw.currentTime + 0.4) |> floor # shift the timecode slightly for alignment.
        if timecode isnt last-timecode
          last-timecode := timecode
          <- defer
          player.set(\timestamp.timecode, timecode)
      )
    )

    # attach transcripts to this player.
    for _, transcript of player.get(\loops)
      transcript.bindToPlayer(player)

    # set mouse start and player height on mouse down and mouse up.
    player.watch(\resize.mouse.clicking).react((clicking) ->
      if clicking is true
        player.set(\resize.mouse.start, player.get(\resize.mouse.y))
      else
        player.set(\base_height, player.get(\height))
    )


module.exports = { Global, Line, LineVM, Lines, Transcript, Player }

