# ShadowList utilities for the web

Template helpers for lists built with [`shadowlist-wasm`](https://github.com/azimgd/shadowlist): avatar colors and
initials, relative times and poll tallies. They run the shared utils core in C++ compiled to WebAssembly, the same
code as the native templates. The helpers have their own binary, `shadowlistutils.wasm`. A list-only application
never fetches it.

## Install

```sh
npm install shadowlist-wasm shadowlist-wasm-utils
```

`shadowlist-wasm` is a peer dependency. The utilities load through its `shadowlist-wasm/loader` and import nothing
else from it.

## Usage

```ts
import {
  loadShadowListUtils,
  avatarInitials,
  relativeTime,
  pollTally,
  pollPercent,
} from 'shadowlist-wasm-utils';

await loadShadowListUtils();
const initials = avatarInitials('Ada Lovelace').toLocaleUpperCase();
const time = relativeTime(createdAtMs, Date.now());
const tally = pollTally([8, 5, 3]);
const percent = pollPercent(8, tally.totalVotes);
```

`loadShadowListUtils` accepts the same `source` and `locateFile` options as `loadShadowListKit`, shares in-flight
calls and permits retries after a failed load. Serve `shadowlistutils.wasm` beside `shadowlistutils.mjs`, pass
`locateFile`, or pass the module itself as `source` (its bytes or a compiled `WebAssembly.Module`). The package
exports the file as `shadowlist-wasm-utils/shadowlistutils.wasm` for a bundler or a server to copy.
`isShadowListUtilsLoaded` reports completion. A helper called before the load throws.

`avatarColorIndex(name, paletteSize)` selects a palette slot using the shared UTF-16 hash; an empty palette
returns 0. `avatarInitials(name)` returns the first code point of the first and last words. The host applies
uppercase and locale rules. `relativeTime(dateMs, nowMs)` returns `{unit, count}` with `unit` one of `now`,
`minutes`, `hours`, `days` or `date`; the host supplies labels and calendar formatting.
`relativeTimeHasDate(dateMs)` rejects nonfinite dates before formatting. `pollTally(votes)` returns
`{totalVotes, leadingIndex}` with -1 for no options, the first index for tied leaders, including all-zero votes.
`pollPercent(votes, totalVotes)` returns the shared whole percentage, with halves rounded up.

## Building from source

The build needs a checkout of the engine repository, [shadowlist](https://github.com/azimgd/shadowlist), for the
engine headers the utils core includes and for `shadowlist-wasm` itself. `SHADOWLIST_ROOT` points at it. The
default is a `shadowlist` folder next to this repository.

```sh
cd packages/shadowlist-wasm-utils
./build.sh
```

- `build.sh` needs Emscripten. It uses `emcmake` from the `PATH`, or sources `emsdk_env.sh` from `$EMSDK`
  (default `~/emsdk`). It stops with an error when the engine checkout is missing.
- `cpp/CMakeLists.txt` compiles `cpp/ShadowListUtilsCoreWasm.cpp` and the sources of `packages/shadowlist-utils-core`
  with this repository's `packages/` and the engine's `packages/` as include roots. A CMake build outside
  `build.sh` takes `-DSHADOWLIST_ROOT=<path>` or the environment variable.
- `dist/` then holds the ES modules, their types, `shadowlistutils.mjs` and `shadowlistutils.wasm`.

During development this repository installs no copy of `shadowlist-wasm`. Three places resolve it to the engine
checkout instead:

- TypeScript: `paths` in `tsconfig.json` map `shadowlist-wasm/loader` to
  `../../../shadowlist/packages/shadowlist-wasm/dist/`. TypeScript reads no environment variables. A checkout
  somewhere else needs that path edited. Build the engine's `shadowlist-wasm` first: its `dist/` holds the types.
- Node: `yarn test` loads `test/resolve-shadowlist-wasm.ts`, which resolves `shadowlist-wasm` and its subpaths
  through the engine package's exports at `SHADOWLIST_ROOT`.
- The browser: the web example's import map uses `/packages/shadowlist-wasm/`, which its server maps to the engine
  checkout.

## Tests

`yarn test` in this package runs `test/*.test.ts` against `dist/` in Node 22 or newer. `utils.test.ts` replays the
avatar, relative-time and poll vectors of `packages/shadowlist-utils-core-tests/vectors` through the real binary
and checks that the kit's binary exports no utility entry points. `browser.test.ts` drives the web example's Feed
and Poll in headless Chrome through `test/fixture.html` and checks that each route loads the utilities only when
it uses them. It is skipped when no Chrome is found or the web example is not built. `CHROME_PATH` picks the
binary. Run `./build.sh`, the engine's `make build-wasm` and the web example's build first.

## Source layout

| File | Role |
| --- | --- |
| `packages/shadowlist-utils-core/` | The shared avatar, relative-time and poll helpers in C++. |
| `cpp/ShadowListUtilsCoreWasm.cpp` | Thin wasm hops into the helpers through a reused scratch area of the heap. |
| `src/ShadowListUtilsCore.ts` | Loads the binary through `shadowlist-wasm/loader` and wraps the wasm calls. |
| `src/PollTally.ts`, `src/RelativeTime.ts` | Result types. |
