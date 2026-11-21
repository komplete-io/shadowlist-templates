# ShadowList web example

The web routes of the templates on [`shadowlist-wasm`](https://github.com/azimgd/shadowlist) and
`shadowlist-wasm-utils`. The page imports the kit from a checkout of the engine repository at `SHADOWLIST_ROOT`
(default `../shadowlist` next to this repository) and the utilities from `packages/shadowlist-wasm-utils`.

```sh
# in the engine checkout
yarn build:wasm
# here
cd examples/shadowlist-web-example
npm run build   # or: ../../packages/shadowlist-wasm-utils/build.sh && ../../node_modules/.bin/tsc -b
npm start       # node --experimental-strip-types serve.ts 8080
```

Then open `http://127.0.0.1:8080/web/?SLRoute=Chat&SLCount=1000`. `SLRoute` takes `Feed`, `Poll`, `Chat`,
`Masonry`, `Horizontal` and `Sticky`. The page puts the list on `window.list` for the console.

`serve.ts` serves the page at `/web/`, the engine's `shadowlist-wasm` at `/packages/shadowlist-wasm/` and the
packages of this repository at `/packages/<name>/`. The import map in `index.html` uses these paths. The engine's
browser test serves the same layout and opens each route. `tsconfig.json` points at the engine's
`../../../shadowlist/packages/shadowlist-wasm/dist` for types. TypeScript reads no environment variables. A checkout
somewhere else needs those paths edited.
