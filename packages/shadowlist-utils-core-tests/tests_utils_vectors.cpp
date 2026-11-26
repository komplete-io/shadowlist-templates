/*
 * Vector tests: every file in vectors/ replayed through the functions of
 * packages/shadowlist-utils-core. The jest tests of shadowlist-utils replay the same files
 * through the TypeScript, which keeps the two sides from drifting apart. A file in the folder
 * without a UTILS_VECTOR_TEST fails every_utils_vector_file_has_a_replay. The list engine
 * replays its own vectors in its repository.
 */

#include "TestFramework.hpp"
#include "UtilsVectorHelpers.hpp"

#include <shadowlist-core/host/RowSizeSpec.hpp>
#include <shadowlist-utils-core/AssistantStep.hpp>
#include <shadowlist-utils-core/Avatar.hpp>
#include <shadowlist-utils-core/BoardColumnLayout.hpp>
#include <shadowlist-utils-core/BoardMovePlan.hpp>
#include <shadowlist-utils-core/ChatLayout.hpp>
#include <shadowlist-utils-core/ContactSection.hpp>
#include <shadowlist-utils-core/FeedImageFrame.hpp>
#include <shadowlist-utils-core/PollTally.hpp>
#include <shadowlist-utils-core/RelativeTime.hpp>
#include <shadowlist-utils-core/SafeUrl.hpp>
#include <shadowlist-utils-core/Text.hpp>

#include <algorithm>
#include <cstddef>
#include <string>
#include <vector>

using namespace slt;
using namespace azimgd::shadowlist;

namespace {

ChatBubbleMetrics metricsOf(const Json& metrics) {
  ChatBubbleMetrics read;
  read.spacingXxs = metrics["spacingXxs"].number;
  read.spacingXs = metrics["spacingXs"].number;
  read.spacingSm = metrics["spacingSm"].number;
  read.spacingMd = metrics["spacingMd"].number;
  read.spacingLg = metrics["spacingLg"].number;
  read.bodyFontSize = metrics["bodyFontSize"].number;
  read.bodyLineHeight = metrics["bodyLineHeight"].number;
  read.bodyLetterSpacing = metrics["bodyLetterSpacing"].number;
  read.captionLineHeight = metrics["captionLineHeight"].number;
  return read;
}

/*
 * A size spec against a case's output, which is null for a row the host measures.
 */
void checkSizeSpec(bool hasSpec, const RowSizeSpec& spec, const Json& output) {
  CHECK_EQ(hasSpec, !output.isNull());
  if (!hasSpec) {
    return;
  }
  CHECK_EQ(spec.fontSize, output["fontSize"].number);
  CHECK_EQ(spec.lineHeight, output["lineHeight"].number);
  CHECK_EQ(spec.letterSpacing, output["letterSpacing"].number);
  CHECK_EQ(spec.widthFraction, output["widthFraction"].number);
  CHECK_EQ(spec.insetWidth, output["insetWidth"].number);
  CHECK_EQ(spec.insetHeight, output["insetHeight"].number);
}

const char* unitName(RelativeTimeUnit unit) {
  switch (unit) {
    case RelativeTimeUnit::Now:
      return "now";
    case RelativeTimeUnit::Minutes:
      return "minutes";
    case RelativeTimeUnit::Hours:
      return "hours";
    case RelativeTimeUnit::Days:
      return "days";
    case RelativeTimeUnit::Date:
      return "date";
  }
  return "";
}

std::vector<std::vector<std::string>> columnsOf(const Json& columns) {
  std::vector<std::vector<std::string>> read;
  for (const Json& column : columns.items) {
    read.emplace_back();
    for (const Json& key : column.items) {
      read.back().push_back(key.text);
    }
  }
  return read;
}

/*
 * The board after a host carried out plan: the card out of every column, then into its place.
 */
std::vector<std::vector<std::string>> applyBoardMove(
  std::vector<std::vector<std::string>> columns,
  const std::string& itemKey,
  const BoardMovePlan& plan) {
  if (plan.isEmpty()) {
    return columns;
  }
  for (std::vector<std::string>& column : columns) {
    column.erase(std::remove(column.begin(), column.end(), itemKey), column.end());
  }
  std::vector<std::string>& destination = columns[plan.destinationColumn];
  destination.insert(destination.begin() + static_cast<std::ptrdiff_t>(plan.destinationIndex), itemKey);
  return columns;
}

/*
 * The name of an avatar case. A case with half a surrogate pair lists its UTF-16 units, which
 * not every JSON reader takes in a string. Each unit is written as its own sequence, the way a
 * host that copies units one by one hands them over.
 */
std::string avatarNameOf(const Json& input) {
  if (!input.has("units")) {
    return input["name"].text;
  }
  std::string name;
  const Json& units = input["units"];
  for (std::size_t index = 0; index < units.size(); ++index) {
    char32_t unit = static_cast<char32_t>(units[index].number);
    if (unit < 0xD800 || unit > 0xDFFF) {
      appendUtf8(name, unit);
      continue;
    }
    name.push_back(static_cast<char>(0xE0 | (unit >> 12)));
    name.push_back(static_cast<char>(0x80 | ((unit >> 6) & 0x3F)));
    name.push_back(static_cast<char>(0x80 | (unit & 0x3F)));
  }
  return name;
}

}

UTILS_VECTOR_TEST(avatar_vectors_replay, "avatar.json") {
  const Json& input = vector["input"];
  const Json& output = vector["output"];
  std::size_t paletteSize = static_cast<std::size_t>(input["paletteSize"].number);
  std::string name = avatarNameOf(input);
  CHECK_EQ(indexToNumber(avatarColorIndex(name, paletteSize)), output["colorIndex"].number);
  CHECK_EQ(avatarInitials(name), output["initials"].text);
}

UTILS_VECTOR_TEST(avatar_initials_vectors_replay, "avatar-initials.json") {
  AvatarInitialsMetrics metrics = avatarInitialsMetrics(vector["input"]["size"].number);
  CHECK_EQ(metrics.fontSize, vector["output"]["fontSize"].number);
}

UTILS_VECTOR_TEST(relative_time_vectors_replay, "relative-time.json") {
  RelativeTime time = relativeTime(vector["input"]["dateMs"].number, vector["input"]["nowMs"].number);
  CHECK_EQ(std::string(unitName(time.unit)), vector["output"]["unit"].text);
  CHECK_EQ(static_cast<double>(time.count), vector["output"]["count"].number);
}

UTILS_VECTOR_TEST(chat_layout_vectors_replay, "chat-layout.json") {
  const Json& input = vector["input"];
  ChatBubbleMetrics metrics = metricsOf(input["metrics"]);
  RowSizeSpec spec;
  if (isVectorFor(vector, "assistantUserMessageSizeSpec")) {
    bool hasSpec =
      assistantUserMessageSizeSpec(input["hasText"].boolean, input["hasAttachments"].boolean, metrics, spec);
    checkSizeSpec(hasSpec, spec, vector["output"]);
    return;
  }
  CHECK(isVectorFor(vector, "chatMessageSizeSpec"));
  const Json& read = input["shape"];
  ChatMessageShape shape;
  shape.hasText = read["hasText"].boolean;
  shape.hasImages = read["hasImages"].boolean;
  shape.isOwn = read["isOwn"].boolean;
  shape.showsAuthor = read["showsAuthor"].boolean;
  shape.hasCaption = read["hasCaption"].boolean;
  shape.failed = read["failed"].boolean;
  checkSizeSpec(chatMessageSizeSpec(shape, metrics, spec), spec, vector["output"]);
}

UTILS_VECTOR_TEST(feed_layout_vectors_replay, "feed-layout.json") {
  const Json& input = vector["input"];
  const Json& output = vector["output"];
  // A null is a side the image does not give, which the hosts pass as 0.
  double width = input["width"].isNull() ? 0.0 : input["width"].number;
  double height = input["height"].isNull() ? 0.0 : input["height"].number;
  FeedImageFrame frame = feedSingleImageFrame(width, height);
  CHECK_EQ(frame.aspectRatio, output.has("aspectRatio") ? output["aspectRatio"].number : 0.0);
  CHECK_EQ(frame.height, output.has("height") ? output["height"].number : 0.0);
}

UTILS_VECTOR_TEST(poll_vectors_replay, "poll.json") {
  const Json& output = vector["output"];
  std::vector<double> votes;
  for (const Json& count : vector["input"]["votes"].items) {
    votes.push_back(count.number);
  }
  PollTally tally = pollTally(votes);
  CHECK_EQ(tally.totalVotes, output["totalVotes"].number);
  CHECK_EQ(indexToNumber(tally.leadingIndex), output["leadingIndex"].number);
  CHECK_EQ(votes.size(), output["percents"].size());
  for (std::size_t index = 0; index < votes.size(); ++index) {
    CHECK_EQ(static_cast<double>(pollPercent(votes[index], tally.totalVotes)), output["percents"][index].number);
  }
}

UTILS_VECTOR_TEST(board_layout_vectors_replay, "board-layout.json") {
  const Json& input = vector["input"];
  const Json& output = vector["output"];
  if (isVectorFor(vector, "boardColumnHeight")) {
    std::vector<double> heights;
    for (const Json& height : input["columnHeights"].items) {
      heights.push_back(height.number);
    }
    CHECK_EQ(boardColumnHeight(heights, input["minimum"].number, input["maximum"].number), output.number);
    return;
  }
  CHECK(isVectorFor(vector, "boardColumnLayout"));
  BoardColumnLayout layout = boardColumnLayout(
    input["boardWidth"].number,
    input["columnWidth"].asOptionalNumber(),
    input["sidePadding"].asOptionalNumber());
  CHECK_EQ(layout.columnWidth, output["columnWidth"].number);
  CHECK_EQ(layout.sidePadding, output["sidePadding"].number);
  CHECK_EQ(layout.snapInterval, output["snapInterval"].number);
}

UTILS_VECTOR_TEST(board_move_vectors_replay, "board-move.json") {
  const Json& input = vector["input"];
  const Json& output = vector["output"];
  std::vector<std::vector<std::string>> columns = columnsOf(input["columns"]);
  BoardMovePlan plan = planBoardMove(
    columns,
    input["itemKey"].text,
    input["destinationColumn"].asIndex(),
    input["destinationKey"].text,
    input["destinationIndex"].asIndex());
  CHECK_EQ(plan.isEmpty(), output["plan"].isNull());
  if (!plan.isEmpty()) {
    CHECK_EQ(indexToNumber(plan.sourceColumn), output["plan"]["sourceColumn"].number);
    CHECK_EQ(indexToNumber(plan.sourceIndex), output["plan"]["sourceIndex"].number);
    CHECK_EQ(indexToNumber(plan.destinationColumn), output["plan"]["destinationColumn"].number);
    CHECK_EQ(indexToNumber(plan.destinationIndex), output["plan"]["destinationIndex"].number);
  }
  CHECK(applyBoardMove(columns, input["itemKey"].text, plan) == columnsOf(output["columns"]));
}

/*
 * group-into-sections.json holds the grouping of the TypeScript, UIKit and Android templates,
 * each in its own string type. The C++ gives the section title of a name that starts in ASCII,
 * which is the section the file lists that name under. A name that starts outside ASCII is the
 * host's to title.
 */
UTILS_VECTOR_TEST(group_into_sections_vectors_replay, "group-into-sections.json") {
  vector["input"].readAll();
  for (const Json& section : vector["output"]["sections"].items) {
    const std::string& title = section["title"].text;
    for (const Json& name : section["names"].items) {
      std::string initial = sectionInitial(name.text);
      if (static_cast<unsigned char>(initial[0]) < 0x80) {
        CHECK_EQ(initial, title);
      }
    }
  }
}

/*
 * markdown.json holds the link policy and the parse cases of the TypeScript reader. The native
 * templates render Markdown with their own renderer, so only the link policy replays here.
 */
UTILS_VECTOR_TEST(markdown_vectors_replay, "markdown.json") {
  if (isVectorFor(vector, "isSafeUrl")) {
    CHECK_EQ(isSafeUrl(vector["input"]["url"].text), vector["output"].boolean);
    return;
  }
  CHECK(isVectorFor(vector, "parseMarkdown"));
  vector.readAll();
}

/*
 * theme.json holds the tokens of the TypeScript themes, which the UIKit and Android templates
 * compare their own themes with. The core holds the ones a chat bubble's size reads, as the
 * defaults of ChatBubbleMetrics.
 */
UTILS_VECTOR_TEST(theme_vectors_hold_the_chat_bubble_metrics, "theme.json") {
  const Json& output = vector["output"];
  ChatBubbleMetrics metrics;
  CHECK_EQ(metrics.spacingXxs, output["spacing"]["xxs"].number);
  CHECK_EQ(metrics.spacingXs, output["spacing"]["xs"].number);
  CHECK_EQ(metrics.spacingSm, output["spacing"]["sm"].number);
  CHECK_EQ(metrics.spacingMd, output["spacing"]["md"].number);
  CHECK_EQ(metrics.spacingLg, output["spacing"]["lg"].number);
  CHECK_EQ(metrics.bodyFontSize, output["typography"]["body"]["fontSize"].number);
  CHECK_EQ(metrics.bodyLineHeight, output["typography"]["body"]["lineHeight"].number);
  CHECK_EQ(metrics.bodyLetterSpacing, output["typography"]["body"]["letterSpacing"].number);
  CHECK_EQ(metrics.captionLineHeight, output["typography"]["caption"]["lineHeight"].number);
  // The colors and the other tokens are the platforms' to check.
  output.readAll();
}

TEST(every_utils_vector_file_has_a_replay) {
  checkEveryVectorFileReplayed(SHADOWLIST_UTILS_VECTORS_DIR, "vectors");
}

UTILS_VECTOR_TEST(assistant_steps_vectors_replay, "assistant-steps.json") {
  const Json& input = vector["input"];
  std::vector<std::int64_t> positions;
  for (const Json& position : input["positions"].items) {
    positions.push_back(position.isNull() ? 0 : static_cast<std::int64_t>(position.number));
  }
  const auto steps = stepsOf(input["content"].text, positions);
  const Json& output = vector["output"];
  CHECK_EQ(steps.size(), output.size());
  for (std::size_t index = 0; index < steps.size(); ++index) {
    const Json& expected = output[index];
    if (const auto* text = std::get_if<AssistantTextStep>(&steps[index])) {
      CHECK_EQ(expected["kind"].text, std::string("text"));
      CHECK_EQ(text->text, expected["text"].text);
      CHECK_EQ(text->at, expected["at"].asIndex());
    } else {
      const auto& calls = std::get<AssistantCallsStep>(steps[index]).callIndices;
      CHECK_EQ(expected["kind"].text, std::string("calls"));
      CHECK_EQ(calls.size(), expected["callIndices"].size());
      for (std::size_t call = 0; call < calls.size(); ++call) CHECK_EQ(calls[call], expected["callIndices"][call].asIndex());
    }
  }
}
