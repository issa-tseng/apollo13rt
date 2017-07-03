$ = require(\jquery)
{ floor, abs } = Math
{ flatten, unique } = require(\prelude-ls)

{ Model, attribute, from, List, Set, Varying } = require(\janus)
{ debounce } = require(\janus-stdlib).util.varying

{ defer, clamp } = require('./util')



########################################
# MISC MODELS

class Global extends Model
  shadow: -> this



########################################
# TRANSCRIPT MODELS

class Line extends Model
  @attribute(\tokens, attribute.CollectionAttribute)
  @attribute(\annotations, attribute.CollectionAttribute)

  @bind(\start.hh, from(\start.epoch).map ((/ 3600) >> floor))
  @bind(\start.mm, from(\start.epoch).map ((% 3600 / 60) >> floor))
  @bind(\start.ss, from(\start.epoch).map (% 60))

  @deserialize = (data) ->
    data.start = { epoch: data.start }
    data.end = { epoch: data.end }
    super(data)

  _initialize: ->
    # massage the description for annotations.
    this.set(\message, this.get(\message).replace(/\{([^}]+)\}/g, (_, text) -> "<span class=\"token-annotation\">#text</span>"))

    # perf:
    this._start = this.get(\start.epoch)
    this._end = this.get(\end.epoch)
    this._id = this.get(\id)

  contains_: (epoch) ->
    (start-epoch = this.get(\start.epoch))? and (start-epoch <= epoch) and (this.get(\end.epoch) >= epoch)

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

  # the index of the immediate-next line to be played regardless of active status.
  # determined by binary search for performance, unless the delta is small, in which
  # case we do a linear walk.
  @bind(\cued_idx, from(\lines).and(\player).all.flatMap((lines, player) ->
    last-idx = null
    last-epoch = -999 # apparently null is zero.
    player?.watch(\timestamp.epoch).map((epoch) ->
      return unless epoch?

      idx = if abs(epoch - last-epoch) <= 30 then last-idx else (lines.length / 2 |> floor)
      low = 0
      high = lines.length - 1
      loop
        break if idx + 1 is lines.length

        target-start = lines.list[idx]._start
        target-end = lines.list[idx]._end

        unless target-start?
          idx -= 1
          continue

        previous-idx = idx - 1
        until lines.list[previous-idx]?._end? or previous-idx <= 0
          previous-idx -= 1

        if (target-start >= epoch) and ((idx is 0) or (lines.list[previous-idx]._start < epoch))
          break
        else if low is high
          break
        else if abs(target-start - epoch) <= 30
          if target-start < epoch
            do
              idx += 1
              break if idx is high
            until lines.list[idx]._start?
          else
            do
              idx -= 1
            until lines.list[idx]._start?
        else if target-start < epoch
          low = idx + 1
          idx = ((high - low) / 2 |> floor) + low
        else if target-start > epoch
          high = idx - 1
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
  @bind(\target_idx, from(\lines).and(\cued_idx).and(\player).watch(\timestamp.epoch).all.map((lines, idx, epoch) ->
    return unless idx? # implies existence of lines.

    candidate-idx = idx - 1
    loop
      break if candidate-idx < 0

      candidate-end = lines.list[candidate-idx]._end
      if !candidate-end?
        search-id = lines.list[candidate-idx]._id
        until (lines.list[candidate-idx]._id is search-id) and lines.list[candidate-idx]._end?
          candidate-idx -= 1
      else if candidate-end >= epoch
        idx = candidate-idx
        candidate-idx = idx - 1
      else
        break

    idx -= 1 unless (idx is 0) or (lines.list[idx]._start <= epoch)
    idx
  ))
  @bind(\target_id, from(\lines).and(\target_idx).all.flatMap((lines, idx) ->
    lines?.watchAt(idx).flatMap (?._id)
  ))
  @bind(\top_line, from(\lines).and(\target_idx).all.flatMap((lines, idx) -> lines?.watchAt(idx)))

  # these two work on primitives as they're only ever used as direct lookups.
  @bind(\nearby_ids, from(\target_id).flatMap((id = 0) -> [ x for x from id - 2 til id + 2 ]))
  @bind(\nearby_terms, from(\nearby_ids).and(\lookup).all.map((ids, lookup) ->
    return [] unless ids? and lookup?
    [ l.list for id in ids when (l = lookup.get(id))? ] |> flatten
  ))

  _initialize: ->
    transcript = this

    do
      # when our target_idx changes, push active state down into lines.
      # but we can't do that until we have a player:
      (player) <- transcript.watch(\player).reactNow()
      return unless player?

      # now watch idx, but also update on epoch-change:
      was-active = {}
      active-ids = {}
      last-idx = -1
      from(transcript.watch(\target_idx)).and(player.watch(\timestamp.epoch)).all.plain().reactNow(([ idx, epoch ]) ->
        return unless idx? and epoch?
        return if idx is last-idx

        # first clear out active primary lines that are no longer.
        for wa-idx, line of was-active when line._start? and not line.contains_(epoch)
          line.set(\active, false)
          delete was-active[wa-idx]
          delete active-ids[line._id]

        # now clear out active secondary lines that are no longer.
        for wa-idx, line of was-active when not active-ids[line._id]
          line.set(\active, false)
          delete was-active[wa-idx]

        # now add lines that should be active. go until we have four inactive in a row.
        lines = transcript.get(\lines).list
        misses = 0
        while misses < 4 and idx < lines.length
          line = lines[idx]
          if line.contains_(epoch) or active-ids[line._id] is true
            unless was-active[idx]?
              line.set(\active, true)
              was-active[idx] = line
              active-ids[line._id] = true
          else
            misses += 1
          idx += 1

        last-idx := idx
      )

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

  decorate: (cross-look) ->
    return unless (terms = cross-look[this.get(\term)])?
    text = this.get(\definition)
    for term in terms
      text .= replace(new RegExp(term, \ig), -> "<span class=\"glossary-term\" data-term=\"#term\">#it</span>")
    this.set(\definition, text)

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

  @deserialize = (data, cross-look = {}) ->
    glossary = new Glossary()

    # create a lookup based on primary and synonym terms.
    lookup = {}
    list = []
    for term, def of data
      inflated = Term.deserialize(def)
      inflated.decorate(cross-look)
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
    default: -> 400
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



########################################
# EXHIBIT MODELS

class ExhibitArea extends Model
class Topic extends Model
class Exhibit extends Model
  _initialize: ->
    # grab our html fragment off of the dom.
    this.set(\content, $("\#markup \##{this.get(\lookup)}").prop(\outerHTML))

module.exports = { Global, Line, Lines, Transcript, Term, Lookup, Glossary, Player, ExhibitArea, Topic, Exhibit }

