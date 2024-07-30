cmake_minimum_required(VERSION 2.8 FATAL_ERROR)

project(AOSGraphQL)

# Define the source and destination directories
set(GRAPHQL_DIR ${CMAKE_SOURCE_DIR}/graphql)
set(DEST_DIR ${CMAKE_SOURCE_DIR}/aos/process)
set(PARSER_LIB ${CMAKE_BINARY_DIR}/parser/luagraphqlparser/luagraphqlparser.so)
set(LIB_DEST_DIR ${DEST_DIR}/graphql)
set(PROCESS_WASM_LIB ${DEST_DIR}/process.wasm)
set(PROCESS_WASM_DEST ${CMAKE_SOURCE_DIR}/process.wasm)

# Add the parser subdirectory
add_subdirectory(parser)

# Custom target to copy GraphQL files
add_custom_command(
    OUTPUT ${DEST_DIR}/graphql
    COMMAND ${CMAKE_COMMAND} -E make_directory ${DEST_DIR}/graphql
    COMMAND ${CMAKE_COMMAND} -E copy_directory ${GRAPHQL_DIR} ${DEST_DIR}/graphql
    COMMENT "Copying GraphQL files..."
    DEPENDS ${GRAPHQL_DIR}
)

# Custom target to build the parser project
add_custom_target(parser_build ALL
    COMMAND ${CMAKE_COMMAND} --build ${CMAKE_BINARY_DIR}/parser
    COMMENT "Building parser project..."
)

# Custom target to copy the shared library
add_custom_command(
    OUTPUT ${LIB_DEST_DIR}/luagraphqlparser.so
    COMMAND ${CMAKE_COMMAND} -E make_directory ${LIB_DEST_DIR}
    COMMAND ${CMAKE_COMMAND} -E copy ${PARSER_LIB} ${LIB_DEST_DIR}/luagraphqlparser.so
    COMMENT "Copying shared library..."
    DEPENDS parser_build
)

# Custom target to run "ao build" in the aos/process directory
add_custom_target(ao_build ALL
    COMMAND ${CMAKE_COMMAND} -E chdir ${DEST_DIR} ao build
    COMMENT "Running 'ao build'..."
    DEPENDS ${DEST_DIR}/graphql ${LIB_DEST_DIR}/luagraphqlparser.so
)

# Custom command to copy the process.wasm file
add_custom_command(
    TARGET ao_build
    COMMAND ${CMAKE_COMMAND} -E copy ${PROCESS_WASM_LIB} ${PROCESS_WASM_DEST}
    COMMENT "Copying process.wasm to build directory..."
    DEPENDS ao_build ${PROCESS_WASM_LIB}
)

# Ensure proper build order
add_dependencies(ao_build parser_build)

# Clean up target
add_custom_target(clean
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${DEST_DIR}/graphql
    COMMAND ${CMAKE_COMMAND} --build ${CMAKE_BINARY_DIR}/parser --target clean
    COMMAND ${CMAKE_COMMAND} -E remove ${PROCESS_WASM_DEST}
    COMMENT "Cleaning up..."
)

# Set the default target to build everything
add_custom_target(default_all
    DEPENDS clean parser_build ao_build
)
