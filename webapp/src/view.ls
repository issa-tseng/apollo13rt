{ DomView, template, find, from, Model, Varying } = require(\janus)
{ debounce } = require(\janus-stdlib).util.varying
$ = require(\jquery)

{ LineVM, Transcript, Player } = require('./model')

clamp = (min, max, x) --> if x < min then min else if x > max then max else x
pct = (x) -> "#{x * 100}%"
pad = (x) -> if x < 10 then "0#x" else x

class LineView extends DomView
  @_fragment = $('
    <div class="line">
      <a class="line-timestamp">
        <span class="hh"/>
        <span class="mm"/>
        <span class="ss"/>
      </a>
      <div class="line-heading">
        <span class="line-source"/>
        <a class="line-edit" target="_blank" title="Suggest an edit"/>
        <a class="line-link" title="Share link to this line"/>
      </div>
      <div class="line-contents"/>
    </div>
  ')
  @_dom = -> @_fragment.clone()
  @_template = template(
    find('.line').classGroup(\line-, from(\line).watch(\id))
    find('.line').classed(\active,
      from(\active)
        .and(\line).watch(\id)
        .and(\transcript).watch(\active_ids)
        .all.flatMap((active, id, active-ids) ->
          active or active-ids?.filter(-> it is id).watchLength().map (> 0)
        )
    )

    find('.line-timestamp').classed(\hide, from(\line).watch(\start.epoch).map((x) -> !x?))
    find('.hh').text(from(\line).watch(\start.hh))
    find('.mm').text(from(\line).watch(\start.mm).map(pad))
    find('.ss').text(from(\line).watch(\start.ss).map(pad))

    find('.line-edit').attr(\href, from(\transcript).watch(\edit_url).and(\line).watch(\line).all.map((base, line) -> "#base\#L#line"))

    find('.line-source').text(from(\line).watch(\source))
    find('.line-contents').text(from(\line).watch(\message))
  )

class TranscriptView extends DomView
  @_dom = -> $('
    <div class="script">
      <div class="script-lines"/>
      <p/>
    </div>
  ')
  @_template = template(
      find('p').text(from(\name))
      find('.script-lines').render(from(\line_vms))
  )
  _wireEvents: ->
    dom = this.artifact()
    transcript = this.subject
    line-container = dom.find('.script-lines')

    auto-scrolling = false
    debounce(transcript.watch(\top_line), 5).react((line) ->
      if (transcript.get(\auto_scroll) is true) and (id = line?.get(\line).get(\id))?
        offset-top = dom.find(".line-#id").get(0).offsetTop - dom.get(0).offsetTop - 50
        auto-scrolling = true
        line-container.finish().animate({ scroll-top: offset-top, complete: (-> auto-scrolling = false) })
    )

class PlayerView extends DomView
  @_dom = -> $('
    <div class="player">
      <div class="player-chrome">
        <div class="player-controls">
          <button class="player-leapback" title="Back 15 seconds"/>
          <button class="player-hopback" title="Back 6 seconds"/>
          <button class="player-playpause"/>
          <button class="player-hopforward" title="Forward 6 seconds"/>
          <button class="player-leapforward" title="Forward 15 seconds"/>
        </div>
        <div class="player-right">
          <div class="player-timestamp">
            <div class="player-timestamp-met">
              <p class="player-timestamp-time"><span class="hh"/><span class="mm"/><span class="ss"/></p>
              <p class="player-timestamp-label">Mission elapsed time</p>
            </div>
            <div class="player-timestamp-accident">
              <p class="player-timestamp-label">Time <span class="accident-direction"/> accident</p>
              <p class="player-timestamp-time"><span class="hh"/><span class="mm"/><span class="ss"/></p>
            </div>
          </div>
          <div class="player-scrubber">
            <div class="player-scrubber-area">
              <div class="player-playbar"/>
              <div class="player-playhead"/>
              <div class="player-scrubber-bubble">
                <span class="hh"/><span class="mm"/><span class="ss"/>
              </div>
            </div>
            <div class="player-chapters"/>
          </div>
        </div>
      </div>
      <div class="player-scripts">
        <div class="player-script-flight"/>
        <div class="player-script-air-ground"/>
      </div>
      <audio/>
    </div>
  ')
  @_template = template(
    find('audio').attr(\src, from(\audio.src))

    find('.player').classed(\playing, from(\audio.playing))

    find('.player-timestamp-met .hh').text(from(\timestamp.hh))
    find('.player-timestamp-met .mm').text(from(\timestamp.mm).map(pad))
    find('.player-timestamp-met .ss').text(from(\timestamp.ss).map(pad))
    find('.player-timestamp-accident .accident-direction').text(
      from(\accident.occurred).map((occurred) -> if occurred then \since else \until))
    find('.player-timestamp-accident .hh').text(from(\accident.delta_hh).map(pad))
    find('.player-timestamp-accident .mm').text(from(\accident.delta_mm).map(pad))
    find('.player-timestamp-accident .ss').text(from(\accident.delta_ss).map(pad))

    find('.player-playhead').css(\right, from(\timestamp.timecode).and(\audio.length).all.map ((/) >> (-> 1 - it) >> pct))

    find('.player-scrubber-bubble').classed(\hide, from(\scrubber.mouse.over).map (not))
    find('.player-scrubber-bubble').css(\left, from(\scrubber.mouse.over).and(\scrubber.mouse.at).all.map((over, at) ->
      if over then at |> pct else 0
    ))
    find('.player-scrubber-bubble .hh').text(from(\scrubber.mouse.hh))
    find('.player-scrubber-bubble .mm').text(from(\scrubber.mouse.mm).map(pad))
    find('.player-scrubber-bubble .ss').text(from(\scrubber.mouse.ss).map(pad))

    find('.player-script-flight').render(from(\loops.flight))
    find('.player-script-air-ground').render(from(\loops.air_ground))
  )
  _wireEvents: ->
    dom = this.artifact()
    player = this.subject
    audio = dom.find('audio')
    audio-raw = audio.get(0)

    # feed audio element back into player.
    player.set(\audio.player, audio)

    # feed mouse events into model.
    scrubber = dom.find('.player-scrubber-area')
    scrubber.on(\mouseenter, -> player.set(\scrubber.mouse.over, true))
    scrubber.on(\mouseleave, -> player.set(\scrubber.mouse.over, false))
    scrubber.on(\mousedown, (event) ->
      player.set(\scrubber.clicking, true)
      event.preventDefault()
    )

    body = $(document)
    left-offset = scrubber.offset().left # unlikely to change; cache for perf.
    body.on(\mousemove, (event) -> player.set(\scrubber.mouse.at,
      ((event.pageX - left-offset) / scrubber.width()) |> clamp(0, 1)))
    body.on(\mouseup, -> player.set(\scrubber.clicking, false))

    # point-in-time mouse reactions.
    from(player.watch(\scrubber.clicking)).and(player.watch(\scrubber.mouse.timecode)).all.plain().react(([ clicking, code ]) ->
      audio-raw.currentTime = code if clicking is true
    )
    dom.find('.player-leapback').on(\click, -> audio-raw.currentTime -= 15)
    dom.find('.player-hopback').on(\click, -> audio-raw.currentTime -= 6)
    dom.find('.player-playpause').on(\click, -> if audio-raw.paused is true then audio-raw.play() else audio-raw.pause())
    dom.find('.player-hopforward').on(\click, -> audio-raw.currentTime += 6)
    dom.find('.player-leapforward').on(\click, -> audio-raw.currentTime += 15)


module.exports = {
  TranscriptView
  LineView
  registerWith: (library) ->
    library.register(Transcript, TranscriptView)
    library.register(LineVM, LineView)
    library.register(Player, PlayerView)
}

