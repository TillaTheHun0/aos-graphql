cmake_minimum_required(VERSION 2.8 FATAL_ERROR)

project(luagraphqlparser C CXX)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE RelWithDebInfo)
endif()
set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}" ${CMAKE_MODULE_PATH})

# Find other dependencies

add_subdirectory(libgraphqlparser EXCLUDE_FROM_ALL)
include_directories("${CMAKE_CURRENT_SOURCE_DIR}/libgraphqlparser" "${CMAKE_CURRENT_BINARY_DIR}/libgraphqlparser")

# Set CFLAGS
set(CMAKE_C_FLAGS "${CMAKE_CXX_FLAGS}")
set(CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG} ${CMAKE_C_FLAGS}")
# Set CXXFLAGS
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} ${CMAKE_CXX_FLAGS}")

# Build module
add_subdirectory(luagraphqlparser)
