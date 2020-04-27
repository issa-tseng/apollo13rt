$ = require(\jquery)
{ Model, bind, DomView, template, find, from } = require(\janus)
{ event-idx } = require('./util')

class Status extends Model

class StatusView extends DomView.build(
  Model.build(
    bind(\epoch, from.app(\epoch))
    bind(\event-idx, event-idx)

    bind(\status, from.subject(\events).and(\event-idx).all.map((events, idx) ->
      events[idx]?.name))
  )
  $('<div class="guide-box status">
  <div class="ship">
    <div class="ship-sm"><img src="/assets/sm.svg"/></div>
    <div class="ship-cm"><img src="/assets/cm.svg"/></div>
    <div class="ship-lm-a"><img src="/assets/lm-a.svg"/></div>
    <div class="ship-lm-d"><img src="/assets/lm-d.svg"/></div>
  </div>
</div>')
  template(
    find('.status').classGroup(\status-, from.vm(\status))
  )
)


module.exports = {
  Status, StatusView
  registerWith: (library) ->
    library.register(Status, StatusView)
}

