import ShadowListKit
import ShadowListUtils
import UIKit

/*
 * What changed between two row lists. UITableView needs it to keep the visible rows still;
 * ShadowListKitListView works it out from the keys.
 */
enum RowChange {
  case reset
  case prepend(Int)
  case append(Int)
  /*
   * Rows inserted at these indices of the new rows, or deleted at these indices of the rows
   * before. The visible rows stay where they are.
   */
  case insert(IndexSet)
  case delete(IndexSet)
  case update
}

/*
 * One list API over the engines being compared. With the sl engine it shows the screen's
 * ShadowListUtils template list. With the others the screen hands it the library's rows and it
 * shows them with ShadowListKitListView, UITableView, or for a grid UICollectionView.
 */
final class ListController: NSObject {
  let engine: Engine
  let columns: Int
  let cache = ShadowListUtilsLayoutCache()

  /*
   * The template list, or nil with an engine that hosts the rows itself.
   */
  let template: ShadowListUtilsList?

  private var hostedRows: [ShadowListUtilsRow] = []

  var rows: [ShadowListUtilsRow] { template?.rows ?? hostedRows }

  var onStartReached: (() -> Void)? {
    didSet { template?.onStartReached = onStartReached }
  }

  var onEndReached: (() -> Void)? {
    didSet { template?.onEndReached = onEndReached }
  }

  /*
   * Set by the cost scenario while it times updates. Prefetch work would compete with them.
   */
  var prefetchPaused = false

  private var backend: ListBackend!

  init(engine: Engine, template: ShadowListUtilsList? = nil, columns: Int = 1, inverted: Bool = false) {
    self.engine = engine
    self.columns = columns
    self.template = engine == .shadowlist ? template : nil
    super.init()
    if let template = self.template {
      backend = TemplateBackend(list: template)
    } else if engine.isShadowList {
      backend = ShadowListBackend(controller: self, inverted: inverted)
    } else if columns > 1 {
      backend = CollectionBackend(controller: self)
    } else if engine.isCompositional, !inverted {
      backend = CompositionalBackend(controller: self)
    } else {
      backend = TableBackend(controller: self, inverted: inverted)
    }
  }

  var view: UIScrollView { backend.scrollView }

  var header: UIView? {
    get { backend.header }
    set { backend.header = newValue }
  }

  var footer: UIView? {
    get { backend.footer }
    set { backend.footer = newValue }
  }

  var stickyIndices: [Int] = [] {
    didSet { backend.stickyIndicesChanged() }
  }

  /*
   * Called after a dragged row was dropped and rows already holds the new order. A template list
   * reports the move through its own onMoveItem.
   */
  var onMove: ((Int, Int) -> Void)?

  var reorderEnabled = false {
    didSet { backend.reorderEnabled = reorderEnabled }
  }

  var snapToItem = false {
    didSet { backend.snapToItem = snapToItem }
  }

  /*
   * The height of every row, for a screen whose rows all have one. The table takes it as its
   * rowHeight and the compositional layout as an absolute height, their fastest setups. Set it
   * before the first rows.
   */
  var fixedRowHeight: CGFloat? {
    didSet { backend.fixedRowHeightChanged() }
  }

  func moveRow(from: Int, to: Int) {
    let row = hostedRows.remove(at: from)
    hostedRows.insert(row, at: to)
    onMove?(from, to)
  }

  var rowWidth: CGFloat {
    let width = view.bounds.width - view.adjustedContentInset.left - view.adjustedContentInset.right
    return columns > 1 ? floor(width / CGFloat(columns)) : width
  }

  /*
   * How long the last backend update took on the main thread, for the cost scenario.
   */
  private(set) var lastUpdateSeconds: CFTimeInterval = 0

  /*
   * Show the rows with an engine that hosts them. The template list takes its items from the
   * screen instead, inside update.
   */
  func setRows(_ rows: [ShadowListUtilsRow], change: RowChange) {
    hostedRows = rows
    if !engine.selfSizing, !prefetchPaused {
      cache.prefetch(rows, width: rowWidth, around: 0, extent: prefetchExtent)
    }
    update { backend.rowsChanged(change) }
  }

  /*
   * Run a data update and keep how long it took.
   */
  func update(_ work: () -> Void) {
    let start = CACurrentMediaTime()
    work()
    lastUpdateSeconds = CACurrentMediaTime() - start
  }

  func scrollToItem(at index: Int, animated: Bool) {
    backend.scrollToItem(at: index, animated: animated)
  }

  func scrollToEnd(animated: Bool) {
    backend.scrollToEnd(animated: animated)
  }

  private var prefetchOffset = -CGFloat.greatestFiniteMagnitude

  /*
   * How far the hosted engines lay rows out ahead, the template list's eight viewports.
   */
  var prefetchExtent: CGFloat {
    view.bounds.height > 0 ? view.bounds.height * 8 : .infinity
  }

  /*
   * Layouts made ahead while the hosted engines scroll, by the policy the template list follows:
   * around the first visible row, each time the offset moved half a viewport. UIKit's own
   * prefetching API does not run while ShadowListKitBench moves the offset. Without this a table
   * or a collection would lay rows out on the main thread in the comparison.
   */
  func scrolled(firstVisible: () -> Int?) {
    guard !engine.selfSizing, !prefetchPaused, abs(view.contentOffset.y - prefetchOffset) > view.bounds.height / 2,
      let index = firstVisible()
    else { return }
    prefetchOffset = view.contentOffset.y
    cache.prefetch(rows, width: rowWidth, around: index, extent: prefetchExtent)
  }

  /*
   * The layout a cell shows, or nil when the engine sizes rows from their views.
   */
  func cachedLayout(_ row: ShadowListUtilsRow, width: CGFloat) -> ShadowListUtilsRowLayout? {
    engine.selfSizing ? nil : cache.layout(row, width: width)
  }
}

protocol ListBackend: AnyObject {
  var scrollView: UIScrollView { get }
  var reorderEnabled: Bool { get set }
  var snapToItem: Bool { get set }
  var header: UIView? { get set }
  var footer: UIView? { get set }
  func rowsChanged(_ change: RowChange)
  func stickyIndicesChanged()
  func scrollToItem(at index: Int, animated: Bool)
  func scrollToEnd(animated: Bool)
  func fixedRowHeightChanged()
}

extension ListBackend {
  func fixedRowHeightChanged() {}
}

// MARK: - ShadowListUtils template

/*
 * The screen's template list. It holds its own items and rows, and the controller only passes
 * the header, the footer and the scroll commands on.
 */
final class TemplateBackend: NSObject, ListBackend {
  private let list: ShadowListUtilsList

  init(list: ShadowListUtilsList) {
    self.list = list
    super.init()
    list.alwaysBounceVertical = true
    list.estimatedItemSize = 120
  }

  var scrollView: UIScrollView { list }

  var reorderEnabled: Bool {
    get { list.reorderEnabled }
    set { list.reorderEnabled = newValue }
  }

  var snapToItem: Bool {
    get { list.snapToItem }
    set { list.snapToItem = newValue }
  }

  var header: UIView? {
    get { list.headerView }
    set { list.headerView = newValue }
  }

  var footer: UIView? {
    get { list.footerView }
    set { list.footerView = newValue }
  }

  func rowsChanged(_ change: RowChange) {}

  func stickyIndicesChanged() {}

  func scrollToItem(at index: Int, animated: Bool) {
    list.scrollToItem(at: index, viewPosition: 0, animated: animated)
  }

  func scrollToEnd(animated: Bool) {
    list.scrollToEnd(animated: animated)
  }
}

// MARK: - ShadowListKitListView

/*
 * A plain kit list with the library's rows, the way an app uses the rows without a template.
 */
final class ShadowListBackend: NSObject, ListBackend, ShadowListKitListViewDataSource, ShadowListKitListViewDelegate {
  private unowned let controller: ListController
  private let list = ShadowListKitListView()
  private var registered = Set<String>()

  init(controller: ListController, inverted: Bool) {
    self.controller = controller
    super.init()
    list.backgroundColor = AppTheme.colors.background
    list.isInverted = inverted
    list.numberOfColumns = controller.columns
    list.alwaysBounceVertical = true
    list.allowsSelection = false
    list.dataSource = self
    list.delegate = self
    list.estimatedItemSize = 120
  }

  var scrollView: UIScrollView { list }

  var reorderEnabled: Bool {
    get { list.reorderEnabled }
    set { list.reorderEnabled = newValue }
  }

  var snapToItem: Bool {
    get { list.snapToItem }
    set { list.snapToItem = newValue }
  }

  func listView(_ listView: ShadowListKitListView, moveItemAt sourceIndex: Int, to destinationIndex: Int) {
    controller.moveRow(from: sourceIndex, to: destinationIndex)
  }

  var header: UIView? {
    get { list.headerView }
    set { list.headerView = newValue }
  }

  var footer: UIView? {
    get { list.footerView }
    set { list.footerView = newValue }
  }

  func rowsChanged(_ change: RowChange) {
    switch change {
    case .prepend(let count):
      list.insertItems(at: IndexSet(integersIn: 0..<count))
    case .append(let count):
      let total = controller.rows.count
      list.insertItems(at: IndexSet(integersIn: (total - count)..<total))
    case .insert(let indices):
      list.insertItems(at: indices)
    case .delete(let indices):
      list.deleteItems(at: indices)
    case .reset, .update:
      list.reloadData()
    }
  }

  func stickyIndicesChanged() {
    list.stickyIndices = IndexSet(controller.stickyIndices)
  }

  func scrollToItem(at index: Int, animated: Bool) {
    list.scrollToItem(at: index, viewPosition: 0, animated: animated)
  }

  func scrollToEnd(animated: Bool) {
    list.scrollToEnd(animated: animated)
  }

  func numberOfItems(in listView: ShadowListKitListView) -> Int {
    controller.rows.count
  }

  func listView(_ listView: ShadowListKitListView, keyForItemAt index: Int) -> String {
    controller.rows[index].key
  }

  func listView(_ listView: ShadowListKitListView, cellForItemAt index: Int) -> ShadowListKitListCell {
    let row = controller.rows[index]
    let identifier = NSStringFromClass(row.viewClass)
    if registered.insert(identifier).inserted {
      listView.register(row.viewClass, forCellReuseIdentifier: identifier)
    }
    let cell = listView.dequeueReusableCell(withIdentifier: identifier)
    let width = controller.columns > 1 ? controller.rowWidth : listView.bounds.width
    (cell as? ShadowListUtilsRowView)?.configure(row, layout: controller.cachedLayout(row, width: width))
    return cell
  }

  /*
   * The precomputed sizes are only offered in the fast mode. Without them the list measures
   * every row through its cell, and respondsToSelector is what it asks.
   */
  override func responds(to selector: Selector!) -> Bool {
    if selector == #selector(ShadowListKitListViewDataSource.listView(_:sizeForItemAt:crossSize:)) {
      return !controller.engine.selfSizing
    }
    return super.responds(to: selector)
  }

  func listView(_ listView: ShadowListKitListView, sizeForItemAt index: Int, crossSize: CGFloat) -> CGFloat {
    controller.cache.layout(controller.rows[index], width: crossSize).height
  }

  func listViewDidReachStart(_ listView: ShadowListKitListView) {
    controller.onStartReached?()
  }

  func listViewDidReachEnd(_ listView: ShadowListKitListView) {
    controller.onEndReached?()
  }
}

/*
 * Keeps the first visible row where it is on screen across a change that moves it in the
 * content, the usual recipe of a table or a collection: read its place, change, lay out and put
 * the offset back. frame gives a row's frame in the content by row index.
 */
struct VisibleAnchor {
  private let index: Int
  private let distance: CGFloat

  init?(_ scrollView: UIScrollView, first index: Int?, frame: (Int) -> CGRect?) {
    guard let index, let rect = frame(index) else { return nil }
    self.index = index
    distance = rect.minY - scrollView.contentOffset.y
  }

  /*
   * Put the row back after the change. moved is the row's index after it, nil when it left.
   */
  func restore(_ scrollView: UIScrollView, moved: Int?, frame: (Int) -> CGRect?) {
    guard let moved, let rect = frame(moved) else { return }
    scrollView.layoutIfNeeded()
    let inset = scrollView.adjustedContentInset
    let maxOffset = max(-inset.top, scrollView.contentSize.height - scrollView.bounds.height + inset.bottom)
    scrollView.contentOffset.y = min(max(-inset.top, rect.minY - distance), maxOffset)
  }

  /*
   * Where the row is after rows were inserted at, or deleted from, these indices.
   */
  func moved(by change: RowChange) -> Int? {
    switch change {
    case .insert(let indices):
      // Insert indices are places in the new rows: each one at or before the row pushes it on.
      var moved = index
      for inserted in indices where inserted <= moved {
        moved += 1
      }
      return moved
    case .delete(let indices):
      return indices.contains(index) ? nil : index - indices.count(in: 0..<index)
    default:
      return index
    }
  }
}

/*
 * Puts one of the library's row views into the content view of a table or collection cell. A
 * row view is a plain view when it has no reuse identifier.
 */
final class RowHost {
  private(set) var rowView: ShadowListUtilsRowView?

  func show(_ row: ShadowListUtilsRow, layout: ShadowListUtilsRowLayout?, in contentView: UIView) {
    if rowView == nil || rowView.map({ type(of: $0) != row.viewClass }) == true {
      rowView?.removeFromSuperview()
      let view = row.viewClass.init(reuseIdentifier: nil)
      view.frame = contentView.bounds
      contentView.addSubview(view)
      rowView = view
    }
    rowView?.configure(row, layout: layout)
  }

  func sizeThatFits(width: CGFloat) -> CGSize {
    rowView?.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)) ?? .zero
  }
}

// MARK: - UITableView

final class TableCell: UITableViewCell {
  private let host = RowHost()

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    selectionStyle = .none
    backgroundColor = AppTheme.colors.background
  }

  required init?(coder: NSCoder) { fatalError() }

  func show(_ row: ShadowListUtilsRow, layout: ShadowListUtilsRowLayout?) {
    host.show(row, layout: layout, in: contentView)
  }

  override func systemLayoutSizeFitting(
    _ targetSize: CGSize, withHorizontalFittingPriority horizontal: UILayoutPriority, verticalFittingPriority vertical: UILayoutPriority
  ) -> CGSize {
    host.sizeThatFits(width: targetSize.width)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    host.rowView?.frame = contentView.bounds
  }
}

final class TableHeader: UITableViewHeaderFooterView {
  private let host = RowHost()

  func show(_ row: ShadowListUtilsRow, layout: ShadowListUtilsRowLayout?) {
    host.show(row, layout: layout, in: contentView)
  }

  override func systemLayoutSizeFitting(
    _ targetSize: CGSize, withHorizontalFittingPriority horizontal: UILayoutPriority, verticalFittingPriority vertical: UILayoutPriority
  ) -> CGSize {
    host.sizeThatFits(width: targetSize.width)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    host.rowView?.frame = contentView.bounds
  }
}

final class TableBackend: NSObject, ListBackend, UITableViewDataSource, UITableViewDelegate, UITableViewDataSourcePrefetching,
  UITableViewDragDelegate, UITableViewDropDelegate
{
  private unowned let controller: ListController
  private let table = UITableView(frame: .zero, style: .plain)
  private let inverted: Bool
  private var registered = Set<String>()
  private var startReachedArmed = true
  private var endReachedArmed = true

  /*
   * Sections when the list has sticky headers: the header row and the rows under it.
   */
  private var sections: [(header: Int?, rows: Range<Int>)] = []

  init(controller: ListController, inverted: Bool) {
    self.controller = controller
    self.inverted = inverted
    super.init()
    table.backgroundColor = AppTheme.colors.background
    table.separatorStyle = .none
    table.dataSource = self
    table.delegate = self
    table.prefetchDataSource = self
    table.sectionHeaderTopPadding = 0
    table.register(TableHeader.self, forHeaderFooterViewReuseIdentifier: "header")
    if controller.engine.selfSizing {
      table.rowHeight = UITableView.automaticDimension
      table.estimatedRowHeight = 120
      table.sectionHeaderHeight = UITableView.automaticDimension
      table.estimatedSectionHeaderHeight = 38
    } else {
      table.estimatedRowHeight = 0
      table.estimatedSectionHeaderHeight = 0
    }
  }

  var scrollView: UIScrollView { table }

  /*
   * Rows of one height go in as the table's rowHeight without heightForRowAt, the fastest setup
   * UITableView has. The table reads which delegate methods exist when the delegate is set.
   */
  func fixedRowHeightChanged() {
    guard let height = controller.fixedRowHeight, !controller.engine.selfSizing else { return }
    table.rowHeight = height
    table.estimatedRowHeight = 0
    table.delegate = nil
    table.delegate = self
  }

  override func responds(to selector: Selector!) -> Bool {
    if selector == #selector(UITableViewDelegate.tableView(_:heightForRowAt:)) {
      return controller.fixedRowHeight == nil || controller.engine.selfSizing
    }
    return super.responds(to: selector)
  }

  /*
   * Rows about to show get their layouts made off the main thread, ahead of the cells, the way
   * the prefetching API is meant to be used.
   */
  func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
    if BenchWindow.enabled, let last = indexPaths.max() {
      BenchWindow.prefetched(tableView.rectForRow(at: last), in: tableView)
    }
    guard !controller.engine.selfSizing, !controller.prefetchPaused, let first = indexPaths.min() else { return }
    controller.cache.prefetch(controller.rows, width: tableView.bounds.width, around: rowIndex(first), extent: controller.prefetchExtent)
  }

  /*
   * Reordering through UITableView's own drag and drop, started by touch and hold.
   */
  var reorderEnabled = false {
    didSet {
      table.dragInteractionEnabled = reorderEnabled
      table.dragDelegate = reorderEnabled ? self : nil
      table.dropDelegate = reorderEnabled ? self : nil
    }
  }

  var snapToItem = false

  func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
    [UIDragItem(itemProvider: NSItemProvider())]
  }

  func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
    UITableViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
  }

  func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {}

  func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
    reorderEnabled
  }

  func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
    controller.moveRow(from: rowIndex(sourceIndexPath), to: rowIndex(destinationIndexPath))
    rebuildSections()
  }

  /*
   * Snapping by hand: rest on the row edge nearest to where the fling would stop.
   */
  func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
    guard snapToItem else { return }
    let inset = table.adjustedContentInset.top
    let target = targetContentOffset.pointee.y + inset
    let probe = CGRect(x: 0, y: target - table.bounds.height, width: 1, height: table.bounds.height * 2)
    var best = target
    var bestDistance = CGFloat.greatestFiniteMagnitude
    for path in table.indexPathsForRows(in: probe) ?? [] {
      let top = table.rectForRow(at: path).minY
      if abs(top - target) < bestDistance {
        bestDistance = abs(top - target)
        best = top
      }
    }
    let maxOffset = max(0, table.contentSize.height - table.bounds.height + table.adjustedContentInset.bottom + inset)
    targetContentOffset.pointee.y = min(best, maxOffset) - inset
  }

  /*
   * A table takes its header and footer at the size they have. The library's views report
   * theirs through sizeThatFits.
   */
  var header: UIView? {
    get { table.tableHeaderView }
    set { table.tableHeaderView = newValue.map(sized) }
  }

  var footer: UIView? {
    get { table.tableFooterView }
    set { table.tableFooterView = newValue.map(sized) }
  }

  private func sized(_ view: UIView) -> UIView {
    let width = table.bounds.width > 0 ? table.bounds.width : UIScreen.main.bounds.width
    view.frame.size = view.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    return view
  }

  private func rebuildSections() {
    let rows = controller.rows.count
    let sticky = controller.stickyIndices.filter { $0 < rows }
    guard !sticky.isEmpty else {
      sections = [(nil, 0..<rows)]
      return
    }
    sections = []
    if sticky[0] > 0 {
      sections.append((nil, 0..<sticky[0]))
    }
    for (position, header) in sticky.enumerated() {
      let end = position + 1 < sticky.count ? sticky[position + 1] : rows
      sections.append((header, (header + 1)..<end))
    }
  }

  private func rowIndex(_ indexPath: IndexPath) -> Int {
    sections[indexPath.section].rows.lowerBound + indexPath.row
  }

  private func indexPath(_ index: Int) -> IndexPath? {
    for (section, entry) in sections.enumerated() {
      if entry.header == index {
        return IndexPath(row: NSNotFound, section: section)
      }
      if entry.rows.contains(index) {
        return IndexPath(row: index - entry.rows.lowerBound, section: section)
      }
    }
    return nil
  }

  func stickyIndicesChanged() {
    rebuildSections()
    table.reloadData()
  }

  func rowsChanged(_ change: RowChange) {
    let previousSections = sections
    rebuildSections()
    switch change {
    case .prepend(let count):
      // Keep the first visible row where it is, the usual UITableView recipe.
      guard let anchor = table.indexPathsForVisibleRows?.first else {
        table.reloadData()
        return
      }
      let before = table.rectForRow(at: anchor).minY - table.contentOffset.y
      table.reloadData()
      table.layoutIfNeeded()
      if let moved = indexPath(rowIndex(anchor) + count), moved.row != NSNotFound {
        table.contentOffset.y = table.rectForRow(at: moved).minY - before
      }
    case .reset:
      table.reloadData()
      if inverted, let last = lastIndexPath() {
        table.layoutIfNeeded()
        table.scrollToRow(at: last, at: .bottom, animated: false)
        // Self-sizing rows land on estimates first. A second pass lands on the real end.
        table.layoutIfNeeded()
        table.scrollToRow(at: last, at: .bottom, animated: false)
      }
    case .append(let count):
      // New rows at the end go in with insertRows, which keeps the heights the table measured.
      let total = controller.rows.count
      let paths = (total - count..<total).compactMap { indexPath($0) }
      if !previousSections.isEmpty, previousSections.count == sections.count, paths.count == count,
        paths.allSatisfy({ $0.row != NSNotFound && $0.section == sections.count - 1 })
      {
        UIView.performWithoutAnimation {
          table.insertRows(at: paths, with: .none)
        }
      } else {
        table.reloadData()
      }
    case .insert(let indices), .delete(let indices):
      // One section: insertRows and deleteRows, with the first visible row kept in place.
      guard sections.count == 1, previousSections.count == 1 else {
        table.reloadData()
        break
      }
      let frame: (Int) -> CGRect? = { [table] index in
        index < table.numberOfRows(inSection: 0) ? table.rectForRow(at: IndexPath(row: index, section: 0)) : nil
      }
      let anchor = VisibleAnchor(table, first: table.indexPathsForVisibleRows?.first?.row, frame: frame)
      let paths = indices.map { IndexPath(row: $0, section: 0) }
      UIView.performWithoutAnimation {
        if case .insert = change {
          table.insertRows(at: paths, with: .none)
        } else {
          table.deleteRows(at: paths, with: .none)
        }
      }
      anchor?.restore(table, moved: anchor?.moved(by: change), frame: frame)
    case .update:
      table.reloadData()
    }
    startReachedArmed = true
    endReachedArmed = true
  }

  private func lastIndexPath() -> IndexPath? {
    guard let section = sections.lastIndex(where: { !$0.rows.isEmpty }) else { return nil }
    return IndexPath(row: sections[section].rows.count - 1, section: section)
  }

  func scrollToItem(at index: Int, animated: Bool) {
    guard let path = indexPath(index) else { return }
    if path.row == NSNotFound {
      table.scrollToRow(at: IndexPath(row: NSNotFound, section: path.section), at: .top, animated: animated)
    } else {
      table.scrollToRow(at: path, at: .top, animated: animated)
    }
  }

  func scrollToEnd(animated: Bool) {
    if let last = lastIndexPath() {
      table.scrollToRow(at: last, at: .bottom, animated: animated)
    }
  }

  func numberOfSections(in tableView: UITableView) -> Int {
    sections.count
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    sections[section].rows.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let row = controller.rows[rowIndex(indexPath)]
    let identifier = NSStringFromClass(row.viewClass)
    if registered.insert(identifier).inserted {
      tableView.register(TableCell.self, forCellReuseIdentifier: identifier)
    }
    let cell = tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath) as! TableCell
    cell.show(row, layout: controller.cachedLayout(row, width: tableView.bounds.width))
    return cell
  }

  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    if controller.engine.selfSizing {
      return UITableView.automaticDimension
    }
    return controller.cache.layout(controller.rows[rowIndex(indexPath)], width: tableView.bounds.width).height
  }

  func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    guard let header = sections[section].header else { return nil }
    let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: "header") as! TableHeader
    let row = controller.rows[header]
    view.show(row, layout: controller.cachedLayout(row, width: tableView.bounds.width))
    return view
  }

  func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    guard let header = sections[section].header else { return 0 }
    if controller.engine.selfSizing {
      return UITableView.automaticDimension
    }
    return controller.cache.layout(controller.rows[header], width: tableView.bounds.width).height
  }

  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    controller.scrolled { table.indexPathsForVisibleRows?.first.map(rowIndex) }
    let offset = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
    let window = scrollView.bounds.height
    let maxOffset = scrollView.contentSize.height - window + scrollView.adjustedContentInset.bottom
    if offset < window {
      if startReachedArmed {
        startReachedArmed = false
        controller.onStartReached?()
      }
    } else {
      startReachedArmed = true
    }
    if offset > maxOffset - window {
      if endReachedArmed {
        endReachedArmed = false
        controller.onEndReached?()
      }
    } else {
      endReachedArmed = true
    }
  }
}

// MARK: - UICollectionView grid

/*
 * Round robin columns like the core: item i goes into column i % columns. Every frame is
 * worked out up front in prepare, the usual custom layout recipe, from row heights the layout
 * cache keeps across reloads.
 */
final class ColumnsLayout: UICollectionViewLayout {
  unowned var controller: ListController!
  private var frames: [CGRect] = []
  private var contentHeight: CGFloat = 0
  var footerHeight: CGFloat = 0

  override func prepare() {
    guard let collectionView else { return }
    let columns = controller.columns
    let width = controller.rowWidth
    var heights = [CGFloat](repeating: 0, count: columns)
    frames = controller.rows.enumerated().map { index, row in
      let column = index % columns
      let height = controller.cache.layout(row, width: width).height
      let frame = CGRect(x: CGFloat(column) * width, y: heights[column], width: width, height: height)
      heights[column] += height
      return frame
    }
    contentHeight = (heights.max() ?? 0) + footerHeight
    _ = collectionView
  }

  override var collectionViewContentSize: CGSize {
    CGSize(width: collectionView?.bounds.width ?? 0, height: contentHeight)
  }

  override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
    var result: [UICollectionViewLayoutAttributes] = []
    for (index, frame) in frames.enumerated() where frame.intersects(rect) {
      let attributes = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: index, section: 0))
      attributes.frame = frame
      result.append(attributes)
    }
    return result
  }

  override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
    let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
    attributes.frame = frames[indexPath.item]
    return attributes
  }

  override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
    newBounds.width != collectionView?.bounds.width
  }
}

final class GridCell: UICollectionViewCell {
  private let host = RowHost()

  func show(_ row: ShadowListUtilsRow, layout: ShadowListUtilsRowLayout?) {
    host.show(row, layout: layout, in: contentView)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    host.rowView?.frame = contentView.bounds
  }
}

final class CollectionBackend: NSObject, ListBackend, UICollectionViewDataSource, UICollectionViewDelegate {
  private unowned let controller: ListController
  private let layout = ColumnsLayout()
  private let collection: UICollectionView
  private var endReachedArmed = true

  init(controller: ListController) {
    self.controller = controller
    collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
    super.init()
    layout.controller = controller
    collection.backgroundColor = AppTheme.colors.background
    collection.dataSource = self
    collection.delegate = self
    collection.register(GridCell.self, forCellWithReuseIdentifier: "cell")
  }

  var scrollView: UIScrollView { collection }

  var reorderEnabled = false
  var snapToItem = false

  var header: UIView?

  var footer: UIView? {
    didSet {
      oldValue?.removeFromSuperview()
      if let footer {
        let width = collection.bounds.width > 0 ? collection.bounds.width : UIScreen.main.bounds.width
        footer.frame.size = footer.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        collection.addSubview(footer)
        layout.footerHeight = footer.frame.height
      }
    }
  }

  func rowsChanged(_ change: RowChange) {
    if case .prepend(let count) = change, let first = collection.indexPathsForVisibleItems.min() {
      let before = (layout.layoutAttributesForItem(at: first)?.frame.minY ?? 0) - collection.contentOffset.y
      collection.reloadData()
      collection.layoutIfNeeded()
      let moved = IndexPath(item: first.item + count, section: 0)
      collection.contentOffset.y = (layout.layoutAttributesForItem(at: moved)?.frame.minY ?? 0) - before
    } else {
      collection.reloadData()
    }
    endReachedArmed = true
  }

  func stickyIndicesChanged() {}

  func scrollToItem(at index: Int, animated: Bool) {
    collection.scrollToItem(at: IndexPath(item: index, section: 0), at: .top, animated: animated)
  }

  func scrollToEnd(animated: Bool) {
    let count = controller.rows.count
    if count > 0 {
      collection.scrollToItem(at: IndexPath(item: count - 1, section: 0), at: .bottom, animated: animated)
    }
  }

  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    controller.rows.count
  }

  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! GridCell
    let row = controller.rows[indexPath.item]
    cell.show(row, layout: controller.cachedLayout(row, width: controller.rowWidth))
    return cell
  }

  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    controller.scrolled { collection.indexPathsForVisibleItems.min()?.item }
    if let footer {
      footer.frame = CGRect(x: 0, y: scrollView.contentSize.height - footer.frame.height, width: scrollView.bounds.width, height: footer.frame.height)
    }
    let offset = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
    let window = scrollView.bounds.height
    if offset > scrollView.contentSize.height - 2 * window {
      if endReachedArmed {
        endReachedArmed = false
        controller.onEndReached?()
      }
    } else {
      endReachedArmed = true
    }
  }
}

// MARK: - UICollectionView, compositional and diffable

/*
 * A collection cell that shows one of the library's row views. Self-sizing asks it for its
 * height: from the row's precomputed layout with the collection engine, through the row view's
 * sizeThatFits with collection-auto. A row of a fixed height keeps the size the layout gave it.
 */
final class CompositionalCell: UICollectionViewCell {
  private let host = RowHost()
  private var row: ShadowListUtilsRow?
  weak var controller: ListController?

  func show(_ row: ShadowListUtilsRow, layout: ShadowListUtilsRowLayout?) {
    self.row = row
    host.show(row, layout: layout, in: contentView)
  }

  override func preferredLayoutAttributesFitting(_ attributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
    guard let controller, let row, controller.fixedRowHeight == nil else { return attributes }
    let width = attributes.size.width
    attributes.size.height =
      controller.engine.selfSizing ? host.sizeThatFits(width: width).height : controller.cache.layout(row, width: width).height
    return attributes
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    host.rowView?.frame = contentView.bounds
  }
}

/*
 * UICollectionView set up the way Apple recommends for a list: a compositional layout of one
 * full width item per group, a diffable data source keyed by the row keys, and prefetching on,
 * with the prefetch data source making the layouts of the rows about to show off the main thread.
 * Rows take an absolute height when the screen gives one, else an estimate and self-sizing.
 * Changes go through snapshots edited in place. Header and footer views are not shown.
 */
final class CompositionalBackend: NSObject, ListBackend, UICollectionViewDelegate, UICollectionViewDataSourcePrefetching {
  private static let estimatedHeight: CGFloat = 120
  private static let section = 0

  private unowned let controller: ListController
  private let collection: UICollectionView
  private var dataSource: UICollectionViewDiffableDataSource<Int, String>!
  private var startReachedArmed = true
  private var endReachedArmed = true

  init(controller: ListController) {
    self.controller = controller
    let layout = UICollectionViewCompositionalLayout { [unowned controller] _, _ in
      let height: NSCollectionLayoutDimension = controller.fixedRowHeight.map { .absolute($0) } ?? .estimated(Self.estimatedHeight)
      let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: height)
      let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [NSCollectionLayoutItem(layoutSize: size)])
      return NSCollectionLayoutSection(group: group)
    }
    collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
    super.init()
    collection.backgroundColor = AppTheme.colors.background
    collection.alwaysBounceVertical = true
    collection.delegate = self
    collection.prefetchDataSource = self
    collection.isPrefetchingEnabled = true
    collection.register(CompositionalCell.self, forCellWithReuseIdentifier: "row")
    dataSource = UICollectionViewDiffableDataSource(collectionView: collection) { [unowned controller] collectionView, indexPath, _ in
      let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "row", for: indexPath) as! CompositionalCell
      let row = controller.rows[indexPath.item]
      cell.controller = controller
      cell.show(row, layout: controller.cachedLayout(row, width: collectionView.bounds.width))
      return cell
    }
  }

  var scrollView: UIScrollView { collection }
  var reorderEnabled = false
  var snapToItem = false
  var header: UIView?
  var footer: UIView?

  func fixedRowHeightChanged() {
    collection.collectionViewLayout.invalidateLayout()
  }

  func stickyIndicesChanged() {}

  private func fullSnapshot() -> NSDiffableDataSourceSnapshot<Int, String> {
    var snapshot = NSDiffableDataSourceSnapshot<Int, String>()
    snapshot.appendSections([Self.section])
    snapshot.appendItems(controller.rows.map(\.key))
    return snapshot
  }

  private func frame(_ index: Int) -> CGRect? {
    guard index < collection.numberOfItems(inSection: Self.section) else { return nil }
    return collection.layoutAttributesForItem(at: IndexPath(item: index, section: Self.section))?.frame
  }

  func rowsChanged(_ change: RowChange) {
    defer {
      startReachedArmed = true
      endReachedArmed = true
    }
    let keys = controller.rows.map(\.key)
    var snapshot = dataSource.snapshot()
    switch change {
    case .reset, .update:
      dataSource.applySnapshotUsingReloadData(fullSnapshot())
      return
    case .append(let count):
      snapshot.appendItems(Array(keys.suffix(count)), toSection: Self.section)
      dataSource.apply(snapshot, animatingDifferences: false)
      return
    case .prepend(let count):
      return apply(.insert(IndexSet(integersIn: 0..<count)), keys: keys, snapshot: &snapshot)
    case .insert, .delete:
      return apply(change, keys: keys, snapshot: &snapshot)
    }
  }

  /*
   * Insert or delete rows in the snapshot in place, with the first visible row kept still.
   */
  private func apply(_ change: RowChange, keys: [String], snapshot: inout NSDiffableDataSourceSnapshot<Int, String>) {
    guard snapshot.numberOfSections == 1 else {
      dataSource.applySnapshotUsingReloadData(fullSnapshot())
      return
    }
    let first = collection.indexPathsForVisibleItems.min()?.item
    let anchor = VisibleAnchor(collection, first: first, frame: frame)
    switch change {
    case .insert(let indices):
      // Each run of new keys goes before the key that follows it, or at the end.
      for range in indices.rangeView.reversed() {
        let added = Array(keys[range])
        if range.upperBound < keys.count {
          snapshot.insertItems(added, beforeItem: keys[range.upperBound])
        } else {
          snapshot.appendItems(added, toSection: Self.section)
        }
      }
    case .delete(let indices):
      let previous = snapshot.itemIdentifiers
      snapshot.deleteItems(indices.map { previous[$0] })
    default:
      break
    }
    dataSource.apply(snapshot, animatingDifferences: false)
    anchor?.restore(collection, moved: anchor?.moved(by: change), frame: frame)
  }

  func scrollToItem(at index: Int, animated: Bool) {
    guard index < collection.numberOfItems(inSection: Self.section) else { return }
    collection.scrollToItem(at: IndexPath(item: index, section: Self.section), at: .top, animated: animated)
  }

  func scrollToEnd(animated: Bool) {
    let count = collection.numberOfItems(inSection: Self.section)
    if count > 0 {
      collection.scrollToItem(at: IndexPath(item: count - 1, section: Self.section), at: .bottom, animated: animated)
    }
  }

  func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
    if BenchWindow.enabled {
      for path in indexPaths {
        if let frame = collectionView.layoutAttributesForItem(at: path)?.frame {
          BenchWindow.prefetched(frame, in: collectionView)
        }
      }
    }
    guard !controller.engine.selfSizing, !controller.prefetchPaused, let first = indexPaths.min() else { return }
    controller.cache.prefetch(controller.rows, width: collectionView.bounds.width, around: first.item, extent: controller.prefetchExtent)
  }

  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    controller.scrolled { collection.indexPathsForVisibleItems.min()?.item }
    let offset = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
    let window = scrollView.bounds.height
    let maxOffset = scrollView.contentSize.height - window + scrollView.adjustedContentInset.bottom
    if offset < window {
      if startReachedArmed {
        startReachedArmed = false
        controller.onStartReached?()
      }
    } else {
      startReachedArmed = true
    }
    if offset > maxOffset - window {
      if endReachedArmed {
        endReachedArmed = false
        controller.onEndReached?()
      }
    } else {
      endReachedArmed = true
    }
  }
}
