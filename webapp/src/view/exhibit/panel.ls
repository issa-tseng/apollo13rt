$ = require(\jquery)

{ DomView, template, find, from, List, Model, attribute } = require(\janus)
{ from-event } = require(\janus-stdlib).util.varying

{ defer, clamp, px, size-of } = require('../../util')
{ min, max } = Math


class PanelVM extends Model
  @attribute(\scale.mode, class extends attribute.EnumAttribute
    values: -> new List([ \all, \fit, \zoom ])
    default: -> \all
  )
  @bind(\window, from.varying(window |> $ |> size-of))
  @bind(\frame.width, from(\window.width))
  @bind(\frame.height, from(\window.height).and(\view.options.app).watch(\global).watch(\player).watch(\base_height)
      .all.map((window-height, player-height) -> window-height - player-height - 145))
  @default(\target.x, 0.5)
  @default(\target.y, 0.5)
  @bind(\mouse.delta.x, from(\mouse.now.x).and(\mouse.down.x).all.map (-))
  @bind(\mouse.delta.y, from(\mouse.now.y).and(\mouse.down.y).all.map (-))

  marginator = (frame, all, scale) -> clamp(0, 0.5, frame / 2 / all / scale)
  @bind(\margin.x, from(\frame.width).and(\all.width).and(\scale.factor).all.map(marginator))
  @bind(\margin.y, from(\frame.height).and(\all.height).and(\scale.factor).all.map(marginator))

  @bind(\scale.factor, from(\scale.mode)
    .and(\frame.width).and(\frame.height).and(\all.width).and(\all.height)
    .all.map((scale-mode, frame-width, frame-height, all-width, all-height) ->
      if scale-mode is \zoom
        1.0
      else if scale-mode is \fit
        max((frame-height / all-height), (frame-width / all-width))
      else if scale-mode is \all
        min((frame-height / all-height), (frame-width / all-width))
    ))

  translator = (scale-factor, target, all, frame, mouse, margin) ->
    clamped-target = clamp(margin, 1 - margin, (target - (mouse / all / scale-factor)))
    (scale-factor * all * (0.5 - clamped-target)) - (all / 2) + (frame / 2)
  @bind(\translate.x, from(\scale.factor).and(\target.x).and(\all.width).and(\frame.width).and(\mouse.delta.x).and(\margin.x).all.map(translator))
  @bind(\translate.y, from(\scale.factor).and(\target.y).and(\all.height).and(\frame.height).and(\mouse.delta.y).and(\margin.y).all.map(translator))

  _initialize: ->
    this.watch(\mouse.clicking).react((is-clicking) ~>
      if is-clicking is false
        # react to trailing edge to adjust target and null mouse delta.
        target-x = this.get(\target.x) - (this.get(\mouse.delta.x) / this.get(\all.width) / this.get(\scale.factor))
        margin-x = this.get(\margin.x)
        this.set(\target.x, clamp(margin-x, 1 - margin-x, target-x))

        target-y = this.get(\target.y) - (this.get(\mouse.delta.y) / this.get(\all.height) / this.get(\scale.factor))
        margin-y = this.get(\margin.y)
        this.set(\target.y, clamp(margin-y, 1 - margin-y, target-y))

        this.unset(\mouse.down)
        this.unset(\mouse.now)
    )

class PanelView extends DomView
  @viewModelClass = PanelVM
  @_template = template(
    find('.panel-wrapper').css(\height, from(\frame.height))
    find('.panel-inner-wrapper').css(\transform, from(\scale.factor).and(\translate.x).and(\translate.y).all.map((factor, x, y) ->
      "translateX(#{x}px) translateY(#{y}px) scale(#factor)"))
    find('.panel-inner-wrapper').css(\width, from(\all.width).map(px))
    find('.panel-inner-wrapper').classed(\dragging, from(\mouse.clicking))
    find('.panel-controls').render(from.attribute(\scale.mode)).context(\edit).find( attributes: { style: \list } )
  )
  @withFragment = (dom) ->
    class AttachedPanelView extends PanelView
      @_dom = -> $(dom)
  _wireEvents: ->
    dom = this.artifact()
    model = this.subject
    wrapper = dom.find('.panel-inner-wrapper')

    # grab the total layout size and store it, as it is soon lost.
    layout = dom.find('.panel-inner-wrapper img')
    this.subject.set( all: { width: layout.width(), height: layout.height() })

    # respond to mouse events.
    mouse-pos = from-event($(document), \mousemove, (event) -> { x: event.screenX, y: event.screenY })
    wrapper.on(\mousedown, (event) ->
      event.preventDefault() # stop default drag operations.

      model.set(\mouse.clicking, true)
      model.set(\mouse.down, { x: event.screenX, y: event.screenY })
      model.set(\mouse.now, { x: event.screenX, y: event.screenY })
      tracker = mouse-pos.react(-> model.set(\mouse.now, it))

      $(document).one(\mouseup, ->
        model.set(\mouse.clicking, false)
        tracker.stop()
      )
    )

    <- defer
    # enable zoom transitions, but only after initial computation.
    wrapper.addClass(\initialized)


module.exports = { PanelView }

