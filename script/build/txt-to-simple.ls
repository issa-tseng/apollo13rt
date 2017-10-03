{ read-file-sync } = require(\fs)

parse-file = (path) ->
  result = []
  hh = 0
  mm = 0
  ss = 0

  for line, nr in read-file-sync(path, \utf8).split('\n')
    if (parse = /^\[(\d\d) (\d\d) (\d\d)[^\]]*\] (.+)$/.exec(line))?
      [ _, line-hh, line-mm, line-ss, source ] = parse

      if line-hh > hh or line-mm > mm
        [ hh, mm, ss ] := [ line-hh, line-mm, line-ss ]
        result.push("#hh:#mm:#ss")

      result.push(source)

    else if (parse = /^\[[^\]]*\] (.+)$/.exec(line))?
      result.push(parse.1)

    else if /^\d?> /.exec(line)?
      continue

    else
      result.push(line.replace(/[{}]/g, ''))

  result.join('\n')

process.argv.2 |> parse-file |> process.stdout.write

