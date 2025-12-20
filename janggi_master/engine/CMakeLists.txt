cmake_minimum_required(VERSION 3.10)

project(stockfish_engine)

# Add all the source files from the src directory
file(GLOB_RECURSE SOURCES "src/*.cpp" "src/syzygy/*.cpp" "src/nnue/*.cpp" "src/nnue/features/*.cpp")
list(APPEND SOURCES "src/c_api.cpp")

# Define the library as a shared library
add_library(stockfish SHARED ${SOURCES})

# Add include directories
target_include_directories(stockfish PUBLIC src)

# Define compile options
target_compile_definitions(stockfish PRIVATE
    -DNDEBUG
    -DIS_64BIT
    -DUSE_PTHREADS
    -DNNUE_EMBEDDING_OFF
)

# For Windows, we need to export the symbols
if(WIN32)
    target_compile_definitions(stockfish PRIVATE -DLARGE_PAGES)
endif()

# Set the output directory for the library
set_target_properties(stockfish PROPERTIES
    ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)
