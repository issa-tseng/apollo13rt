$ = require(\jquery)
marked = require(\marked)

{ DomView, template, find, from, List, Model, attribute, Varying } = require(\janus)
{ debounce, sticky, from-event } = require(\janus-stdlib).util.varying

{ Line, Transcript, Term, Glossary, Player, ExhibitArea, Topic, Exhibit } = require('./model')
{ defer, clamp, px, pct, pad, get-time, max-int, size-of } = require('./util')
{ min } = Math



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

    # fixed player/scroll handling.
    container = $('#timeline')
    threshold = dom.position().top
    chrome-height = dom.outerHeight() - player.get(\base_height)
    crossed-threshold = from-event(body, \scroll, (.target.scrollingElement.scrollTop > threshold))

    crossed-threshold.react((is-fixed) -> container.toggleClass(\fixed-player, is-fixed is true))
    from(crossed-threshold).and(player.watch(\base_height)).all.plain().map((is-fixed, base-height) ->
      if is-fixed then chrome-height + base-height else \auto
    ).react(-> container.css(\height, it))



########################################
# EXHIBIT VIEWS

class ExhibitAreaView extends DomView
  @_dom = -> $('
    <div class="exhibit-area">
      <div class="exhibit-toc"/>
      <div class="exhibit-wrapper"/>
    </div>
  ')
  @_template = template(
    find('.exhibit-area').classed(\has-exhibit, from.app(\global).watch(\exhibit).map (?))
    find('.exhibit-toc').render(from(\topics))
    find('.exhibit-wrapper').render(from.app(\global).watch(\exhibit))

    # need this to suppress spurious transitions.
    find('.exhibit-area').classed(\has-exhibit-delayed, from.app(\global).flatMap((global) ->
      sticky(global.watch(\exhibit).map((?)), false: 900 )
    ))
  )
  _wireEvents: ->
    dom = this.artifact()
    global = this.options.app.get(\global)

    dom.on(\click, '.exhibit-title', -> global.set(\exhibit, $(this).data(\view).subject))
    global.watch(\exhibit).react((active) ->
      $('body').animate({ scrollTop: $('header').height() }) if active?
    )

class TopicView extends DomView
  @_dom = -> $('
    <div class="topic">
      <div class="topic-header">
        <div class="topic-name"><span class="name"/><span class="arrow"/></div>
        <div class="topic-active-name"/>
      </div>
      <div class="topic-contents"></div>
    </div>
  ')
  @_template = template(
    find('.topic').attr(\id, from(\title).map(-> "topic-#it"))
    find('.topic').classed(\active, from.app(\global).watch(\exhibit).and(\exhibits).all.flatMap((active, all) ->
      if active? then all.any (is active) else false))
    find('.topic-name .name').text(from(\title))
    find('.topic-contents').render(from(\exhibits)).options( renderItem: (.context(\summary)) )

    find('.topic-active-name').text(from.app(\global).watch(\exhibit).and(\exhibits).all.flatMap((active, all) ->
      all.any((is active)).flatMap((own) -> active.watch(\title) if own) if active?))
  )
  _wireEvents: ->
    dom = this.artifact()

    # kind of gross. but effective and performant.
    $('body').append($("
      <style>
        .has-exhibit-delayed \#topic-#{this.subject.get(\title)}:hover {
          transform: translateY(-#{dom.height() - 30}px);
        }
      </style>"))

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
  @_dom = -> $('
    <div class="exhibit">
      <h1/>
      <div class="exhibit-content"/>
    </div>
  ')
  @_template = template(
    find('h1').text(from(\title))
    find('.exhibit-content').html(from(\content))
  )
  _wireEvents: ->
    dom = this.artifact()
    app = this.options.app

    # wait for completion.
    <~ this.on(\appendedToDocument)

    # rig up zoom controls if we are a panel display.
    dom.find('.panel').each(->
      view = new (PanelView.withFragment(this))(null, { app })
      view.wireEvents()
    )



########################################
# CUSTOM EXHIBIT VIEWS

class PanelVM extends Model
  @attribute(\scale.mode, class extends attribute.EnumAttribute
    values: -> new List([ \all, \fit, \zoom ])
    default: -> \all
  )
  @bind(\window, from(\view).flatMap((view) -> window |> $ |> size-of))
  @bind(\frame.width, from(\window.width).map (- 85))
  @bind(\frame.height, from(\window.height).map (- 150))
  @default(\target.x, 0.5)
  @default(\target.y, 0.5)
  @bind(\mouse.delta.x, from(\mouse.now.x).and(\mouse.down.x).all.map (-))
  @bind(\mouse.delta.y, from(\mouse.now.y).and(\mouse.down.y).all.map (-))

  marginator = (frame, all, scale) -> clamp(0, 0.5, frame / 2 / all / scale)
  @bind(\margin.x, from(\frame.width).and(\all.width).and(\scale.factor).all.map(marginator))
  @bind(\margin.y, from(\frame.height).and(\all.height).and(\scale.factor).all.map(marginator))

  @bind(\scale.factor, from(\scale.mode)
    .and(\frame.width).and(\frame.height).and(\all.width).and(\all.height)
    .all.map((scale-mode, frame-width, frame-height, all-width, all-height) ->
      if scale-mode is \zoom
        1.0
      else if scale-mode is \fit
        frame-height / all-height
      else if scale-mode is \all
        min((frame-height / all-height), (frame-width / all-width))
    ))

  translator = (scale-factor, target, all, frame, mouse, margin) ->
    clamped-target = clamp(margin, 1 - margin, (target - (mouse / all / scale-factor)))
    (scale-factor * all * (0.5 - clamped-target)) - (all / 2) + (frame / 2)
  @bind(\translate.x, from(\scale.factor).and(\target.x).and(\all.width).and(\frame.width).and(\mouse.delta.x).and(\margin.x).all.map(translator))
  @bind(\translate.y, from(\scale.factor).and(\target.y).and(\all.height).and(\frame.height).and(\mouse.delta.y).and(\margin.y).all.map(translator))

  _initialize: ->
    this.watch(\mouse.clicking).react((is-clicking) ~>
      if is-clicking is false
        # react to trailing edge to adjust target and null mouse delta.
        target-x = this.get(\target.x) - (this.get(\mouse.delta.x) / this.get(\all.width) / this.get(\scale.factor))
        margin-x = this.get(\margin.x)
        this.set(\target.x, clamp(margin-x, 1 - margin-x, target-x))

        target-y = this.get(\target.y) - (this.get(\mouse.delta.y) / this.get(\all.height) / this.get(\scale.factor))
        margin-y = this.get(\margin.y)
        this.set(\target.y, clamp(margin-y, 1 - margin-y, target-y))

        this.unset(\mouse.down)
        this.unset(\mouse.now)
    )

class PanelView extends DomView
  @viewModelClass = PanelVM
  @_template = template(
    find('.panel-wrapper').css(\height, from(\frame.height))
    find('.panel-inner-wrapper').css(\transform, from(\scale.factor).and(\translate.x).and(\translate.y).all.map((factor, x, y) ->
      "translateX(#{x}px) translateY(#{y}px) scale(#factor)"))
    find('.panel-inner-wrapper').css(\width, from(\all.width).map(px))
    find('.panel-inner-wrapper').classed(\dragging, from(\mouse.clicking))
    find('.panel-controls').render(from.attribute(\scale.mode)).context(\edit).find( attributes: { style: \list } )
  )
  @withFragment = (dom) ->
    class AttachedPanelView extends PanelView
      @_dom = -> $(dom)
  _wireEvents: ->
    dom = this.artifact()
    model = this.subject
    wrapper = dom.find('.panel-inner-wrapper')

    # grab the total layout size and store it, as it is soon lost.
    layout = dom.find('.panel-inner-wrapper img')
    this.subject.set( all: { width: layout.width(), height: layout.height() })

    # respond to mouse events.
    mouse-pos = from-event($(document), \mousemove, (event) -> { x: event.screenX, y: event.screenY })
    wrapper.on(\mousedown, (event) ->
      event.preventDefault() # stop default drag operations.

      model.set(\mouse.clicking, true)
      model.set(\mouse.down, { x: event.screenX, y: event.screenY })
      model.set(\mouse.now, { x: event.screenX, y: event.screenY })
      tracker = mouse-pos.react(-> model.set(\mouse.now, it))

      $(document).one(\mouseup, ->
        model.set(\mouse.clicking, false)
        tracker.stop()
      )
    )

    <- defer
    # enable zoom transitions, but only after initial computation.
    wrapper.addClass(\initialized)


module.exports = {
  LineView, TranscriptView
  TermView, GlossaryView
  PlayerView
  ExhibitAreaView, TopicView, ExhibitTitleView, ExhibitView
  PanelView

  registerWith: (library) ->
    library.register(Term, TermView)
    library.register(Glossary, GlossaryView)
    library.register(Line, LineView)
    library.register(Transcript, TranscriptView)
    library.register(Player, PlayerView)

    library.register(ExhibitArea, ExhibitAreaView)
    library.register(Topic, TopicView)
    library.register(Exhibit, ExhibitTitleView, context: \summary)
    library.register(Exhibit, ExhibitView)
}

