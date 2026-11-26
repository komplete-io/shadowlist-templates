import { memo } from 'react';
import {
  Image,
  StyleSheet,
  Text,
  View,
  type LayoutChangeEvent,
} from 'react-native';
import type { BenchItem, BenchScenario } from './benchData';

/*
 * BENCHMARK-ONLY. One row component per scenario, used unchanged by every list on BenchScreen.
 * The row root carries testID bench-<id>: the native viewport monitors (AppDelegate.swift,
 * BenchMonitor.kt) find rows by it to score blank area and to follow the anchor row.
 */

export const BENCH_COLORS = {
  background: '#000000',
  row: '#1C1C1E',
  separator: '#2C2C2E',
  title: '#FFFFFF',
  body: '#AEAEB2',
  meta: '#8E8E93',
};

export const ROW_PADDING_H = 16;
export const ROW_PADDING_V = 12;
export const ROW_GAP = 12;
export const TITLE_LINE = 22;
export const TITLE_GAP = 4;
export const BODY_FONT = 14;
export const BODY_LINE = 20;
export const SEPARATOR = 1;

export const FIXED_ROW_HEIGHT = 72;
export const IMAGE_ROW_HEIGHT = 129;
export const TEXT_AVATAR = 40;
const FIXED_AVATAR = 48;
const PHOTO = 104;

/*
 * Every row render, for the update benchmark: an update has settled once frames pass without one.
 */
export const benchStats = { rowRenders: 0 };

interface RowProps {
  item: BenchItem;
  onLayout?: (event: LayoutChangeEvent) => void;
}

const FixedRow = memo(({ item, onLayout }: RowProps) => {
  benchStats.rowRenders++;
  return (
    <View
      testID={`bench-${item.id}`}
      style={[styles.row, styles.fixed]}
      onLayout={onLayout}
    >
      <View style={[styles.fixedAvatar, { backgroundColor: item.color }]} />
      <View style={styles.column}>
        <Text style={styles.title} numberOfLines={1}>
          {item.title}
        </Text>
        <Text style={styles.body} numberOfLines={1}>
          {item.body}
        </Text>
      </View>
    </View>
  );
});

const TextRow = memo(({ item, onLayout }: RowProps) => {
  benchStats.rowRenders++;
  return (
    <View testID={`bench-${item.id}`} style={styles.row} onLayout={onLayout}>
      <View style={[styles.textAvatar, { backgroundColor: item.color }]} />
      <View style={styles.column}>
        <Text style={styles.title} numberOfLines={1}>
          {item.title}
        </Text>
        <Text style={styles.body}>{item.body}</Text>
      </View>
    </View>
  );
});

const ImageRow = memo(({ item, onLayout }: RowProps) => {
  benchStats.rowRenders++;
  return (
    <View
      testID={`bench-${item.id}`}
      style={[styles.row, styles.image]}
      onLayout={onLayout}
    >
      <Image source={item.photo} style={styles.photo} resizeMode="cover" />
      <View style={styles.column}>
        <Text style={styles.title} numberOfLines={1}>
          {item.title}
        </Text>
        <Text style={styles.body} numberOfLines={3}>
          {item.body}
        </Text>
        <Text style={styles.meta} numberOfLines={1}>
          {`${item.body.length} likes · ${item.title.length} comments`}
        </Text>
      </View>
    </View>
  );
});

export const BENCH_ROWS: Record<BenchScenario, typeof FixedRow> = {
  fixed: FixedRow,
  text: TextRow,
  image: ImageRow,
};

/*
 * Row height a list can take without measuring: fixed and image rows only.
 */
export const BENCH_FIXED_HEIGHT: Partial<Record<BenchScenario, number>> = {
  fixed: FIXED_ROW_HEIGHT,
  image: IMAGE_ROW_HEIGHT,
};

/*
 * Space around a text row's body: what ShadowList's getItemSizeSpec adds to the measured text.
 */
export const TEXT_INSET_WIDTH = ROW_PADDING_H * 2 + TEXT_AVATAR + ROW_GAP;
export const TEXT_INSET_HEIGHT =
  ROW_PADDING_V * 2 + TITLE_LINE + TITLE_GAP + SEPARATOR;

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: ROW_GAP,
    paddingHorizontal: ROW_PADDING_H,
    paddingVertical: ROW_PADDING_V,
    backgroundColor: BENCH_COLORS.row,
    borderBottomWidth: SEPARATOR,
    borderBottomColor: BENCH_COLORS.separator,
  },
  fixed: {
    height: FIXED_ROW_HEIGHT,
    alignItems: 'center',
  },
  image: {
    height: IMAGE_ROW_HEIGHT,
  },
  fixedAvatar: {
    width: FIXED_AVATAR,
    height: FIXED_AVATAR,
    borderRadius: FIXED_AVATAR / 2,
  },
  textAvatar: {
    width: TEXT_AVATAR,
    height: TEXT_AVATAR,
    borderRadius: TEXT_AVATAR / 2,
  },
  photo: {
    width: PHOTO,
    height: PHOTO,
    borderRadius: 8,
  },
  column: {
    flex: 1,
    gap: TITLE_GAP,
  },
  title: {
    fontSize: 16,
    lineHeight: TITLE_LINE,
    fontWeight: '600',
    color: BENCH_COLORS.title,
  },
  body: {
    fontSize: BODY_FONT,
    lineHeight: BODY_LINE,
    color: BENCH_COLORS.body,
  },
  meta: {
    fontSize: 12,
    lineHeight: 16,
    color: BENCH_COLORS.meta,
  },
});
