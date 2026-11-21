cmake_minimum_required(VERSION 3.13)
project(shadowlistutils CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# The packages folder of this repository, which holds shadowlist-utils-core.
get_filename_component(SHADOWLIST_TEMPLATES_PACKAGES_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../.." ABSOLUTE)

# The engine checkout. -DSHADOWLIST_ROOT=... or the SHADOWLIST_ROOT environment variable override
# the default, a shadowlist folder next to this repository.
if(DEFINED ENV{SHADOWLIST_ROOT} AND NOT "$ENV{SHADOWLIST_ROOT}" STREQUAL "")
  set(SHADOWLIST_ROOT_DEFAULT "$ENV{SHADOWLIST_ROOT}")
else()
  set(SHADOWLIST_ROOT_DEFAULT "${SHADOWLIST_TEMPLATES_PACKAGES_DIR}/../../shadowlist")
endif()
set(SHADOWLIST_ROOT "${SHADOWLIST_ROOT_DEFAULT}" CACHE PATH "The shadowlist engine checkout")
get_filename_component(SHADOWLIST_ROOT "${SHADOWLIST_ROOT}" ABSOLUTE)
if(NOT EXISTS "${SHADOWLIST_ROOT}/packages/shadowlist-core/Row.hpp")
  message(FATAL_ERROR
    "shadowlist engine checkout not found at ${SHADOWLIST_ROOT}. Clone it next to this repository "
    "or pass -DSHADOWLIST_ROOT=<path> (or set the SHADOWLIST_ROOT environment variable).")
endif()

include(${SHADOWLIST_TEMPLATES_PACKAGES_DIR}/shadowlist-utils-core/sources.cmake)

add_executable(shadowlistutils
  ShadowListUtilsCoreWasm.cpp
  ${SHADOWLIST_UTILS_SOURCES}
)

# The module loads as an ES module named shadowlistutils.mjs next to shadowlistutils.wasm.
set_target_properties(shadowlistutils PROPERTIES SUFFIX ".mjs")

# Utility headers include <shadowlist-utils-core/...> from this repository and the engine
# headers as <shadowlist-core/...> from the engine checkout.
target_include_directories(shadowlistutils PRIVATE
  ${SHADOWLIST_TEMPLATES_PACKAGES_DIR}
  ${SHADOWLIST_ROOT}/packages
)

target_compile_options(shadowlistutils PRIVATE -fno-rtti $<$<NOT:$<CONFIG:Debug>>:-O3>)

target_link_options(shadowlistutils PRIVATE
  -fno-rtti
  $<$<NOT:$<CONFIG:Debug>>:-O3>
  -sMODULARIZE=1
  -sEXPORT_ES6=1
  -sEXPORT_NAME=createShadowListUtilsModule
  -sENVIRONMENT=web,node
  -sALLOW_MEMORY_GROWTH=1
  -sFILESYSTEM=0
  -sEXPORTED_FUNCTIONS=_malloc,_free
  -sEXPORTED_RUNTIME_METHODS=HEAPF64,HEAPU8
)
