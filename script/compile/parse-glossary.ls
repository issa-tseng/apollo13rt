{ read-file-sync } = require(\fs)

parse-glossary = (path) ->
  result = {}

  # we read line-by-line as a state machine so that we can track source line numbers.
  incr = 0
  current-category = null
  current-definition = null
  current-line = \term
  for line, nr in read-file-sync(path, \utf8).split('\n')
    if line.length is 0
      continue
    else if (parse = /^\[([a-z0-9_])+\]$/.exec(line))?
      # set the current category. that's all.
      current-category = parse.1
    else if current-line is \term
      if (parse = /^([^(]+) \(([^)]+)\)$/g.exec(line))?
        [ _, term, subclause ] = parse
        synonyms = subclause.split(\,).map (.trim())
        current-definition = { term, synonyms }
      else
        current-definition = { term: line }
      result[current-definition.term] = current-definition
      current-line = \definition
    else if current-line is \definition
      current-definition.definition = line
      current-definition.line = nr + 1
      current-line = \term
    else
      console.error("Not sure what to do with line #{nr + 1}.")

  result

process.argv.2 |> parse-glossary |> JSON.stringify |> process.stdout.write

