{ read-file-sync } = require(\fs)
{ inline-lexer } = require(\marked)
{ epoch-to-hms, pad } = require('../src/util')

md = (text) -> inline-lexer(text, [])
render-if = (bool, content) --> if bool is true then content else ''
render-line = (line) ->
  line.start = { [ k, pad(v) ] for k, v of epoch-to-hms(line.start) } if line.start?
  line.message = line.message.replace(/\{([^}]+)\}/g, (_, text) -> "<span class=\"token-annotation\">#text</span>")

  token-annotations = "<ul>#{[ "<li><span>#{text |> md}</span></li>" for text in line.tokens ].join('')}</ul>" if line.tokens?
  whole-annotations = "<ul>#{[ "<li><span>#{text |> md}</span></li>" for text in line.annotations ].join('')}</ul>" if line.annotations?

  return "
    <li>
      <div class=\"line line-#{line.id}\">
        #{"<a class=\"line-timestamp\" href=\"##{line.start?.hh}:#{line.start?.mm}:#{line.start?.ss}\">
            <span class=\"hh\">#{line.start?.hh}</span>
            <span class=\"mm\">#{line.start?.mm}</span>
            <span class=\"ss\">#{line.start?.ss}</span>
          </a>" |> render-if line.start?}
        <div class=\"line-heading\">
          <span class=\"line-source\">#{line.source}</span>
          <a class=\"line-edit\" href=\"\#L#{line.line}\" target=\"_blank\" title=\"Suggest an edit\"></a>
          #{"<a class=\"line-link\" title=\"Share link to this line\"></a>" |> render-if(line.start?)}
        </div>
        <div class=\"line-contents\">#{line.message}</div>
        #{"<div class=\"line-annotations\">
          #{"<div class=\"line-token-annotations\">#token-annotations</div>" |> render-if token-annotations?}
          #{"<div class=\"line-whole-annotations\">#whole-annotations</div>" |> render-if whole-annotations?}
        </div>" |> render-if(token-annotations? or whole-annotations?)}
      </div>
    </li>"

lines = read-file-sync(process.argv.2, \utf8) |> JSON.parse
content = lines.map(render-line).join('\n')
sanitized-name = /\/([^\/]+)\.json/.exec(process.argv.2).1
"<div id=\"script-#sanitized-name\">#content</div>" |> process.stdout.write

