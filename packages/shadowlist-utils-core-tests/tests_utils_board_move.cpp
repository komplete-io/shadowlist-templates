/*
 * Board move tests: a card's move on a board, as a plan over each column's keys.
 */

#include "TestFramework.hpp"

#include <shadowlist-core/Constants.hpp>
#include <shadowlist-utils-core/BoardMovePlan.hpp>

#include <cstddef>
#include <string>
#include <vector>

using namespace slt;
using namespace azimgd::shadowlist;

namespace {

using Board = std::vector<std::vector<std::string>>;

Board board() {
  return {{"a", "b", "c"}, {"d", "e"}, {}};
}

void checkPlan(
  const BoardMovePlan& plan,
  std::size_t sourceColumn,
  std::size_t sourceIndex,
  std::size_t destinationColumn,
  std::size_t destinationIndex) {
  CHECK(!plan.isEmpty());
  CHECK_EQ(plan.sourceColumn, sourceColumn);
  CHECK_EQ(plan.sourceIndex, sourceIndex);
  CHECK_EQ(plan.destinationColumn, destinationColumn);
  CHECK_EQ(plan.destinationIndex, destinationIndex);
}

}

TEST(a_board_move_into_another_column_lands_before_the_keyed_item) {
  checkPlan(planBoardMove(board(), "b", 1, "e", 0), 0, 1, 1, 1);
}

TEST(a_board_move_with_an_empty_key_lands_at_the_end) {
  checkPlan(planBoardMove(board(), "a", 2, "", 0), 0, 0, 2, 0);
  checkPlan(planBoardMove(board(), "a", 1, "", 0), 0, 0, 1, 2);
}

TEST(a_board_move_before_a_missing_key_falls_back_to_the_index) {
  checkPlan(planBoardMove(board(), "b", 1, "gone", 1), 0, 1, 1, 1);
  // The index is kept inside the column.
  checkPlan(planBoardMove(board(), "b", 1, "gone", 99), 0, 1, 1, 2);
}

TEST(a_board_move_before_a_missing_key_without_an_index_changes_nothing) {
  CHECK(planBoardMove(board(), "b", 1, "gone", UNDEFINED_INDEX).isEmpty());
  CHECK(planBoardMove(board(), "new", 1, "gone", UNDEFINED_INDEX).isEmpty());
  // An empty key is the end, whatever the index.
  checkPlan(planBoardMove(board(), "a", 1, "", UNDEFINED_INDEX), 0, 0, 1, 2);
}

TEST(a_board_move_within_a_column_counts_the_column_without_the_card) {
  // Before c, which is index 1 once a is out.
  checkPlan(planBoardMove(board(), "a", 0, "c", 0), 0, 0, 0, 1);
  checkPlan(planBoardMove(board(), "a", 0, "", 0), 0, 0, 0, 2);
  checkPlan(planBoardMove(board(), "c", 0, "a", 0), 0, 2, 0, 0);
}

TEST(a_board_move_to_the_same_place_changes_nothing) {
  CHECK(planBoardMove(board(), "a", 0, "b", 0).isEmpty());
  CHECK(planBoardMove(board(), "c", 0, "", 0).isEmpty());
  CHECK(planBoardMove(board(), "b", 0, "gone", 1).isEmpty());
}

TEST(a_board_move_to_a_column_off_the_board_changes_nothing) {
  CHECK(planBoardMove(board(), "a", 3, "", 0).isEmpty());
  CHECK(planBoardMove(board(), "a", UNDEFINED_INDEX, "", 0).isEmpty());
  CHECK(planBoardMove({}, "a", 0, "", 0).isEmpty());
}

TEST(a_board_move_of_a_card_on_no_column_has_no_source) {
  checkPlan(planBoardMove(board(), "new", 1, "e", 0), UNDEFINED_INDEX, UNDEFINED_INDEX, 1, 1);
}

TEST(a_board_move_of_a_card_in_two_columns_is_never_empty) {
  // The card already sits before b, and still has to leave the other column.
  Board stale = {{"a", "b"}, {"a", "d"}};
  checkPlan(planBoardMove(stale, "a", 0, "b", 0), 0, 0, 0, 0);
}

TEST(a_board_move_before_the_card_itself_falls_back_to_the_index) {
  checkPlan(planBoardMove(board(), "b", 0, "b", 0), 0, 1, 0, 0);
}

TEST(a_board_move_leaves_the_columns_it_was_given) {
  Board columns = board();
  planBoardMove(columns, "b", 1, "e", 0);
  CHECK(columns == board());
}
