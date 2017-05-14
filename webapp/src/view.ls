{ DomView, template, find, from, Model, Varying } = require(\janus)
{ debounce, sticky } = require(\janus-stdlib).util.varying
$ = require(\jquery)
marked = require(\marked)

{ LineVM, Transcript, Term, Glossary, Player } = require('./model')

defer = (f) -> set-timeout(f, 0)
clamp = (min, max, x) --> if x < min then min else if x > max then max else x
px = (x) -> "#{x}px"
pct = (x) -> "#{x * 100}%"
pad = (x) -> if x < 10 then "0#x" else x
get-time = -> (new Date()).getTime()
max-int = Number.MAX_SAFE_INTEGER



########################################
# TRANSCRIPT VIEWS

class LineView extends DomView
  @_fragment = $('
    <div class="line">
      <a class="line-timestamp" href="#">
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
      <div class="script-scroll-indicator-container">
        <a class="script-scroll-indicator" href="#" title="Sync with audio"/>
      </div>
      <div class="script-lines"/>
      <p/>
    </div>
  ')
  @_template = template(
      find('p').text(from(\name))
      find('.script-lines').render(from(\line_vms))
      find('.script-scroll-indicator').classed(\active, from(\auto_scroll).map (not))
  )
  _wireEvents: ->
    dom = this.artifact()
    transcript = this.subject
    line-container = dom.find('.script-lines')
    indicator = dom.find('.script-scroll-indicator')

    # automatically scrolls to a given line.
    relinquished = max-int
    get-offset = (id) -> dom.find(".line-#id").get(0).offsetTop
    scroll-to = (scroll-top) ->
      relinquished := max-int
      line-container.finish().animate({ scroll-top }, { complete: (-> relinquished := get-time()) })

    debounce(transcript.watch(\top_line), 50).react((line) ->
      id = line?.get(\line).get(\id)
      return unless id?
      offset = get-offset(id)

      # scroll to the top line if relevant.
      scroll-to(offset - 50) if transcript.get(\auto_scroll) is true

      # position the scroll indicator always.
      indicator.css(\top, offset / line-container.get(0).scrollHeight |> pct)
    )

    # watch for autoscroll rising edge and trip scroll.
    transcript.watch(\auto_scroll).react((auto) ->
      id |> get-offset |> (- 50) |> scroll-to if auto and (id = transcript.get(\top_line)?.get(\line).get(\id))?
    )

    # turn off auto-scrolling as intelligently as we can.
    line-container.on(\scroll, ->
      transcript.set(\auto_scroll, false) if get-time() > (relinquished + 250) # complete fires early
    )
    line-container.on(\wheel, ->
      line-container.finish()
      transcript.set(\auto_scroll, false)
      null # return value is significant.
    )

    # do this via delegate here once rather for each line for perf.
    dom.on(\click, '.line-timestamp', (event) ->
      event.preventDefault()
      line-vm = $(event.target).closest('.line').data(\view).subject
      transcript.get(\player).epoch(line-vm.get(\line).get(\start.epoch))
    )

    indicator.on(\click, -> transcript.set(\auto_scroll, true))



########################################
# GLOSSARY VIEWS

base-term-edit-url = "https://github.com/clint-tseng/apollo13rt/edit/master/script/glossary.txt"
class TermView extends DomView
  @_dom = -> $('
    <div class="term">
      <div class="term-name">
        <span class="name"/>
        <span class="synonyms"/>
        <a class="term-edit" target="_blank" title="Suggest an edit"/>
        <a class="term-hide"/>
      </div>
      <p class="term-definition"/>
    </div>
  ')
  @_template = template(
    find('.term').classGroup(\category-, from(\category))

    find('.term').classed(\active,
      from(\hidden)
        .and(\glossary).watch(\show.hidden)
        .and(\matches)
        .and.app(\global).watch(\player).watch(\nearby_terms)
        .all.flatMap((hidden, show-hidden, f, terms) ->
          if hidden and show-hidden
            true
          else if hidden
            false
          else
            terms.any(f)
        )
    )

    find('.term-name .name').text(from(\term))
    find('.term-name .synonyms').render(
      from(\synonyms)
        .and.app(\global).watch(\player).watch(\nearby_terms)
        .all.map((synonyms, nearby) -> synonyms.filter((term) -> nearby.any (is term)))
    )

    find('.term-edit').attr(\href, from(\line).map(-> "#base-term-edit-url\#L#it"))
    find('.term-hide').classed(\active, from(\hidden))
    find('.term-hide').attr(\title, from(\hidden).map(-> if it then "Show this term" else "Don't show me again"))
    find('.term-definition').html(from(\definition).map (marked))
  )
  _wireEvents: ->
    dom = this.artifact()
    term = this.subject

    dom.find('.term-hide').on(\click, -> term.set(\hidden, !term.get(\hidden)))
    dom.on(\mousedown, 'p a', (event) -> $(event.target).attr(\target, \_blank))

class GlossaryView extends DomView
  @_dom = -> $('
    <div class="glossary">
      <div class="glossary-items"/>
      <p>Glossary</p>
      <div class="glossary-controls">
        <label class="glossary-show-personnel" title="Show personnel titles">
          <span class="checkbox"/> Personnel
        </label>
        <label class="glossary-show-technical" title="Show technical jargon">
          <span class="checkbox"/> Technical
        </label>
        <label class="glossary-show-hidden" title="Show terms you\'ve hidden">
          <span class="checkbox"/> Hidden
        </label>
      </div>
    </div>
  ')
  @_template = template(
    find('.glossary').classed(\hide-personnel, from(\show.personnel).map (not))
    find('.glossary').classed(\hide-technical, from(\show.technical).map (not))

    find('.glossary-items').render(from(\list))

    find('.glossary-show-personnel').classed(\checked, from(\show.personnel))
    find('.glossary-show-personnel span').render(from.attribute(\show.personnel)).context(\edit)

    find('.glossary-show-technical').classed(\checked, from(\show.technical))
    find('.glossary-show-technical span').render(from.attribute(\show.technical)).context(\edit)

    find('.glossary-show-hidden').classed(\checked, from(\show.hidden))
    find('.glossary-show-hidden span').render(from.attribute(\show.hidden)).context(\edit)
  )



########################################
# PLAYER VIEW

class PlayerView extends DomView
  @_dom = -> $('
    <div class="player">
      <audio/>
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
        <div class="player-script-air-ground"/>
        <div class="player-script-flight"/>
        <div class="player-glossary"/>
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

    find('.player-playhead').css(\right, from(\timestamp.timecode).and(\audio.length).all.map ((/) >> (-> 1 - it) >> pct))

    find('.player-scrubber-bubble').classed(\hide, from(\scrubber.mouse.over).map (not))
    find('.player-scrubber-bubble').css(\left, from(\scrubber.mouse.over).and(\scrubber.mouse.at).all.map((over, at) ->
      if over then at |> pct else 0
    ))
    find('.player-scrubber-bubble .hh').text(from(\scrubber.mouse.hh))
    find('.player-scrubber-bubble .mm').text(from(\scrubber.mouse.mm).map(pad))
    find('.player-scrubber-bubble .ss').text(from(\scrubber.mouse.ss).map(pad))

    find('.player-scripts').css(\height, from(\height).map (px))

    find('.player-script-flight').render(from(\loops.flight))
    find('.player-script-air-ground').render(from(\loops.air_ground))
    find('.player-glossary').render(from(\glossary))
  )
  _wireEvents: ->
    dom = this.artifact()
    player = this.subject
    audio = dom.find('audio')
    audio-raw = audio.get(0)

    # feed audio element back into player.
    player.set(\audio.player, audio)

    # feed scrubber mouse events into model.
    scrubber = dom.find('.player-scrubber-area')
    scrubber.on(\mouseenter, -> player.set(\scrubber.mouse.over, true))
    scrubber.on(\mouseleave, -> player.set(\scrubber.mouse.over, false))
    scrubber.on(\mousedown, (event) ->
      player.set(\scrubber.clicking, true)
      event.preventDefault()
    )

    # feed resizer mouse events into model.
    resizer = dom.find('.player-resize')
    resizer.on(\mousedown, (event) ->
      player.set(\resize.mouse.clicking, true)
      event.preventDefault()
    )

    # feed body mouse events into model.
    body = $(document)
    left-offset = scrubber.offset().left # unlikely to change; cache for perf.
    body.on(\mousemove, (event) ->
      player.set(\scrubber.mouse.at, ((event.pageX - left-offset) / scrubber.width()) |> clamp(0, 1))
      player.set(\resize.mouse.y, event.pageY)
    )
    body.on(\mouseup, ->
      player.set(\scrubber.clicking, false)
      player.set(\resize.mouse.clicking, false)
    )

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
    library.register(Term, TermView)
    library.register(Glossary, GlossaryView)
    library.register(LineVM, LineView)
    library.register(Player, PlayerView)
}

