{ DomView, template, find, from, Model, Varying } = require(\janus)
{ debounce, sticky } = require(\janus-stdlib).util.varying
$ = require(\jquery)
marked = require(\marked)

{ Line, Transcript, Term, Glossary, Player, ExhibitArea, Topic, Exhibit } = require('./model')

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
      <div class="line-annotations">
        <div class="line-token-annotations"/>
        <div class="line-whole-annotations"/>
      </div>
    </div>
  ')
  @_dom = -> @_fragment.clone()
  @_template = template(
    find('.line').classGroup(\line-, from(\id))
    find('.line').classed(\active, from(\active))

    find('.line-timestamp').classed(\hide, from(\start.epoch).map((x) -> !x?))
    find('.hh').text(from(\start.hh))
    find('.mm').text(from(\start.mm).map(pad))
    find('.ss').text(from(\start.ss).map(pad))

    find('.line-edit').attr(\href, from(\line).map((line) -> "\#L#line"))

    find('.line-source').text(from(\source))
    find('.line-contents').html(from(\message))

    find('.line-token-annotations').render(from(\tokens))
    find('.line-whole-annotations').render(from(\annotations))
  )

class TranscriptView extends DomView
  @_dom = -> $('
    <div class="script">
      <div class="script-scroll-indicator-container">
        <a class="script-scroll-indicator" href="#" title="Sync with audio"/>
      </div>
      <div class="script-lines"/>
      <p><span class="leader">Transcript:</span><span class="name"/></p>
    </div>
  ')
  @_template = template(
      find('p .name').text(from(\name))
      find('.script-lines').render(from(\lines))
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
      line-container.stop(true).animate({ scroll-top }, { complete: (-> relinquished := get-time()) })

    debounce(transcript.watch(\top_line), 50).react((line) ->
      id = line?._id
      return unless id?
      offset = get-offset(id)

      # scroll to the top line if relevant.
      scroll-to(offset - 50) if transcript.get(\auto_scroll) is true

      # position the scroll indicator always.
      indicator.css(\top, offset / line-container.get(0).scrollHeight |> pct)
    )

    # watch for autoscroll rising edge and trip scroll.
    transcript.watch(\auto_scroll).react((auto) ->
      id |> get-offset |> (- 50) |> scroll-to if auto and (id = transcript.get(\top_line)?._id)?
    )

    # turn off auto-scrolling as intelligently as we can.
    line-container.on(\scroll, ->
      transcript.set(\auto_scroll, false) if get-time() > (relinquished + 200) # complete fires early
    )
    line-container.on(\wheel, ->
      line-container.finish()
      transcript.set(\auto_scroll, false)
      null # return value is significant.
    )

    # do these via delegate here once rather for each line for perf.
    dom.on(\click, '.line-timestamp', (event) ->
      event.preventDefault()
      line = $(event.target).closest('.line').data(\view).subject
      transcript.get(\player).epoch(line.get(\start.epoch))
      transcript.set(\auto_scroll, true)
    )
    dom.on(\mouseenter, '.line-edit', ->
      return if this.hostname isnt window.location.hostname
      this.href = transcript.get(\edit_url) + this.hash
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
        <a class="term-hide" href="#"/>
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
            terms.find(f)?
        )
    )

    find('.term-name .name').text(from(\term))
    find('.term-name .synonyms').render(
      from(\synonyms).and.app(\global).watch(\player).all.map((synonyms, player) ->
        synonyms.filter((term) -> player.watch(\nearby_terms).map((nearby) -> term in nearby))
      )
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
    find('.player-scripts').classed(\inactive, from(\height).map (< 35))

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



########################################
# EXHIBIT VIEWS

class ExhibitAreaView extends DomView
  @_dom = -> $('
    <div class="exhibit-area">
      <div class="exhibit-toc"/>
      <div class="exhibit-content"/>
    </div>
  ')
  @_template = template(
    find('.exhibit-area').classed(\has-exhibit, from.app(\global).watch(\exhibit).map (?))
    find('.exhibit-toc').render(from(\topics))
    find('.exhibit-content').render(from.app(\global).watch(\exhibit))
  )
  _wireEvents: ->
    dom = this.artifact()
    global = this.options.app.get(\global)

    dom.on(\click, '.exhibit-title', -> global.set(\exhibit, $(this).data(\view).subject))

class TopicView extends DomView
  @_dom = -> $('
    <div class="topic">
      <div class="topic-header">
        <div class="topic-active">
          <div class="topic-active-name"><span class="name"/><span class="close">&times;</span></div>
        </div>
        <div class="topic-name"><span class="name"/><span class="arrow"/></div>
      </div>
      <div class="topic-contents"></div>
    </div>
  ')
  @_template = template(
    find('.topic-name .name').text(from(\title))
    find('.topic-contents').render(from(\exhibits)).options( renderItem: (.context(\summary)) )

    find('.topic').classed(\active, from.app(\global).watch(\exhibit).and(\exhibits)
      .all.flatMap((active, all) -> if active? then all.any (is active) else false)
    )
  )
  _wireEvents: ->
    dom = this.artifact()
    app = this.options.app

    # we want to retain the last relevant name, so handle this point-in-time instead:
    active-name = dom.find('.topic-active-name .name')
    from(app.watch(\global)).watch(\exhibit)
      .and(this.subject.watch(\exhibits))
      .all.plain().flatMap((active, all) ->
        (all.any (is active)).flatMap((is-ours) -> if is-ours then active.watch(\title) else null)
      ).react((title) -> active-name.text(title) if title?)

    # clear active exhibit if close is pressed.
    dom.find('.close').on(\click, ~> app.get(\global).unset(\exhibit))

class ExhibitTitleView extends DomView
  @_dom = -> $('
    <div class="exhibit-title">
      <p class="name"/>
      <p class="description"/>
    </div>
  ')
  @_template = template(
    find('.exhibit-title').classed(\active, from.app(\global).watch(\exhibit).and.self().map(-> it.subject).all.map (is))
    find('.name').text(from(\title))
    find('.description').text(from(\description))
  )

class ExhibitView extends DomView
  @_dom = -> $('<div class="exhibit"/>')
  @_template = template(find('.exhibit').text(from(\title)))


module.exports = {
  TranscriptView
  LineView
  registerWith: (library) ->
    library.register(Transcript, TranscriptView)
    library.register(Term, TermView)
    library.register(Glossary, GlossaryView)
    library.register(Line, LineView)
    library.register(Player, PlayerView)

    library.register(ExhibitArea, ExhibitAreaView)
    library.register(Topic, TopicView)
    library.register(Exhibit, ExhibitTitleView, context: \summary)
    library.register(Exhibit, ExhibitView)
}

