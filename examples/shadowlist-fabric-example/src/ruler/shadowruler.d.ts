/*
 * The real package in SHADOWRULER=1 builds, a null stub otherwise. See metro.config.js.
 */
declare module '@shadowruler/react-native' {
  const ShadowRuler: unknown;
  export default ShadowRuler;
}
