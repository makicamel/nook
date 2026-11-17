import Module from 'manifold-3d';

const wasm = await Module();
wasm.setup();
wasm.setCircularSegments(96);
const { Manifold, CrossSection } = wasm;

// Manifold objects live in WebAssembly memory and are freed by hand, so every
// one made on the way is recorded in `created`.
function toManifold(tree, created) {
  const solid = evaluate(tree, created);
  created.push(solid);
  return solid;
}

function evaluate(tree, created) {
  switch (tree.op) {
    case 'box': {
      const [width, depth] = tree.size;
      const cube = Manifold.cube(tree.size);
      created.push(cube);
      return cube.translate([-width / 2, -depth / 2, 0]);
    }
    case 'cylinder':
      // 0 segments lets manifold-3d choose the count from setCircularSegments.
      return Manifold.cylinder(tree.height, tree.diameter / 2, tree.top_diameter / 2, tree.segments ?? 0);
    case 'prism': {
      // NonZero accepts the points in either winding order. A miter limit of 4
      // keeps corners down to about 30 degrees sharp while offsetting. Shrinking
      // and then growing by the same radius rounds the outward corners.
      const outline = new CrossSection([tree.points], 'NonZero');
      const offset = outline.offset(tree.offset, 'Miter', 4);
      const shrunk = offset.offset(-tree.corner_radius, 'Round');
      const rounded = shrunk.offset(tree.corner_radius, 'Round');
      created.push(outline, offset, shrunk, rounded);
      return rounded.extrude(tree.height);
    }
    case 'move':
      return toManifold(tree.child, created).translate(tree.offset);
    case 'rotate':
      return toManifold(tree.child, created).rotate(tree.degrees);
    case 'wrap':
      return Manifold.hull(tree.children.map((child) => toManifold(child, created)));
    case 'union':
    case 'difference':
    case 'intersection': {
      const [first, second] = tree.children.map((child) => toManifold(child, created));
      const method = { union: 'add', difference: 'subtract', intersection: 'intersect' }[tree.op];
      return first[method](second);
    }
    default:
      throw new Error(`unknown shape operation: ${tree.op}`);
  }
}

// Replaces the shape of every part with its mesh: positions and triangles.
export function buildMeshes(parts) {
  const created = [];
  try {
    return parts.map((part) => {
      const { shape, ...rest } = part;
      const mesh = toManifold(shape, created).getMesh();
      return { ...rest, positions: mesh.vertProperties, triangles: mesh.triVerts };
    });
  } finally {
    created.forEach((solid) => solid.delete());
  }
}
