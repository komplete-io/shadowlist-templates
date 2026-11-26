# ShadowList templates

List templates, visual components and example apps for [ShadowList](https://github.com/azimgd/shadowlist): the
`shadowlist-utils` hooks and list kits for React Native, ShadowListUtils for UIKit and Android views, the template
logic they share in C++, web helpers on that C++ in WebAssembly, and an example app for every kit.

## Engine checkout

Everything here builds against a checkout of the engine, [shadowlist](https://github.com/azimgd/shadowlist). Clone
it next to this repository:

```sh
git clone https://github.com/azimgd/shadowlist.git ../shadowlist
```

Or set `SHADOWLIST_ROOT` to the engine folder. [`shadowlist.js`](shadowlist.js) resolves it for Metro, Babel and the
React Native CLI, and stops with an error when the folder is missing. TypeScript cannot read the environment: the
`tsconfig.json` paths always point at `../shadowlist`. With the engine elsewhere, make `../shadowlist` a symlink to
it. The Podfile.lock files record the pod path of `../shadowlist` as well.

`make typecheck-web` reads the engine's `packages/shadowlist-wasm/dist`, built there with `make build-wasm`. Building
`shadowlist-utils` with `make build` reads the engine's `packages/shadowlist-fabric/lib`, built there with `make build`.

## Repo layout

| Path | Contents |
| --- | --- |
| `packages/shadowlist-utils` | `shadowlist-utils` on npm: hooks, helpers and list kits for React Native |
| `packages/shadowlist-utils-core` | Template logic in C++, shared by the native and web templates |
| `packages/shadowlist-utils-core-tests` | Tests for the template C++, and the vector files jest replays too |
| `packages/shadowlist-uikit-utils` | ShadowListUtils for UIKit |
| `packages/shadowlist-android-utils` | ShadowListUtils for Android views |
| `packages/shadowlist-wasm-utils` | Template helpers for `shadowlist-wasm` lists |
| `examples/shadowlist-fabric-example` | React Native example app for iOS and Android |
| `examples/shadowlist-macos-example` | React Native macOS example app, on the screens of the iOS and Android app |
| `examples/shadowlist-uikit-example` | UIKit example app |
| `examples/shadowlist-appkit-example` | AppKit example app |
| `examples/shadowlist-android-example` | Android views example app |
| `examples/shadowlist-web-example` | Web example app |

## Development

`make` at the repo root runs `install` by default. A JS target passes through to the `yarn` script of the same name, with `-`
for `:` (`make format-check` runs `yarn format:check`).

| Command | What it does |
| --- | --- |
| `make install` | Installs the workspaces: `shadowlist-utils`, `shadowlist-wasm-utils` and the two React Native apps |
| `make lint` | ESLint over the repo |
| `make typecheck` | TypeScript for `shadowlist-utils`, both React Native apps and `shadowlist-wasm-utils` |
| `make typecheck-web` | TypeScript for the web example |
| `make test` | Jest for `shadowlist-utils` |
| `make test-wasm` | Node tests for `shadowlist-wasm-utils` against its `dist/` |
| `make test-core` | Builds `packages/shadowlist-utils-core-tests` with CMake and runs it with ctest |
| `make test-core-tsan` | The same tests under ThreadSanitizer |
| `make build` | Builds `shadowlist-utils` with bob |
| `make build-wasm` | Builds `shadowlist-wasm-utils` with Emscripten and TypeScript |
| `make format` | Prettier over the repo. `make format-check` only checks. |
| `make docs-check` | Checks the READMEs' local links, headings and compact tables |
| `make check` | `lint`, `format-check`, `typecheck`, `docs-check` and `test` |

`UPDATE_VECTORS=1 yarn test` writes the vector files from the TypeScript, after a change both sides make.

[Code style](docs/code-style.md) has the rules for template code. The engine's
[code style](https://github.com/azimgd/shadowlist/blob/main/docs/code-style.md) holds the shared rules, which apply here too.

## React Native apps

The apps read `shadowlist` from the engine checkout and `shadowlist-utils` from this repository, both as TypeScript
source. Neither is a dependency in the apps' `package.json`.

| Command | What it does |
| --- | --- |
| `yarn workspace shadowlist-example start` | Metro for the iOS and Android app |
| `yarn workspace shadowlist-example run build:android` | Debug build of the Android app |
| `cd examples/shadowlist-fabric-example/ios && pod install` | Installs the iOS pods, then build `ShadowListExample.xcworkspace` in Xcode |
| `make pods-macos` | Installs the macOS pods, then build `ShadowListMacOS.xcworkspace` in Xcode |
