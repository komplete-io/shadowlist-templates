#include "SwiftStreamingCAPI.h"
#include "DocumentStore.hpp"
#include <memory>
#include <string>

struct EMCStreamingDocument {
  std::string source;
  std::shared_ptr<const Markdown::ParsedDocument> parsed;
  size_t sharedBlocks = 0;
};

extern "C" {

EMCStreamingDocument *em_stream_create(void) { return new EMCStreamingDocument(); }
void em_stream_release(EMCStreamingDocument *document) { delete document; }

void em_stream_update(EMCStreamingDocument *document, const char *text, size_t length,
                      EMCStreamingOptions options, int streaming) {
  if (!document) return;
  Markdown::Md4cFlags flags;
  flags.latexMath = false;
  flags.underline = options.underline != 0;
  flags.superscript = options.superscript != 0;
  flags.subscript = options.subscript != 0;
  flags.highlight = options.highlight != 0;
  flags.hardSoftBreaks = options.hardSoftBreaks != 0;
  flags.permissiveAutolinks = options.permissiveAutolinks != 0;
  flags.preserveBlankLines = options.preserveBlankLines != 0;
  flags.admonitions = options.admonitions != 0;
  auto &store = Markdown::DocumentStore::shared();
  const std::string source = text ? std::string(text, length) : std::string();
  // snapshot runs upstream's filter and inline repair, and records the finished prefix for parse.
  document->source = streaming ? store.snapshot(source, {{}, flags}).markdown : source;
  auto next = store.parse(document->source, flags, true);
  document->sharedBlocks = document->parsed ? Markdown::sharedLeadingBlocks(*document->parsed, *next) : 0;
  document->parsed = std::move(next);
}

const void *em_stream_root(const EMCStreamingDocument *document) {
  return document && document->parsed ? document->parsed->ast.get() : nullptr;
}
const char *em_stream_source(const EMCStreamingDocument *document) {
  return document ? document->source.data() : nullptr;
}
size_t em_stream_source_length(const EMCStreamingDocument *document) {
  return document ? document->source.size() : 0;
}
size_t em_stream_shared_blocks(const EMCStreamingDocument *document) {
  return document ? document->sharedBlocks : 0;
}
size_t em_ast_node_content_length(const void *node) {
  return node ? static_cast<const Markdown::MarkdownASTNode *>(node)->content.size() : 0;
}

} // extern "C"
