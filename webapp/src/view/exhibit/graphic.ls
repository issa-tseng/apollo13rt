{ Model, DomView, template, find, from } = require(\janus)
marked = require(\marked)

$ = require(\jquery)

class GraphicView extends DomView
  @_dom = -> $('
    <div class="graphic">
      <img/>
      <div class="graphic-caption">
        <strong>Figure <span class="graphic-caption-number"/></strong>: 
        <span class="graphic-caption-text"/>
      </div>
    </div>
  ')
  @_template = template(
    find('.graphic').classed(\down, from(\down))

    find('img').attr(\src, from(\src))
    find('img').css(\width, from(\width))
    find('img').css(\height, from(\height))

    find('.graphic-caption').classed(\hide, from(\caption).map(-> !it?))
    find('.graphic-caption-text').html(from(\caption).map(marked))
    find('.graphic-caption-number').text(from(\caption_number))
  )

module.exports = { GraphicView }

