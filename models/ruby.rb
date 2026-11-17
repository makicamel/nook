# A cut gem. The point cannot stand on the bed, so it prints with the flat
# face down, where the slope from the face to the widest edge is the only
# overhang.
model 'ruby' do
  printed_upside_down

  param :diameter, 40, range: 20..80
  param :face_diameter, 24, range: 10..60
  param :face_height, 8, range: 4..20
  param :point_height, 24, range: 10..50
  param :facets, 8, range: 6..16, step: 2

  part :gem, color: :dark_red do
    face = cylinder(diameter: face_diameter, top_diameter: diameter, height: face_height, segments: facets)
    point = cylinder(diameter: diameter, top_diameter: 0, height: point_height, segments: facets).up(face_height)
    face + point
  end
end
