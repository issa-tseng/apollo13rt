$ = require(\jquery)
copy = require(\clipboard-copy)

{ DomView, template, find, from, Varying } = require(\janus)
{ debounce, sticky } = require(\janus-stdlib).util.varying

{ Line, Transcript } = require('../model')
{ pct, pad, get-time, max-int, bump } = require('../util')


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
      find('.script-lines').html(from(\markup).map((id) -> $("#id")[0].innerHTML))
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

    debounce(50, transcript.watch(\top_line)).reactLater((line) ->
      id = line?._id
      return unless id?
      offset = get-offset(id)

      # scroll to the top line if relevant.
      scroll-to(offset - 50) if transcript.get(\auto_scroll) is true

      # position the scroll indicator always.
      indicator.css(\top, offset / line-container.get(0).scrollHeight |> pct)
    )

    # watch for autoscroll rising edge and trip scroll.
    transcript.watch(\auto_scroll).reactLater((auto) -> scroll-top-line() if auto)

    # track whether the browser is getting resized or is blurred, and suppress autoscroll disengagement.
    # TODO: this seems like a common pattern. perhaps the stdlib utils should have some automatic
    # inner-varying management system.
    is-resizing = new Varying(false)
    is-blurred = new Varying(false)
    $(window).on(\resize, ->
      bump(is-resizing)
      scroll-top-line()
    ).on(\blur, -> is-blurred.set(true)).on(\focus, -> is-blurred.set(false))
    suppress-disengagement = sticky( true: 100 )(Varying.pure(is-resizing, is-blurred, (or)))
    suppress-disengagement.react(->) # TODO: reed to subscribe to this to make it work.

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
      this.href = transcript.get(\edit_url) + this.hash
    )
    dom.on(\click, '.line-link', (event) ->
      line = $(event.target).closest('.line').data(\view).subject
      if copy(window.location.href.replace(/(?:#.*)?$/, \# + line.startHms_())) is true
        $('#tooltip').text('Copied!')
    )
    dom.on(\focus, 'a', (event) ->
      $(event.target).attr(\target, \_blank) if event.target.host isnt window.location.host
    )

    # return to autoscroll when sync icon is clicked.
    indicator.on(\click, (event) ->
      event.preventDefault()
      transcript.set(\auto_scroll, true)
    )

    # if we are the next transcript after a gap, mark the line.
    is-active = Varying.pure(player.watch(\timestamp.epoch), transcript.watch(\top_line), (epoch, line) ->
      epoch <= line._end
    )
    transcript.watch(\player).react((player) ->
      return unless player?
      Varying.pure(player.watch(\post_gap_script), transcript.watch(\cued_idx), is-active, (script, idx, active) ->
        if !active and script is transcript
          transcript.get(\lines).at(idx)._id
        else
          null
      ).react((gap-id) ->
        dom.find('.post-gap').removeClass(\post-gap)
        dom.find(".line-#gap-id").addClass(\post-gap) if gap-id?
      )
    )

    # when our target_idx changes, push active state down into lines.
    # but we can't do that until we have a player:
    transcript.watch(\player).react((player) ->
      return unless player?

      # now watch idx, but also update on epoch-change:
      was-active = {}
      active-ids = {}
      last-idx = -1
      from(transcript.watch(\target_idx)).and(player.watch(\timestamp.epoch)).all.plain().react(([ idx, epoch ]) ->
        return unless idx? and epoch?
        return if idx is last-idx

        # first clear out active primary lines that are no longer.
        for wa-idx, line of was-active when line._start? and not line.contains_(epoch)
          dom.find(".line-#{line._id}").removeClass(\active)
          delete was-active[wa-idx]
          delete active-ids[line._id]

        # now clear out active secondary lines that are no longer.
        for wa-idx, line of was-active when not active-ids[line._id]
          dom.find(".line-#{line._id}").removeClass(\active)
          delete was-active[wa-idx]

        # now add lines that should be active. go until we have four inactive in a row.
        lines = transcript.get(\lines).list
        misses = 0
        while misses < 4 and idx < lines.length
          line = lines[idx]
          if line.contains_(epoch) or active-ids[line._id] is true
            unless was-active[idx]?
              dom.find(".line-#{line._id}").addClass(\active)
              was-active[idx] = line
              active-ids[line._id] = true
          else
            misses += 1
          idx += 1

        last-idx := idx
      )
    )


module.exports = {
  TranscriptView
  registerWith: (library) ->
    library.register(Transcript, TranscriptView)
}

