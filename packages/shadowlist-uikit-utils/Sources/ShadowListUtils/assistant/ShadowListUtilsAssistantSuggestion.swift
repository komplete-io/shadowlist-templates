/*
 * A suggested prompt. Selection returns this application-owned value unchanged.
 */
public struct ShadowListUtilsAssistantSuggestion: Hashable {
  public var title: String
  public var prompt: String
  public var description: String?
  public init(title: String, prompt: String, description: String? = nil) { self.title = title; self.prompt = prompt; self.description = description }
}
