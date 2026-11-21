cmake_minimum_required(VERSION 3.13)
project(shadowlistutils CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# The template logic comes from this repo's packages/shadowlist-utils-core. A host that vendors
# it elsewhere passes the copy's folder as SHADOWLIST_UTILS_CORE_DIR. The folder is named
# shadowlist-utils-core.
if(NOT SHADOWLIST_UTILS_CORE_DIR)
  get_filename_component(SHADOWLIST_UTILS_CORE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../shadowlist-utils-core" ABSOLUTE)
endif()
get_filename_component(SHADOWLIST_UTILS_CORE_PARENT_DIR "${SHADOWLIST_UTILS_CORE_DIR}" DIRECTORY)

# The engine headers come from the engine checkout's packages/shadowlist-core. Gradle passes the
# checkout as SHADOWLIST_ROOT. A host that vendors the core headers passes their folder as
# SHADOWLIST_UTILS_ENGINE_CORE_DIR instead. That folder is named shadowlist-core.
if(NOT SHADOWLIST_UTILS_ENGINE_CORE_DIR)
  if(NOT SHADOWLIST_ROOT)
    message(FATAL_ERROR "Set SHADOWLIST_ROOT to the shadowlist engine checkout, or SHADOWLIST_UTILS_ENGINE_CORE_DIR to its packages/shadowlist-core folder.")
  endif()
  set(SHADOWLIST_UTILS_ENGINE_CORE_DIR "${SHADOWLIST_ROOT}/packages/shadowlist-core")
endif()
if(NOT EXISTS "${SHADOWLIST_UTILS_ENGINE_CORE_DIR}/Constants.hpp")
  message(FATAL_ERROR "The shadowlist core headers were not found in ${SHADOWLIST_UTILS_ENGINE_CORE_DIR}.")
endif()
get_filename_component(SHADOWLIST_UTILS_ENGINE_PARENT_DIR "${SHADOWLIST_UTILS_ENGINE_CORE_DIR}" DIRECTORY)

# Only the template logic compiles here. It uses the engine's headers and none of its sources.
# The list core is already inside the kit's shadowlistkit library, and a second copy of it would
# double the binary.
include(${SHADOWLIST_UTILS_CORE_DIR}/sources.cmake)

add_library(shadowlistutils SHARED
  ${CMAKE_CURRENT_LIST_DIR}/ShadowListUtilsCoreJNI.cpp
  ${SHADOWLIST_UTILS_SOURCES}
)

# Headers include each other as <shadowlist-utils-core/...> and <shadowlist-core/...>. The parent
# folders resolve them.
target_include_directories(shadowlistutils PRIVATE
  ${SHADOWLIST_UTILS_CORE_PARENT_DIR}
  ${SHADOWLIST_UTILS_ENGINE_PARENT_DIR}
)

# The static C++ runtime stays private to the library. Apps with their own libc++ do not see its symbols.
target_link_options(shadowlistutils PRIVATE -Wl,--exclude-libs,ALL)

# A row's layout calls this code for every row it sizes. Optimized builds use -O3.
target_compile_options(shadowlistutils PRIVATE -fno-rtti $<$<NOT:$<CONFIG:Debug>>:-O3>)

# A host that links a second copy of the core into the same app renames this copy's namespace,
# like SHADOWLIST_UTILS_COMPILE_DEFINITIONS="azimgd=host_utils_azimgd".
if(SHADOWLIST_UTILS_COMPILE_DEFINITIONS)
  target_compile_definitions(shadowlistutils PRIVATE ${SHADOWLIST_UTILS_COMPILE_DEFINITIONS})
endif()
