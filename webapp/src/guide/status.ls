$ = require(\jquery)
{ Model, DomView, template, find, from } = require(\janus)

class Status extends Model

class StatusView extends DomView.build(
  Model.build(
  )
  $('<div class="guide-box status"><div class="ship"/></div>')
  template(
  )
)


module.exports = {
  Status, StatusView
  registerWith: (library) ->
    library.register(Status, StatusView)
}

