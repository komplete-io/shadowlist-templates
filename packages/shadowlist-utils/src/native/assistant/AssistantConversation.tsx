import {
  useCallback,
  useRef,
  useState,
  type ComponentType,
  type Ref,
} from 'react';
import {
  Animated,
  ScrollView,
  StyleSheet,
  Text,
  View,
  type ViewProps,
} from 'react-native';
import type { ShadowListCommands } from 'shadowlist';
import { useLabels } from '../labels';
import { defaultAssistantLabels } from './labels';
import { useSafeAreaInsets } from '../internal/safeAreaInsets';
import { createStyles } from '../theme';
import { PillButton } from '../controls/PillButton';
import {
  AssistantComposer,
  type AssistantComposerHandle,
  type AssistantComposerProps,
} from './AssistantComposer';
import { AssistantEmpty } from './AssistantEmpty';
import { AssistantList, type AssistantListProps } from './AssistantList';
import { AssistantScrollButton } from './AssistantScrollButton';
import type { AssistantSuggestion } from './types';

export interface AssistantConversationContent {
  title: string;
  description: string;
  placeholder: string;
  suggestions: readonly AssistantSuggestion[];
}

export interface AssistantConversationProps {
  content: AssistantConversationContent;
  disclaimer: string;
  hasMessages: boolean;
  onSelectSuggestion: (suggestion: AssistantSuggestion) => void;
  list: AssistantListProps;
  listRef?: Ref<ShadowListCommands>;
  composer: AssistantComposerProps;
  composerRef?: Ref<AssistantComposerHandle>;
  resume?: () => void;
  keyboardSpace?:
    number | Animated.Value | ReturnType<typeof Animated.multiply>;
  transcriptContainer?: ComponentType<ViewProps>;
}

/*
 * One conversation layout for every session and presentation. The transcript stays mounted
 * beneath the scrollable empty state, preserving its end-marker and streaming behavior.
 */
export const AssistantConversation = ({
  content,
  disclaimer,
  hasMessages,
  onSelectSuggestion,
  list,
  listRef,
  composer,
  composerRef,
  resume,
  keyboardSpace = 0,
  transcriptContainer: TranscriptContainer = View,
}: AssistantConversationProps) => {
  const styles = useStyles();
  const labels = useLabels(defaultAssistantLabels, list.labels);
  const insets = useSafeAreaInsets();
  const [awayFromEnd, setAwayFromEnd] = useState(false);
  const transcriptRef = useRef<ShadowListCommands | null>(null);
  const setListRef = useCallback(
    (commands: ShadowListCommands | null) => {
      transcriptRef.current = commands;
      if (typeof listRef === 'function') return listRef(commands);
      if (listRef) listRef.current = commands;
    },
    [listRef]
  );
  const scrollToEnd = () =>
    transcriptRef.current?.scrollToEnd({ animated: false });
  return (
    <View style={styles.screen}>
      <TranscriptContainer style={styles.list}>
        <AssistantList
          {...list}
          ref={setListRef}
          style={styles.list}
          showsVerticalScrollIndicator
          onAtEndChange={(atEnd) => {
            setAwayFromEnd(!atEnd);
            list.onAtEndChange?.(atEnd);
          }}
        />
        {!hasMessages && (
          <ScrollView
            style={StyleSheet.absoluteFill}
            contentContainerStyle={styles.empty}
            keyboardShouldPersistTaps="handled"
          >
            <AssistantEmpty
              labels={{
                emptyTitle: content.title,
                emptySubtitle: content.description,
              }}
              suggestions={content.suggestions}
              onSelectSuggestion={onSelectSuggestion}
            />
          </ScrollView>
        )}
        <AssistantScrollButton
          visible={hasMessages && awayFromEnd}
          onPress={scrollToEnd}
        />
      </TranscriptContainer>
      {resume && (
        <View style={styles.resume}>
          <Text style={styles.resumeText} numberOfLines={2}>
            {labels.resumeMessage}
          </Text>
          <PillButton label={labels.resume} onPress={resume} />
        </View>
      )}
      <AssistantComposer
        {...composer}
        ref={composerRef}
        style={styles.composer}
        labels={{ ...composer.labels, placeholder: content.placeholder }}
        accessory={<View style={styles.accessories}>{composer.accessory}</View>}
      />
      <Text
        style={[
          styles.disclaimer,
          {
            paddingBottom: Math.max(
              insets.bottom,
              styles.disclaimer.paddingBottom
            ),
          },
        ]}
      >
        {disclaimer}
      </Text>
      <Animated.View style={{ height: keyboardSpace }} />
    </View>
  );
};

const useStyles = createStyles((theme) =>
  StyleSheet.create({
    screen: {
      flex: 1,
      minHeight: 0,
      overflow: 'hidden',
      backgroundColor: theme.colors.background,
    },
    list: { flex: 1, minHeight: 0 },
    empty: { flexGrow: 1, justifyContent: 'center' },
    accessories: {
      flex: 1,
      minWidth: 0,
      flexDirection: 'row',
      alignItems: 'center',
      gap: theme.spacing.xs,
    },
    resume: {
      flexDirection: 'row',
      alignItems: 'center',
      gap: theme.spacing.md,
      paddingHorizontal: theme.spacing.lg,
      paddingVertical: theme.spacing.sm,
      borderTopWidth: StyleSheet.hairlineWidth,
      borderTopColor: theme.colors.separator,
    },
    resumeText: {
      flex: 1,
      color: theme.colors.secondaryLabel,
      ...theme.typography.footnote,
    },
    composer: { paddingBottom: theme.spacing.sm },
    disclaimer: {
      color: theme.colors.tertiaryLabel,
      ...theme.typography.footnote,
      textAlign: 'center',
      paddingHorizontal: theme.spacing.lg,
      paddingBottom: theme.spacing.sm,
    },
  })
);
