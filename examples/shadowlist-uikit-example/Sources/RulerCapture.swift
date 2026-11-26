#if canImport(ShadowRuler)
import ShadowRuler
import UIKit

/*
 * -SLRuler 1, in a build generated with SHADOWRULER_ROOT: once the opening screen is on screen
 * and its rows show, ShadowRuler measures the window's views and stays drawn over them. The
 * capture, the snapshot with its measurements, goes to Documents/ruler.json and its path to an
 * [SLRULER] line. Run it with -SLLatency 0,0 so the fake network is not waited for.
 */
@MainActor
enum RulerCapture {
  private static var session: RulerSession?

  static func start(in window: UIWindow, navigation: UINavigationController) {
    guard UserDefaults.standard.string(forKey: "SLRuler") == "1" else { return }
    Frames.when({ navigation.transitionCoordinator == nil && navigation.topViewController?.viewIfLoaded?.window != nil }) {
      // Two frames for the rows a screen sets on its first layout to show.
      Frames.after(frames: 2) {
        MainActor.assumeIsolated { capture(window) }
      }
    }
  }

  private static func capture(_ window: UIWindow) {
    do {
      let ruler = try ShadowRuler.install(on: window)
      session = ruler
      let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("ruler.json")
      try ruler.writeCapture(to: url)
      print("[SLRULER] \(url.path)")
    } catch {
      print("[SLRULER] failed: \(error)")
    }
    fflush(stdout)
  }
}
#else
import UIKit

enum RulerCapture {
  static func start(in window: UIWindow, navigation: UINavigationController) {}
}
#endif
