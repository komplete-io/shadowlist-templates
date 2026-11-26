jest.mock(
  'react-native',
  () => ({
    PlatformColor: (...names: string[]) => names[0],
    Platform: {
      OS: 'ios',
      select: (options: { ios?: unknown }) => options.ios,
    },
    StyleSheet: {
      create: <T,>(styles: T) => styles,
      hairlineWidth: 1,
      absoluteFill: {
        position: 'absolute',
        top: 0,
        bottom: 0,
        left: 0,
        right: 0,
      },
    },
    View: 'View',
    Text: 'Text',
    Pressable: 'Pressable',
    TextInput: 'TextInput',
    ScrollView: 'ScrollView',
    Animated: { View: 'AnimatedView' },
  }),
  { virtual: true }
);
jest.mock('../../theme', () => ({
  useTheme: () => mockTheme,
  createStyles: (factory: (theme: unknown) => unknown) => () =>
    factory(mockTheme),
}));
jest.mock('../../internal/safeAreaInsets', () => ({
  useSafeAreaInsets: () => ({ bottom: 34, top: 0, left: 0, right: 0 }),
}));
jest.mock('../../icons', () =>
  Object.fromEntries(
    [
      'SparkleIcon',
      'ArrowUpIcon',
      'ChevronIcon',
      'CloseIcon',
      'MicIcon',
      'PencilIcon',
      'PlusIcon',
      'StopIcon',
    ].map((name) => [name, name])
  )
);
jest.mock('../AssistantAttachmentChip', () => ({
  AssistantAttachmentChip: 'Attachment',
}));
jest.mock('../AssistantList', () => ({ AssistantList: 'Transcript' }));
jest.mock('../AssistantScrollButton', () => ({
  AssistantScrollButton: 'ScrollButton',
}));
jest.mock('../../controls/PillButton', () => ({ PillButton: 'PillButton' }));

import { createRef } from 'react';
import type { ShadowListCommands } from 'shadowlist';
import TestRenderer, {
  act,
  type ReactTestRenderer,
  type ReactTestInstance,
} from 'react-test-renderer';
import {
  AssistantConversation,
  type AssistantConversationProps,
} from '../AssistantConversation';
import {
  AssistantComposer,
  type AssistantComposerHandle,
} from '../AssistantComposer';
import { lightTheme } from '../../theme/lightTheme';
import { macOSAppKitTheme } from '../../theme/macOSTokens';
import type { Theme } from '../../theme/Theme';
import { createStreamStore } from '../stream';

let mockTheme: Theme = lightTheme;
Object.assign(globalThis, {
  IS_REACT_ACT_ENVIRONMENT: true,
  IS_REACT_NATIVE_TEST_ENVIRONMENT: true,
});
const suggestions = [
  { title: 'Budget', description: 'Income and bills', prompt: 'Make a budget' },
  { title: 'Trip', description: 'Days and bookings', prompt: 'Plan a trip' },
];
const base: AssistantConversationProps = {
  content: {
    title: 'Ask',
    description: 'Help with spreadsheets',
    placeholder: 'Question',
    suggestions,
  },
  disclaimer: 'Check important information.',
  hasMessages: false,
  onSelectSuggestion: jest.fn(),
  list: { data: [], store: createStreamStore() },
  composer: { streaming: false, onSend: jest.fn(), onPressAttach: jest.fn() },
};
function mount(props: Partial<AssistantConversationProps> = {}, commands = {}) {
  let renderer: ReactTestRenderer;
  act(() => {
    renderer = TestRenderer.create(
      <AssistantConversation {...base} {...props} />,
      {
        createNodeMock: (element) =>
          element.type === 'Transcript' ? commands : null,
      }
    );
  });
  return renderer!;
}
function host(renderer: ReactTestRenderer, name: string) {
  return renderer.root.findAllByType(name as never);
}
function style(node: ReactTestInstance): Record<string, unknown> {
  const value =
    typeof node.props.style === 'function'
      ? node.props.style({ pressed: false })
      : node.props.style;
  return Object.assign({}, ...[value].flat(Infinity).filter(Boolean));
}
afterEach(() => {
  mockTheme = lightTheme;
});

it.each([320, 768, 1200])(
  'keeps suggestions as full-width grouped rows at width %i',
  (width) => {
    const onSelectSuggestion = jest.fn();
    const renderer = mount({ onSelectSuggestion });
    const rows = host(renderer, 'Pressable').filter((node) =>
      suggestions.some((item) => item.title === node.props.accessibilityLabel)
    );
    expect(rows).toHaveLength(2);
    expect(style(rows[0]!).flexBasis).toBeUndefined();
    expect(style(rows[0]!).minHeight).toBe(mockTheme.grouped.rowHeight);
    expect(style(rows[1]!).borderTopWidth).toBe(1);
    const group = rows[0]!.parent!;
    expect(style(group)).toMatchObject({
      alignSelf: 'stretch',
      borderRadius: mockTheme.grouped.radius,
      overflow: 'hidden',
    });
    expect(style(group).flexDirection).not.toBe('row');
    expect(style(group).minWidth ?? 0).toBeLessThan(width);
    act(() => rows[1]!.props.onPress());
    expect(onSelectSuggestion).toHaveBeenCalledWith(suggestions[1]);
    expect(
      host(renderer, 'Text').find(
        (node) => node.props.children === 'Days and bookings'
      )?.props.numberOfLines
    ).toBe(2);
  }
);

it.each(['ios', 'android', 'macos'])(
  'uses theme radii and concentric composer controls on %s',
  (platform) => {
    mockTheme =
      platform === 'macos'
        ? { ...lightTheme, ...macOSAppKitTheme }
        : {
            ...lightTheme,
            grouped: {
              ...lightTheme.grouped,
              radius: platform === 'android' ? 20 : 10,
            },
          };
    const renderer = mount();
    const input = host(renderer, 'TextInput')[0]!;
    const field = input.parent!;
    const toolbar = host(renderer, 'Pressable').find(
      (node) => node.props.accessibilityLabel === 'Send'
    )!.parent!;
    expect(style(field).borderRadius).toBe(
      mockTheme.radius.lg + mockTheme.spacing.xs
    );
    expect(style(toolbar).paddingBottom).toBe(mockTheme.spacing.xs);
    for (const label of ['Send', 'Add attachment']) {
      const button = host(renderer, 'Pressable').find(
        (node) => node.props.accessibilityLabel === label
      )!;
      expect(style(button).borderRadius).toBe(mockTheme.radius.lg);
    }
  }
);

it('keeps the transcript mounted, removes empty suggestions after a message, and keeps the disclaimer below the composer', () => {
  const renderer = mount();
  const transcript = host(renderer, 'Transcript')[0];
  act(() => renderer.update(<AssistantConversation {...base} hasMessages />));
  expect(host(renderer, 'Transcript')[0]).toBe(transcript);
  expect(host(renderer, 'ScrollView')).toHaveLength(0);
  const root = host(renderer, 'View')[0]!;
  const children = root.children.filter(
    (child): child is ReactTestInstance => typeof child !== 'string'
  );
  expect(
    children.findIndex((node) => node.type === AssistantComposer)
  ).toBeLessThan(
    children.findIndex((node) => node.props.children === base.disclaimer)
  );
});

it('preserves draft handles, streaming redirect, continue and scroll-to-end callbacks', () => {
  const composerRef = createRef<AssistantComposerHandle>();
  const scrollToEnd = jest.fn();
  const listRef = { current: { scrollToEnd } as unknown as ShadowListCommands };
  const onSend = jest.fn();
  const resume = jest.fn();
  const onStop = jest.fn();
  const renderer = mount(
    {
      composerRef,
      listRef,
      hasMessages: true,
      resume,
      composer: { streaming: true, sendWhileStreaming: true, onSend, onStop },
    },
    { scrollToEnd }
  );
  expect(
    host(renderer, 'Pressable').some(
      (node) => node.props.accessibilityLabel === 'Stop generating'
    )
  ).toBe(true);
  act(() => composerRef.current!.setDraft('Next question', { focus: false }));
  expect(composerRef.current!.getDraft()).toBe('Next question');
  act(() =>
    host(renderer, 'Pressable')
      .find((node) => node.props.accessibilityLabel === 'Send')!
      .props.onPress()
  );
  expect(onSend).toHaveBeenCalledWith('Next question', []);
  expect(composerRef.current!.getDraft()).toBe('');
  act(() => host(renderer, 'PillButton')[0]!.props.onPress());
  expect(resume).toHaveBeenCalledTimes(1);
  act(() => host(renderer, 'Transcript')[0]!.props.onAtEndChange(false));
  expect(host(renderer, 'ScrollButton')[0]!.props.visible).toBe(true);
  act(() => host(renderer, 'ScrollButton')[0]!.props.onPress());
  expect(scrollToEnd).toHaveBeenCalledWith({ animated: false });
});
