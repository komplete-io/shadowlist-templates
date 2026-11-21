#pragma once

#include "VectorHelpers.hpp"

/*
 * The vector files of the template logic in packages/shadowlist-utils-core, in vectors/ next to
 * these tests. The list engine keeps its own vectors in its repository.
 */

/*
 * A test that replays one vector file of vectors/. The build passes the folder as
 * SHADOWLIST_UTILS_VECTORS_DIR.
 */
#define UTILS_VECTOR_TEST(name, file) SLT_FOLDER_VECTOR_TEST(name, SHADOWLIST_UTILS_VECTORS_DIR, file)
