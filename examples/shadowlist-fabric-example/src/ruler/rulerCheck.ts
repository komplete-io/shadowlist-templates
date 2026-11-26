import ShadowRulerModule from '@shadowruler/react-native';
import { launchSetting } from '../launchSettings';

export const RULER = launchSetting('SLRuler') === '1';

/*
 * The app's root view, measured instead of the key window: the window of a scene app is not
 * the one ShadowRuler finds on its own. App.tsx sets it while RULER is on.
 */
export const rulerTarget: { current: unknown } = { current: null };

/*
 * LAYOUT-CHECK-ONLY. With SLRuler 1 in a build made with SHADOWRULER=1 (see
 * react-native.config.js), measures the open screen once it went quiet: installs a ShadowRuler
 * session on the app's root view, writes its capture JSON and a PNG with the ruler drawn, and logs
 * [SLRULER] lines with both paths. shadowlist-core-bench/ruler-check.sh pulls them.
 */
interface RulerSession {
  writeCapture(path?: string): Promise<string>;
  writeScreenshot(path: string): Promise<string>;
  remove(): Promise<void>;
}

interface RulerModule {
  install(
    target: unknown,
    options: { includeFlattened: boolean }
  ): Promise<RulerSession>;
}

const QUIET_FRAMES = 30;

const log = (line: string) => console.log(line);

/*
 * Resolves once QUIET_FRAMES frames in a row came on time, the screen's lists having mounted.
 */
function quiet(): Promise<void> {
  return new Promise((resolve) => {
    let last = 0;
    let onTime = 0;
    const tick = (now: number) => {
      onTime = last !== 0 && now - last < 20 ? onTime + 1 : 0;
      last = now;
      if (onTime >= QUIET_FRAMES) {
        resolve();
        return;
      }
      requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  });
}

async function measure(ruler: RulerModule) {
  await quiet();
  const session = await ruler.install(rulerTarget, {
    includeFlattened: true,
  });
  // SLRulerDir names a folder the host can read, like the app's external files on Android.
  const dir = launchSetting('SLRulerDir');
  const capture = await session.writeCapture(
    dir ? `${dir}/shadowruler-${Date.now()}.json` : undefined
  );
  const screenshot = await session.writeScreenshot(
    capture.replace(/\.json$/, '') + '.png'
  );
  log(`[SLRULER] capture=${capture} screenshot=${screenshot}`);
  await session.remove();
}

if (RULER) {
  const ruler = ShadowRulerModule as unknown as RulerModule | null;
  if (!ruler) {
    log('[SLRULER] error=not linked, build with SHADOWRULER=1');
  } else {
    measure(ruler).catch((error: unknown) =>
      log(`[SLRULER] error=${String(error)}`)
    );
  }
}
