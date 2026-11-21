#pragma once

#include <shadowlist-core/Constants.hpp>

#include <algorithm>
#include <cstddef>
#include <string>
#include <vector>

namespace azimgd::shadowlist {

/*
 * A card's move on a board. The host takes the card out of every column that holds its key,
 * then puts it into destinationColumn at destinationIndex, an index into that column without
 * the card. sourceColumn and sourceIndex are where the card first sits now, UNDEFINED_INDEX for
 * a card that is on no column yet. An empty plan changes nothing.
 */
struct BoardMovePlan {
  std::size_t sourceColumn = UNDEFINED_INDEX;
  std::size_t sourceIndex = UNDEFINED_INDEX;
  std::size_t destinationColumn = UNDEFINED_INDEX;
  std::size_t destinationIndex = UNDEFINED_INDEX;

  bool isEmpty() const {
    return destinationColumn == UNDEFINED_INDEX;
  }
};

/*
 * Where a card lands when it moves on a board. columns are each column's item keys in order.
 * The card goes into destinationColumn before destinationKey, at the end for an empty key, or
 * at destinationIndex when the key is gone. That index is kept inside the column, as
 * dragBoardDropIndex in host/DragBoard.hpp keeps a drop's index. The plan is empty when the key
 * is gone and destinationIndex is UNDEFINED_INDEX, which is no drop spot, when the card already
 * sits there and nowhere else, or when destinationColumn is not on the board.
 */
inline BoardMovePlan planBoardMove(
  const std::vector<std::vector<std::string>>& columns,
  const std::string& itemKey,
  std::size_t destinationColumn,
  const std::string& destinationKey,
  std::size_t destinationIndex) {
  BoardMovePlan plan;
  if (destinationColumn >= columns.size()) {
    return plan;
  }

  std::size_t heldCount = 0;
  for (std::size_t column = 0; column < columns.size(); ++column) {
    for (std::size_t index = 0; index < columns[column].size(); ++index) {
      if (columns[column][index] != itemKey) {
        continue;
      }
      if (heldCount == 0) {
        plan.sourceColumn = column;
        plan.sourceIndex = index;
      }
      ++heldCount;
    }
  }

  // Indices below count the destination column without the card.
  const std::vector<std::string>& destination = columns[destinationColumn];
  std::size_t remaining = 0;
  std::size_t keyed = UNDEFINED_INDEX;
  for (const std::string& key : destination) {
    if (key == itemKey) {
      continue;
    }
    if (keyed == UNDEFINED_INDEX && !destinationKey.empty() && key == destinationKey) {
      keyed = remaining;
    }
    ++remaining;
  }
  std::size_t landing = UNDEFINED_INDEX;
  if (destinationKey.empty()) {
    landing = remaining;
  } else if (keyed != UNDEFINED_INDEX) {
    landing = keyed;
  } else if (destinationIndex != UNDEFINED_INDEX) {
    landing = std::min(destinationIndex, remaining);
  }
  if (landing == UNDEFINED_INDEX) {
    return {};
  }

  bool alreadyThere = heldCount == 1 && plan.sourceColumn == destinationColumn && plan.sourceIndex == landing;
  if (alreadyThere) {
    return {};
  }
  plan.destinationColumn = destinationColumn;
  plan.destinationIndex = landing;
  return plan;
}

}
