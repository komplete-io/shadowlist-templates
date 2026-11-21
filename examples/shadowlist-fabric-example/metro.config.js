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
config.resolver.extraNodeModules = {
  ...(config.resolver.extraNodeModules || {}),
  'shadowlist-utils': utilsRoot,
};

config.resolver.nodeModulesPaths = [
  ...(config.resolver.nodeModulesPaths || []),
  path.join(__dirname, 'node_modules'),
  path.join(repoRoot, 'node_modules'),
];

module.exports = config;
