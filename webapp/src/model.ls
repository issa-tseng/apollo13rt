$ = require(\jquery)
{ floor, abs, max, min } = Math

{ Model, attribute, from, List, Set, Varying, types } = require(\janus)
{ Request, Store } = require(\janus).store
{ throttle } = require(\janus-stdlib).util.varying

{ defer, clamp, pad, get-time, epoch-to-hms, hash-to-hms, hms-to-epoch, epoch-to-hms } = require('./util')



########################################
# MISC MODELS

class Global extends Model
  shadow: -> this

class Splash extends Model
  @bind(\progress.adjusted, from(\progress.epoch).and(\progress.mtime).all.map((epoch, mtime) ->
    return if Number.isNaN(epoch) or Number.isNaN(mtime)
    diff = get-time() - mtime
    if diff > 60 * 60 * 1000 # over an hour
      epoch - 15
    else if diff > 60 * 1000 # over a minute
      epoch - 8
    else
      epoch
  ))
  @bind(\progress.parts, from(\progress.adjusted).map(epoch-to-hms))

  @bind(\hash.parts, from(\hash.raw).map(hash-to-hms))
  @bind(\hash.epoch, from(\hash.parts.hh).and(\hash.parts.mm).and(\hash.parts.ss).all.map(hms-to-epoch))

  @initialize = ->
    # load attributes from various known locations.
    new Splash({
      progress: { epoch: localStorage.getItem(\progress_epoch) |> parse-int, mtime: localStorage.getItem(\progress_mtime) |> parse-int }
      hash: { raw: window.location.hash }
    })



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
  startHms_: -> "#{this.get(\start.hh)}:#{this.get(\start.mm) |> pad}:#{this.get(\start.ss) |> pad}"

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
  @bind(\cued_epoch, from(\lines).and(\cued_idx).all.flatMap((lines, idx) -> lines?.watch(idx)).map((line) -> line?._start))

  # now that we have the cued idx, we potentially migrate backwards until we have
  # one of the earliest still-playing line or the last line that was played, in that
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
  @bind(\is_active, from(\top_line).and(\player).watch(\timestamp.epoch).all.map((line, epoch) -> line?.contains_(epoch)))

  # these two work on primitives as they're only ever used as direct lookups.
  @bind(\nearby_ids, from(\target_id).flatMap((id = 0) -> [ x for x from id - 2 til id + 2 ]))
  @bind(\nearby_terms, from(\nearby_ids).and(\lookup).all.map((ids, lookup) ->
    return [] unless ids? and lookup?
    [ term for id in ids when (l = lookup.get(id))? for term in l.list ]
  ))

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

  @bind(\bookmark.timecode, from(\bookmark.epoch).and(\timestamp.offset).all.map (-))

  @bind(\resize.mouse.delta, from(\resize.mouse.y).and(\resize.mouse.start).all.map (-))
  @bind(\height, from(\base_height).and(\resize.mouse.clicking).and(\resize.mouse.delta).all.map((base-height, clicking, delta) ->
    if clicking is true then base-height + delta else base-height
  ))

  @bind(\nearby_terms, from(\loops.flight).watch(\nearby_terms).and(\loops.air_ground).watch(\nearby_terms).all.map (++))

  @bind(\post_gap_script, from(\timestamp.epoch).and(\loops.flight).and(\loops.air_ground).all.map((now, flight, air-ground) ->
    # compute these point-in-time as they can't change unless timestamp changes anyway.
    threshold = now + 20
    air-ground-cue = air-ground.get(\cued_epoch)
    air-ground-gap = !air-ground.get(\is_active) and (threshold < air-ground-cue)
    flight-cue = flight.get(\cued_epoch)
    flight-gap = !flight.get(\is_active) and (threshold < flight-cue)
    if air-ground-gap is true and flight-gap is true
      if air-ground-cue < flight-cue then air-ground else flight
    else
      false
  ))

  @bind(\event_timer.model, from(\timers).and.self().all.flatMap((timers, player) ->
    epoch = player.watch(\timestamp.epoch)
    timers.filter((.contains(epoch))).watchAt(-1)
  ))
  @bind(\event_timer.delta, from(\timestamp.epoch).and(\event_timer.model).watch(\zero).all.map (-))
  @bind(\event_timer.parts, from(\event_timer.delta).map(epoch-to-hms))

  _initialize: ->
    player = this

    # bind audio player properties back into the model.
    player.watch(\audio.player).reactLater((dom) ->
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
    # attach chapters to this player.
    for chapter in player.get(\chapters).list
      chapter.bindToPlayer(player)

    # set mouse start and player height on mouse down and mouse up.
    player.watch(\resize.mouse.clicking).reactLater((clicking) ->
      if clicking is true
        player.set(\resize.mouse.start, player.get(\resize.mouse.y))
      else
        player.set(\base_height, max(0, player.get(\height)))
    )

    # update our saved position every few seconds.
    throttle(5_000, player.watch(\timestamp.epoch)).reactLater(this~setProgress)

  # starts playing the audio.
  play: -> this.get(\audio.player).get(0).play()

  # navigates the player to a given epoch.
  epoch: (epoch) !->
    this.get(\audio.player).get(0).currentTime = (epoch - this.get(\timestamp.offset))
    this.setProgress()

  # sets the player bookmark to the current epoch. (unless less than 15 seconds
  # have played from the very beginning)
  bookmark: !->
    return if this.get(\timestamp.timecode) < 15
    this.set(\bookmark.epoch, this.get(\timestamp.epoch))

  # saves the current position to localstorage for resumption.
  setProgress: !->
    epoch = this.get(\timestamp.epoch)
    return if !epoch? or epoch < (this.get(\timestamp.offset) + 15)
    localStorage.setItem(\progress_mtime, get-time())
    localStorage.setItem(\progress_epoch, epoch)


########################################
# PLAYER MISC MODELS

class Timer extends Model
  contains: (epoch) ->
    Varying.pure(epoch, this.watch(\start), this.watch(\end), (epoch, start, end) ->
      start <= epoch <= end
    )

class Chapter extends Model
  @bind(\duration, from(\end).and(\start).all.map (-))
  bindToPlayer: (player) -> this.set(\player, player)


########################################
# EXHIBIT MODELS

class ExhibitArea extends Model
  @bind(\all_topics, from(\topics).map((topics) -> topics.flatMap(-> it.watch(\exhibits)).flatten()))

class Topic extends Model
class Exhibit extends Model
  _initialize: ->
    # grab our html fragment off of the dom.
    if (raw = $("\#markup \##{this.get(\lookup)}").prop(\outerHTML))?
      processed = raw.replace(/(?:<p>)?{{figure:([^}]+)}}(?:<\/p>)?/gi, '<div class="figure" data-figure="$1"></div>')
      this.set(\content, processed)

class Graphic extends Model
  @default(\width, 300)



########################################
# BASIC REQUESTS

class BasicRequest extends Request
  (url) -> super({ url })
class BasicStore extends Store
  _handle: ->
    $.getJSON(this.request.options.url, (data) ~> this.request.set(types.result.success(data)))
    types.handling.handled()



module.exports = {
  Global, Splash,
  Line, Lines, Transcript,
  Term, Lookup, Glossary,
  Player, Timer, Chapter,
  ExhibitArea, Topic, Exhibit, Graphic,
  BasicRequest, BasicStore,

  registerWith: (library) -> library.register(BasicRequest, BasicStore)
}

