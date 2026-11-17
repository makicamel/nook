import { createZip } from './zip.js';

const CONTENT_TYPES = `<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/>
</Types>
`;

const RELATIONSHIPS = `<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Target="/3D/3dmodel.model" Id="rel0" Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/>
</Relationships>
`;

const MATERIALS_ID = 1;

// Float32 coordinates print as 14.999999046325684 without rounding.
function millimeters(value) {
  return Math.round(value * 100000) / 100000;
}

// #RRGGBBAA
function displayColor(part) {
  const alpha = Math.round(part.opacity * 255).toString(16).padStart(2, '0');
  return (part.hex + alpha).toUpperCase();
}

function meshObject(part, id, materialIndex) {
  const lines = [`    <object id="${id}" type="model" name="${part.name}" pid="${MATERIALS_ID}" pindex="${materialIndex}">`, '      <mesh>', '        <vertices>'];
  for (let index = 0; index < part.positions.length; index += 3) {
    const [x, y, z] = [...part.positions.subarray(index, index + 3)].map(millimeters);
    lines.push(`          <vertex x="${x}" y="${y}" z="${z}"/>`);
  }
  lines.push('        </vertices>', '        <triangles>');
  for (let index = 0; index < part.triangles.length; index += 3) {
    const [v1, v2, v3] = part.triangles.subarray(index, index + 3);
    lines.push(`          <triangle v1="${v1}" v2="${v2}" v3="${v3}"/>`);
  }
  lines.push('        </triangles>', '      </mesh>', '    </object>');
  return lines.join('\n');
}

// Each part becomes one component of a single object, colored through
// basematerials. Slicers assign one filament per color.
function modelXml(name, parts) {
  const firstPartId = MATERIALS_ID + 1;
  const assemblyId = firstPartId + parts.length;
  const materials = parts.map((part) => `      <base name="${part.name}" displaycolor="${displayColor(part)}"/>`);
  const objects = parts.map((part, index) => meshObject(part, firstPartId + index, index));
  const components = parts.map((_, index) => `        <component objectid="${firstPartId + index}"/>`);
  return `<?xml version="1.0" encoding="UTF-8"?>
<model unit="millimeter" xml:lang="en-US" xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02">
  <resources>
    <basematerials id="${MATERIALS_ID}">
${materials.join('\n')}
    </basematerials>
${objects.join('\n')}
    <object id="${assemblyId}" type="model" name="${name}">
      <components>
${components.join('\n')}
      </components>
    </object>
  </resources>
  <build>
    <item objectid="${assemblyId}"/>
  </build>
</model>
`;
}

export function create3mf(name, parts) {
  return createZip([
    { path: '[Content_Types].xml', text: CONTENT_TYPES },
    { path: '_rels/.rels', text: RELATIONSHIPS },
    { path: '3D/3dmodel.model', text: modelXml(name, parts) },
  ]);
}
