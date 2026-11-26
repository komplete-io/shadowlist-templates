const path = require('path');
const { fabricRoot } = require('../../shadowlist');

const pkg = require(path.join(fabricRoot, 'package.json'));

/*
 * Layout checks only: SHADOWRULER=1 links @shadowruler/react-native from the checkout next to
 * this repository (SHADOWRULER_ROOT overrides it). SLRuler 1 then measures the open screen,
 * see src/ruler/rulerCheck.ts.
 */
const rulerRoot =
  process.env.SHADOWRULER === '1'
    ? path.join(
        process.env.SHADOWRULER_ROOT ||
          path.resolve(__dirname, '../../../shadowruler'),
        'packages/react-native'
      )
    : null;

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
    ...(rulerRoot
      ? {
          '@shadowruler/react-native': {
            root: rulerRoot,
            platforms: { ios: {} },
          },
        }
      : {}),
  },
};
