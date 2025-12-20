@echo off
echo Compiling DLL test program...
echo.

g++ -o test_dll.exe test_dll.cpp -std=c++17

if %ERRORLEVEL% EQU 0 (
    echo ========================================
    echo Build successful!
    echo ========================================
    echo.
    echo Running tests...
    echo.
    test_dll.exe
) else (
    echo ========================================
    echo Build failed!
    echo ========================================
    pause
)
