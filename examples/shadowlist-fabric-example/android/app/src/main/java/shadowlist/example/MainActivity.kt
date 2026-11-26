package shadowlist.example

import android.os.Bundle
import com.facebook.react.ReactActivity
import com.facebook.react.ReactActivityDelegate
import com.facebook.react.defaults.DefaultNewArchitectureEntryPoint.fabricEnabled
import com.facebook.react.defaults.DefaultReactActivityDelegate

class MainActivity : ReactActivity() {

  override fun getMainComponentName(): String = "ShadowListExample"

  /*
   * Keeps the SL* intent extras for JS. LaunchSettings reads them.
   */
  override fun onCreate(savedInstanceState: Bundle?) {
    LaunchSettings.capture(intent?.extras)
    super.onCreate(savedInstanceState)
    // Layout checks: makes the external files folder ShadowRuler captures go to (SLRulerDir).
    if (LaunchSettings.values["SLRuler"] == "1") {
      getExternalFilesDir(null)
    }
    if (LaunchSettings.values["SLRoute"] == "Bench") {
      BenchMonitor(this, anchors = LaunchSettings.values["SLOps"] == "1").start()
    }
  }

  override fun createReactActivityDelegate(): ReactActivityDelegate =
      DefaultReactActivityDelegate(this, mainComponentName, fabricEnabled)
}
