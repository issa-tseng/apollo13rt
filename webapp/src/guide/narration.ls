$ = require(\jquery)
{ List, Model, bind, DomView, template, find, from } = require(\janus)
{ line-idx } = require('./util')
{ clamp, epoch-to-hms } = require('../util')

class Narration extends Model

class NarrationView extends DomView.build(
  Model.build(
    bind(\epoch, from.app(\global).get(\player).get(\timestamp.epoch))
    bind(\line-idx, line-idx)

    bind(\next-epoch, from.subject(\events).and(\line-idx)
      .all.map((events, idx) -> events[idx + 1]?.epoch))
    bind(\time-to-next, from(\next-epoch).and(\epoch).all.map((-)))

    bind(\shown-lines, from.subject(\events).and(\line-idx).all.map((events, idx) ->
      return new List() unless idx?
      lines = events[clamp(0, Infinity, idx - 5) to idx]
      new List([ new NarrationLine(line) for line in lines ])
    ))
  )
  $('<div class="guide-box narration"><div class="narration-lines"/><div class="narration-next"/></div>')
  template(
    find('.narration-lines')
      .render(from.vm(\shown-lines))
      .classGroup(\count-, from.vm(\shown-lines).map((.length_))) # immut

    find('.narration-next').classGroup(\in-, from.vm(\time-to-next).map((ttn) ->
      if ttn > 5 then \long else ttn))
  )
)

class NarrationLine extends Model

class NarrationLineView extends DomView.build(
  Model.build(bind(\hms, from.subject(\epoch).map(epoch-to-hms)))
  $('<div class="narration-line"><div class="nl-epoch"><span class="hh"/><span class="mm"/><span class="ss"/></div><div class="nl-content"/></div>')
  template(
    find('.nl-epoch .hh').text(from.vm(\hms.hh))
    find('.nl-epoch .mm').text(from.vm(\hms.mm))
    find('.nl-epoch .ss').text(from.vm(\hms.ss))
    find('.nl-content').html(from(\text))
  )
)


module.exports = {
  Narration, NarrationView
  NarrationLine, NarrationLineView
  registerWith: (library) ->
    library.register(Narration, NarrationView)
    library.register(NarrationLine, NarrationLineView)
}

