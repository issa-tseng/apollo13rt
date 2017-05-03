{ DomView, template, find, from } = require(\janus)
$ = require(\jquery)

{ Line, Transcript } = require('./model')

class TranscriptView extends DomView
  @_dom = -> $('<div class="transcript"><div class="lines"/></div>')
  @_template = template(
    find('.lines').render(from(\lines))
  )

class LineView extends DomView
  @_dom = -> $('
    <div class="line">
      <div class="line-timestamp">
        <span class="hh"/>
        <span class="mm"/>
        <span class="ss"/>
      </div>
      <div class="line-source"/>
      <div class="line-contents"/>
    </div>
  ')
  @_template = template(
    find('.hh').text(from(\start.hh))
    find('.mm').text(from(\start.mm))
    find('.ss').text(from(\start.ss))

    find('.line-source').text(from(\source))
    find('.line-contents').text(from(\message))
  )

module.exports = {
  TranscriptView
  LineView
  registerWith: (library) ->
    library.register(Transcript, TranscriptView)
    library.register(Line, LineView)
}

