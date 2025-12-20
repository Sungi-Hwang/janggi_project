@echo off
REM Build Fairy-Stockfish as a shared library (DLL) for Flutter FFI

echo Building Stockfish DLL for Janggi...

REM Set compiler and flags
set CXX=g++
set CXXFLAGS=-O3 -std=c++17 -DNDEBUG -DIS_64BIT -DUSE_POPCNT -DLARGEBOARDS -DNNUE_EMBEDDING_OFF -DPRECOMPUTED_MAGICS -shared -fPIC
set INCLUDES=-I.
set OUTPUT=stockfish.dll

REM Source files
set SOURCES=benchmark.cpp bitbase.cpp bitboard.cpp endgame.cpp evaluate.cpp ^
material.cpp misc.cpp movegen.cpp movepick.cpp pawns.cpp position.cpp psqt.cpp ^
search.cpp thread.cpp timeman.cpp tt.cpp uci.cpp ucioption.cpp tune.cpp ^
partner.cpp parser.cpp piece.cpp variant.cpp xboard.cpp ^
syzygy/tbprobe.cpp ^
nnue/evaluate_nnue.cpp nnue/features/half_ka_v2.cpp nnue/features/half_ka_v2_variants.cpp ^
c_api.cpp

REM Build the DLL
echo Compiling...
%CXX% %CXXFLAGS% %INCLUDES% %SOURCES% -o %OUTPUT% -static-libgcc -static-libstdc++ -Wl,--out-implib,libstockfish.a

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo Build successful!
    echo Output: %OUTPUT%
    echo ========================================
    echo.
    echo Copying DLL to Flutter project...
    if not exist "..\..\windows\runner" mkdir "..\..\windows\runner"
    copy /Y %OUTPUT% ..\..\windows\runner\
    copy /Y %OUTPUT% ..\..\
    echo Done!
) else (
    echo.
    echo ========================================
    echo Build failed with error code %ERRORLEVEL%
    echo ========================================
)

pause
