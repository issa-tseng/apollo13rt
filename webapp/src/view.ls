{ DomView, template, find, from, Varying } = require(\janus)
$ = require(\jquery)

{ Line, Transcript, Player } = require('./model')

clamp = (min, max, x) --> if x < min then min else if x > max then max else x
pct = (x) -> "#{x * 100}%"
pad = (x) -> if x < 10 then "0#x" else x

class TranscriptView extends DomView
  @_dom = -> $('<div class="transcript"><div class="lines"/></div>')
  @_template = template(
    find('.lines').render(from(\lines))
  )

class LineView extends DomView
  @_dom = -> $('
    <div class="line">
      <div class="line-timestamp">
        <span class="hh"/>
        <span class="mm"/>
        <span class="ss"/>
      </div>
      <div class="line-source"/>
      <div class="line-contents"/>
    </div>
  ')
  @_template = template(
    find('.line-timestamp').classed(\hide, from(\start.epoch).map((x) -> !x?))
    find('.hh').text(from(\start.hh))
    find('.mm').text(from(\start.mm).map(pad))
    find('.ss').text(from(\start.ss).map(pad))

    find('.line-source').text(from(\source))
    find('.line-contents').text(from(\message))
  )

class PlayerView extends DomView
  @_dom = -> $('
    <div class="player">
      <div class="player-chrome">
        <div class="player-controls">
          <button class="player-leapback"/>
          <button class="player-hopback"/>
          <button class="player-playpause"/>
          <button class="player-hopforward"/>
          <button class="player-leapforward"/>
        </div>
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
      <div class="player-script"/>
      <audio/>
    </div>
  ')
  @_template = template(
    find('audio').attr(\src, from(\audio.src))

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

    find('.player-script').render(from(\loops.flight).watch(\lines))
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
    library.register(Line, LineView)
    library.register(Player, PlayerView)
}

