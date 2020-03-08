$ = require(\jquery)
copy = require(\clipboard-copy)

{ DomView, template, find, from, Varying } = require(\janus)
{ debounce, sticky, zip-sequential } = require(\janus-stdlib).varying

{ Line, Transcript } = require('../model')
{ pct, pad, get-time, max-int, bump, click-touch } = require('../util')


class TranscriptView extends DomView.build($('
    <div class="script">
      <div class="script-scroll-indicator-container">
        <a class="script-scroll-indicator" href="#" title="Sync with audio"/>
      </div>
      <div class="script-lines"/>
      <p><span class="leader">Transcript:</span><span class="name"/></p>
    </div>
  '), template(
      find('p .name').text(from(\name))
      find('.script-lines').html(from(\markup).map((id) -> $("#id")[0].innerHTML))
      find('.script-scroll-indicator').classed(\active, from(\auto_scroll).map (not))
))
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
    scroll-top-line = -> id |> get-offset |> (- 50) |> scroll-to if (id = transcript.get_(\top_line)?._id)?

    debounce(50, transcript.get(\top_line)).react(false, (line) ->
      id = line?._id
      return unless id?
      offset = get-offset(id)

      # scroll to the top line if relevant.
      scroll-to(offset - 50) if transcript.get_(\auto_scroll) is true

      # position the scroll indicator always.
      indicator.css(\top, offset / line-container.get(0).scrollHeight |> pct)
    )

    # watch for autoscroll rising edge and trip scroll.
    transcript.get(\auto_scroll).react(false, (auto) -> scroll-top-line() if auto)

    # track whether the browser is getting resized or is blurred, and suppress autoscroll disengagement.
    # TODO: this seems like a common pattern. perhaps the stdlib utils should have some automatic
    # inner-varying management system.
    is-resizing = new Varying(false)
    is-blurred = new Varying(false)
    $(window).on(\resize, ->
      bump(is-resizing)
      scroll-top-line()
    ).on(\blur, -> is-blurred.set(true)).on(\focus, -> is-blurred.set(false))
    suppress-disengagement = sticky( true: 100 )(Varying.mapAll(is-resizing, is-blurred, (or)))
    suppress-disengagement.react(->) # TODO: need to subscribe to this to make it work.

    # turn off auto-scrolling as intelligently as we can.
    line-container.on(\scroll, ->
      # buffer by 200 ms on relinquished, as complete often fires early.
      if (get-time() > (relinquished + 200)) and not suppress-disengagement.get()
        transcript.set(\auto_scroll, false)
    )
    line-container.on(\wheel, ->
      line-container.finish()
      transcript.set(\auto_scroll, false)
      null # return value is significant.
    )

    # do these via delegate here once rather for each line for perf.
    dom.on(\mouseenter, '.line-edit', ->
      return if this.hostname isnt window.location.hostname
      this.href = transcript.get_(\edit_url) + this.hash
    )
    dom.on(\click, '.line-link', (event) ->
      if copy($(event.target).closest('.line').find('.line-timestamp').get(0)?.href) is true
        $('#tooltip').text('Copied!')
      else
        $('#tooltip').text('Right-click to copy address.')
    )

    # return to autoscroll when sync icon is clicked.
    click-touch(indicator, (event) ->
      event.preventDefault()
      transcript.set(\auto_scroll, true)
    )

    # if we are the next transcript after a gap, mark the line.
    transcript.get(\player).flatMap((player) ->
      return null unless player?
      Varying.mapAll(player.get(\post_gap_script), transcript.get(\cued_idx), (script, idx) ->
        if script is transcript then transcript.get_(\lines).at_(idx)._id else null
      )
    ).react((gap-id) ->
      dom.find('.post-gap').removeClass(\post-gap)
      dom.find(".line-#gap-id").addClass(\post-gap) if gap-id?
    )

    transcript.get(\active-ids).pipe(zip-sequential(false)).react(([ last-ids = [], ids ]) ->
      for id of last-ids when !ids[id]?
        dom.find(".line-#id").removeClass(\active)
      for id of ids when !last-ids[id]?
        dom.find(".line-#id").addClass(\active)
      return
    )


module.exports = {
  TranscriptView
  registerWith: (library) ->
    library.register(Transcript, TranscriptView)
}

