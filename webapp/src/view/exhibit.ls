$ = require(\jquery)

{ Model, DomView, template, find, from } = require(\janus)
{ sticky } = require(\janus-stdlib).util.varying

{ ExhibitArea, Topic, Exhibit } = require('../model')
{ PanelView } = require('./exhibit/panel')
{ get-exhibit-model } = require('./exhibit/package')


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
      sticky( false: 900 )(global.watch(\exhibit).map((?)))
    ))
  )
  _wireEvents: ->
    dom = this.artifact()
    global = this.options.app.get(\global)

    dom.on(\click, '.exhibit-title', (event) ->
      unless event.ctrlKey or event.shiftKey or event.altKey or event.metaKey
        global.set(\exhibit, $(this).data(\view).subject)
        event.preventDefault() unless global.get(\mode.exhibit) is true
    )
    global.watch(\exhibit).react((active) ->
      if active?
        $('body').animate({ scrollTop: $('header').height() })
        dom.addClass(\exhibited)
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
    <a class="exhibit-title passthrough">
      <p class="name"/>
      <p class="description"/>
    </a>
  ')
  @_template = template(
    find('.exhibit-title').attr(\href, from(\lookup).map(-> "/?exhibit##it"))
    find('.exhibit-title').classed(\active, from.app(\global).watch(\exhibit).and.self().map(-> it.subject).all.map (is))
    find('.name').text(from(\title))
    find('.description').text(from(\description))
  )

class ExhibitVM extends Model
  @bind(\all_topics, from.app(\stack).flatMap((.watchAt(-2))).watch(\all_topics))
  @bind(\idx, from(\subject).and(\all_topics).all.flatMap((exhibit, all) -> all.indexOf(exhibit)))

  @bind(\prev, from(\all_topics).and(\idx).all.flatMap((all, idx) -> all.watchAt(idx - 1) unless idx is 0))
  @bind(\next, from(\all_topics).and(\idx).all.flatMap((all, idx) -> all.watchAt(idx + 1)))

class ExhibitView extends DomView
  @viewModelClass = ExhibitVM
  @_dom = -> $('
    <div class="exhibit">
      <div class="exhibit-close">Close</div>
      <h1/>
      <div class="exhibit-content"/>
      <div class="exhibit-nav">
        <div class="prev"><strong>Previously</strong> <div class="exhibit-nav-target"/></div>
        <div class="next"><strong>Next up</strong> <div class="exhibit-nav-target"/></div>
      </div>
    </div>
  ')
  @_template = template(
    find('.exhibit').classed(\reference, from(\subject).watch(\reference))

    find('h1').text(from(\subject).watch(\title))
    find('.exhibit-content').html(from(\subject).watch(\content))

    find('.exhibit-nav .prev').classed(\hide, from(\prev).map(-> !it?))
    find('.exhibit-nav .prev .exhibit-nav-target').render(from(\prev)).context(\summary)

    find('.exhibit-nav .next').classed(\hide, from(\next).map(-> !it?))
    find('.exhibit-nav .next .exhibit-nav-target').render(from(\next)).context(\summary)
  )
  _wireEvents: ->
    dom = this.artifact()
    app = this.options.app
    exhibit = this.subject
    global = app.get(\global)

    dom.find('.exhibit-close').on(\click, ~> global.unset(\exhibit))

    # wait for completion.
    <~ this.on(\appendedToDocument)

    # rig up zoom controls if we are a panel display.
    dom.find('.panel').each(->
      view = new (PanelView.withFragment(this))(exhibit, { app })
      view.wireEvents()
    )

    # drop in figures where we find them.
    dom.find('.figure').each(->
      container = $(this)
      if (view = app.vendView(get-exhibit-model(container.attr(\data-figure))))?
        container.append(view.artifact())
        view.wireEvents()
    )

    dom.find('.prev').on(\click, ~> global.set(\exhibit, this.subject.get(\prev)))
    dom.find('.next').on(\click, ~> global.set(\exhibit, this.subject.get(\next)))


module.exports = {
  ExhibitAreaView, TopicView, ExhibitTitleView, ExhibitView

  registerWith: (library) ->
    library.register(ExhibitArea, ExhibitAreaView)
    library.register(Topic, TopicView)
    library.register(Exhibit, ExhibitTitleView, context: \summary)
    library.register(Exhibit, ExhibitView)
}

