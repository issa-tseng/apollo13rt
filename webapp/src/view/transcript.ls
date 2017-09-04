$ = require(\jquery)
copy = require(\clipboard-copy)

{ DomView, template, find, from, Varying } = require(\janus)
{ debounce, sticky } = require(\janus-stdlib).util.varying

{ Line, Transcript } = require('../model')
{ pct, pad, get-time, max-int, bump } = require('../util')


class LineView extends DomView
  # custom render methodology for better perf; render immutable text once only.
  _render: ->
    line = this.subject
    fragment = $("
      <div>
        <div class=\"line line-#{line._id}\">
          #{("<a class=\"line-timestamp\" href=\"##{line.startHms_()}\">
              <span class=\"hh\">#{line.get(\start.hh)}</span>
              <span class=\"mm\">#{line.get(\start.mm) |> pad}</span>
              <span class=\"ss\">#{line.get(\start.ss) |> pad}</span>
            </a>" if line._start?) ? ''}
          <div class=\"line-heading\">
            <span class=\"line-source\">#{line.get(\source)}</span>
            <a class=\"line-edit\" href=\"\#L#{line.get(\line)}\" target=\"_blank\" title=\"Suggest an edit\"/>
            #{("<a class=\"line-link\" title=\"Share link to this line\"/>" if line._start?) ? ''}
          </div>
          <div class=\"line-contents\">#{line.get(\message)}</div>
          <div class=\"line-annotations\">
            <div class=\"line-token-annotations\"/>
            <div class=\"line-whole-annotations\"/>
          </div>
        </div>
      </div>
    ")

    # now kick off bindings as usual.
    this._bindings = LineView._template(fragment)((x) ~> LineView.point(x, this))
    fragment.children()

  # these commented templating lines are now integrated directly above.
  @_template = template(
    #find('.line').classGroup(\line-, from(\id))
    find('.line').classed(\active, from(\active))

    #find('.line-timestamp').classed(\hide, from(\start.epoch).map((x) -> !x?))
    #find('.hh').text(from(\start.hh))
    #find('.mm').text(from(\start.mm).map(pad))
    #find('.ss').text(from(\start.ss).map(pad))

    #find('.line-edit').attr(\href, from(\line).map((line) -> "\#L#line"))

    #find('.line-source').text(from(\source))
    #find('.line-contents').html(from(\message))

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
    scroll-top-line = -> id |> get-offset |> (- 50) |> scroll-to if (id = transcript.get(\top_line)?._id)?

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
    transcript.watch(\auto_scroll).react((auto) -> scroll-top-line() if auto)

    # track whether the browser is getting resized, and suppress autoscroll disengagement.
    # TODO: this seems like a common pattern. perhaps the stdlib utils should have some automatic
    # inner-varying management system.
    is-resizing-inner = new Varying(false)
    is-resizing = sticky(is-resizing-inner, true: 50 )
    $(window).on(\resize, ->
      bump(is-resizing-inner)
      scroll-top-line()
    )

    # turn off auto-scrolling as intelligently as we can.
    line-container.on(\scroll, ->
      transcript.set(\auto_scroll, false) if get-time() > (relinquished + 200) and not is-resizing.get() # complete fires early
    )
    line-container.on(\wheel, ->
      line-container.finish()
      transcript.set(\auto_scroll, false)
      null # return value is significant.
    )

    # do these via delegate here once rather for each line for perf.
    dom.on(\mouseenter, '.line-edit', ->
      return if this.hostname isnt window.location.hostname
      this.href = transcript.get(\edit_url) + this.hash
    )
    dom.on(\click, '.line-link', (event) ->
      line = $(event.target).closest('.line').data(\view).subject
      if copy(window.location.href.replace(/(?:#.*)?$/, \# + line.startHms_())) is true
        $('#tooltip').text('Copied!')
    )

    indicator.on(\click, (event) ->
      event.preventDefault()
      transcript.set(\auto_scroll, true)
    )


module.exports = {
  LineView, TranscriptView
  registerWith: (library) ->
    library.register(Line, LineView)
    library.register(Transcript, TranscriptView)
}

