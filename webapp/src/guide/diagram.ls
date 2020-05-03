$ = require(\jquery)
{ Model, bind, from, DomView, template, find } = require(\janus)

{ Graphic } = require('../model')
{ event-idx } = require('./util')
{ get-exhibit-model } = require('../view/exhibit/package')

class Diagram extends Model

class DiagramView extends DomView.build(
  Model.build(
    bind(\epoch, from.app(\epoch))
    bind(\event-idx, event-idx)

    bind(\diagram, from.subject(\events).and(\event-idx).all.map((events, idx) ->
      events[idx]?.name))
  )
  $('<div class="guide-diagram"/>')
  find('.guide-diagram').render(from.vm(\diagram).map(get-exhibit-model)).context(\diagram)
)

class DiagramGraphicView extends DomView.build(
  $('<img/>')
  find('img').attr(\src, from(\src))
)

module.exports = {
  Diagram, DiagramView, DiagramGraphicView
  registerWith: (library) ->
    library.register(Diagram, DiagramView)
    library.register(Graphic, DiagramGraphicView, context: \diagram)
}

