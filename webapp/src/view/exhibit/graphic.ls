{ Model, DomView, template, find, from } = require(\janus)
marked = require(\marked)

$ = require(\jquery)

safe-marked = (x) -> marked(x) if x?

class GraphicView extends DomView
  @_dom = -> $('
    <div class="graphic">
      <a class="graphic-expand" target="_blank"/>
      <img/>
      <div class="graphic-caption">
        <strong>Figure <span class="graphic-caption-number"/></strong>: 
        <span class="graphic-caption-text"/>
      </div>
    </div>
  ')
  @_template = template(
    find('.graphic').classed(\down, from(\down))

    find('.graphic-expand').attr(\href, from(\expandable).and(\src).all.map((expands, src) -> src if expands))
    find('.graphic-expand').classed(\hide, from(\expandable).map (not))
    find('.graphic-expand').css(\width, from(\width))
    find('.graphic-expand').css(\height, from(\height))

    find('img').attr(\src, from(\src))
    find('img').css(\width, from(\width))
    find('img').css(\height, from(\height))

    find('.graphic-caption').classed(\hide, from(\caption).map(-> !it?))
    find('.graphic-caption-text').html(from(\caption).map(safe-marked))
    find('.graphic-caption-number').text(from(\caption_number))
  )

module.exports = { GraphicView }

