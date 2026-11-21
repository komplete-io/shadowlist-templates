import { View } from 'react-native';
import { Poll } from 'shadowlist-utils/native';
import { usePollQuery, useVote } from '../queries/poll';
import { QueryStatus } from './QueryStatus';
import { useScreenStyles } from './screenStyles';

/*
 * The macOS app has no safe area context and a macOS window has no bottom inset.
 */
export const PollScreen = () => {
  const styles = useScreenStyles();
  const poll = usePollQuery();
  const { mutate: vote } = useVote();

  if (poll.data === undefined) {
    return <QueryStatus error={poll.error} onRetry={poll.refetch} />;
  }

  return (
    <View style={styles.container}>
      <Poll.List poll={poll.data} onVote={vote} style={styles.list} />
    </View>
  );
};
