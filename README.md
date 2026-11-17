# nook

A shelf for small things to 3D print. Shapes are written in Ruby and previewed in the browser.

## Usage

The site consists of static files only. Serve it locally with Ruby's static server, which needs the webrick gem.

```bash
ruby -run -e httpd . -p 8932
```

Open http://localhost:8932 and choose a model.

- Moving a dimension slider updates the shape
- Each part can be given a filament color
- Switching the display to "Mesh" drops the colors and shows how the surface is split into triangles
- "Upside down" turns the preview over. It starts checked for a model declared with `printed_upside_down`

## Writing a model

Put one model per file in `models/` and add the file name to `models/index.json`.

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
    - Declares that the model prints upside down, with its top on the bed. The preview shows it turned over

Lengths are in millimeters.

## Colors

A part names its color from the list in `colors.yml`.

```yaml
dark_red: { filament: 'PLA Matte', code: '11202', color: '#BB3D43' }
clear: { filament: 'PETG Translucent', code: '32101', color: '#FFFFFF', opacity: 0.3 }
```

`color` and `code` come from Bambu Studio's filament color table. `opacity` is for translucent filaments and defaults to 1.

## Structure

```
lib/nook.rb       DSL for describing models
lib/page.rb       Control panel (a Funicular component)
models/           Models
colors.yml        Filament colors
js/               Mesh calculation and preview
```

Ruby builds a tree of operations such as "subtract a cylinder from a cylinder", and JavaScript turns the tree into meshes. The control panel is written in Ruby as well. Libraries are loaded from a CDN with pinned versions.

- [PicoRuby.wasm](https://www.npmjs.com/package/@picoruby/wasm-wasi)
    - Runs Ruby in the browser
- [Funicular](https://picoruby.org/funicular)
    - Renders the control panel. Bundled with PicoRuby.wasm
- [manifold-3d](https://github.com/elalish/manifold)
    - Calculates the union, difference, and intersection of shapes
- [three.js](https://threejs.org/)
    - Draws the preview
- [js-yaml](https://github.com/nodeca/js-yaml)
    - Reads `colors.yml`
