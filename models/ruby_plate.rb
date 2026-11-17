# A flat ruby sealed in clear filament, with an arch on the back for a hair
# tie. It prints face down so that the front is the smooth side against the
# bed. From the bed: a clear layer, black cut lines surrounded by clear, the
# red ruby surrounded by clear, a clear back, and the arch.
model 'ruby_plate' do
  printed_upside_down

  param :width, 30, range: 15..30
  param :margin, 2.8, range: 0.8..4.0, step: 0.1
  param :line_width, 0.8, range: 0.4..1.6, step: 0.1
  param :corner_radius, 1.7, range: 0.0..3.0, step: 0.1
  # The height from the widest line to the point, as a ratio of the ruby's width.
  param :point_height_ratio, 0.51, range: 0.3..1.2, step: 0.01
  param :plate_corner_radius, 2.8, range: 0.0..6.0, step: 0.1
  param :edge_radius, 0.4, range: 0.0..1.0, step: 0.1
  param :top_thickness, 1.0, range: 0.2..2.0, step: 0.2
  param :line_thickness, 0.4, range: 0.2..1.0, step: 0.2
  param :ruby_thickness, 1.2, range: 0.4..3.0, step: 0.2
  param :bottom_thickness, 1.6, range: 0.4..3.0, step: 0.2
  param :elastic_diameter, 3, range: 1.5..4, step: 0.5
  param :arch_thickness, 2.2, range: 1.4..4, step: 0.2
  param :arch_depth, 5, range: 3..8, step: 0.5

  # A gem seen from the side, in proportions of its width w: a flat top, a
  # crown down to the widest line, and a long point. The origin is at the
  # center, and the left half mirrors these points.
  gem = lambda do |w|
    half_height = w * (0.29 + point_height_ratio) / 2
    girdle_y = half_height - w * 0.29
    {
      corner: [w * 0.5, girdle_y], top: [w * 0.32, half_height],
      cut_top: [w * 0.135, half_height], cut_girdle: [w * 0.195, girdle_y],
      point: [0, -half_height],
    }
  end

  # width is the whole plate. Its widest points are the rounded corners of the
  # plate beside the widest line of the ruby. Offsetting a corner moves it
  # along its bisector, so its x grows by a fixed ratio of the distance, found
  # here from the corner's two edges in a gem of width 1. A corner rounded with
  # radius plate_corner_radius reaches as far as the corner offset by
  # margin - plate_corner_radius, plus plate_corner_radius.
  unit_gem = gem.call(1.0)
  unit = ->(v) { length = Math.sqrt(v[0] * v[0] + v[1] * v[1]); [v[0] / length, v[1] / length] }
  toward = ->(from, to) { unit.call([to[0] - from[0], to[1] - from[1]]) }
  up_edge = toward.call(unit_gem[:corner], unit_gem[:top])
  down_edge = toward.call(unit_gem[:corner], unit_gem[:point])
  half_angle_sine = Math.sqrt((1 - (up_edge[0] * down_edge[0] + up_edge[1] * down_edge[1])) / 2)
  inward = unit.call([up_edge[0] + down_edge[0], up_edge[1] + down_edge[1]])
  corner_reach = -inward[0] / half_angle_sine
  points = gem.call(width - 2 * ((margin - plate_corner_radius) * corner_reach + plate_corner_radius))
  corner, top, cut_top, cut_girdle, point = points.values_at(:corner, :top, :cut_top, :cut_girdle, :point)
  mirror = ->(xy) { [-xy[0], xy[1]] }

  outline = [point, corner, top, mirror.call(top), mirror.call(corner)]
  cuts = [
    [mirror.call(corner), corner],
    [cut_top, cut_girdle], [mirror.call(cut_top), mirror.call(cut_girdle)],
    [cut_girdle, point], [mirror.call(cut_girdle), point],
  ]

  # A cut is a strip of line_width around the segment between two points.
  # Round dots at the points join cuts that meet there without gaps or
  # corners sticking out.
  strip = lambda do |from, to|
    dx = to[0] - from[0]
    dy = to[1] - from[1]
    length = Math.sqrt(dx * dx + dy * dy)
    nx = -dy / length * line_width / 2
    ny = dx / length * line_width / 2
    [[from[0] + nx, from[1] + ny], [to[0] + nx, to[1] + ny], [to[0] - nx, to[1] - ny], [from[0] - nx, from[1] - ny]]
  end

  line_z = top_thickness
  ruby_z = line_z + line_thickness
  bottom_z = ruby_z + ruby_thickness
  arch_z = bottom_z + bottom_thickness
  shape = ->(thickness, offset = 0, radius = corner_radius) { prism(outline, height: thickness, offset: offset, corner_radius: radius) }
  # Rounded edges are built from slices: going deeper from a face, in steps
  # along a quarter circle, the outline is set back less. Each pair is
  # [depth from the face, how far the outline is set back].
  round_steps = 6
  quarter = (0..round_steps).map do |step|
    angle = Math::PI / 2 * step / round_steps
    [edge_radius * (1 - Math.cos(angle)), edge_radius * (1 - Math.sin(angle))]
  end

  # The plate's corners have their own radius, so that the clear plate keeps
  # the ruby's shape however wide the margin is. Wrapping the slices
  # rounds its front and back edges.
  plate_shape = ->(thickness, inset) { shape.call(thickness, margin - inset, [plate_corner_radius - inset, 0].max) }
  plate = wrap(*quarter.map { |depth, inset| plate_shape.call(arch_z - depth * 2, inset).up(depth) })
  # The cuts end on a border along the ruby's edge, as in a drawn gem, and
  # everything is trimmed to the outline.
  ruby_face = shape.call(line_thickness)
  # The inner edge of the border is rounded less, so that the border keeps
  # its width around the corners.
  border = ruby_face - shape.call(line_thickness, -line_width, [corner_radius - line_width, 0].max)
  strips = cuts.map { |from, to| prism(strip.call(from, to), height: line_thickness) }
  dots = cuts.flatten(1).uniq.map { |x, y| cylinder(diameter: line_width, height: line_thickness, segments: 16).move(x: x, y: y) }
  lines = (((strips + dots).inject(:+) + border) & ruby_face).up(line_z)
  ruby = shape.call(ruby_thickness).up(ruby_z)

  # The arch is a bridge on the back. A hair tie goes through it folded in two,
  # and the plate is then passed through the end of the loop. It is drawn as a
  # side view, x across and y up from the back of the plate:
  # - the pillars widen toward the plate, where pulling the tie strains the
  #   arch the most
  # - the upper corners of the opening are cut off, which shortens the span
  #   printed over thin air and leaves more material where the beam meets
  #   the pillars
  opening_width = elastic_diameter * 2 + 0.5
  opening_height = elastic_diameter + 0.4
  cut = 1.0
  inner = opening_width / 2
  outer = inner + arch_thickness
  foot = outer + arch_thickness * 0.7
  arch_height = opening_height + arch_thickness
  # Both views reach below the back of the plate, and the part below is cut
  # off at the end, so that rounding the edges leaves the feet on the plate.
  below = edge_radius + 1
  side_view = [[-foot, -below], [foot, -below], [foot, 0], [outer, arch_height - cut], [outer - cut, arch_height],
               [-(outer - cut), arch_height], [-outer, arch_height - cut], [-foot, 0]]
  opening = [[-inner, -below], [inner, -below], [inner, opening_height - cut], [inner - cut, opening_height],
             [-(inner - cut), opening_height], [-inner, opening_height - cut]]
  above_plate = [[-foot - 1, 0], [foot + 1, 0], [foot + 1, arch_height + 1], [-foot - 1, arch_height + 1]]

  # The edges at both ends of the arch are rounded, outside and around the
  # opening, where the tie rubs. A mouth is the opening widening toward an
  # end. Unlike the outside it curves inward, which one wrap cannot follow,
  # so it joins a wrap for every step. place gives the height of a thin
  # slice at a depth from that end.
  solid = wrap(*quarter.map { |depth, inset| prism(side_view, height: arch_depth - depth * 2, offset: -inset).up(depth) })
  slice = 0.01
  mouth = lambda do |place|
    (0...round_steps).map do |step|
      wrap(*quarter[step, 2].map { |depth, inset| prism(opening, height: slice, offset: inset).up(place.call(depth)) })
    end.inject(:+)
  end
  near_mouth = mouth.call(->(depth) { depth })
  far_mouth = mouth.call(->(depth) { arch_depth - depth - slice })
  # Standing the side view up turns its x to the plate's y, so the tie runs
  # along the widest line of the ruby. The arch sits between the center and
  # that line, near where the plate balances.
  arch = ((solid - prism(opening, height: arch_depth) - near_mouth - far_mouth) & prism(above_plate, height: arch_depth))
         .rotate(x: 90, z: 90).move(x: -arch_depth / 2.0, y: corner[1] / 2.0, z: arch_z)

  part :clear, color: :clear do
    (plate - lines - ruby) + arch
  end

  part :cuts, color: :charcoal do
    lines
  end

  part :ruby, color: :dark_red do
    ruby
  end
end
