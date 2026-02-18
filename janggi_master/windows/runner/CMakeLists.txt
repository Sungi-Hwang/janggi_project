cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
  "Runner.rc"
  "runner.exe.manifest"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the build version.
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION=\"${FLUTTER_VERSION}\"")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MAJOR=${FLUTTER_VERSION_MAJOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_MINOR=${FLUTTER_VERSION_MINOR}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_PATCH=${FLUTTER_VERSION_PATCH}")
target_compile_definitions(${BINARY_NAME} PRIVATE "FLUTTER_VERSION_BUILD=${FLUTTER_VERSION_BUILD}")

# Disable Windows macros that collide with C++ standard library functions.
target_compile_definitions(${BINARY_NAME} PRIVATE "NOMINMAX")

# Add dependency libraries and include directories. Add any application-specific
# dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_link_libraries(${BINARY_NAME} PRIVATE "dwmapi.lib")
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)

# --- Stockfish Engine Configuration ---
# Collect engine sources
file(GLOB ENGINE_SOURCES "../../engine/src/*.cpp")
# Exclude standalone entry points and web-specific files
list(FILTER ENGINE_SOURCES EXCLUDE REGEX "main\\.cpp$")
list(FILTER ENGINE_SOURCES EXCLUDE REGEX "test_dll\\.cpp$")
list(FILTER ENGINE_SOURCES EXCLUDE REGEX "ffishjs\\.cpp$")
list(FILTER ENGINE_SOURCES EXCLUDE REGEX "pyffish\\.cpp$")

# Define the shared library
add_library(stockfish SHARED ${ENGINE_SOURCES})

# Compilation definitions (Janggi + Windows)
target_compile_definitions(stockfish PRIVATE
  "-DLARGEBOARDS"
  "-DALLVARS"
  "-DIS_64BIT"
  "-DUSE_POPCNT"
  "-D_WIN32"
  "-D_WINDLL"
  "-DNOMINMAX"
)

# Include directories
target_include_directories(stockfish PRIVATE "../../engine/src")

# Ensure stockfish is built before runner (though not strictly linked)
add_dependencies(${BINARY_NAME} stockfish)

# Copy stockfish.dll to the runner's output directory (next to runner.exe)
add_custom_command(TARGET ${BINARY_NAME} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different
  $<TARGET_FILE:stockfish>
  $<TARGET_FILE_DIR:${BINARY_NAME}>
)
# --------------------------------------
