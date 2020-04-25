$ = require(\jquery)
{ Model, attribute, bind, from, DomView, template, find } = require(\janus)

{ px } = require('../util')
{ event-idx } = require('./util')
{ Status } = require('./status')
{ Narration } = require('./narration')

class Conductor extends Model.build(
  attribute(\status, attribute.Model.of(Status))
  attribute(\narration, attribute.Model.of(Narration))
)

box-layout = (name) ->
  find(".guide-#name")
    .css(\left, from("left-#name").map(px))
    .css(\width, from("width-#name").map(px))
    .classed(\is-last, from(\last).map((is name)))

class ConductorView extends DomView.build(
  Model.build(
    bind(\epoch, from.app(\epoch))
    bind(\event-idx, event-idx)
  )
  $('<div class="guide-main">
  <div class="guide-status"/>
  <div class="guide-narration"/>
</div>')
  template(
    find('.guide-main').css(\height, from.app(\global).get(\player).get(\height)
      .map((script-height) -> "calc(100vh - 20.5em - #{script-height}px)"))

    ...([ \status, \narration ].map(box-layout))
    find('.guide-status').render(from(\status))
    find('.guide-narration').render(from(\narration))
  )
)
  _wireEvents: ->
    dom = this.artifact()
    events = this.subject.get_(\events)

    this.vm.get(\event-idx).react((idx) ->
      layout = events[idx].panels
      console.log(layout)
    )

module.exports = {
  Conductor, ConductorView
  registerWith: (library) -> library.register(Conductor, ConductorView)
}

