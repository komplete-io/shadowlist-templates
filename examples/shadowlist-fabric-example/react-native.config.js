const path = require('path');
const { fabricRoot } = require('../../shadowlist');

const pkg = require(path.join(fabricRoot, 'package.json'));

/*
 * shadowlist is not a dependency in package.json. Autolinking and codegen take it from the
 * engine checkout through this entry.
 */
module.exports = {
  project: {
    ios: {
      automaticPodsInstallation: true,
    },
  },
  dependencies: {
    [pkg.name]: {
      root: fabricRoot,
      platforms: {
        // Codegen fails without these, even when empty.
        ios: {},
        android: {},
      },
    },
  },
};
