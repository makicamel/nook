# Describes printable models as trees of shape operations. The trees are plain
# hashes so that the JavaScript side can turn them into meshes.
module Nook
  REGISTRY = {}

  def self.define(name, &block)
    REGISTRY[name] = Definition.new(name, block)
  end

  def self.build(name, values = {})
    REGISTRY.fetch(name).build(values)
  end

  class Definition
    def initialize(name, block)
      @name = name
      @block = block
    end

    def build(values)
      builder = Builder.new(values)
      builder.instance_eval(&@block)
      { name: @name, params: builder.params, parts: builder.parts, printed_upside_down: builder.printed_upside_down? }
    end
  end

  class Builder
    attr_reader :params, :parts

    def initialize(values)
      @values = values
      @params = []
      @parts = []
      @printed_upside_down = false
    end

    # A model is written in the position it prints in. This marks one that
    # prints with its top on the bed.
    def printed_upside_down
      @printed_upside_down = true
    end

    def printed_upside_down?
      @printed_upside_down
    end

    # Declares an adjustable number and defines a reader with the same name.
    def param(name, default, range:, step: 1)
      value = @values.fetch(name.to_s, default)
      @params << { name: name.to_s, value: value, min: range.first, max: range.last, step: step }
      define_singleton_method(name) { value }
    end

    # One part is printed with one filament. color is a name in colors.yml.
    def part(name, color:)
      @parts << { name: name.to_s, color: color.to_s, shape: yield.tree }
    end

    # Shapes are centered on the x and y axes and stand on z = 0.
    def box(width, depth, height)
      Shape.new(op: 'box', size: [width, depth, height])
    end

    # top_diameter makes a cone, and a few segments make a prism or pyramid.
    def cylinder(diameter:, height:, top_diameter: diameter, segments: nil)
      Shape.new(op: 'cylinder', diameter: diameter, top_diameter: top_diameter, height: height, segments: segments)
    end

    # A flat outline given as [x, y] points, raised to height. offset grows the
    # outline outward by that distance, or shrinks it when negative, keeping its
    # corners sharp, and corner_radius then rounds the outward corners.
    def prism(points, height:, offset: 0, corner_radius: 0)
      Shape.new(op: 'prism', points: points, height: height, offset: offset, corner_radius: corner_radius)
    end
  end

  class Shape
    attr_reader :tree

    def initialize(tree)
      @tree = tree
    end

    def +(other)
      combine('union', other)
    end

    def -(other)
      combine('difference', other)
    end

    def &(other)
      combine('intersection', other)
    end

    def move(x: 0, y: 0, z: 0)
      Shape.new(op: 'move', offset: [x, y, z], child: @tree)
    end

    def up(distance)
      move(z: distance)
    end

    private

    def combine(op, other)
      Shape.new(op: op, children: [@tree, other.tree])
    end
  end
end

def model(name, &block)
  Nook.define(name, &block)
end
