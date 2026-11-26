import Foundation
import os
import UIKit

/*
 * Row layouts by row key, filled ahead on a background queue. A layout is kept for the reuse
 * identifier, the width and the content version it was made for, and made again when one
 * differs. Each prefetch drops the layouts of rows further than twice prefetchRadius from where it starts,
 * which bounds the cache however far the list scrolls, and a memory warning drops them all.
 * layout requires the main thread for ShadowListUtilsMainThreadRow; prefetch skips those rows.
 */
public final class ShadowListUtilsLayoutCache {
  private struct Entry {
    let reuseIdentifier: String
    let width: CGFloat
    let contentVersion: Int
    let layout: ShadowListUtilsRowLayout
  }

  private struct State {
    var entries: [String: Entry] = [:]
    var generation = 0

    /*
     * Counts the times layouts were dropped. A layout that was being made on another thread
     * while they were is not kept: what it was made from, like the text size, may be gone.
     */
    var invalidations = 0
  }

  /*
   * The most rows on each side of the given index one prefetch lays out. A prefetch given an
   * extent stops sooner on a side, once the rows it laid out there are that long. It keeps twice
   * as many rows on each side as it reached.
   */
  static let prefetchRadius = 100

  private let state = OSAllocatedUnfairLock(uncheckedState: State())
  private let queue = DispatchQueue(label: "com.shadowlist.utils.layout", qos: .userInitiated)

  private var memoryWarning: NSObjectProtocol?

  public init() {
    memoryWarning = NotificationCenter.default.addObserver(
      forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: nil
    ) { [weak self] _ in
      self?.invalidateAll()
    }
  }

  deinit {
    memoryWarning.map(NotificationCenter.default.removeObserver)
  }

  /*
   * The row's layout for a width, from the cache or computed now.
   */
  public func layout(_ row: ShadowListUtilsRow, width: CGFloat) -> ShadowListUtilsRowLayout {
    precondition(!(row is ShadowListUtilsMainThreadRow) || Thread.isMainThread)
    let key = row.key
    let reuseIdentifier = row.reuseIdentifier
    let contentVersion = row.contentVersion
    let (found, started) = state.withLockUnchecked { state -> (ShadowListUtilsRowLayout?, Int) in
      guard let entry = state.entries[key], entry.reuseIdentifier == reuseIdentifier, entry.width == width,
        entry.contentVersion == contentVersion
      else {
        return (nil, state.invalidations)
      }
      return (entry.layout, state.invalidations)
    }
    if let found {
      return found
    }
    let layout = row.layout(width: width)
    state.withLockUnchecked { state in
      guard state.invalidations == started else { return }
      state.entries[key] = Entry(reuseIdentifier: reuseIdentifier, width: width, contentVersion: contentVersion, layout: layout)
    }
    return layout
  }

  /*
   * Lay out rows the list has not reached yet, off the main thread: the row at the given index
   * and the rows on each side of it, nearest first, up to prefetchRadius rows or extent points
   * on a side. The layouts of rows further away than twice that are dropped, and of rows further
   * than twice the radius before it starts. A newer call replaces the one still running.
   */
  public func prefetch(_ rows: [ShadowListUtilsRow], width: CGFloat, around index: Int = 0, extent: CGFloat = .infinity) {
    guard width > 0, !rows.isEmpty else { return }
    let generation = state.withLockUnchecked { state -> Int in
      state.generation += 1
      return state.generation
    }
    let center = min(max(index, 0), rows.count - 1)
    queue.async { [weak self] in
      guard let self else { return }
      // A prefetch a newer one cuts short still bounds the cache by twice the radius.
      self.dropLayouts(
        outside: rows, from: max(0, center - 2 * Self.prefetchRadius), through: min(rows.count - 1, center + 2 * Self.prefetchRadius),
        generation: generation)
      // Outward from the center, a row on each side in turn, until each side is long enough.
      var low = center
      var high = center
      var lowLength: CGFloat = 0
      var highLength: CGFloat = 0
      guard self.prefetchRow(rows[center], width: width, generation: generation) != nil else { return }
      for _ in 0..<Self.prefetchRadius {
        let lowNext = low > 0 && lowLength <= extent
        let highNext = high < rows.count - 1 && highLength <= extent
        if !lowNext && !highNext { break }
        if highNext {
          guard let height = self.prefetchRow(rows[high + 1], width: width, generation: generation) else { return }
          high += 1
          highLength += height
        }
        if lowNext {
          guard let height = self.prefetchRow(rows[low - 1], width: width, generation: generation) else { return }
          low -= 1
          lowLength += height
        }
      }
      self.dropLayouts(outside: rows, from: max(0, 2 * low - center), through: min(rows.count - 1, 2 * high - center), generation: generation)
    }
  }

  /*
   * A prefetched row's height, or nil when a newer prefetch started.
   */
  private func prefetchRow(_ row: ShadowListUtilsRow, width: CGFloat, generation: Int) -> CGFloat? {
    guard state.withLockUnchecked({ $0.generation == generation }) else { return nil }
    // Skip UIKit-backed rows; zero only advances this speculative traversal, never a cached height.
    if row is ShadowListUtilsMainThreadRow { return 0 }
    return layout(row, width: width).height
  }

  /*
   * Drop the layouts of every key but the rows from low through high, unless a newer prefetch
   * started.
   */
  private func dropLayouts(outside rows: [ShadowListUtilsRow], from low: Int, through high: Int, generation: Int) {
    let kept = Set(rows[low...high].map(\.key))
    state.withLockUnchecked { state in
      guard state.generation == generation else { return }
      state.entries = state.entries.filter { kept.contains($0.key) }
    }
  }

  public func invalidate(_ key: String) {
    state.withLockUnchecked { state in
      state.invalidations += 1
      state.entries.removeValue(forKey: key)
    }
  }

  public func invalidateAll() {
    state.withLockUnchecked { state in
      state.generation += 1
      state.invalidations += 1
      state.entries.removeAll()
    }
  }

  /*
   * Drop the layouts of keys that left the data, and end the prefetch still running over the
   * rows before. A list calls it with the keys of the rows it shows now.
   */
  func prune(keeping keys: Set<String>) {
    state.withLockUnchecked { state in
      state.generation += 1
      state.invalidations += 1
      state.entries = state.entries.filter { keys.contains($0.key) }
    }
  }

  /*
   * End the prefetch still running, like for a list that left its window.
   */
  func cancelPrefetch() {
    state.withLockUnchecked { $0.generation += 1 }
  }

  /*
   * How many layouts the cache holds.
   */
  var count: Int {
    state.withLockUnchecked { $0.entries.count }
  }
}
