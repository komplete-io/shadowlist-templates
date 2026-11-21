cmake_minimum_required(VERSION 3.13)
project(shadowlist_utils_core_tests CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# The engine checkout the template logic builds against. The template logic includes a few
# engine headers as shadowlist-core/... and links none of the engine sources. The default is
# the SHADOWLIST_ROOT environment variable, then a shadowlist checkout next to this repository.
if(DEFINED ENV{SHADOWLIST_ROOT} AND NOT "$ENV{SHADOWLIST_ROOT}" STREQUAL "")
  set(SHADOWLIST_ROOT_DEFAULT "$ENV{SHADOWLIST_ROOT}")
else()
  set(SHADOWLIST_ROOT_DEFAULT "${CMAKE_CURRENT_SOURCE_DIR}/../../../shadowlist")
endif()
set(SHADOWLIST_ROOT "${SHADOWLIST_ROOT_DEFAULT}" CACHE PATH "Root of the shadowlist engine checkout")
get_filename_component(SHADOWLIST_ROOT "${SHADOWLIST_ROOT}" ABSOLUTE)

if(NOT EXISTS "${SHADOWLIST_ROOT}/packages/shadowlist-core/Constants.hpp")
  message(FATAL_ERROR
    "The shadowlist engine was not found at ${SHADOWLIST_ROOT}: "
    "${SHADOWLIST_ROOT}/packages/shadowlist-core/Constants.hpp is missing. "
    "Check out the engine next to this repository or point SHADOWLIST_ROOT at it, "
    "as an environment variable or with -DSHADOWLIST_ROOT=<path>.")
endif()

include(${CMAKE_CURRENT_SOURCE_DIR}/../shadowlist-utils-core/sources.cmake)
file(GLOB TEST_SRCS CONFIGURE_DEPENDS
  ${CMAKE_CURRENT_SOURCE_DIR}/tests_utils_*.cpp
  ${CMAKE_CURRENT_SOURCE_DIR}/main.cpp)

add_executable(shadowlist_utils_core_tests ${SHADOWLIST_UTILS_SOURCES} ${TEST_SRCS})

target_include_directories(shadowlist_utils_core_tests PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/..      # for shadowlist-utils-core includes
  ${SHADOWLIST_ROOT}/packages         # for shadowlist-core includes
  ${CMAKE_CURRENT_SOURCE_DIR})        # for the test framework and helpers

# Keep core [SL] traces out of test output in every build type.
target_compile_definitions(shadowlist_utils_core_tests PRIVATE SHADOWLIST_DEBUG_LOG=0)

# The vector tests replay the files in vectors/. The jest tests of shadowlist-utils replay them too.
target_compile_definitions(shadowlist_utils_core_tests PRIVATE
  SHADOWLIST_UTILS_VECTORS_DIR="${CMAKE_CURRENT_SOURCE_DIR}/vectors")

enable_testing()
add_test(NAME shadowlist_utils_core_tests COMMAND shadowlist_utils_core_tests)
