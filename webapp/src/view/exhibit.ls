$ = require(\jquery)

{ DomView, template, find, from } = require(\janus)
{ sticky } = require(\janus-stdlib).util.varying

{ ExhibitArea, Topic, Exhibit } = require('../model')
{ PanelView } = require('./exhibit/panel')


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
      <div class="exhibit-close">Close</div>
      <h1/>
      <div class="exhibit-content"/>
    </div>
  ')
  @_template = template(
    find('h1').text(from(\title))
    find('.exhibit').classed(\reference, from(\reference))
    find('.exhibit-content').html(from(\content))
  )
  _wireEvents: ->
    dom = this.artifact()
    app = this.options.app
    global = app.get(\global)

    dom.find('.exhibit-close').on(\click, ~> global.unset(\exhibit))

    # wait for completion.
    <~ this.on(\appendedToDocument)

    # rig up zoom controls if we are a panel display.
    dom.find('.panel').each(->
      view = new (PanelView.withFragment(this))(null, { app })
      view.wireEvents()
    )


module.exports = {
  ExhibitAreaView, TopicView, ExhibitTitleView, ExhibitView

  registerWith: (library) ->
    library.register(ExhibitArea, ExhibitAreaView)
    library.register(Topic, TopicView)
    library.register(Exhibit, ExhibitTitleView, context: \summary)
    library.register(Exhibit, ExhibitView)
}

