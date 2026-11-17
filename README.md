# nook

A shelf for small things to 3D print. Shapes are written in Ruby.

## Writing a model

```ruby
model 'inlay_tile' do
  param :size, 30, range: 20..60
  param :dot_diameter, 16, range: 6..18

  dot = cylinder(diameter: dot_diameter, height: 1).up(5)

  part :tile, color: :ivory_white do
    box(size, size, 6) - dot
  end

  part :dot, color: :dark_red do
    dot
  end
end
```

- `param`
    - An adjustable number with a default and a range. Its value is read through a method of the same name
- `part`
    - A part printed in one color. The value of the block becomes its shape
- `box(width, depth, height)`, `cylinder(diameter:, height:)`
    - Shapes centered on the x and y axes, with the bottom face on z = 0
- `cylinder(..., top_diameter:, segments:)`
    - Optional arguments. `top_diameter` makes a cone, and a few `segments` make a prism or pyramid
- `+`, `-`, `&`
    - Union, difference, and intersection of shapes
- `move(x:, y:, z:)`, `up(distance)`
    - Move a shape

Lengths are in millimeters.

## Colors

A part names its color from the list in `colors.yml`.

```yaml
dark_red: { filament: 'PLA Matte', code: '11202', color: '#BB3D43' }
clear: { filament: 'PETG Translucent', code: '32101', color: '#FFFFFF', opacity: 0.3 }
```

`color` and `code` come from Bambu Studio's filament color table. `opacity` is for translucent filaments and defaults to 1.
