{ Model, attribute, from, List } = require(\janus)
{ debounce } = require(\janus-stdlib).util.varying
{ floor, abs } = Math
{ flatten, unique } = require(\prelude-ls)

# util.
defer = (f) -> set-timeout(f, 0)
clamp = (min, max, x) --> if x < min then min else if x > max then max else x


class Global extends Model
  shadow: -> this



########################################
# TRANSCRIPT MODELS

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

  overlaps: (range-start, range-end) ->
    (start-epoch = this.get(\start.epoch))? and (start-epoch <= range-end) and (this.get(\end.epoch) >= range-start)

class LineVM extends Model
  @bind(\active, from(\player).watch(\timestamp.epoch).and(\line).all.map((epoch, line) ->
    line.contains(epoch)
  ))

  _initialize: ->
    # perf:
    this._start = this.get(\line).get(\start.epoch)
    this._end = this.get(\line).get(\end.epoch)
    this._id = this.get(\line).get(\id)

  overlaps: (range-start, range-end) -> this.get(\line).overlaps(range-start, range-end)

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

  # the index of the immediate-next line to be played regardless of active status.
  # determined by binary search for performance, unless the delta is small, in which
  # case we do a linear walk.
  @bind(\cued_idx, from(\line_vms).and(\player).all.flatMap((lvms, player) ->
    last-idx = null
    last-epoch = -999 # apparently null is zero.
    player?.watch(\timestamp.epoch).map((epoch) ->
      return unless epoch?

      idx = if abs(epoch - last-epoch) <= 30 then last-idx else (lvms.length / 2 |> floor)
      low = 0
      high = lvms.length - 1
      loop
        target-start = lvms.list[idx]._start
        target-end = lvms.list[idx]._end

        unless target-start?
          idx -= 1
          continue

        previous-idx = idx - 1
        until lvms.list[previous-idx]?._end? or previous-idx <= 0
          previous-idx -= 1

        if (target-start >= epoch) and ((idx is 0) or (lvms.list[previous-idx]._start < epoch))
          break
        else if abs(target-start - epoch) <= 30
          if target-start < epoch
            do
              idx += 1
            until lvms.list[idx]._start?
          else
            do
              idx -= 1
            until lvms.list[idx]._start?
        else if target-start < epoch
          low = idx
          idx = ((high - low) / 2 |> floor) + low
        else if target-start > epoch
          high = idx
          idx = ((high - low) / 2 |> floor) + low
        else
          throw new Error('what?')

      last-epoch := epoch
      last-idx := idx
    )
  ))

  # now that we have the cued idx, we potentially migrate backwards until we have
  # one of the earliest still-playing line or the next line to be played, in that
  # order of preference.
  @bind(\target_idx, from(\line_vms).and(\cued_idx).and(\player).watch(\timestamp.epoch).all.map((lvms, idx, epoch) ->
    return unless idx? # implies existence of lvms.

    candidate-idx = idx - 1
    loop
      break if candidate-idx < 0

      candidate-end = lvms.list[candidate-idx]._end
      if !candidate-end?
        search-id = lvms.list[candidate-idx]._id
        until (lvms.list[candidate-idx]._id is search-id) and lvms.list[candidate-idx]._end?
          candidate-idx -= 1
      else if candidate-end >= epoch
        idx = candidate-idx
        candidate-idx = idx - 1
      else
        break

    idx -= 1 unless (idx is 0) or (lvms.list[idx]._start <= epoch)
    idx
  ))
  @bind(\target_id, from(\line_vms).and(\target_idx).all.flatMap((lvms, idx) ->
    lvms?.watchAt(idx).flatMap (?._id)
  ))

  @bind(\active_lines, from(\line_vms).map((lvms) -> lvms?.filter (.watch(\active))))
  @bind(\active_ids, from(\active_lines).map((active) -> active?.map (._id))) # these never change so we just get.

  @bind(\top_line, from(\line_vms).and(\target_idx).all.flatMap((lvms, idx) -> lvms?.watchAt(idx)))

  @bind(\nearby_ids, from(\line_vms).and(\target_id).all.map((lvms, id) ->
    return unless lvms? and id?
    # TODO: object constancy?
    new List([ x for x from id - 2 til id + 2 ])
  ))
  @bind(\nearby_terms, from(\nearby_ids).and(\lookup).all.map((ids, lookup) ->
    ids?.flatMap((id) -> lookup?.watch(id.toString())).flatten()
  ))

  _initialize: ->
    transcript = this

  bindToPlayer: (player) -> this.set(\player, player)



########################################
# GLOSSARY MODELS

class Term extends Model
  @attribute(\synonyms, class extends attribute.CollectionAttribute
    default: -> new List()
  )
  @attribute(\hidden, attribute.BooleanAttribute)

  @bind(\matches, from(\term).and(\synonyms).all.map((term, synonyms) ->
    (x) -> (x is term) or (x in synonyms.list)
  ))

class Lookup extends Model
  @deserialize = (data) -> super({ [ id, new List(terms) ] for id, terms of data })

class Glossary extends Model
  @attribute(\show.personnel, class extends attribute.BooleanAttribute
    default: -> true
  )
  @attribute(\show.technical, class extends attribute.BooleanAttribute
    default: -> true
  )
  @attribute(\show.hidden, class extends attribute.BooleanAttribute
    default: -> false
  )

  @deserialize = (data) ->
    glossary = new Glossary()

    # create a lookup based on primary and synonym terms.
    lookup = {}
    list = []
    for term, def of data
      inflated = Term.deserialize(def)
      inflated.set(\glossary, glossary)
      lookup[term] = inflated
      list.push(inflated)

      if (synonyms = lookup[term].get(\synonyms))?
        for synonym in synonyms.list
          lookup[synonym] = lookup[term]

    glossary.set({ lookup, list: new List(list) })
    glossary



########################################
# PLAYER MODEL

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

  @bind(\nearby_terms, from(\loops.flight).watch(\nearby_terms).and(\loops.air_ground).watch(\nearby_terms).all.map (++))

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

  # navigates the player to a given epoch.
  epoch: (epoch) ->
    this.get(\audio.player).get(0).currentTime = (epoch - this.get(\timestamp.offset))


module.exports = { Global, Line, LineVM, Lines, Transcript, Term, Lookup, Glossary, Player }

