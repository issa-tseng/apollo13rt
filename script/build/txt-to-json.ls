{ parse-file } = require('./parse-txt')

process.argv.2 |> parse-file |> JSON.stringify |> process.stdout.write

