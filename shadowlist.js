/*
 * Where the shadowlist engine checkout lives. SHADOWLIST_ROOT overrides the default, a
 * shadowlist folder next to this repository.
 */
const fs = require('fs');
const path = require('path');

const shadowlistRoot = path.resolve(
  process.env.SHADOWLIST_ROOT || path.resolve(__dirname, '../shadowlist')
);

if (
  !fs.existsSync(shadowlistRoot) ||
  !fs.statSync(shadowlistRoot).isDirectory()
) {
  throw new Error(
    `shadowlist engine checkout not found at ${shadowlistRoot}. Clone the engine next to this repository or set SHADOWLIST_ROOT to its folder.`
  );
}

const packageRoot = (name) => path.join(shadowlistRoot, 'packages', name);

module.exports = {
  shadowlistRoot,
  coreRoot: packageRoot('shadowlist-core'),
  fabricRoot: packageRoot('shadowlist-fabric'),
  uikitRoot: packageRoot('shadowlist-uikit'),
  appkitRoot: packageRoot('shadowlist-appkit'),
  androidRoot: packageRoot('shadowlist-android'),
  wasmRoot: packageRoot('shadowlist-wasm'),
};
