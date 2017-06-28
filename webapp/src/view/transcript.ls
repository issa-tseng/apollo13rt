$ = require(\jquery)

{ DomView, template, find, from } = require(\janus)
{ debounce } = require(\janus-stdlib).util.varying

{ Line, Transcript } = require('../model')
{ pct, pad, get-time, max-int } = require('../util')


class LineView extends DomView
  @_fragment = $('
    <div class="line">
      <a class="line-timestamp" href="#">
        <span class="hh"/>
        <span class="mm"/>
        <span class="ss"/>
      </a>
      <div class="line-heading">
        <span class="line-source"/>
        <a class="line-edit" target="_blank" title="Suggest an edit"/>
        <a class="line-link" title="Share link to this line"/>
      </div>
      <div class="line-contents"/>
      <div class="line-annotations">
        <div class="line-token-annotations"/>
        <div class="line-whole-annotations"/>
      </div>
    </div>
  ')
  @_dom = -> @_fragment.clone()
  @_template = template(
    find('.line').classGroup(\line-, from(\id))
    find('.line').classed(\active, from(\active))

    find('.line-timestamp').classed(\hide, from(\start.epoch).map((x) -> !x?))
    find('.hh').text(from(\start.hh))
    find('.mm').text(from(\start.mm).map(pad))
    find('.ss').text(from(\start.ss).map(pad))

    find('.line-edit').attr(\href, from(\line).map((line) -> "\#L#line"))

    find('.line-source').text(from(\source))
    find('.line-contents').html(from(\message))

    find('.line-token-annotations').render(from(\tokens))
    find('.line-whole-annotations').render(from(\annotations))
  )

class TranscriptView extends DomView
  @_dom = -> $('
    <div class="script">
      <div class="script-scroll-indicator-container">
        <a class="script-scroll-indicator" href="#" title="Sync with audio"/>
      </div>
      <div class="script-lines"/>
      <p><span class="leader">Transcript:</span><span class="name"/></p>
    </div>
  ')
  @_template = template(
      find('p .name').text(from(\name))
      find('.script-lines').render(from(\lines))
      find('.script-scroll-indicator').classed(\active, from(\auto_scroll).map (not))
  )
  _wireEvents: ->
    dom = this.artifact()
    transcript = this.subject
    line-container = dom.find('.script-lines')
    indicator = dom.find('.script-scroll-indicator')

    # automatically scrolls to a given line.
    relinquished = max-int
    get-offset = (id) -> dom.find(".line-#id").get(0).offsetTop
    scroll-to = (scroll-top) ->
      relinquished := max-int
      line-container.stop(true).animate({ scroll-top }, { complete: (-> relinquished := get-time()) })

    debounce(transcript.watch(\top_line), 50).react((line) ->
      id = line?._id
      return unless id?
      offset = get-offset(id)

      # scroll to the top line if relevant.
      scroll-to(offset - 50) if transcript.get(\auto_scroll) is true

      # position the scroll indicator always.
      indicator.css(\top, offset / line-container.get(0).scrollHeight |> pct)
    )

    # watch for autoscroll rising edge and trip scroll.
    transcript.watch(\auto_scroll).react((auto) ->
      id |> get-offset |> (- 50) |> scroll-to if auto and (id = transcript.get(\top_line)?._id)?
    )

    # turn off auto-scrolling as intelligently as we can.
    line-container.on(\scroll, ->
      transcript.set(\auto_scroll, false) if get-time() > (relinquished + 200) # complete fires early
    )
    line-container.on(\wheel, ->
      line-container.finish()
      transcript.set(\auto_scroll, false)
      null # return value is significant.
    )

    # do these via delegate here once rather for each line for perf.
    dom.on(\click, '.line-timestamp', (event) ->
      event.preventDefault()
      line = $(event.target).closest('.line').data(\view).subject
      transcript.get(\player).epoch(line.get(\start.epoch))
      transcript.set(\auto_scroll, true)
    )
    dom.on(\mouseenter, '.line-edit', ->
      return if this.hostname isnt window.location.hostname
      this.href = transcript.get(\edit_url) + this.hash
    )

    indicator.on(\click, -> transcript.set(\auto_scroll, true))


module.exports = {
  LineView, TranscriptView
  registerWith: (library) ->
    library.register(Line, LineView)
    library.register(Transcript, TranscriptView)
}

