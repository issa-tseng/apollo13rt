{ from } = require(\janus)

event-idx = from.self().and('epoch').and.subject('events')
  .all.map((self, epoch, events) ->
    return unless epoch?
    return unless events?

    return null if epoch < events[0].epoch

    # quickpath shortcut for continuous playback (likely this or next line)
    if (idx = self.get_(\event-idx))?
      return idx if (idx + 1) is events.length
      idx = 0 unless epoch >= events[idx].epoch
    idx ?= 0 # otherwise fallback to search from start.

    while ((idx + 1) < events.length) and (epoch >= events[idx + 1].epoch)
      idx++
    return idx
  )

module.exports = { event-idx }

