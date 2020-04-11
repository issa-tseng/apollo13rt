$ = require(\jquery)

{ Model, bind, initial, DomView, template, find, from } = require(\janus)
{ sticky } = require(\janus-stdlib).varying

{ ExhibitArea, Topic, Exhibit } = require('../model')
{ PanelView } = require('./exhibit/panel')
{ get-exhibit-model } = require('./exhibit/package')


class ExhibitAreaView extends DomView.build(Model.build(
  bind(\has-exhibit, from.app(\global).get(\guide)
    .and.app(\global).get(\exhibit).map((guide, exhibit) -> (guide is true) or exhibit?))
), $('
    <div class="exhibit-area">
      <div class="exhibit-toc"/>
      <div class="exhibit-wrapper"/>
    </div>
  '), template(
    find('.exhibit-area').classed(\has-exhibit, from.vm(\has-exhibit))
    find('.exhibit-toc').render(from(\topics))
    find('.exhibit-wrapper').render(from.app(\global).get(\exhibit))

    # need this to suppress spurious transitions.
    find('.exhibit-area').classed(\has-exhibit-delayed,
      from.vm(\has-exhibit).pipe(sticky( false: 900 )))
))
  _wireEvents: ->
    dom = this.artifact()
    global = this.options.app.get_(\global)

    dom.on(\click, '.exhibit-title', (event) ->
      unless event.ctrlKey or event.shiftKey or event.altKey or event.metaKey
        global.set(\exhibit, $(this).data(\view).subject)
        event.preventDefault() unless global.get_(\mode.exhibit) is true
    )
    global.get(\exhibit).react((active) ->
      if active?
        $('body').animate({ scrollTop: $('header').height() })
        dom.addClass(\exhibited)
    )

class TopicView extends DomView.build($('
    <div class="topic">
      <div class="topic-header">
        <div class="topic-name"><span class="name"/><span class="arrow"/></div>
        <div class="topic-active-name"/>
      </div>
      <div class="topic-contents"></div>
    </div>
  '), template(
    find('.topic').attr(\id, from(\title).map(-> "topic-#it"))
    find('.topic').classed(\active, from.app(\global).get(\exhibit).and(\exhibits).all.flatMap((active, all) ->
      if active? then all.any (is active) else false))
    find('.topic-name .name').text(from(\title))
    find('.topic-contents').render(from(\exhibits)).options( renderItem: (.context(\summary)) )

    find('.topic-active-name').text(from.app(\global).get(\exhibit).and(\exhibits).all.flatMap((active, all) ->
      all.any((is active)).flatMap((own) -> active.get(\title) if own) if active?))
))
  _wireEvents: ->
    dom = this.artifact()

    # kind of gross. but effective and performant.
    $('body').append($("
      <style>
        .has-exhibit-delayed \#topic-#{this.subject.get_(\title)}:hover {
          transform: translateY(-#{dom.height() - 30}px);
        }
      </style>"))

class ExhibitTitleView extends DomView.build($('
    <a class="exhibit-title passthrough">
      <p class="name"/>
      <p class="description"/>
    </a>
  '), template(
    find('.exhibit-title').attr(\href, from(\lookup).map(-> "/?exhibit##it"))
    find('.exhibit-title').classed(\active, from.app(\global).get(\exhibit).and.self().map(-> it.subject).all.map (is))
    find('.name').text(from(\title))
    find('.description').text(from(\description))
))

class ExhibitVM extends Model.build(
  bind(\all_topics, from('view').flatMap((.closest_(ExhibitArea).subject)).get(\all_topics))
  bind(\idx, from.subject().and(\all_topics).all.flatMap((exhibit, all) -> all.indexOf(exhibit)))

  bind(\prev, from(\all_topics).and(\idx).all.flatMap((all, idx) -> all.at(idx - 1) unless idx is 0))
  bind(\next, from(\all_topics).and(\idx).all.flatMap((all, idx) -> all.at(idx + 1)))
)

class ExhibitView extends DomView.build(ExhibitVM, $('
    <div class="exhibit">
      <div class="exhibit-close">Close</div>
      <h1/>
      <div class="exhibit-content"/>
      <div class="exhibit-nav">
        <div class="prev"><strong>Previously</strong> <div class="exhibit-nav-target"/></div>
        <div class="next"><strong>Next up</strong> <div class="exhibit-nav-target"/></div>
      </div>
    </div>
  '), template(
    find('.exhibit').classed(\reference, from(\reference))

    find('h1').text(from(\title))
    find('.exhibit-content').html(from(\content))

    find('.exhibit-nav .prev').classed(\hide, from.vm(\prev).map(-> !it?))
    find('.exhibit-nav .prev .exhibit-nav-target').render(from.vm(\prev)).context(\summary)

    find('.exhibit-nav .next').classed(\hide, from.vm(\next).map(-> !it?))
    find('.exhibit-nav .next .exhibit-nav-target').render(from.vm(\next)).context(\summary)
))
  _wireEvents: ->
    dom = this.artifact()
    app = this.options.app
    exhibit = this.subject
    global = app.get_(\global)

    dom.find('.exhibit-close').on(\click, -> global.unset(\exhibit))

    # rig up zoom controls if we are a panel display.
    dom.find('.panel').each(->
      view = new PanelView(exhibit, $(this), { app })
      view.wireEvents()
    )

    # drop in figures where we find them.
    dom.find('.figure').each(->
      container = $(this)
      if (view = app.view(get-exhibit-model(container.attr(\data-figure))))?
        container.append(view.artifact())
        view.wireEvents()
    )

    dom.find('.prev').on(\click, (event) ~>
      event.preventDefault()
      global.set(\exhibit, this.subject.get_(\prev))
    )
    dom.find('.next').on(\click, (event) ~>
      event.preventDefault()
      global.set(\exhibit, this.subject.get_(\next))
    )


module.exports = {
  ExhibitAreaView, TopicView, ExhibitTitleView, ExhibitView

  registerWith: (library) ->
    library.register(ExhibitArea, ExhibitAreaView)
    library.register(Topic, TopicView)
    library.register(Exhibit, ExhibitTitleView, context: \summary)
    library.register(Exhibit, ExhibitView)
}

