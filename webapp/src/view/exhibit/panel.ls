$ = require(\jquery)

{ DomView, template, find, from, List, Model, attribute, bind, initial } = require(\janus)
{ from-event } = require(\janus-stdlib).varying
{ Term, BasicRequest } = require('../../model')

{ defer, clamp, px, size-of, attach-floating-box, get-touch-x, get-touch-y } = require('../../util')
{ min, max } = Math


translator = (scale-factor, target, all, frame, mouse, margin) ->
  clamped-target = clamp(margin, 1 - margin, (target - (mouse / all / scale-factor)))
  (scale-factor * all * (0.5 - clamped-target)) - (all / 2) + (frame / 2)

class PanelVM extends Model.build(
  attribute(\lookup, attribute.Reference.to(
    new BasicRequest('/assets/ref-panel.lookup.json')
  ))

  attribute(\scale.mode, class extends attribute.Enum
    _values: -> new List([ \all, \fit, \zoom ])
    initial: -> \all
  )
  bind(\window, from.varying(window |> $ |> size-of))
  bind(\frame.width, from(\window.width))
  bind(\frame.height, from(\window.height).and(\view.options.app).get(\global).get(\player).get(\base_height)
      .all.map((window-height, player-height) -> window-height - player-height - 145))
  initial(\target.x, 0.5)
  initial(\target.y, 0.5)
  bind(\mouse.delta.x, from(\mouse.now.x).and(\mouse.down.x).all.map (-))
  bind(\mouse.delta.y, from(\mouse.now.y).and(\mouse.down.y).all.map (-))

  marginator = (frame, all, scale) -> clamp(0, 0.5, frame / 2 / all / scale)
  bind(\margin.x, from(\frame.width).and(\all.width).and(\scale.factor).all.map(marginator))
  bind(\margin.y, from(\frame.height).and(\all.height).and(\scale.factor).all.map(marginator))

  bind(\scale.factor, from(\scale.mode)
    .and(\frame.width).and(\frame.height).and(\all.width).and(\all.height)
    .all.map((scale-mode, frame-width, frame-height, all-width, all-height) ->
      if scale-mode is \zoom
        1.0
      else if scale-mode is \fit
        max((frame-height / all-height), (frame-width / all-width))
      else if scale-mode is \all
        min((frame-height / all-height), (frame-width / all-width))
    ))

  bind(\translate.x, from(\scale.factor).and(\target.x).and(\all.width).and(\frame.width).and(\mouse.delta.x).and(\margin.x).all.map(translator))
  bind(\translate.y, from(\scale.factor).and(\target.y).and(\all.height).and(\frame.height).and(\mouse.delta.y).and(\margin.y).all.map(translator))
)

  _initialize: ->
    this.get(\mouse.clicking).react((is-clicking) ~>
      if is-clicking is false
        # react to trailing edge to adjust target and null mouse delta.
        this.focusTarget(
          this.get_(\target.x) - (this.get_(\mouse.delta.x) / this.get_(\all.width) / this.get_(\scale.factor)),
          this.get_(\target.y) - (this.get_(\mouse.delta.y) / this.get_(\all.height) / this.get_(\scale.factor))
        )

        this.unset(\mouse.down)
        this.unset(\mouse.now)
    )

    # request our lookup as well.
    this.attribute('lookup').resolveWith(this.get_(\options.app))
    this.get('lookup').react(->)

  # pans to focus on an (x, y) point in real-screen-space relative to the current frame.
  focusScreenXY: (x, y, scale-factor = this.get_(\scale.factor)) ->
    this.focusTarget(
      this.get_(\target.x) + (x - (this.get_(\frame.width) / 2)) / this.get_(\all.width) / scale-factor,
      this.get_(\target.y) + (y - (this.get_(\frame.height) / 2)) / this.get_(\all.height) / scale-factor
    )

  # pans to focus on a specific (x, y) [0, 1]-space point. clamps as necessary.
  focusTarget: (x, y) ->
    margin-x = this.get_(\margin.x)
    this.set(\target.x, clamp(margin-x, 1 - margin-x, x))
    margin-y = this.get_(\margin.y)
    this.set(\target.y, clamp(margin-y, 1 - margin-y, y))

  # zooms in by one level.
  zoom: ->
    switch this.get_(\scale.mode)
    | \all => this.set(\scale.mode, \fit)
    | \fit => this.set(\scale.mode, \zoom)


panel-template = template(
  find('.panel-wrapper').css(\height, from.vm(\frame.height))
  find('.panel-inner-wrapper').css(\transform, from.vm(\scale.factor).and.vm(\translate.x).and.vm(\translate.y).all.map((factor, x, y) ->
    "translateX(#{x}px) translateY(#{y}px) scale(#factor)"))
  find('.panel-inner-wrapper').css(\width, from.vm(\all.width).map(px))
  find('.panel-inner-wrapper').classed(\dragging, from.vm(\mouse.clicking))
  find('.panel-expand').attr(\href, from(\lookup).map(-> "/?exhibit##it"))
  find('.panel-zoom').render(from.vm().attribute(\scale.mode)).criteria( style: \list )
)

class PanelView extends DomView
  (subject, fragment, options) ->
    this._fragment = fragment
    super(subject, options)

  @viewModelClass = PanelVM

  _render: ->
    this._bindings = panel-template(this._fragment)(this._fragment, this.pointer())
    this._fragment

  _wireEvents: ->
    dom = this.artifact()
    app = this.options.app
    vm = this.vm
    outer-wrapper = dom.find('.panel-wrapper')
    wrapper = dom.find('.panel-inner-wrapper')
    $document = $(document)

    # respond to mouse events.
    outer-wrapper.on(\dblclick, (event) ->
      event.preventDefault()
      scale-factor = vm.get_(\scale.factor)
      vm.zoom()
      vm.focusScreenXY(event.pageX, event.pageY - outer-wrapper.offset().top, scale-factor)
      false
    )

    mouse-pos = from-event($document, \mousemove, false, (event) -> { x: event.screenX, y: event.screenY })
    wrapper.on(\mousedown, (event) ->
      return if event.button is 2 # ignore right clicks.

      event.preventDefault() # stop default drag operations.

      vm.set(\mouse.clicking, true)
      vm.set(\mouse.down, { x: event.screenX, y: event.screenY })
      vm.set(\mouse.now, { x: event.screenX, y: event.screenY })
      tracker = mouse-pos.react(false, vm.set(\mouse.now))

      $document.one(\mouseup, ->
        tracker.stop()
        vm.set(\mouse.clicking, false)
      )
    )

    wrapper.on('mouseenter mouseup', '[id]:not(.active)', (event) ->
      initiator = $(this)
      if (info = vm.get_(\lookup)[initiator.attr(\id)])?
        term = new Term({ term: info.title, definition: info.description }) # for now at least reuse glossary.
        term-view = app.view(term)
        attach-floating-box(initiator, term-view)
    )

    # respond to touch events:
    # TODO: someday support pinch zoom.
    event-to-coords = (event) -> { x: get-touch-x(event), y: get-touch-y(event) }
    touch-pos = from-event($document, \touchmove, event-to-coords)
    wrapper.on(\touchstart, (event) ->
      event.preventDefault() # stop default scroll operations.

      coords = event-to-coords(event)
      vm.set(\mouse.clicking, true)
      vm.set(\mouse.now, coords)

      # some setup is for the first finger only; bail otherwise.
      return if event.touches.length > 1

      vm.set(\mouse.down, coords)
      tracker = touch-pos.react(false, vm.set(\mouse.now))

      $document.on('touchend.panel', (event) ->
        return if event.touches.length > 0

        $document.off('touchend.panel')
        vm.set(\mouse.clicking, false)
        tracker.stop()
      )
    )

    # grab the total layout size and store it, as it is soon lost.
    layout = dom.find('.panel-inner-wrapper img')

    # try until we succeed. after we succeed, enable zoom transitions.
    measure = ->
      all = { width: layout.width(), height: layout.height() }
      if all.height > 0
        vm.set({ all })
        <- defer
        wrapper.addClass(\initialized)
      else
        set-timeout(measure, 15)
    measure()


module.exports = { PanelView }

