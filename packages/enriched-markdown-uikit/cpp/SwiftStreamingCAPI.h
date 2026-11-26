#pragma once

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct EMCStreamingDocument EMCStreamingDocument;
typedef struct EMCStreamingOptions {
  int underline, superscript, subscript, highlight, hardSoftBreaks;
  int permissiveAutolinks, preserveBlankLines, admonitions;
} EMCStreamingOptions;

EMCStreamingDocument *em_stream_create(void);
void em_stream_release(EMCStreamingDocument *document);
// All returned pointers remain valid until the next update or release. UTF-8 lengths are explicit.
void em_stream_update(EMCStreamingDocument *document, const char *text, size_t length,
                      EMCStreamingOptions options, int streaming);
const void *em_stream_root(const EMCStreamingDocument *document);
const char *em_stream_source(const EMCStreamingDocument *document);
size_t em_stream_source_length(const EMCStreamingDocument *document);
size_t em_stream_shared_blocks(const EMCStreamingDocument *document);
size_t em_ast_node_content_length(const void *node);

#ifdef __cplusplus
}
#endif
