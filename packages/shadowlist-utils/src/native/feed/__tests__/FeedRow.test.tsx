/*
 * FeedRow imports react-native, which does not load under Node. The mocks draw its components as
 * named host elements, so the tests read the props the row gives them.
 */
jest.mock(
  'react-native',
  () => ({
    Platform: {
      OS: 'ios',
      select: (options: { ios?: unknown }) => options.ios,
    },
    Appearance: {
      getColorScheme: () => 'light',
      addChangeListener: () => ({ remove: () => {} }),
    },
    PixelRatio: { getFontScale: () => 1 },
    PlatformColor: (...names: string[]) => names[0],
    StyleSheet: {
      create: <T,>(styles: T) => styles,
      hairlineWidth: 1,
      flatten: (style: unknown) => style,
    },
    useWindowDimensions: () => ({ width: 400, height: 1000, fontScale: 1 }),
    Pressable: 'Pressable',
    ScrollView: 'ScrollView',
    Image: 'Image',
    View: 'View',
    Text: 'Text',
  }),
  { virtual: true }
);
jest.mock('../../hooks/useLargeText', () => ({ useLargeText: () => false }));
jest.mock('../../primitives/Avatar', () => ({ Avatar: 'Avatar' }));

import TestRenderer, { act, type ReactTestRenderer } from 'react-test-renderer';
import { FeedRow } from '../FeedRow';
import type { FeedItem } from '../types';

Object.assign(globalThis, {
  IS_REACT_ACT_ENVIRONMENT: true,
  IS_REACT_NATIVE_TEST_ENVIRONMENT: true,
});

type Style = Record<string, number | undefined>;

/*
 * Nested style arrays merged into one object, later entries winning.
 */
function flat(style: unknown): Style {
  if (Array.isArray(style)) {
    return Object.assign({}, ...style.map(flat));
  }
  return style && typeof style === 'object' ? (style as Style) : {};
}

const edge = (style: Style, side: 'Left' | 'Right') =>
  (style[`margin${side}`] ?? style.marginHorizontal ?? style.margin ?? 0) +
  (style[`padding${side}`] ?? style.paddingHorizontal ?? style.padding ?? 0);

const ITEM: FeedItem = {
  id: 'p1',
  author: { name: 'Mara Quinn' },
  text: 'Boarding at gate B14',
  images: [
    { uri: 'https://example.com/a.jpg', width: 800, height: 600 },
    { uri: 'https://example.com/b.jpg', width: 800, height: 600 },
    { uri: 'https://example.com/c.jpg', width: 800, height: 600 },
  ],
} as FeedItem;

function mount(): ReactTestRenderer {
  let renderer: ReactTestRenderer | undefined;
  act(() => {
    renderer = TestRenderer.create(<FeedRow item={ITEM} />);
  });
  return renderer!;
}

describe('FeedRow photo strip', () => {
  it('starts the first photo at the text column leading edge', () => {
    const strip = mount().root.findByType('ScrollView' as never);
    const stripStyle = flat(strip.props.style);
    const content = flat(strip.props.contentContainerStyle);
    const photos = strip.children.filter(
      (child) => typeof child !== 'string'
    ) as TestRenderer.ReactTestInstance[];
    const first = flat(photos[0]!.props.style);
    expect(
      edge(stripStyle, 'Left') + edge(content, 'Left') + edge(first, 'Left')
    ).toBe(0);
  });

  it('keeps the photos 8 apart', () => {
    const strip = mount().root.findByType('ScrollView' as never);
    const content = flat(strip.props.contentContainerStyle);
    const photos = strip.children.filter(
      (child) => typeof child !== 'string'
    ) as TestRenderer.ReactTestInstance[];
    expect(photos.length).toBe(3);
    for (let index = 1; index < photos.length; index++) {
      const before = flat(photos[index - 1]!.props.style);
      const after = flat(photos[index]!.props.style);
      const gap =
        (before.marginRight ?? before.marginHorizontal ?? 0) +
        (after.marginLeft ?? after.marginHorizontal ?? 0) +
        (content.columnGap ?? content.gap ?? 0);
      expect(gap).toBe(8);
    }
  });
});
