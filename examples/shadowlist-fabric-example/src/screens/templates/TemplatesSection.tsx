import type { ReactNode } from 'react';
import { StyleSheet, View } from 'react-native';
import { Grouped, createStyles } from 'shadowlist-utils/native';

export interface TemplatesSectionProps {
  title: string;
  children: ReactNode;
  card?: boolean;
}

/*
 * One captioned block of the Templates page.
 */
export const TemplatesSection = ({
  title,
  children,
  card = false,
}: TemplatesSectionProps) => {
  const styles = useStyles();
  return (
    <View style={styles.section}>
      <Grouped.Caption title={title} />
      {card ? (
        <Grouped.Card style={styles.card}>{children}</Grouped.Card>
      ) : (
        <View style={styles.content}>{children}</View>
      )}
    </View>
  );
};

const useStyles = createStyles(({ spacing, grouped }) =>
  StyleSheet.create({
    section: {
      marginTop: spacing.xxl,
    },
    /*
     * Content lines up with the caption: grouped.inset plus grouped.rowInset from the edge, in
     * a card or not, as a card's rows do.
     */
    content: {
      marginHorizontal: grouped.inset + grouped.rowInset,
      gap: spacing.md,
    },
    card: {
      paddingHorizontal: grouped.rowInset,
      paddingVertical: spacing.md,
      gap: spacing.md,
    },
  })
);
