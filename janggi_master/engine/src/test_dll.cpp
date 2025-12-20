#include <iostream>
#include <windows.h>

typedef void (*InitFunc)();
typedef const char* (*CommandFunc)(const char*);
typedef void (*CleanupFunc)();

int main() {
    std::cout << "Loading stockfish.dll..." << std::endl;

    HMODULE hDll = LoadLibraryA("../../windows/runner/stockfish.dll");
    if (!hDll) {
        std::cerr << "Failed to load DLL! Error code: " << GetLastError() << std::endl;
        return 1;
    }

    std::cout << "DLL loaded successfully!" << std::endl;

    // Get function pointers
    auto stockfish_init = (InitFunc)GetProcAddress(hDll, "stockfish_init");
    auto stockfish_command = (CommandFunc)GetProcAddress(hDll, "stockfish_command");
    auto stockfish_cleanup = (CleanupFunc)GetProcAddress(hDll, "stockfish_cleanup");

    if (!stockfish_init || !stockfish_command || !stockfish_cleanup) {
        std::cerr << "Failed to get function pointers!" << std::endl;
        FreeLibrary(hDll);
        return 1;
    }

    std::cout << "Function pointers loaded successfully!" << std::endl;
    std::cout << "\n=== Testing Stockfish Engine ===" << std::endl;

    // Test 1: Initialize
    std::cout << "\n[Test 1] Initializing engine..." << std::endl;
    stockfish_init();

    // Test 2: UCI command
    std::cout << "\n[Test 2] Sending 'uci' command..." << std::endl;
    const char* response = stockfish_command("uci");
    std::cout << "Response:\n" << response << std::endl;

    // Test 3: isready
    std::cout << "\n[Test 3] Sending 'isready' command..." << std::endl;
    response = stockfish_command("isready");
    std::cout << "Response: " << response << std::endl;

    // Test 4: Set position to starting position
    std::cout << "\n[Test 4] Setting starting position..." << std::endl;
    response = stockfish_command("position startpos");
    std::cout << "Response: " << response << std::endl;

    // Test 5: Get best move (shallow search)
    std::cout << "\n[Test 5] Getting best move (depth 5)..." << std::endl;
    response = stockfish_command("go depth 5");
    std::cout << "Response:\n" << response << std::endl;

    // Test 6: New game
    std::cout << "\n[Test 6] Starting new game..." << std::endl;
    response = stockfish_command("ucinewgame");
    std::cout << "Response: " << response << std::endl;

    // Test 7: Position with moves
    std::cout << "\n[Test 7] Setting position with moves..." << std::endl;
    response = stockfish_command("position startpos moves b0c2 b9c7");
    std::cout << "Response: " << response << std::endl;

    // Test 8: Another best move
    std::cout << "\n[Test 8] Getting best move after 2 moves..." << std::endl;
    response = stockfish_command("go depth 5");
    std::cout << "Response:\n" << response << std::endl;

    // Test 9: Error handling - invalid command
    std::cout << "\n[Test 9] Testing error handling (invalid command)..." << std::endl;
    response = stockfish_command("invalid_command");
    std::cout << "Response: " << response << std::endl;

    // Test 10: Cleanup
    std::cout << "\n[Test 10] Cleaning up..." << std::endl;
    stockfish_cleanup();
    std::cout << "Cleanup complete!" << std::endl;

    FreeLibrary(hDll);

    std::cout << "\n=== All tests completed ===" << std::endl;
    std::cout << "\nPress Enter to exit...";
    std::cin.get();

    return 0;
}
