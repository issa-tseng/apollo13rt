$ = require(\jquery)

{ DomView, template, find, from } = require(\janus)
{ Splash } = require('../model')

{ nonextant, is-blank, pad, if-extant, wait } = require('../util')



class SplashView extends DomView
  @_dom = -> $('<div class="splash"/>').append($('#markup > #introduction').clone())
  @_template = template(
    find('#resume-saved').classed(\hide, from(\progress.epoch).map(is-blank))
    find('#resume-saved .hh').text(from(\progress.parts.hh))
    find('#resume-saved .mm').text(from(\progress.parts.mm).map(if-extant pad))
    find('#resume-saved .ss').text(from(\progress.parts.ss).map(if-extant pad))

    find('#start-url').classed(\hide, from(\hash.parts.hh).map(is-blank))
    find('#start-url .hh').text(from(\hash.parts.hh))
    find('#start-url .mm').text(from(\hash.parts.mm).map(if-extant pad))
    find('#start-url .ss').text(from(\hash.parts.ss).map(if-extant pad))

    find('.start-options').classed(\loading, from.app(\global).watch(\loaded).map (not))
  )

  _wireEvents: ->
    dom = this.artifact()
    global = this.options.app.get(\global)
    splash = this.subject

    start-at = (at) -> (player) ->
      return unless player?
      this.stop()
      player.epoch(at)
      player.play()
      splash.destroy()

    dom.find('#start-beginning').on(\click, ->
      player.play()
      splash.destroy()
    )
    dom.find('#resume-saved').on(\click, ->
      global.watch(\player).react(start-at(splash.get(\progress.adjusted)))
    )
    dom.find('#start-url').on(\click, ->
      console.log(splash.get(\hash))
      global.watch(\player).react(start-at(splash.get(\hash.epoch)))
    )

    dom.on(\focus, 'a', (event) ->
      $(event.target).attr(\target, \_blank) if event.target.host isnt window.location.host
    )

  destroy: ->
    $('body').removeClass(\init)
    this.artifact().addClass(\destroying)
    <~ wait(500)
    DomView.prototype.destroy.call(this)



module.exports = {
  SplashView
  registerWith: (library) -> library.register(Splash, SplashView)
}

