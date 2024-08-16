cmake_minimum_required(VERSION 2.8 FATAL_ERROR)

project(AOSGraphQL)

set(PACKAGES_DIR ${CMAKE_SOURCE_DIR}/packages)

# Define the source and destination directories
set(PROCESS_CONFIG_SRC ${PACKAGES_DIR}/config/config.yml)
set(GRAPHQL_RUNTIME_SRC_DIR ${PACKAGES_DIR}/runtime)
set(GRAPHQL_SRC_DIR ${GRAPHQL_RUNTIME_SRC_DIR}/graphql)
set(PARSER_SRC_DIR ${GRAPHQL_RUNTIME_SRC_DIR}/parser)
# set(PARSER_SRC_DIR ${CMAKE_BINARY_DIR}/parser)
set(GRAPHQL_SERVER_SRC_DIR ${PACKAGES_DIR}/server)
set(GRAPHQL_GATEWAY_SRC_DIR ${PACKAGES_DIR}/gateway)
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

# TODO: remove once 'ao exec' is working
set(AO_IMAGE p3rmaw3b/ao:0.1.2)

# Add the parser subdirectory
add_subdirectory(${PARSER_SRC_DIR})

# Custom target to copy GraphQL runtime and server impl
add_custom_command(
    OUTPUT ${GRAPHQL_DEST_DIR}
    COMMAND ${CMAKE_COMMAND} -E make_directory ${GRAPHQL_DEST_DIR}
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${GRAPHQL_SRC_DIR} ${GRAPHQL_DEST_DIR}
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${GRAPHQL_SERVER_SRC_DIR} ${GRAPHQL_DEST_DIR}/server
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${GRAPHQL_GATEWAY_SRC_DIR} ${GRAPHQL_DEST_DIR}/gateway
    COMMENT "Copying GraphQL files..."
    DEPENDS ${GRAPHQL_SRC_DIR} ${GRAPHQL_SERVER_SRC_DIR} ${GRAPHQL_GATEWAY_SRC_DIR}
)

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
    OUTPUT ${LIBS_DEST_DIR}/lsqlite3.a
    OUTPUT ${LIBS_DEST_DIR}/sqlite3.a
    COMMAND ${CMAKE_COMMAND} -E make_directory ${LIBS_DEST_DIR}
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${AO_LIBS_SRC_DIR} ${LIBS_DEST_DIR}
    COMMAND ${CMAKE_COMMAND} -E copy ${PARSER_SRC_DIR}/build/libgraphqlparser/libgraphqlparser.a ${LIBS_DEST_DIR}/libgraphqlparser.a
    COMMAND ${CMAKE_COMMAND} -E copy ${PARSER_SRC_DIR}/build/luagraphqlparser/luagraphqlparser.a ${LIBS_DEST_DIR}/luagraphqlparser.a
    COMMENT "Copying static libraries..."
    DEPENDS parser_build
)

# Custom target to copy process config
add_custom_command(
    OUTPUT ${PROCESS_CONFIG_DEST}
    COMMAND ${CMAKE_COMMAND} -E copy ${PROCESS_CONFIG_SRC} ${PROCESS_CONFIG_DEST}
    COMMENT "Copying process config libraries..."
)

# Custom target to run "ao build" in the aos/pocess directory
add_custom_target(ao_build ALL
    COMMAND ${CMAKE_COMMAND} -E chdir ${DEST_DIR} ao build
    COMMENT "Running 'ao build'..."
    DEPENDS ${GRAPHQL_DEST_DIR} ${PROCESS_CONFIG_DEST} ${LIBS_DEST_DIR}/libgraphqlparser.a ${LIBS_DEST_DIR}/luagraphqlparser.a
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
add_custom_target(default_clean
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${GRAPHQL_DEST_DIR}
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${LIBS_DEST_DIR}
    COMMAND ${CMAKE_COMMAND} -E remove ${PROCESS_CONFIG_DEST}
    # COMMAND ${CMAKE_COMMAND} --build ${CMAKE_BINARY_DIR}/parser --target clean
    COMMENT "Cleaning up..."
)

# Set the default target to build everything
add_custom_target(default_all
    DEPENDS default_clean parser_build ao_build
)
