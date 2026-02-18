cmake_minimum_required(VERSION 3.10)

project(stockfish_engine)

# Add all the source files from the src directory
file(GLOB_RECURSE SOURCES "src/*.cpp" "src/syzygy/*.cpp" "src/nnue/*.cpp" "src/nnue/features/*.cpp")

# Exclude platform-specific and standalone executable files
list(REMOVE_ITEM SOURCES
    "${CMAKE_CURRENT_SOURCE_DIR}/src/main.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/test_dll.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/ffishjs.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/pyffish.cpp"
)

# Define the library as a shared library
add_library(stockfish SHARED ${SOURCES})

# Add include directories
target_include_directories(stockfish PUBLIC src)

# Define compile options
target_compile_definitions(stockfish PRIVATE
    -DNDEBUG
    -DUSE_PTHREADS
    -DNNUE_EMBEDDING_OFF
    -DLARGEBOARDS
    -DALLVARS
)

# Add IS_64BIT only for 64-bit systems
if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    target_compile_definitions(stockfish PRIVATE -DIS_64BIT)
endif()

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

# Link against Android log library for debugging
if(ANDROID)
    find_library(log-lib log)
    target_link_libraries(stockfish ${log-lib})
endif()
