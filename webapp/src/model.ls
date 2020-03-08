$ = require(\jquery)
{ floor, abs, max, min } = Math

{ Model, attribute, initial, bind, from, List, Set, Varying, types, Request } = require(\janus)
{ throttle } = require(\janus-stdlib).varying

{ defer, clamp, pad, get-time, epoch-to-hms, hash-to-hms, hms-to-epoch, epoch-to-hms } = require('./util')



########################################
# MISC MODELS

class Global extends Model
  shadow: -> this

class Splash extends Model.build(
  bind(\progress.adjusted, from(\progress.epoch).and(\progress.mtime).all.map((epoch, mtime) ->
    return if Number.isNaN(epoch) or Number.isNaN(mtime)
    diff = get-time() - mtime
    if diff > 60 * 60 * 1000 # over an hour
      epoch - 15
    else if diff > 60 * 1000 # over a minute
      epoch - 8
    else
      epoch
  ))
  bind(\progress.parts, from(\progress.adjusted).map(epoch-to-hms))

  bind(\hash.parts, from(\hash.raw).map(hash-to-hms))
  bind(\hash.epoch, from(\hash.parts.hh).and(\hash.parts.mm).and(\hash.parts.ss).all.map(hms-to-epoch))
)

  @initialize = ->
    # load attributes from various known locations.
    new Splash({
      progress: { epoch: localStorage.getItem(\progress_epoch) |> parse-int, mtime: localStorage.getItem(\progress_mtime) |> parse-int }
      hash: { raw: window.location.hash }
    })



########################################
# TRANSCRIPT MODELS

class Line extends Model.build(
  attribute(\tokens, attribute.List)
  attribute(\annotations, attribute.List)

  bind(\start.hh, from(\start.epoch).map ((/ 3600) >> floor))
  bind(\start.mm, from(\start.epoch).map ((% 3600 / 60) >> floor))
  bind(\start.ss, from(\start.epoch).map (% 60))
)

  @deserialize = (data) ->
    super(Object.assign({}, data, { start: { epoch: data.start }, end: { epoch: data.end } }))

  _initialize: ->
    # massage the description for annotations.
    this.set(\message, this.get_(\message).replace(/\{([^}]+)\}/g, (_, text) -> "<span class=\"token-annotation\">#text</span>"))

    # perf:
    this._start = this.get_(\start.epoch)
    this._end = this.get_(\end.epoch)
    this._id = this.get_(\id)

  contains_: (epoch) ->
    (start-epoch = this.get_(\start.epoch))? and (start-epoch <= epoch) and (this.get_(\end.epoch) >= epoch)
  startHms_: -> "#{this.get_(\start.hh)}:#{this.get_(\start.mm) |> pad}:#{this.get_(\start.ss) |> pad}"

class Lines extends List.of(Line)

class Transcript extends Model.build(
  attribute(\lines, class extends attribute.List.of(Lines).withInitial())
  initial(\auto_scroll, true, attribute.Boolean)

  # the index of the immediate-next line to be played regardless of active status.
  # determined by binary search for performance, unless the delta is small, in which
  # case we do a linear walk.
  bind(\cued_idx, from(\lines).and(\player).all.flatMap((lines, player) ->
    last-idx = null
    last-epoch = -999 # apparently null is zero.
    player?.get(\timestamp.epoch).map((epoch) ->
      return unless epoch?

      idx = if abs(epoch - last-epoch) <= 30 then last-idx else (lines.length_ / 2 |> floor)
      low = 0
      high = lines.length_ - 1
      loop
        break if idx + 1 is lines.length_

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
  bind(\cued_epoch, from(\lines).and(\cued_idx).all.flatMap((lines, idx) -> lines?.get(idx)).map((line) -> line?._start))

  # now that we have the cued idx, we potentially migrate backwards until we have
  # one of the earliest still-playing line or the last line that was played, in that
  # order of preference.
  bind(\target_idx, from(\lines).and(\cued_idx).and(\player).get(\timestamp.epoch).all.map((lines, idx, epoch) ->
    return unless idx? # implies existence of lines.

    candidate-idx = idx - 1
    loop
      break if candidate-idx < 0

      candidate-end = lines.list[candidate-idx]._end
      if !candidate-end? # if we have a partial, migrate upward until we have the root.
        search-id = lines.list[candidate-idx]._id
        until (lines.list[candidate-idx]._id is search-id) and lines.list[candidate-idx]._end?
          candidate-idx -= 1
      else if candidate-end >= epoch # this line is still playing.
        idx = candidate-idx
        candidate-idx = idx - 1
      else
        # we think we have it, but we need to walk back a couple more just to see if an
        # even earlier line is still playing.
        for walkback from 5 to 1
          walkback-line = lines.list[candidate-idx - walkback]
          if walkback-line?._end? and walkback-line._end >= epoch
            idx = candidate-idx - walkback
            candidate-idx = idx - 1
            break

        break

    idx -= 1 unless (idx is 0) or (lines.list[idx]._start <= epoch)
    idx
  ))
  bind(\target_id, from(\lines).and(\target_idx).all.flatMap((lines, idx) ->
    lines?.at(idx).flatMap (?._id)
  ))
  bind(\top_line, from(\lines).and(\target_idx).all.flatMap((lines, idx) -> lines?.at(idx)))
  bind(\is_active, from(\top_line).and(\player).get(\timestamp.epoch).all.map((line, epoch) -> line?.contains_(epoch)))

  # these two work on primitives as they're only ever used as direct lookups.
  bind(\nearby_ids, from(\target_id).flatMap((id = 0) -> [ x for x from id - 2 til id + 2 ]))
  bind(\nearby_terms, from(\nearby_ids).and(\lookup).all.map((ids, lookup) ->
    return [] unless ids? and lookup?
    [ term for id in ids when (l = lookup.get_(id))? for term in l.list ]
  ))
)

  bindToPlayer: (player) -> this.set(\player, player)



########################################
# GLOSSARY MODELS

class Term extends Model.build(
  attribute(\synonyms, class extends attribute.List.withInitial())
  attribute(\hidden, attribute.Boolean)

  bind(\matches, from(\term).and(\synonyms).all.map((term, synonyms) ->
    (x) -> (x is term) or (x in synonyms.list)
  ))
)

  decorate: (cross-look) ->
    return unless (terms = cross-look[this.get_(\term)])?
    text = this.get_(\definition)
    for term in terms
      text .= replace(new RegExp(term, \ig), -> "<span class=\"glossary-term\" data-term=\"#term\">#it</span>")
    this.set(\definition, text)

class Lookup extends Model
  @deserialize = (data) -> super({ [ id, new List(terms) ] for id, terms of data })

class Glossary extends Model.build(
  initial(\show.personnel, true, attribute.Boolean)
  initial(\show.technical, true, attribute.Boolean)
  initial(\show.hidden, false, attribute.Boolean)
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

      if (synonyms = lookup[term].get_(\synonyms))?
        for synonym in synonyms.list
          lookup[synonym] = lookup[term]

    glossary.set({ lookup, list: new List(list) })
    glossary



########################################
# PLAYER MODEL

class Player extends Model.build(
  initial(\base_height, 400, attribute.Number)

  bind(\timestamp.epoch, from(\timestamp.timecode).and(\timestamp.offset).all.map (+))
  bind(\timestamp.hh, from(\timestamp.epoch).map ((/ 3600) >> floor))
  bind(\timestamp.mm, from(\timestamp.epoch).map ((% 3600 / 60) >> floor))
  bind(\timestamp.ss, from(\timestamp.epoch).map (% 60))

  bind(\accident.delta, from(\timestamp.epoch).and(\accident.epoch).all.map ((-) >> abs))
  bind(\accident.occurred, from(\timestamp.epoch).and(\accident.epoch).all.map (>=))
  bind(\accident.delta_hh, from(\accident.delta).map ((/ 3600) >> floor))
  bind(\accident.delta_mm, from(\accident.delta).map ((% 3600 / 60) >> floor))
  bind(\accident.delta_ss, from(\accident.delta).map (% 60))

  bind(\scrubber.mouse.timecode, from(\scrubber.mouse.at).and(\audio.length).all.map ((*) >> floor))
  bind(\scrubber.mouse.epoch, from(\scrubber.mouse.timecode).and(\timestamp.offset).all.map (+))
  bind(\scrubber.mouse.hh, from(\scrubber.mouse.epoch).map ((/ 3600) >> floor))
  bind(\scrubber.mouse.mm, from(\scrubber.mouse.epoch).map ((% 3600 / 60) >> floor))
  bind(\scrubber.mouse.ss, from(\scrubber.mouse.epoch).map (% 60))

  bind(\bookmark.timecode, from(\bookmark.epoch).and(\timestamp.offset).all.map (-))

  bind(\resize.mouse.delta, from(\resize.mouse.y).and(\resize.mouse.start).all.map (-))
  bind(\height, from(\base_height).and(\resize.mouse.clicking).and(\resize.mouse.delta).all.map((base-height, clicking, delta) ->
    if clicking is true then base-height + delta else base-height
  ))

  bind(\nearby_terms, from(\loops.flight).get(\nearby_terms).and(\loops.air_ground).get(\nearby_terms).all.map (++))

  bind(\post_gap_script, from(\timestamp.epoch).and(\loops.flight).and(\loops.air_ground).all.map((now, flight, air-ground) ->
    # compute these point-in-time as they can't change unless timestamp changes anyway.
    threshold = now + 20
    air-ground-cue = air-ground.get_(\cued_epoch)
    air-ground-gap = !air-ground.get_(\is_active) and (threshold < air-ground-cue)
    flight-cue = flight.get_(\cued_epoch)
    flight-gap = !flight.get_(\is_active) and (threshold < flight-cue)
    if air-ground-gap is true and flight-gap is true
      if air-ground-cue < flight-cue then air-ground else flight
    else
      false
  ))

  bind(\event_timer.model, from(\timers).and.self().all.flatMap((timers, player) ->
    epoch = player.get(\timestamp.epoch)
    timers.filter((.contains(epoch))).at(-1)
  ))
  bind(\event_timer.delta, from(\timestamp.epoch).and(\event_timer.model).get(\zero).all.map (-))
  bind(\event_timer.parts, from(\event_timer.delta).map(epoch-to-hms))
)

  _initialize: ->
    player = this

    # bind audio player properties back into the model.
    player.get(\audio.player).react(false, (dom) ->
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
    for _, transcript of player.get_(\loops)
      transcript.bindToPlayer(player)
    # attach chapters to this player.
    for chapter in player.get_(\chapters).list
      chapter.bindToPlayer(player)

    # set mouse start and player height on mouse down and mouse up.
    player.get(\resize.mouse.clicking).react(false, (clicking) ->
      if clicking is true
        player.set(\resize.mouse.start, player.get_(\resize.mouse.y))
      else
        player.set(\base_height, max(0, player.get_(\height)))
    )

    # update our saved position every few seconds.
    throttle(5_000, player.get(\timestamp.epoch)).react(false, this~setProgress)

  # starts playing the audio.
  play: !-> this.get_(\audio.player).get(0).play()

  # navigates the player to a given epoch.
  # will schedule the seek for after the audio is loaded if it isn't ready (#53).
  epoch: (epoch) !->
    audio = this.get_(\audio.player).get(0)
    if isNaN(audio.duration)
      # can't seek yet.
      scheduled = this.get_(\delayed-seek)?
      this.set(\delayed-seek, epoch)
      return if scheduled
      <~ audio.addEventListener(\canplay)
      this._seek(this.get_(\delayed-seek))
      this.unset(\delayed-seek)
    else
      this._seek(epoch)

  # helper used by #epoch() to actually do the seek.
  _seek: (epoch) !->
    this.get_(\audio.player).get(0).currentTime = (epoch - this.get_(\timestamp.offset))
    this.setProgress()

  # sets the player bookmark to the current epoch. (unless less than 15 seconds
  # have played from the very beginning)
  bookmark: !->
    return if this.get_(\timestamp.timecode) < 15
    this.set(\bookmark.epoch, this.get_(\timestamp.epoch))

  # saves the current position to localstorage for resumption.
  setProgress: !->
    epoch = this.get_(\timestamp.epoch)
    return if !epoch? or epoch < (this.get_(\timestamp.offset) + 15)
    localStorage.setItem(\progress_mtime, get-time())
    localStorage.setItem(\progress_epoch, epoch)


########################################
# PLAYER MISC MODELS

class Timer extends Model
  contains: (epoch) ->
    Varying.mapAll(epoch, this.get(\start), this.get(\end), (epoch, start, end) ->
      start <= epoch <= end
    )

class Chapter extends Model.build(
  bind(\duration, from(\end).and(\start).all.map (-))
)
  bindToPlayer: (player) -> this.set(\player, player)


########################################
# EXHIBIT MODELS

class ExhibitArea extends Model.build(
  bind(\all_topics, from(\topics).map((topics) -> topics.flatMap((.get(\exhibits))).flatten()))
)

class Topic extends Model
class Exhibit extends Model
  _initialize: ->
    # grab our html fragment off of the dom.
    if (raw = $("\#markup \##{this.get_(\lookup)}").prop(\outerHTML))?
      processed = raw.replace(/(?:<p>)?{{figure:([^}]+)}}(?:<\/p>)?/gi, '<div class="figure" data-figure="$1"></div>')
      this.set(\content, processed)

class Graphic extends Model.build(
  initial(\width, 300)
)



########################################
# BASIC REQUESTS

class BasicRequest extends Request
  (url) -> super({ url })
basicResolver = (req) ->
  result = new Varying()
  $.getJSON(req.options.url, (data) -> result.set(types.result.success(data)))
  result



module.exports = {
  Global, Splash,
  Line, Lines, Transcript,
  Term, Lookup, Glossary,
  Player, Timer, Chapter,
  ExhibitArea, Topic, Exhibit, Graphic,
  BasicRequest, basicResolver,

  registerWith: (library) -> library.register(BasicRequest, basicResolver)
}

