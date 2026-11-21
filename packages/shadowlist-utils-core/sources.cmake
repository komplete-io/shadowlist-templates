# The template logic, which the templates libraries and the utils core tests link. It builds
# without the engine sources and includes the engine headers as shadowlist-core/...
file(GLOB SHADOWLIST_UTILS_SOURCES CONFIGURE_DEPENDS
  ${CMAKE_CURRENT_LIST_DIR}/*.cpp)
