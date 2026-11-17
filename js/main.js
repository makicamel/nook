import { runRubySources } from './ruby.js';
import { buildMeshes } from './meshes.js';
import { Preview } from './preview.js';
import { load as parseYaml } from 'js-yaml';

const preview = new Preview(document.getElementById('preview'));

// What lib/page.rb calls. Data crosses the boundary as JSON strings.
window.nookHost = {
  palette: '{}',

  show(json, mode, upsideDown, fitCamera) {
    const model = JSON.parse(json);
    preview.show(buildMeshes(model.parts), mode, upsideDown);
    if (fitCamera) preview.fitCamera();
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
