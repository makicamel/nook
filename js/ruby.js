// The loader script in index.html exposes the PicoRuby runtime as
// window.picorubyModule and adds picorubyRun to it when it is ready.
async function runtimeReady() {
  while (!window.picorubyModule?.picorubyRun) await new Promise((resolve) => setTimeout(resolve, 20));
  return window.picorubyModule;
}

// Tasks take turns, so a source that depends on an earlier one must wait for
// it. The wrapper reports the end of a source without shifting line numbers.
function runSource(runtime, path, source) {
  return new Promise((resolve, reject) => {
    window.rubySourceFinished = (error) => (error ? reject(new Error(`${path}: ${error}`)) : resolve());
    const wrapped = `begin; ${source}\nrescue Exception => error\n  JS.global.rubySourceFinished("#{error.class}: #{error.message}")\nelse\n  JS.global.rubySourceFinished('')\nend`;
    const status = runtime.ccall('picorb_create_task_with_filename', 'number', ['string', 'string'], [wrapped, path]);
    if (status !== 0) reject(new Error(`${path}: could not be compiled`));
  });
}

export async function runRubySources(paths) {
  const runtime = await runtimeReady();
  for (const path of paths) {
    const response = await fetch(path, { cache: 'no-cache' });
    if (!response.ok) throw new Error(`${path}: ${response.status}`);
    await runSource(runtime, path, await response.text());
  }
}
