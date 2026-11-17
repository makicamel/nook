import { runRubySources } from './ruby.js';
import { buildMeshes } from './meshes.js';
import { Preview } from './preview.js';
import { create3mf } from './three_mf.js';
import { load as parseYaml } from 'js-yaml';

const preview = new Preview(document.getElementById('preview'));
let shown = null; // { name, parts } of the model on screen

// What lib/page.rb calls. Data crosses the boundary as JSON strings.
window.nookHost = {
  palette: '{}',

  show(json, mode, upsideDown, fitCamera) {
    const model = JSON.parse(json);
    shown = { name: model.name, parts: buildMeshes(model.parts) };
    preview.show(shown.parts, mode, upsideDown);
    if (fitCamera) preview.fitCamera();
  },

  download() {
    const link = document.createElement('a');
    link.href = URL.createObjectURL(create3mf(shown.name, shown.parts));
    link.download = `${shown.name}.3mf`;
    link.click();
    URL.revokeObjectURL(link.href);
  },
};

// The server sends no Cache-Control header, so without revalidation the browser
// can keep showing a model list or model file from before an edit.
async function start() {
  window.nookHost.palette = JSON.stringify(parseYaml(await (await fetch('colors.yml', { cache: 'no-cache' })).text()));
  const names = await (await fetch('models/index.json', { cache: 'no-cache' })).json();
  await runRubySources(['lib/nook.rb', ...names.map((name) => `models/${name}.rb`), 'lib/page.rb']);
}

start().catch((error) => {
  document.getElementById('panel').textContent = error.message;
});
