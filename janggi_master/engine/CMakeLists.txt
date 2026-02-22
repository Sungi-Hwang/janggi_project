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
    USE_PTHREADS
    NNUE_EMBEDDING_OFF
    LARGEBOARDS
    ALLVARS
    "$<$<OR:$<CONFIG:Release>,$<CONFIG:RelWithDebInfo>,$<CONFIG:MinSizeRel>>:NDEBUG>"
)

if(MSVC)
    target_compile_options(stockfish PRIVATE
        "$<$<OR:$<CONFIG:Release>,$<CONFIG:RelWithDebInfo>,$<CONFIG:MinSizeRel>>:/O2>"
    )
else()
    target_compile_options(stockfish PRIVATE
        "$<$<OR:$<CONFIG:Release>,$<CONFIG:RelWithDebInfo>,$<CONFIG:MinSizeRel>>:-O3>"
    )
endif()

# Add IS_64BIT only for 64-bit systems
if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    target_compile_definitions(stockfish PRIVATE IS_64BIT)
endif()

# For Windows, we need to export the symbols
if(WIN32)
    target_compile_definitions(stockfish PRIVATE LARGE_PAGES)
endif()

# Enable ARM NEON path when building Android ARM ABIs.
if(ANDROID AND (ANDROID_ABI STREQUAL "arm64-v8a" OR ANDROID_ABI STREQUAL "armeabi-v7a"))
    target_compile_definitions(stockfish PRIVATE USE_NEON)
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
