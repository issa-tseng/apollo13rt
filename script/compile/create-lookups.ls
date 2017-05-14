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
      regex = new RegExp("(?:^|[^a-z])(#{lookup.join(\|)})(?:$|[^a-z])", \gi)
      if (parse = regex.exec(line.source))?
        attach-term(result, line.id, find-exact(lookup, parse.1))

      while (parse = regex.exec(line.message))?
        exact = find-exact(lookup, parse.1)
        # discard if the source term is all-caps and the target is not.
        continue if !/[a-z]/.test(exact) and exact isnt parse.1
        attach-term(result, line.id, exact)
  result

# t- = target; s- = source.
annotate-glossary = (glossary) ->
  result = {}
  for t-term, t-def of glossary
    for s-term, s-def of glossary
      continue if t-term is s-term

      lookup = [ s-term ] ++ (s-def.synonyms ? [])
      regex = new RegExp("(?:^|[^a-z])(#{lookup.join(\|)})(?:$|[^a-z])", \gi)

      while (parse = regex.exec(t-def.definition))?
        exact = find-exact(lookup, parse.1)
        # discard if the source term is all-caps and the target is not.
        continue if !/[a-z]/.test(exact) and exact isnt parse.1
        attach-term(result, t-term, find-exact(lookup, exact))
  result

glossary = load-json(process.argv.3)
annotator = if /glossary/i.test(process.argv.2) then annotate-glossary else annotate-script(glossary)
process.argv.2 |> load-json |> annotator |> JSON.stringify |> process.stdout.write

