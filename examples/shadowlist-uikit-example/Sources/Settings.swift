import Foundation

/*
 * Launch arguments, the same names the React Native example reads: -SLRoute Feed -SLCount 1000
 * -SLDebug 1. -SLEngine picks the list implementation.
 */
enum Engine: String, CaseIterable {
  /*
   * The ShadowListUtils template list of the screen, with sizes from its precomputed layouts.
   */
  case shadowlist = "sl"
  /*
   * ShadowListKitListView with the library's rows, measuring each through its cell's sizeThatFits
   * on the main thread.
   */
  case shadowlistAuto = "sl-auto"
  /*
   * UITableView hosting the library's row views, with heightForRowAt from the same precomputed
   * layouts. Grids use a UICollectionView with a custom column layout instead.
   */
  case table = "table"
  /*
   * UITableView with self-sizing rows and an estimated height. Grids use the custom column
   * layout with each row's height computed once on the main thread.
   */
  case tableAuto = "table-auto"
  /*
   * UICollectionView with a compositional layout, a diffable data source and prefetching, the
   * setup Apple recommends for new lists. Rows size themselves from the same precomputed
   * layouts, or take an absolute height when every row has the same one. Grids use the custom
   * column layout of the table engines.
   */
  case collection = "collection"
  /*
   * The compositional collection with self-sizing rows measured through sizeThatFits.
   */
  case collectionAuto = "collection-auto"

  var title: String {
    switch self {
    case .shadowlist: return "ShadowListKitListView"
    case .shadowlistAuto: return "ShadowListKitListView (self-sizing)"
    case .table: return "UITableView, UICollectionView in grids"
    case .tableAuto: return "UITableView (self-sizing), UICollectionView in grids"
    case .collection: return "UICollectionView, compositional and diffable"
    case .collectionAuto: return "UICollectionView, compositional and diffable (self-sizing)"
    }
  }

  var isShadowList: Bool { self == .shadowlist || self == .shadowlistAuto }
  var selfSizing: Bool { self == .shadowlistAuto || self == .tableAuto || self == .collectionAuto }
  var isCompositional: Bool { self == .collection || self == .collectionAuto }
}

enum Settings {
  private static let defaults = UserDefaults.standard

  static var route: String? { defaults.string(forKey: "SLRoute") }
  static var engine: Engine { Engine(rawValue: defaults.string(forKey: "SLEngine") ?? "") ?? .shadowlist }
  static var count: Int {
    let value = defaults.integer(forKey: "SLCount")
    return value > 0 ? value : 1000
  }
  static var debug: Bool { defaults.string(forKey: "SLDebug") == "1" }
  static var images: Bool { defaults.string(forKey: "SLImages") != "0" }

  /*
   * -SLImages local: the fixtures' images come from files the app draws once on the device, for
   * benchmarks that must not wait on the network. They still go through the image loader.
   */
  static var localImages: Bool { defaults.string(forKey: "SLImages") == "local" }

  /*
   * -SLStates 1: the Feed and Chat screens also show what their fixtures lack: placeholder
   * posts, messages that are sending or failed, and captions.
   */
  static var states: Bool { defaults.string(forKey: "SLStates") == "1" }
}
