import { useCallback, useMemo, useRef } from 'react';

/*
 * Stable position labels for rows, like item 1 or item 2.
 * A row's number is given once, when it first appears, and kept by id rather than by index.
 * Loading chat history shifts every index, and labels based on the index would renumber and
 * re-render every mounted row at once.
 * Rows that arrive before the numbered ones count separately, away from the start. Each
 * prepended page keeps its own sequence. Rows appended after the last numbered one continue
 * the forward count.
 */

interface ItemNumber {
  value: number;
  prepended: boolean;
}

interface OrdinalRegistry {
  numbers: Map<string, ItemNumber>;
  headId: string | null;
  tailId: string | null;
  forwardCount: number;
  prependedCount: number;
}

interface ItemOrdinals {
  labelOf: (id: string) => string;
}

/*
 * The label for a position, like item 539. Rows numbered away from the start read
 * prepended: item 539.
 */
function formatOrdinalLabel(value: number, prepended = false): string {
  return prepended ? `prepended: item ${value}` : `item ${value}`;
}

/*
 * Numbers each row of data once, in arrival order, and returns a stable labelOf. Safe to call
 * on every render, since only new rows are numbered and a prepend costs one pass over its page.
 */
export function useItemOrdinals<ItemT extends { id: string }>(
  data: ReadonlyArray<ItemT>
): ItemOrdinals {
  const registryRef = useRef<OrdinalRegistry>({
    numbers: new Map(),
    headId: null,
    tailId: null,
    forwardCount: 0,
    prependedCount: 0,
  });

  /*
   * Numbered during render, not in an effect, because this commit's rows read their labels as
   * they render. An effect would leave the first frame of a new page unlabelled.
   */
  useMemo(() => {
    const registry = registryRef.current;
    if (data.length === 0) return;

    const headIndex =
      registry.headId === null
        ? -1
        : data.findIndex((item) => item.id === registry.headId);

    if (headIndex === -1) {
      // Nothing is numbered yet, or the numbered rows are gone. This is the baseline page.
      registry.numbers.clear();
      registry.forwardCount = 0;
      registry.prependedCount = 0;
      data.forEach((item) => {
        registry.numbers.set(item.id, {
          value: ++registry.forwardCount,
          prepended: false,
        });
      });
    } else {
      /*
       * Rows before the previous head are a prepended page. Number them from the row nearest the head
       * outwards. Each older page keeps counting where the previous one stopped.
       */
      for (let index = headIndex - 1; index >= 0; index--) {
        const item = data[index]!;
        if (registry.numbers.has(item.id)) continue;
        registry.numbers.set(item.id, {
          value: ++registry.prependedCount,
          prepended: true,
        });
      }
    }

    // Rows after the last numbered one continue the forward count.
    const tailIndex =
      registry.tailId === null
        ? -1
        : data.findIndex((item) => item.id === registry.tailId);
    for (let index = tailIndex + 1; index < data.length; index++) {
      const item = data[index]!;
      if (registry.numbers.has(item.id)) continue;
      registry.numbers.set(item.id, {
        value: ++registry.forwardCount,
        prepended: false,
      });
    }

    registry.headId = data[0]!.id;
    registry.tailId = data[data.length - 1]!.id;
  }, [data]);

  /*
   * Stable for the life of the screen. The row renderer reads it, and a new identity would
   * rebuild every mounted row.
   */
  const labelOf = useCallback((id: string) => {
    const number = registryRef.current.numbers.get(id);
    return number === undefined
      ? ''
      : formatOrdinalLabel(number.value, number.prepended);
  }, []);

  return useMemo(() => ({ labelOf }), [labelOf]);
}
