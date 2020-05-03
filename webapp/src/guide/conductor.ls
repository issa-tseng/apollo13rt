$ = require(\jquery)
{ Model, attribute, bind, from, DomView, template, find } = require(\janus)

{ event-idx } = require('./util')
{ Diagram } = require('./diagram')
{ Narration } = require('./narration')
{ Status } = require('./status')

class Conductor extends Model.build(
  attribute(\status, attribute.Model.of(Status))
  attribute(\narration, attribute.Model.of(Narration))
  attribute(\diagram, attribute.Model.of(Diagram))
)

default-lefts = {
  status: 0
}
default-widths = {
  status: 25
  narration: 40
  diagram: 30
}

do-layout = (layout) ->
  result = {}
  for name of default-widths
    result["left-#name"] = default-lefts[name] ? \100vw
    result["width-#name"] = 0

  left-em = 0
  left-vw = 0
  last = layout[layout.length - 1]
  for box in layout
    result["left-#{box.name}"] =
      if !left-vw then "#{left-em}em"
      else if !left-em then "#{left-vw}vw"
      else "calc(#{left-em}em + #{left-vw}vw)"

    if box is last
      result["width-#{box.name}"] = "calc(100vw - #{left-em + 2.5}em - #{left-vw}vw)"
    else if box.weight?
      result["width-#{box.name}"] = "#{box.weight}vw"
      left-vw += box.weight
    else
      width = default-widths[box.name]
      result["width-#{box.name}"] = "#{width}em"
      left-em += width

  result

box-layout = (name) ->
  find(".guide-#name")
    .css(\left, from("left-#name"))
    .css(\width, from("width-#name"))

class ConductorView extends DomView.build(
  Model.build(
    bind(\epoch, from.app(\epoch))
    bind(\event-idx, event-idx)
  )
  $('<div class="guide-main">
  <div class="guide-diagram guide-wrapper"/>
  <div class="guide-status guide-wrapper"/>
  <div class="guide-narration guide-wrapper"/>
</div>')
  template(
    find('.guide-main').css(\height, from.app(\global).get(\player).get(\height)
      .map((script-height) -> "calc(100vh - 20.5em - #{script-height}px)"))

    find('.guide-diagram').render(from(\diagram))
    find('.guide-narration').render(from(\narration))
    find('.guide-status').render(from(\status))

    ...([ \diagram, \narration, \status ].map(box-layout))
  )
)
  _wireEvents: ->
    dom = this.artifact()
    events = this.subject.get_(\events)

    this.vm.get(\event-idx)
      .map((idx) -> do-layout(events[idx].panels))
      .react(this.subject~set)

module.exports = {
  Conductor, ConductorView
  registerWith: (library) -> library.register(Conductor, ConductorView)
}

