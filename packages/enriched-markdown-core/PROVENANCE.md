# Provenance

- Upstream: https://github.com/software-mansion/enriched-markdown
- Commit: `27db9a7f8e13e485dc00064c4bcf16a7ea2daad2`
- Source: `packages/core/cpp`, copied verbatim with the same relative paths.
- Omitted: `tests/` (including benchmarks and fixtures) and `wasm/` only.
- License: upstream root MIT `LICENSE` copied here; all embedded notices, including
  `repair/LICENSE.remend`, are retained.
- Local source patches: none. `LICENSE` and this file are the only additions.
- No external symlinks. Consumers refer to this folder directly.

The iOS manifests compile `enrmrkd`, `parser`, `repair`, `highlight` and `latex`, matching
upstream's base library. `highlight/CodeBlockHighlighter.cpp` uses its existing no-op branch
because `ENRICHED_MARKDOWN_CODE_HIGHLIGHT` is not defined. `latex/LatexSpeech.cpp` is a
text-only utility needed by the original C shim, not a LaTeX rendering target. No tree-sitter,
RaTeX, fonts, generated grammars, optional plugins, or asset downloads are enabled.
`input/` is retained verbatim for other consumers but is not compiled by the iOS targets.

No compilation, tests, package resolution, or network operations were performed.
