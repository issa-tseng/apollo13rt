{ read-file-sync } = require(\fs)

load-json = read-file-sync >> JSON.parse

attach-term = (target, id, term) ->
  if target[id]?
    target[id].push(term) unless term in target[id]
  else
    target[id] = [ term ]

find-exact = (lookup, parsed) ->
  for term in lookup when parsed.toLowerCase() is term.toLowerCase()
    return term
  return parsed

annotate-script = (glossary, script) -->
  result = {}
  for line in script
    for term, def of glossary
      lookup = [ term ] ++ (def.synonyms ? [])
      regex = new RegExp("(?:^|[^a-z])(#{lookup.join(\|)})(?:$|[^a-z])", \i)
      if (parse = regex.exec(line.source))?
        attach-term(result, line.id, find-exact(lookup, parse.1))
      if (parse = regex.exec(line.message))?
        attach-term(result, line.id, find-exact(lookup, parse.1))
  result

glossary = load-json(process.argv.3)
process.argv.2 |> load-json |> annotate-script(glossary) |> JSON.stringify |> process.stdout.write

