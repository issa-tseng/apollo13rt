wrap = require(\wordwrap)(80)
{ read-file-sync } = require(\fs)

pad = (length, str) --> [ ' ' for to length - str.length ].join('') + str

parse-file = (path) ->
  result = []
  line-header = null

  for line, nr in read-file-sync(path, \utf8).split('\n')
    if (parse = /^\[(\d\d) (\d\d) (\d\d)[^\]]*\] (.+)$/.exec(line))?
      [ _, hh, mm, ss, source ] = parse
      line-header = "#hh:#mm:#ss #{pad(17, source)}  "

    else if (parse = /^\[[^\]]*\] (.+)$/.exec(line))?
      line-header = "         #{pad(17, parse.1)}  "

    else if line.length is 0 or /^\d?> /.exec(line)?
      continue

    else
      [ first, ...rest ] = wrap(line.replace(/[{}]/g, '')).split('\n')
      result.push(line-header + first)
      if rest?
        for wrapped-line in rest
          result.push("                             " + wrapped-line)

  result.join('\n')

process.argv.2 |> parse-file |> process.stdout.write

