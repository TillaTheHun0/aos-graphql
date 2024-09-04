cmake_minimum_required(VERSION 2.8 FATAL_ERROR)

project(AOSGraphQL)

option(INCLUDE_GRAPHQL_BUNDLES "Build and copy the GraphQL runtime, server, and gateway bundles, to be built as part of the WASM")
option(INCLUDE_SQLITE_SYMBOLS "Include the SQLite symbols and lua bindings, to be built as part of the WASM")
set(PROCESS_CONFIG_TYPE "sm" CACHE STRING "The ao dev-cli configuration file type to use")

set(PACKAGES_DIR ${CMAKE_SOURCE_DIR}/packages)

# Define the source and destination directories
set(PROCESS_CONFIG_SRC ${PACKAGES_DIR}/config/config.${PROCESS_CONFIG_TYPE}.yml)

set(GRAPHQL_RUNTIME_SRC_DIR ${PACKAGES_DIR}/runtime)
set(GRAPHQL_SRC_DIR ${GRAPHQL_RUNTIME_SRC_DIR}/graphql)
set(PARSER_SRC_DIR ${GRAPHQL_RUNTIME_SRC_DIR}/parser)
set(GRAPHQL_RUNTIME_SRC_BUNDLE ${GRAPHQL_SRC_DIR}/bundle.lua)

# set(PARSER_SRC_DIR ${CMAKE_BINARY_DIR}/parser)
set(GRAPHQL_SERVER_SRC_DIR ${PACKAGES_DIR}/server)
set(GRAPHQL_SERVER_SRC_BUNDLE ${GRAPHQL_SERVER_SRC_DIR}/bundle.lua)

set(GRAPHQL_GATEWAY_SRC_DIR ${PACKAGES_DIR}/gateway)
set(GRAPHQL_GATEWAY_SRC_BUNDLE ${GRAPHQL_GATEWAY_SRC_DIR}/bundle.lua)

set(AO_LIBS_SRC_DIR ${CMAKE_SOURCE_DIR}/ao_libs)

set(DEST_DIR ${CMAKE_SOURCE_DIR}/aos/process)
set(GRAPHQL_DEST_DIR ${DEST_DIR}/graphql)
set(LIBS_DEST_DIR ${DEST_DIR}/libs)
set(PROCESS_CONFIG_DEST ${DEST_DIR}/config.yml)

set(PROCESS_WASM_ARTIFACT ${DEST_DIR}/process.wasm)
set(PROCESS_WASM_DEST ${CMAKE_SOURCE_DIR}/process.wasm)

set(EMXX_CFLAGS "-s MEMORY64=1 -O3 -msimd128 -fno-rtti -DNDEBUG \
-flto=full -s BUILD_AS_WORKER=1 -s EXPORT_ALL=1 \
-s EXPORT_ES6=1 -s MODULARIZE=1 -s INITIAL_MEMORY=10MB \
-s MAXIMUM_MEMORY=8GB -s ALLOW_MEMORY_GROWTH -s FORCE_FILESYSTEM=1 \
-s EXPORTED_FUNCTIONS=_main -s EXPORTED_RUNTIME_METHODS=callMain -s \
NO_EXIT_RUNTIME=1 -Wno-unused-command-line-argument -Wno-experimental /lua-5.3.4/src/liblua.a -I/lua-5.3.4/src"
)

set(BUILD_DEPS_LIST ${LIBS_DEST_DIR}/libgraphqlparser.a ${LIBS_DEST_DIR}/luagraphqlparser.a ${PROCESS_CONFIG_DEST})

# TODO: remove once 'ao exec' is working
set(AO_IMAGE p3rmaw3b/ao:0.1.2)

# Add the parser subdirectory
# add_subdirectory(${PARSER_SRC_DIR})

# Custom target to copy GraphQL runtime and server impl
if(INCLUDE_GRAPHQL_BUNDLES)
    list(APPEND BUILD_DEPS_LIST ${GRAPHQL_DEST_DIR})
    add_custom_command(
        OUTPUT ${GRAPHQL_DEST_DIR}
        COMMAND ${CMAKE_COMMAND} -E make_directory ${GRAPHQL_DEST_DIR}
        COMMAND ${CMAKE_COMMAND} -E copy ${GRAPHQL_RUNTIME_SRC_BUNDLE} ${GRAPHQL_DEST_DIR}/runtime.lua
        COMMAND ${CMAKE_COMMAND} -E copy ${GRAPHQL_SERVER_SRC_BUNDLE} ${GRAPHQL_DEST_DIR}/server.lua
        COMMAND ${CMAKE_COMMAND} -E copy ${GRAPHQL_GATEWAY_SRC_BUNDLE} ${GRAPHQL_DEST_DIR}/gateway.lua
        COMMENT "Copying GraphQL Bundles..."
        DEPENDS ${GRAPHQL_RUNTIME_SRC_BUNDLE} ${GRAPHQL_SERVER_SRC_BUNDLE} ${GRAPHQL_GATEWAY_SRC_BUNDLE}
    )
else()
    message(STATUS "GraphQL Bundles not included...")
endif()

# Custom target to build the parser project
add_custom_target(parser_build ALL
    # COMMAND ${CMAKE_COMMAND} --build ${CMAKE_BINARY_DIR}/parser
    # TODO: replace with calls to 'ao exec'
    COMMAND docker run -v ${PARSER_SRC_DIR}:/parser ${AO_IMAGE} sh -c 'cd /parser && mkdir -p build && cd build && emcmake cmake -DCMAKE_CXX_FLAGS=${EMXX_CFLAGS} -S .. -B .'
    COMMAND docker run -v ${PARSER_SRC_DIR}:/parser ${AO_IMAGE} sh -c 'cd /parser/build && cmake --build .'
    COMMENT "Building parser project..."
)

# Custom target to copy the static libraries
add_custom_command(
    OUTPUT ${LIBS_DEST_DIR}/libgraphqlparser.a
    OUTPUT ${LIBS_DEST_DIR}/luagraphqlparser.a
    COMMAND ${CMAKE_COMMAND} -E make_directory ${LIBS_DEST_DIR}
    COMMAND ${CMAKE_COMMAND} -E copy ${PARSER_SRC_DIR}/build/libgraphqlparser/libgraphqlparser.a ${LIBS_DEST_DIR}/libgraphqlparser.a
    COMMAND ${CMAKE_COMMAND} -E copy ${PARSER_SRC_DIR}/build/luagraphqlparser/luagraphqlparser.a ${LIBS_DEST_DIR}/luagraphqlparser.a
    COMMENT "Copying GraphQL parser libraries..."
    DEPENDS parser_build
)

if(INCLUDE_SQLITE_SYMBOLS)
    list(APPEND BUILD_DEPS_LIST ${LIBS_DEST_DIR}/lsqlite3.a ${LIBS_DEST_DIR}/sqlite3.a)
    add_custom_command(
        OUTPUT ${LIBS_DEST_DIR}/lsqlite3.a
        OUTPUT ${LIBS_DEST_DIR}/sqlite3.a
        COMMAND ${CMAKE_COMMAND} -E make_directory ${LIBS_DEST_DIR}
        COMMAND ${CMAKE_COMMAND} -E copy ${AO_LIBS_SRC_DIR}/sqlite3.a ${LIBS_DEST_DIR}/sqlite3.a
        COMMAND ${CMAKE_COMMAND} -E copy ${AO_LIBS_SRC_DIR}/lsqlite3.a ${LIBS_DEST_DIR}/lsqlite3.a
        COMMENT "Copying SQLite libraries..."
    )
else()
    message(STATUS "SQLite Libraries not included...")
endif()

# Custom target to copy process config
add_custom_command(
    OUTPUT ${PROCESS_CONFIG_DEST}
    COMMAND ${CMAKE_COMMAND} -E copy ${PROCESS_CONFIG_SRC} ${PROCESS_CONFIG_DEST}
    COMMENT "Copying ao Dev-CLI config..."
)

# Custom target to run "ao build" in the aos/pocess directory
add_custom_target(ao_build ALL
    COMMAND ${CMAKE_COMMAND} -E chdir ${DEST_DIR} ao build
    COMMENT "Running 'ao build'..."
    DEPENDS ${BUILD_DEPS_LIST}
)

# Custom command to copy the process.wasm file
add_custom_command(
    TARGET ao_build
    COMMAND ${CMAKE_COMMAND} -E copy ${PROCESS_WASM_ARTIFACT} ${PROCESS_WASM_DEST}
    COMMENT "Copying process.wasm to build directory..."
    DEPENDS ao_build ${PROCESS_WASM_ARTIFACT}
)

# Ensure proper build order
add_dependencies(ao_build parser_build)

# Clean up target
add_custom_target(clean
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${GRAPHQL_DEST_DIR}
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${LIBS_DEST_DIR}
    COMMAND ${CMAKE_COMMAND} -E remove ${PROCESS_CONFIG_DEST}
    COMMAND ${CMAKE_COMMAND} -E remove ${PROCESS_WASM_ARTIFACT}
    # COMMAND ${CMAKE_COMMAND} --build ${CMAKE_BINARY_DIR}/parser --target clean
    COMMENT "Cleaning up..."
)

# Set the default target to build everything
add_custom_target(default_all
    DEPENDS default_clean parser_build ao_build
)
