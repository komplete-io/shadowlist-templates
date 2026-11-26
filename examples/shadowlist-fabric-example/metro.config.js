const path = require('path');
const { getDefaultConfig } = require('@react-native/metro-config');
const { withMetroConfig } = require('react-native-monorepo-config');
const { fabricRoot } = require('../../shadowlist');

const repoRoot = path.resolve(__dirname, '../..');
const utilsRoot = path.resolve(__dirname, '../../packages/shadowlist-utils');

/*
 * shadowlist comes from the engine checkout (SHADOWLIST_ROOT, or ../shadowlist next to this
 * repository). The monorepo config reads its sources and blocks the react and react-native
 * copies in the engine's node_modules.
 */
/** @type {import('metro-config').MetroConfig} */
const config = withMetroConfig(getDefaultConfig(__dirname), {
  root: fabricRoot,
  dirname: __dirname,
  workspaces: [],
});

config.watchFolders = [...(config.watchFolders || []), utilsRoot, repoRoot];

config.resolver = config.resolver || {};
/*
 * Layout checks only: with SHADOWRULER=1 the bundle gets @shadowruler/react-native from the
 * checkout next to this repository, otherwise a stub (src/ruler/stub). Its react and react-native
 * imports resolve to this app's copies, not the ones in its own node_modules.
 */
const rulerRoot =
  process.env.SHADOWRULER === '1'
    ? path.join(
        process.env.SHADOWRULER_ROOT ||
          path.resolve(__dirname, '../../../shadowruler'),
        'packages/react-native'
      )
    : null;
if (rulerRoot) config.watchFolders.push(rulerRoot);

config.resolver.extraNodeModules = {
  ...(config.resolver.extraNodeModules || {}),
  'shadowlist-utils': utilsRoot,
  '@shadowruler/react-native':
    rulerRoot || path.join(__dirname, 'src/ruler/stub'),
};

if (rulerRoot) {
  const resolveRequest = config.resolver.resolveRequest;
  config.resolver.resolveRequest = (context, moduleName, platform) => {
    const shared =
      moduleName === 'react' ||
      moduleName === 'react-native' ||
      moduleName.startsWith('react/') ||
      moduleName.startsWith('react-native/');
    const next = resolveRequest || context.resolveRequest;
    if (shared && context.originModulePath.startsWith(rulerRoot)) {
      return next(
        { ...context, originModulePath: path.join(__dirname, 'index.js') },
        moduleName,
        platform
      );
    }
    return next(context, moduleName, platform);
  };
}

config.resolver.nodeModulesPaths = [
  ...(config.resolver.nodeModulesPaths || []),
  path.join(__dirname, 'node_modules'),
  path.join(repoRoot, 'node_modules'),
];

module.exports = config;
