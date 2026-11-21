/*
 * Resolves shadowlist-wasm and its subpaths to the engine checkout during development, where
 * this repository installs no copy of the kit. The engine is SHADOWLIST_ROOT (default
 * ../shadowlist next to this repository), found through the repository's shadowlist.js.
 * Loaded with node --import before the tests. The hook itself runs as plain JavaScript.
 */
import { createRequire, register } from 'node:module';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';

const { wasmRoot } = createRequire(import.meta.url)(
  '../../../shadowlist.js'
) as {
  wasmRoot: string;
};

register(
  'data:text/javascript,' +
    encodeURIComponent(`
const KIT = ${JSON.stringify(pathToFileURL(join(wasmRoot, 'package.json')).href)};
export async function resolve(specifier, context, next) {
  /*
   * The kit resolves its own name through its exports, the way an installed copy would.
   */
  if (specifier === 'shadowlist-wasm' || specifier.startsWith('shadowlist-wasm/')) {
    return next(specifier, { ...context, parentURL: KIT });
  }
  return next(specifier, context);
}
`)
);
