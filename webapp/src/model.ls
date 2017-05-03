{ Model, attribute, from, List } = require(\janus)
{ floor } = Math

class Line extends Model
  @bind(\start.hh, from(\start.epoch).map ((/ 3600) >> floor))
  @bind(\start.mm, from(\start.epoch).map ((% 3600 / 60) >> floor))
  @bind(\start.ss, from(\start.epoch).map (% 60))

  @deserialize = (data) ->
    data.start = { epoch: data.start }
    data.end = { epoch: data.end }
    super(data)

class Lines extends List
  @modelClass = Line

class Transcript extends Model
  @attribute(\lines, class extends attribute.CollectionAttribute
    @collectionClass = Lines
    default: -> new Lines()
  )

class Player extends Model


module.exports = { Line, Lines, Transcript, Player }

