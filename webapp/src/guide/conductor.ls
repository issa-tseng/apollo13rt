$ = require(\jquery)
{ Model, attribute, bind, from, DomView, template, find } = require(\janus)

{ line-idx } = require('./util')
{ Status } = require('./status')
{ Narration } = require('./narration')

class Conductor extends Model.build(
  attribute('status', attribute.Model.of(Status))
  attribute('narration', attribute.Model.of(Narration))
)
  @deserialize = (data) ->
    # TODO: sloppy
    super(Object.assign({}, data, {
      narration: { events: data.narration }
      status: { events: data.status }
    }))

box-layout = (name) ->
  find(".guide-#name")
    .css('transform', from("transform-#name"))
    .css('width', from("width-#name"))
    .classed('is-last', from('last').map((is name)))

class ConductorView extends DomView.build(
  Model.build(
    bind('epoch', from.app('global').get('player').get('timestamp.epoch'))
    bind('line-idx', line-idx)
  ),
  $('<div class="guide-main">
  <div class="guide-status"/>
  <div class="guide-narration"/>
</div>'),
  template(
    ...([ 'status', 'narration' ].map(box-layout))

    find('.guide-status').render(from('status'))
    find('.guide-narration').render(from('narration'))
  )
)
  _wireEvents: ->
    dom = this.artifact()

    #a

module.exports = {
  Conductor, ConductorView
  registerWith: (library) -> library.register(Conductor, ConductorView)
}

