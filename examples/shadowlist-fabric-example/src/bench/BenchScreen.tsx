import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  FlatList,
  Platform,
  Settings,
  StyleSheet,
  View,
  useWindowDimensions,
} from 'react-native';
import { ShadowList, type ItemSizeSpec } from 'shadowlist';
import { LegendList } from '@legendapp/list/react-native';
import { FlashList } from '@shopify/flash-list';
import { launchSetting, listCount } from '../launchSettings';
import { benchItems, type BenchItem, type BenchScenario } from './benchData';
import {
  BENCH_COLORS,
  BENCH_FIXED_HEIGHT,
  BENCH_ROWS,
  BODY_FONT,
  BODY_LINE,
  TEXT_INSET_HEIGHT,
  TEXT_INSET_WIDTH,
  benchStats,
} from './BenchRows';

/*
 * BENCHMARK-ONLY. One list library on one scenario, for the comparison in
 * shadowlist-core-bench/scroll-bench.sh. Launch settings:
 *
 *   SLRoute Bench
 *   SLList shadowlist | legend | flash | flat
 *   SLBench fixed | text | image          the row component, the same for every list
 *   SLCount N                             rows
 *   SLDraw PT                             render window past each viewport edge, in pt (dp on
 *                                         Android), default 500. Each list gets it in its own
 *                                         unit, see shadowWindow and windowSize below.
 *   SLOps 1                               after mount, jump to the middle and time data updates
 *
 * Logs [SLMOUNTSTART] on its first render (the native monitors log [SLFILLED] once rows cover
 * the whole list), [SLMOUNT] once the first rows laid out, [SLBENCH] ready once the screen went quiet,
 * then with SLOps one [SLOP] line per update. iOS starts its scroll driver on ready.
 */
type BenchList = 'shadowlist' | 'legend' | 'flash' | 'flat';

const LIST: BenchList = (() => {
  const value = launchSetting('SLList');
  return value === 'legend' || value === 'flash' || value === 'flat'
    ? value
    : 'shadowlist';
})();

const SCENARIO: BenchScenario = (() => {
  const value = launchSetting('SLBench');
  return value === 'fixed' || value === 'image' ? value : 'text';
})();

const DRAW = (() => {
  const value = Number(launchSetting('SLDraw'));
  return Number.isFinite(value) && value >= 0 ? value : 500;
})();

const OPS = launchSetting('SLOps') === '1';

/*
 * SLInitial N sets ShadowList's initialNumToRender, for experiments. Unset keeps the default.
 * SLNoSpec 1 leaves out getItemSizeSpec, for experiments.
 */
const SL_NO_SPEC = launchSetting('SLNoSpec') === '1';

const SL_INITIAL = (() => {
  const value = Number(launchSetting('SLInitial'));
  return Number.isInteger(value) && value > 0 ? value : undefined;
})();

/*
 * How ShadowList gets the render window, SLWindow:
 *   viewports (default) - native overscan DRAW / viewport height, no extra mount rows: the rows
 *     React mounts are the rows native measures and places, DRAW past each edge.
 *   rows - native overscan 0, mountOverscanRows DRAW / average row height on each side.
 *   defaults - the library's defaults (overscan 1 viewport plus 4 / 10 rows), a larger window
 *     than the others get. For reference only.
 */
const SL_WINDOW = (() => {
  const value = launchSetting('SLWindow');
  return value === 'rows' || value === 'defaults' ? value : 'viewports';
})();

/*
 * Average row height in pt, measured on the iPhone 17 Pro simulator for text rows. Used to
 * convert the pt window into rows for ShadowList and as LegendList's estimatedItemSize.
 */
const TEXT_AVERAGE_HEIGHT = 170;

const OP_SIZE = 100;
const QUIET_FRAMES = 10;
const MAX_SETTLE_FRAMES = 600;

declare const performance: { now(): number };

const log = (line: string) => console.log(line);

const nextFrame = () =>
  new Promise<number>((resolve) => requestAnimationFrame(resolve));

/*
 * Waits until QUIET_FRAMES frames pass without a row render. Returns the time from start to
 * the last frame that rendered a row, the rows rendered since `first` (the count when the
 * update began), the frames waited and the longest gap between JS frames.
 */
async function settle(start: number, first = benchStats.rowRenders) {
  let renders = first;
  let lastChange = start;
  let last = start;
  let longest = 0;
  let quiet = 0;
  let frames = 0;
  while (quiet < QUIET_FRAMES && frames < MAX_SETTLE_FRAMES) {
    const now = await nextFrame();
    frames++;
    longest = Math.max(longest, now - last);
    last = now;
    if (benchStats.rowRenders !== renders) {
      renders = benchStats.rowRenders;
      lastChange = now;
      quiet = 0;
    } else {
      quiet++;
    }
  }
  return {
    ms: Math.max(0, lastChange - start),
    renders: renders - first,
    frames,
    longest,
  };
}

interface Scroller {
  scrollToOffset: (params: { offset: number; animated?: boolean }) => void;
}

function averageHeight() {
  return BENCH_FIXED_HEIGHT[SCENARIO] ?? TEXT_AVERAGE_HEIGHT;
}

export const BenchScreen = () => {
  const startRef = useRef(0);
  if (startRef.current === 0) {
    startRef.current = performance.now();
    // The native monitors time the first frame with the screen filled from this line.
    log(`[SLMOUNTSTART] list=${LIST}`);
  }
  const { height: windowHeight } = useWindowDimensions();
  const [data, setData] = useState(() => benchItems(listCount));
  const dataRef = useRef(data);
  dataRef.current = data;
  const listRef = useRef<Scroller>(null);
  const firstVisibleRef = useRef(0);
  const [mounted, setMounted] = useState(false);
  /*
   * Rows rendered before the first layout carry onLayout, later ones don't. A ref, so that
   * mounting doesn't re-render every row.
   */
  const mountedRef = useRef(false);
  const Row = BENCH_ROWS[SCENARIO];

  const onFirstLayout = useCallback(() => {
    if (mountedRef.current) return;
    mountedRef.current = true;
    log(
      `[SLMOUNT] list=${LIST} scenario=${SCENARIO} count=${listCount} ms=${(
        performance.now() - startRef.current
      ).toFixed(1)}`
    );
    setMounted(true);
  }, []);

  const renderItem = useCallback(
    ({ item }: { item: BenchItem }) => (
      <Row
        item={item}
        onLayout={mountedRef.current ? undefined : onFirstLayout}
      />
    ),
    [Row, onFirstLayout]
  );

  const keyExtractor = useCallback((item: BenchItem) => item.id, []);

  const onViewableItemsChanged = useCallback(
    (info: { viewableItems: ReadonlyArray<{ index?: number | null }> }) => {
      let first = Number.MAX_SAFE_INTEGER;
      for (const token of info.viewableItems) {
        if (token.index != null && token.index < first) first = token.index;
      }
      if (first !== Number.MAX_SAFE_INTEGER) firstVisibleRef.current = first;
    },
    []
  );
  const viewabilityConfig = useMemo(
    () => ({ itemVisiblePercentThreshold: 50 }),
    []
  );

  /*
   * Once mounted and quiet: tell the scroll driver, then run the updates.
   */
  useEffect(() => {
    if (!mounted) return;
    let cancelled = false;
    const run = async () => {
      const quiet = await settle(performance.now());
      if (cancelled) return;
      log(
        `[SLBENCH] ready list=${LIST} scenario=${SCENARIO} count=${listCount} settle=${quiet.ms.toFixed(
          1
        )} renders=${quiet.renders}`
      );
      if (Platform.OS === 'ios') Settings.set({ SLBenchReady: Date.now() });
      if (!OPS) return;
      const op = async (name: string, apply: () => void) => {
        log(`[SLOP] begin name=${name}`);
        await nextFrame();
        const start = performance.now();
        const before = benchStats.rowRenders;
        apply();
        const result = await settle(start, before);
        log(
          `[SLOP] done name=${name} ms=${result.ms.toFixed(1)} longest=${result.longest.toFixed(
            1
          )} renders=${result.renders} frames=${result.frames}`
        );
      };
      let serial = 0;
      const fresh = (prefix: string) =>
        benchItems(OP_SIZE, `${prefix}${serial++}-`);
      await op('jump-middle', () =>
        listRef.current?.scrollToOffset({
          offset: (averageHeight() * listCount) / 2,
          animated: false,
        })
      );
      await op('prepend', () => setData((items) => [...fresh('p'), ...items]));
      await op('insert-above-viewport', () =>
        setData((items) => {
          const at = Math.max(0, firstVisibleRef.current - 5);
          return [...items.slice(0, at), ...fresh('m'), ...items.slice(at)];
        })
      );
      await op('remove-top', () => setData((items) => items.slice(OP_SIZE)));
      await op('remove-above-viewport', () =>
        setData((items) => {
          const end = Math.max(0, firstVisibleRef.current - 5);
          const start = Math.max(0, end - OP_SIZE);
          return [...items.slice(0, start), ...items.slice(end)];
        })
      );
      log(`[SLBENCH] ops-done list=${LIST}`);
    };
    run();
    return () => {
      cancelled = true;
    };
  }, [mounted]);

  /*
   * The render window, DRAW pt past each viewport edge, in each library's unit:
   *   ShadowList: see SL_WINDOW. The rows React mounts are the rows native measures and places
   *     (overscan, in viewports) plus mountOverscanRows on each side.
   *   LegendList and FlashList: drawDistance in pt.
   *   FlatList: windowSize in viewports, 1 + 2 * DRAW / viewport height.
   * The viewport is the list's own height, from its container's layout.
   */
  const [viewport, setViewport] = useState(windowHeight);
  const onContainerLayout = useCallback(
    (event: { nativeEvent: { layout: { height: number } } }) =>
      setViewport(event.nativeEvent.layout.height),
    []
  );
  const shadowWindow =
    SL_WINDOW === 'defaults'
      ? {}
      : SL_WINDOW === 'rows'
        ? {
            overscan: 0,
            mountOverscanRows: Math.ceil(DRAW / averageHeight()),
            mountOverscanRowsLeading: Math.ceil(DRAW / averageHeight()),
          }
        : {
            overscan: DRAW / viewport,
            mountOverscanRows: 0,
            mountOverscanRowsLeading: 0,
          };
  const windowSize = 1 + (2 * DRAW) / viewport;
  const fixedHeight = BENCH_FIXED_HEIGHT[SCENARIO];

  const getItemSizeSpec = useCallback(
    (item: BenchItem): ItemSizeSpec =>
      fixedHeight !== undefined
        ? { text: '', fixedHeight }
        : {
            text: item.body,
            fontSize: BODY_FONT,
            lineHeight: BODY_LINE,
            insetWidth: TEXT_INSET_WIDTH,
            insetHeight: TEXT_INSET_HEIGHT,
          },
    [fixedHeight]
  );
  const getItemLayout = useMemo(
    () =>
      fixedHeight === undefined
        ? undefined
        : (_: ArrayLike<BenchItem> | null | undefined, index: number) => ({
            length: fixedHeight,
            offset: fixedHeight * index,
            index,
          }),
    [fixedHeight]
  );
  const getFixedItemSize = useMemo(
    () => (fixedHeight === undefined ? undefined : () => fixedHeight),
    [fixedHeight]
  );
  const viewability = OPS
    ? { viewabilityConfig, onViewableItemsChanged }
    : undefined;

  let list;
  switch (LIST) {
    case 'legend':
      list = (
        <LegendList
          ref={listRef as never}
          data={data}
          renderItem={renderItem}
          keyExtractor={keyExtractor}
          recycleItems
          estimatedItemSize={averageHeight()}
          getFixedItemSize={getFixedItemSize}
          drawDistance={DRAW}
          maintainVisibleContentPosition
          style={styles.list}
          {...viewability}
        />
      );
      break;
    case 'flash':
      list = (
        <FlashList
          ref={listRef as never}
          data={data}
          renderItem={renderItem}
          keyExtractor={keyExtractor}
          drawDistance={DRAW}
          style={styles.list}
          {...viewability}
        />
      );
      break;
    case 'flat':
      list = (
        <FlatList
          ref={listRef as never}
          data={data}
          renderItem={renderItem}
          keyExtractor={keyExtractor}
          getItemLayout={getItemLayout}
          windowSize={windowSize}
          initialNumToRender={Math.ceil(windowHeight / averageHeight()) + 1}
          maintainVisibleContentPosition={MVCP}
          style={styles.list}
          {...viewability}
        />
      );
      break;
    default:
      list = (
        <ShadowList
          ref={listRef as never}
          data={data}
          renderItem={renderItem}
          keyExtractor={keyExtractor}
          getItemSizeSpec={SL_NO_SPEC ? undefined : getItemSizeSpec}
          initialNumToRender={SL_INITIAL}
          {...shadowWindow}
          style={styles.list}
          {...viewability}
        />
      );
  }

  return (
    <View style={styles.container} onLayout={onContainerLayout}>
      {list}
    </View>
  );
};

const MVCP = { minIndexForVisible: 0 };

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: BENCH_COLORS.background,
  },
  list: {
    flex: 1,
    backgroundColor: BENCH_COLORS.background,
  },
});
