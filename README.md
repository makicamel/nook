# nook

A shelf for small things to 3D print. Shapes are written in Ruby.

## Writing a model

Put one model per file in `models/`.

```ruby
model 'ruby' do
  printed_upside_down

  param :diameter, 40, range: 20..80
  param :facets, 8, range: 6..16, step: 2

  part :gem, color: :dark_red do
    face = cylinder(diameter: 24, top_diameter: diameter, height: 8, segments: facets)
    point = cylinder(diameter: diameter, top_diameter: 0, height: 24, segments: facets).up(8)
    face + point
  end
end
```

- `param`
    - An adjustable number with a default and a range. Its value is read through a method of the same name
- `part`
    - A part printed in one color. The value of the block becomes its shape. A model with several colors has one part per color
- `box(width, depth, height)`, `cylinder(diameter:, height:)`
    - Shapes centered on the x and y axes, with the bottom face on z = 0
- `cylinder(..., top_diameter:, segments:)`
    - Optional arguments. `top_diameter` makes a cone, and a few `segments` make a prism or pyramid
- `+`, `-`, `&`
    - Union, difference, and intersection of shapes
- `move(x:, y:, z:)`, `up(distance)`
    - Move a shape
- `printed_upside_down`
    - Declares that the model prints upside down, with its top on the bed

Lengths are in millimeters.

## Colors

A part names its color from the list in `colors.yml`.

```yaml
dark_red: { filament: 'PLA Matte', code: '11202', color: '#BB3D43' }
clear: { filament: 'PETG Translucent', code: '32101', color: '#FFFFFF', opacity: 0.3 }
```

`color` and `code` come from Bambu Studio's filament color table. `opacity` is for translucent filaments and defaults to 1.
