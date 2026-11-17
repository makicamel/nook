// Writes an uncompressed zip archive, which is all a 3MF container needs.

const CRC_TABLE = new Uint32Array(256).map((_, index) => {
  let value = index;
  for (let bit = 0; bit < 8; bit++) value = value & 1 ? 0xedb88320 ^ (value >>> 1) : value >>> 1;
  return value;
});

function crc32(bytes) {
  let crc = 0xffffffff;
  for (const byte of bytes) crc = CRC_TABLE[(crc ^ byte) & 0xff] ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
}

function header(signature, fields) {
  const bytes = new Uint8Array(4 + fields.reduce((sum, [size]) => sum + size, 0));
  const view = new DataView(bytes.buffer);
  view.setUint32(0, signature, true);
  let offset = 4;
  for (const [size, value] of fields) {
    if (size === 2) view.setUint16(offset, value, true);
    else view.setUint32(offset, value, true);
    offset += size;
  }
  return bytes;
}

// files: [{ path: string, text: string }]
export function createZip(files) {
  const encoder = new TextEncoder();
  const chunks = [];
  const directory = [];
  let offset = 0;

  for (const file of files) {
    const name = encoder.encode(file.path);
    const data = encoder.encode(file.text);
    // version, flags (UTF-8 names), method (stored), time, date (1980-01-01), crc, sizes, name length, extra length
    const shared = [[2, 20], [2, 0x0800], [2, 0], [2, 0], [2, 0x21], [4, crc32(data)], [4, data.length], [4, data.length], [2, name.length], [2, 0]];
    chunks.push(header(0x04034b50, shared), name, data);
    // version made by, shared fields, comment length, disk number, internal attributes, external attributes, local header offset
    directory.push(header(0x02014b50, [[2, 20], ...shared, [2, 0], [2, 0], [2, 0], [4, 0], [4, offset]]), name);
    offset += 30 + name.length + data.length;
  }

  const directorySize = directory.reduce((sum, chunk) => sum + chunk.length, 0);
  const end = header(0x06054b50, [[2, 0], [2, 0], [2, files.length], [2, files.length], [4, directorySize], [4, offset], [2, 0]]);
  return new Blob([...chunks, ...directory, end]);
}
