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
    <div class="ship-sm">
      <img src="/assets/sm.svg"/>
      <span class="sublabel">Command/Service Module (CSM)</span>
      <span class="subsublabel">Service Module (SM)</span>
    </div>
    <div class="ship-cm">
      <img src="/assets/cm.svg"/>
      <span class="subsublabel">Command Module (CM)</span>
    </div>
    <div class="ship-lm-a">
      <img src="/assets/lm-a.svg"/>
      <span class="sublabel">Lunar Module (LM)</span>
      <span class="subsublabel">Ascent</span>
    </div>
    <div class="ship-lm-d">
      <img src="/assets/lm-d.svg"/>
      <span class="subsublabel">Descent</span>
    </div>
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

