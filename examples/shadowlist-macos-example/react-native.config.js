const path = require('path');
const { fabricRoot } = require('../../shadowlist');

/*
 * shadowlist is not a dependency in package.json. Autolinking and codegen take it from the
 * engine checkout through the dependencies entry.
 */
module.exports = {
  reactNativePath: path.dirname(
    require.resolve('react-native-macos/package.json')
  ),
  dependencies: {
    shadowlist: { root: fabricRoot },
  },
};
