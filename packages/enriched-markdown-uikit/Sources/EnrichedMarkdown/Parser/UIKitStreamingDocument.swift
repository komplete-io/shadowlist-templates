import EnrichedMarkdownCppShim
import Foundation

/// Owned by one UIKit view on the main thread. Finished AST blocks survive append updates.
final class UIKitStreamingDocument {
    private let handle = em_stream_create()
    private var children: [MarkdownASTNode] = []
    private(set) var source = ""

    deinit { em_stream_release(handle) }

    func update(_ text: String, options: MarkdownParsingOptions, streaming: Bool) -> MarkdownASTNode {
        let flags = EMCStreamingOptions(
            underline: options.underline ? 1 : 0,
            superscript: options.superscript ? 1 : 0,
            subscript: options.subscript ? 1 : 0,
            highlight: options.highlight ? 1 : 0,
            hardSoftBreaks: options.hardSoftBreaks ? 1 : 0,
            permissiveAutolinks: options.permissiveAutolinks ? 1 : 0,
            preserveBlankLines: options.preserveBlankLines ? 1 : 0,
            admonitions: options.admonitions ? 1 : 0
        )
        text.withCString { em_stream_update(handle, $0, text.utf8.count, flags, streaming ? 1 : 0) }
        if let bytes = em_stream_source(handle) {
            source = String(decoding: UnsafeRawBufferPointer(start: bytes, count: Int(em_stream_source_length(handle))), as: UTF8.self)
        } else {
            source = ""
        }
        guard let root = em_stream_root(handle) else {
            children = []
            return MarkdownASTNode(type: .document)
        }
        let count = Int(em_ast_node_child_count(root))
        let shared = min(Int(em_stream_shared_blocks(handle)), min(children.count, count))
        var next = Array(children.prefix(shared))
        for index in shared..<count {
            if let node = em_ast_node_child_at(root, index) {
                next.append(MarkdownParserBridge.convertNode(node))
            }
        }
        children = next
        return MarkdownASTNode(type: .document, children: children)
    }
}
