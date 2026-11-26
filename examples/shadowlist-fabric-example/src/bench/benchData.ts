import type { ImageSourcePropType } from 'react-native';
import { SAMPLE_TEXTS } from '../fixtures/common';

/*
 * BENCHMARK-ONLY. Rows for the list comparison screen (BenchScreen). Every list renders the same
 * items with the same row components, so the data is deterministic: row n is the same on every
 * run and every list.
 */
export type BenchScenario = 'fixed' | 'text' | 'image';

export interface BenchItem {
  id: string;
  title: string;
  body: string;
  color: string;
  photo: ImageSourcePropType;
}

const PHOTOS: ImageSourcePropType[] = [
  require('./images/photo0.jpg'),
  require('./images/photo1.jpg'),
  require('./images/photo2.jpg'),
  require('./images/photo3.jpg'),
  require('./images/photo4.jpg'),
  require('./images/photo5.jpg'),
  require('./images/photo6.jpg'),
  require('./images/photo7.jpg'),
];

const COLORS = [
  '#E76F51',
  '#2A9D8F',
  '#E9C46A',
  '#457B9D',
  '#F4A261',
  '#8AB17D',
  '#6D597A',
  '#BC4749',
];

const WORDS = SAMPLE_TEXTS.join(' ').split(/\s+/);

/*
 * A body of 4 to 90 words, picked by a small hash of the row number so neighbors differ.
 */
function bodyOf(serial: number): string {
  const hash = (serial * 2654435761) % 4294967296;
  const length = 4 + (hash % 87);
  const start = Math.floor(hash / 256) % WORDS.length;
  const words: string[] = [];
  for (let i = 0; i < length; i++) {
    words.push(WORDS[(start + i) % WORDS.length]!);
  }
  return words.join(' ');
}

export function benchItem(serial: number, prefix = 'r'): BenchItem {
  return {
    id: `${prefix}${serial}`,
    title: `Row ${prefix}${serial}`,
    body: bodyOf(serial),
    color: COLORS[serial % COLORS.length]!,
    photo: PHOTOS[serial % PHOTOS.length]!,
  };
}

export function benchItems(count: number, prefix = 'r', from = 0): BenchItem[] {
  const items: BenchItem[] = new Array(count);
  for (let i = 0; i < count; i++) items[i] = benchItem(from + i, prefix);
  return items;
}
