{ read-file-sync } = require(\fs)

hms = (hh, mm, ss) -> parse-int(hh) * 60 * 60 + parse-int(mm) * 60 + parse-int(ss)

attach-line-annotation = (line, annotation) -> line.[]annotations.push(annotation)
attach-token-annotation = (line, idx, annotation) -> line.{}tokens[idx] = annotation

parse-file = (path) ->
  result = []

  # we read line-by-line as a state machine so that we can track source line numbers.
  incr = 0
  by-id = {}
  by-last-source = {}
  current-source = null
  last-start = 0
  for line, nr in read-file-sync(path, \utf8).split('\n')
    if (parse = /^\[(\d\d) (\d\d) (\d\d) - (\d\d) (\d\d) (\d\d)\] (.+)$/.exec(line))?
      # a full line. create.
      [ _, start-hh, start-mm, start-ss, end-hh, end-mm, end-ss, source ] = parse
      start = hms(start-hh, start-mm, start-ss)
      end = hms(end-hh, end-mm, end-ss)
      id = incr++

      throw new Error("Message goes back in time (#{nr + 1} -> #line)") if start > end
      throw new Error("Message predates predecessor (#{nr + 1} -> #line)") if start < last-start
      last-start := start

      current-source = source
      line = by-last-source[current-source] = by-id[id] = { id, start, end, source, line: nr + 1 }
      result.push(line)

    else if (parse = /^\[(\d\d) (\d\d) (\d\d)\] (.+)$/.exec(line))?
      # a full burst line. create.
      [ _, hh, mm, ss, source ] = parse
      start = hms(hh, mm, ss)
      end = start
      id = incr++

      throw new Error("Message predates predecessor (#{nr + 1} -> #line)") if start < last-start
      last-start := start

      current-source = source
      line = by-last-source[current-source] = by-id[id] = { id, start, end, source, line: nr + 1 }
      result.push(line)

    else if (parse = /^\[(\d\d) (\d\d) (\d\d) -\] (.+)$/.exec(line))?
      # a starting partial fragment. create.
      [ _, start-hh, start-mm, start-ss, source ] = parse
      start = hms(start-hh, start-mm, start-ss)
      id = incr++

      throw new Error("Message predates predecessor (#{nr + 1} -> #line)") if start < last-start
      last-start := start

      current-source = source
      line = by-last-source[current-source] = by-id[id] = { id, start, source, line: nr + 1 }
      result.push(line)

    else if (parse = /^\[ - \] (.+)$/.exec(line))?
      # a middle partial fragment. track and create.
      [ _, source ] = parse
      id = by-last-source[source].id

      current-source = source
      line = by-last-source[current-source] = { id, source, line: nr + 1 }
      result.push(line)

    else if (parse = /^\[- (\d\d) (\d\d) (\d\d)\] (.+)$/.exec(line))?
      # an ending partial fragment. track and create, and fill in an endstamp on the originating line.
      [ _, end-hh, end-mm, end-ss, source ] = parse
      id = by-last-source[source].id
      by-id[id].end = hms(end-hh, end-mm, end-ss)

      throw new Error("Message goes back in time (#{nr + 1} -> #line) (start: #{by-id[id].start}; end: #{by-id[id].end})") if by-id[id].start > by-id[id].end

      current-source = source
      line = by-last-source[current-source] = by-id[id] = { id, source, line: nr + 1 }
      result.push(line)

    else if (parse = /^> (.+)$/.exec(line))?
      # a full-line annotation. attach.
      [ _, message ] = parse
      attach-line-annotation(by-last-source[current-source], message)

    else if (parse = /^(\d+)> (.+)$/.exec(line))?
      # a token annotation. attach.
      [ _, idx, message ] = parse
      attach-token-annotation(by-last-source[current-source], parse-int(idx), message)

    else if line.length > 0
      # a message line. attach.
      throw new Error("Trying to attach a message where one already exists (#{nr + 1} -> #line) (extant: #{by-last-source[current-source].message})") if by-last-source[current-source].message?
      by-last-source[current-source].message = line

  result

module.exports = { parse-file }

