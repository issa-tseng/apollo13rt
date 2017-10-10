$ = require(\jquery)

{ DomView, template, find, from, Varying } = require(\janus)
{ from-event } = require(\janus-stdlib).util.varying

{ Player, Chapter } = require('../model')
{ clamp, px, pct, pad, click-touch, get-touch-x, get-touch-y } = require('../util')
{ min } = Math

class PlayerView extends DomView
  @_dom = -> $('
    <div class="player">
      <audio/>
      <div class="player-chrome">
        <div class="player-controls">
          <button class="player-leapback" title="Back 15 seconds (&#8679;J)"/>
          <button class="player-hopback" title="Back 6 seconds (J)"/>
          <button class="player-playpause"/>
          <button class="player-hopforward" title="Forward 6 seconds (L)"/>
          <button class="player-leapforward" title="Forward 15 seconds (&#8679;L)"/>
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
            <div class="player-timestamp-event-wrapper">
              <div class="player-timestamp-event">
                <p class="player-timestamp-label"></p>
                <p class="player-timestamp-time"><span class="sign"/><span class="hh"/><span class="mm"/><span class="ss"/></p>
              </div>
            </div>
          </div>
          <div class="player-scrubber">
            <div class="player-scrubber-area">
              <div class="player-chapters"/>
              <div class="player-playbar"/>
              <div class="player-playhead"/>
              <div class="player-bookmark">
                <div class="player-bookmark-icon reverse-tooltip" title="Back to previous position"/>
              </div>
              <div class="player-scrubber-bubble">
                <span class="hh"/><span class="mm"/><span class="ss"/>
              </div>
            </div>
          </div>
        </div>
      </div>
      <div class="player-scripts">
        <div class="player-script-air-ground"/>
        <div class="player-script-flight"/>
        <div class="player-glossary"/>
        <div class="player-postscript">
          <img src="/assets/postscript-crew.jpg" alt="The crew poses on board the USS Iwo Jima as sailors cheer."/>
          <img src="/assets/postscript-mocr.jpg" alt="Gene Kranz and Deke Slayton celebrate in Mission Control."/>
          <div class="player-postscript-content"/>
        </div>
      </div>
      <div class="player-resize"/>
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

    find('.player-timestamp-event-wrapper').classed(\has-model, from(\event_timer.model).map (?))
    find('.player-timestamp-event-wrapper').classed(\active, from.self().and(\event_timer.model).all.flatMap((view, timer) ->
      Varying.pure(view.subject.watch(\timestamp.epoch), timer.watch(\end), (now, end) -> (end - now) > 0) if timer?
    ))
    find('.player-timestamp-event .player-timestamp-label').text(from(\event_timer.model).watch(\caption))
    find('.player-timestamp-event .sign').text(from(\event_timer.parts.sign))
    find('.player-timestamp-event .hh').text(from(\event_timer.parts.hh).map(pad))
    find('.player-timestamp-event .mm').text(from(\event_timer.parts.mm).map(pad))
    find('.player-timestamp-event .ss').text(from(\event_timer.parts.ss).map(pad))
    find('.player-timestamp-event').classed(\hot, from.self().and(\event_timer.model).watch(\hot).all.flatMap((view, hot) ->
      epoch = view.subject.watch(\timestamp.epoch)
      hot?.filter((.contains(epoch))).watchLength().map (> 0)
    ))

    find('.player-playhead').css(\right, from(\timestamp.timecode).and(\audio.length).all.map ((/) >> (-> 1 - it) >> pct))

    find('.player-scrubber-bubble').classed(\hide, from(\scrubber.mouse.over).map (not))
    find('.player-scrubber-bubble').css(\left, from(\scrubber.mouse.over).and(\scrubber.mouse.at).all.map((over, at) ->
      if over then at |> pct else 0
    ))
    find('.player-scrubber-bubble .hh').text(from(\scrubber.mouse.hh))
    find('.player-scrubber-bubble .mm').text(from(\scrubber.mouse.mm).map(pad))
    find('.player-scrubber-bubble .ss').text(from(\scrubber.mouse.ss).map(pad))

    find('.player-bookmark').classed(\hide, from(\bookmark.epoch).map(-> !it?))
    find('.player-bookmark').css(\right, from(\bookmark.timecode).and(\audio.length).all.map ((/) >> (-> 1 - it) >> pct))

    find('.player-chapters').classed(\active, from(\scrubber.mouse.over))
    find('.player-chapters').render(from(\chapters))

    find('.player-scripts').css(\height, from(\height).map (px))
    find('.player-scripts').classed(\inactive, from(\height).map (< 35))

    find('.player-script-flight').render(from(\loops.flight))
    find('.player-script-air-ground').render(from(\loops.air_ground))
    find('.player-glossary').render(from(\glossary))

    find('.player-postscript').classed(\active, from(\timestamp.timecode).and(\audio.length).all.map (>=))
  )
  _wireEvents: ->
    dom = this.artifact()
    player = this.subject
    audio = dom.find('audio')
    audio-raw = audio.get(0)

    # cache dom elements.
    scrubber = dom.find('.player-scrubber-area')
    resizer = dom.find('.player-resize')

    # feed audio element back into player.
    player.set(\audio.player, audio)

    # drop postscript content in.
    dom.find('.player-postscript-content').append($('#markup > #postscript').detach())

    # util for touch/click handling:
    x-to-pct = (x) -> ((x - left-offset) / scrubber.width()) |> clamp(0, 1)

    # feed mouse events into model.
    left-offset = scrubber.offset().left # unlikely to change; cache for perf.
    scrubber.on(\mouseenter, -> player.set(\scrubber.mouse.over, true))
    scrubber.on(\mouseleave, -> player.set(\scrubber.mouse.over, false))
    scrubber.on(\mousedown, (event) ->
      player.set(\scrubber.clicking, true)
      event.preventDefault()
    )
    resizer.on(\mousedown, (event) ->
      player.set(\resize.mouse.clicking, true)
      event.preventDefault()
    )

    # feed touch events into model.
    scrubber.on(\touchstart, (event) ->
      # we have to handle touchstart separately, as we don't know where the finger is til it touches.
      player.set( 'scrubber.mouse.over': true, 'scrubber.clicking': true )
      player.set(\scrubber.mouse.at, event |> get-touch-x |> x-to-pct)
      event.preventDefault()
    )
    resizer.on(\touchstart, (event) ->
      player.set(\resize.mouse.y, get-touch-y(event))
      player.set(\resize.mouse.clicking, true)
      event.preventDefault()
    )
    scrubber.on(\touchend, -> player.set( 'scrubber.mouse.over': false, 'scrubber.clicking': false ))

    # feed body mouse events into model.
    body = $(document)
    body.on(\mousemove, (event) ->
      player.set(\scrubber.mouse.at, x-to-pct(event.pageX))
      player.set(\resize.mouse.y, event.pageY)
    )
    body.on(\touchmove, (event) ->
      player.set(\scrubber.mouse.at, event |> get-touch-x |> x-to-pct)
      player.set(\resize.mouse.y, get-touch-y(event))
    )
    body.on('mouseup touchend', ->
      player.set(\scrubber.clicking, false)
      player.set(\resize.mouse.clicking, false)
      true # don't swallow touchends.
    )

    # point-in-time mouse reactions.
    from(player.watch(\scrubber.clicking)).and(player.watch(\scrubber.mouse.timecode)).all.plain().reactLater(([ clicking, code ]) ->
      audio-raw.currentTime = code if clicking is true
      player.setProgress() # really, these two lines should be player.epoch() but oh well.
    )

    click-touch(dom.find('.player-leapback'), -> audio-raw.currentTime -= 15)
    click-touch(dom.find('.player-hopback'), -> audio-raw.currentTime -= 6)
    click-touch(dom.find('.player-playpause'), -> if audio-raw.paused is true then audio-raw.play() else audio-raw.pause())
    click-touch(dom.find('.player-hopforward'), -> audio-raw.currentTime += 6)
    click-touch(dom.find('.player-leapforward'), -> audio-raw.currentTime += 15)
    dom.find('.player-bookmark').on('click', (event) ->
      event.stopPropagation() # so the standard mouse timecode handler does not fire.
      player.epoch(player.get(\bookmark.epoch))
      player.unset(\bookmark)
    )

    # fixed player/scroll handling.
    container = $('#timeline')
    threshold = dom.position().top
    chrome-height = dom.outerHeight() - player.get(\base_height)
    crossed-threshold = from-event(body, \scroll, (.target.scrollingElement.scrollTop > threshold))

    crossed-threshold.reactLater((is-fixed) -> container.toggleClass(\fixed-player, is-fixed is true))
    from(crossed-threshold).and(player.watch(\base_height)).all.plain().map((is-fixed, base-height) ->
      if is-fixed then chrome-height + base-height else \auto
    ).reactLater(-> container.css(\height, it))

    # keyboard audio navigation.
    body.on(\keydown, (event) ->
      increment = if event.shiftKey is true then 15 else 6
      if event.which is 74
        audio-raw.currentTime -= increment
      else if event.which is 76
        audio-raw.currentTime += increment
      else if event.which is 75
        if audio-raw.paused is true then audio-raw.play() else audio-raw.pause()
    )


class ChapterView extends DomView
  @_dom = -> $('
    <div class="chapter">
      <div class="chapter-inner">
        <p class="title" />
      </div>
      <div class="chapter-bubble">
        <p class="description" />
      </div>
    </div>
  ')
  @_template = template(
    find('.chapter').css(\left, from(\start).and(\player).watch(\timestamp.offset).and(\player).watch(\audio.length).all.map((start, offset, length) ->
      (start - offset) / length |> pct
    ))
    find('.chapter').css(\width, from(\duration).and(\player).watch(\audio.length).all.map((chapter-length, audio-length) ->
      chapter-length / audio-length |> pct
    ))

    find('.chapter').classed(\active, from(\start).and(\end).and(\player).watch(\scrubber.mouse.epoch).all.map((start, end, cursor) -> start <= cursor <= end))

    find('.title').text(from(\title))
    find('.description').text(from(\description))
  )


module.exports = {
  PlayerView, ChapterView
  registerWith: (library) ->
    library.register(Player, PlayerView)
    library.register(Chapter, ChapterView)
}

