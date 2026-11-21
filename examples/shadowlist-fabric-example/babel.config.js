const path = require('path');
const { getConfig } = require('react-native-builder-bob/babel-config');
const { fabricRoot } = require('../../shadowlist');

const pkg = require(path.join(fabricRoot, 'package.json'));

module.exports = getConfig(
  {
    presets: ['module:@react-native/babel-preset'],
    plugins: ['react-native-worklets/plugin'],
  },
  { root: fabricRoot, pkg }
);
