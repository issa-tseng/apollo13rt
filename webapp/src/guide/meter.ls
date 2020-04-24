$ = require(\jquery)
{ Model, bind, from, DomView, template, find } = require(\janus)



time = -> (new Date()).getTime()

################################################################################
# MODELS

class Scale extends Model.build(
)

class Meter extends Model.build(
  # expects static name, range, active-intervals and points
)


################################################################################
# VIEWS

class MeterView extends DomView.build(
  Model.build(
    bind(\playing, from.app(\player).get(\audio.playing))
    bind(\in-active-interval, from.subject(\active-intervals)
      .and.app(\player).get(\timestamp.epoch).asVarying()
      .all.map((intervals, epochv) -> intervals.flatMap((interval) -> interval.contains(epochv)).any()))
    bind(\active, from(\playing).and(\in-active-interval).all.map((and)))
  )
  $('<div class="meter">
  <label class="meter-name"/>
  <div class="meter-scales"/>
  <div class="meter-arrow"/>
</div>')
  template(
    find('.meter-name').text(from(\name))
    find('.meter-scales').render(from(\scales))
    find('.meter-arrow').css(\transform, from.vm(\value).and.subject()
      .all.map((value, meter) -> "translateY(-#{meter.scale(value) * 300}px)"))
  )
)
  _set: ->
    meter = this.subject
    vm = this.vm
    return unless vm.get_(\playing) is true
    return unless vm.get_(\active) is true

    # gets detailed epoch in millis
    epoch = vm.get_(\last-jump-epoch) + (time() - vm.get_(\last-jump-real))

    # determine current data index
    data-idx = this._lastIdx ? 0
    data = meter.get_(\points)
    while data.list[data-idx].0 < epoch
      ++data-idx
    return if data-idx >= data.length_
    this._lastIdx = data-idx

    # get previous and next data points
    [ prev-epoch, prev-val ] = data.list[data-idx - 1]
    [ next-epoch, next-val ] = data.list[data-idx]

    # now lerp
    delta-t = (epoch - prev-epoch) / (next-epoch - prev-epoch)
    value = prev-val + delta-t * (next-val - prev-val)

    # setval and loop
    vm.set(\value, value)
    window.requestAnimationFrame(this~_set)
    return

  _wireEvents: ->
    dom = this.artifact()
    this.reactTo(this.vm.get(\active), this~_set)
    return

