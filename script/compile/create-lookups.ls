{ read-file-sync } = require(\fs)

load-json = read-file-sync >> JSON.parse

attach-term = (target, id, term) ->
  if target[id]?
    target[id].push(term) unless term in target[id]
  else
    target[id] = [ term ]

annotate-script = (glossary, script) -->
  result = {}
  for line in script
    for term, def of glossary
      lookup = [ term ] ++ (def.synonyms ? [])
      regex = new RegExp("(^|[^a-z])(#{lookup.join(\|)})($|[^a-z])", \i)
      attach-term(result, line.id, term) if regex.exec(line.source)? or regex.exec(line.message)?
  result

glossary = load-json(process.argv.3)
process.argv.2 |> load-json |> annotate-script(glossary) |> JSON.stringify |> process.stdout.write

