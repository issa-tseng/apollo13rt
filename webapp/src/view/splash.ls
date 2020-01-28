$ = require(\jquery)

{ DomView, template, find, from } = require(\janus)
{ Splash } = require('../model')

{ nonextant, is-blank, pad, if-extant, wait } = require('../util')



class SplashView extends DomView.build(
  $('<div class="splash"/>').append($('#markup > #introduction').clone()),
  template(
    find('#resume-saved').classed(\hide, from(\progress.epoch).map(is-blank))
    find('#resume-saved .hh').text(from(\progress.parts.hh))
    find('#resume-saved .mm').text(from(\progress.parts.mm).map(if-extant pad))
    find('#resume-saved .ss').text(from(\progress.parts.ss).map(if-extant pad))

    find('#start-url').classed(\hide, from(\hash.parts.hh).map(is-blank))
    find('#start-url .hh').text(from(\hash.parts.hh))
    find('#start-url .mm').text(from(\hash.parts.mm).map(if-extant pad))
    find('#start-url .ss').text(from(\hash.parts.ss).map(if-extant pad))

    find('.start-options').classed(\loading, from.app(\global).get(\loaded).map (not))
  )
)

  _wireEvents: ->
    dom = this.artifact()
    global = this.options.app.get_(\global)
    splash = this.subject
    this.destroyWith(splash)

    start-at = (at) -> (player) ->
      return unless player?
      this.stop()
      player.epoch(at)
      player.play()

    dom.find('#start-beginning').on(\click, ->
      player.play()
    )
    dom.find('#resume-saved').on(\click, ->
      global.get(\player).react(start-at(splash.get_(\progress.adjusted)))
    )
    dom.find('#start-url').on(\click, ->
      global.get(\player).react(start-at(splash.get_(\hash.epoch)))
    )

    global.get(\player).flatMap((?.get(\audio.playing))).react((is-playing) ->
      if is-playing is true
        splash.destroy()
        this.stop()
    )

  _destroy: ->
    $('body').removeClass(\init)
    this.artifact().addClass(\destroying)
    <~ wait(500) # for the animation.
    DomView.prototype.destroy.call(this)



module.exports = {
  SplashView
  registerWith: (library) -> library.register(Splash, SplashView)
}

