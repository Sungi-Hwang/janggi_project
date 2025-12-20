
#include <iostream>
#include <string>
#include <sstream>
#include <vector>
#include <cstring>
#include <mutex>

#include "uci.h"
#include "thread.h"
#include "position.h"
#include "misc.h"
#include "movegen.h"
#include "search.h"
#include "variant.h"
#include "piece.h"
#include "psqt.h"
#include "bitboard.h"
#include "endgame.h"

using namespace Stockfish;

// Thread safety
static std::mutex g_engine_mutex;
static bool g_initialized = false;

// A buffer to capture the engine's output
std::stringstream cout_buffer;
std::streambuf* old_cout_streambuf = nullptr;

// The engine's position and state
Position g_pos;
StateListPtr g_states(new std::deque<StateInfo>(1));

// A buffer for the returned output string
char output_buffer[8192];

// Helper function to handle position command
void handle_position(Position& pos, std::istringstream& is, StateListPtr& states) {
    Move m;
    std::string token, fen;

    is >> token;
    bool sfen = token == "sfen";

    if (token == "startpos") {
        std::string variant_name = Options["UCI_Variant"];
        std::cerr << "[POSITION] Using variant: " << variant_name << std::endl;
        auto it = variants.find(variant_name);
        if (it == variants.end()) {
            std::cout << "error: variant not found" << std::endl;
            return;
        }
        fen = it->second->startFen;
        std::cerr << "[POSITION] startFen: " << fen << std::endl;
        is >> token; // Consume "moves" token if any
    }
    else if (token == "fen" || token == "sfen") {
        while (is >> token && token != "moves")
            fen += token + " ";
    }
    else {
        return;
    }

    auto it = variants.find(Options["UCI_Variant"]);
    if (it == variants.end()) {
        std::cout << "error: variant not found" << std::endl;
        return;
    }

    states = StateListPtr(new std::deque<StateInfo>(1));
    pos.set(it->second, fen, Options["UCI_Chess960"], &states->back(), Threads.main(), sfen);

    // Parse move list (if any)
    int move_count = 0;
    while (is >> token) {
        std::cerr << "[MOVE_PARSE] Parsing move: " << token << std::endl;
        m = UCI::to_move(pos, token);
        if (m == MOVE_NONE) {
            std::cerr << "[MOVE_PARSE] Invalid move, stopping: " << token << std::endl;
            break;
        }
        std::cerr << "[MOVE_PARSE] Valid move, applying..." << std::endl;
        states->emplace_back();
        pos.do_move(m, states->back());
        move_count++;
    }
    std::cerr << "[MOVE_PARSE] Applied " << move_count << " moves. Side to move: "
              << (pos.side_to_move() == WHITE ? "WHITE" : "BLACK") << std::endl;
}

// Helper function to handle go command
void handle_go(Position& pos, std::istringstream& is, StateListPtr& states) {
    Search::LimitsType limits;
    std::string token;

    limits.startTime = now();

    while (is >> token) {
        if (token == "searchmoves") {
            while (is >> token)
                limits.searchmoves.push_back(UCI::to_move(pos, token));
        }
        else if (token == "wtime")     is >> limits.time[WHITE];
        else if (token == "btime")     is >> limits.time[BLACK];
        else if (token == "winc")      is >> limits.inc[WHITE];
        else if (token == "binc")      is >> limits.inc[BLACK];
        else if (token == "movestogo") is >> limits.movestogo;
        else if (token == "depth")     is >> limits.depth;
        else if (token == "nodes")     is >> limits.nodes;
        else if (token == "movetime")  is >> limits.movetime;
        else if (token == "infinite")  limits.infinite = 1;
    }

    Threads.start_thinking(pos, states, limits, false);
}

// Helper function to handle setoption command
void handle_setoption(std::istringstream& is) {
    std::string token, name, value;

    is >> token; // "name"

    // Read option name (can contain spaces)
    while (is >> token && token != "value")
        name += (name.empty() ? "" : " ") + token;

    // Read option value (can contain spaces)
    while (is >> token)
        value += (value.empty() ? "" : " ") + token;

    if (Options.count(name))
        Options[name] = value;
}

extern "C" {

    // Initializes the engine
    __declspec(dllexport) void stockfish_init() {
        std::lock_guard<std::mutex> lock(g_engine_mutex);

        // Prevent double initialization
        if (g_initialized) {
            std::cout << "info string Engine already initialized" << std::endl;
            return;
        }

        try {
            // Full initialization - do it all here non-blocking
            std::cerr << "[INIT] Starting pieceMap.init()..." << std::endl;
            pieceMap.init();
            std::cerr << "[INIT] pieceMap.init() done" << std::endl;

            std::cerr << "[INIT] Starting variants.init()..." << std::endl;
            variants.init();
            std::cerr << "[INIT] variants.init() done" << std::endl;

            // Initialize UCI first (this sets default options)
            std::cout << "[INIT] Starting UCI::init()..." << std::flush;
            UCI::init(Options);
            std::cout << " done" << std::endl << std::flush;

            // CRITICAL: Set variant AFTER UCI init (UCI::init sets default to "chess")
            std::cerr << "[INIT] Setting options..." << std::endl;
            Options["UCI_Variant"] = std::string("janggi");
            Options["Threads"] = 1;
            Options["Hash"] = 16;  // Small hash table for faster init
            std::cerr << "[INIT] Options set" << std::endl;

            // Bitboards::init() is REQUIRED - cannot skip!
            std::cout << "[INIT] Starting Bitboards::init()..." << std::flush;
            Bitboards::init();
            std::cout << " done" << std::endl << std::flush;

            std::cout << "[INIT] Starting Position::init()..." << std::flush;
            Position::init();
            std::cout << " done" << std::endl << std::flush;

            std::cout << "[INIT] Starting PSQT::init()..." << std::flush;
            auto it = variants.find(Options["UCI_Variant"]);
            if (it != variants.end()) {
                PSQT::init(it->second);
            }
            std::cout << " done" << std::endl << std::flush;

            // DON'T initialize threads here - it blocks on Windows!
            // Threads will be lazily initialized on first search
            // Threads.set(1);
            // Search::clear();

            // DON'T initialize starting position yet - no threads available
            // Will be done on first command
            // it = variants.find("janggi");
            // if (it != variants.end()) {
            //     const Variant* v = it->second;
            //     g_pos.set(v, v->startFen, false, &g_states->back(), Threads.main());
            // }

            std::cerr << "[INIT] All done!" << std::endl;
            g_initialized = true;
        }
        catch (const std::exception& e) {
            std::cerr << "Init exception: " << e.what() << std::endl;
            g_initialized = false;
        }
        catch (...) {
            std::cerr << "Unknown init exception" << std::endl;
            g_initialized = false;
        }
    }

    // Sends a command to the engine and returns the output
    __declspec(dllexport) const char* stockfish_command(const char* cmd) {
        std::lock_guard<std::mutex> lock(g_engine_mutex);

        // Check initialization
        if (!g_initialized) {
            std::strncpy(output_buffer, "error: Engine not initialized", sizeof(output_buffer) - 1);
            output_buffer[sizeof(output_buffer) - 1] = '\0';
            return output_buffer;
        }

        // Lazy initialization of threads and position on first command
        static bool threads_initialized = false;
        if (!threads_initialized) {
            try {
                std::cout << "[LAZY] Initializing threads..." << std::endl;

                // Initialize thread pool - Fixed Thread constructor to not deadlock
                std::cout << "[LAZY] Threads.set(1)..." << std::endl;
                Threads.set(1);
                std::cout << "[LAZY] Threads.set done!" << std::endl;

                std::cout << "[LAZY] Search::clear()..." << std::endl;
                Search::clear();

                // Initialize starting position
                std::cout << "[LAZY] Setting initial janggi position..." << std::endl;
                auto it = variants.find("janggi");
                if (it != variants.end()) {
                    const Variant* v = it->second;
                    g_pos.set(v, v->startFen, false, &g_states->back(), Threads.main());
                }

                std::cout << "[LAZY] Thread initialization SUCCESS!" << std::endl;
                threads_initialized = true;
            } catch (const std::exception& e) {
                std::snprintf(output_buffer, sizeof(output_buffer),
                    "error: Thread init failed - %s", e.what());
                return output_buffer;
            }
        }

        // Validate input
        if (cmd == nullptr) {
            std::strncpy(output_buffer, "error: Null command", sizeof(output_buffer) - 1);
            output_buffer[sizeof(output_buffer) - 1] = '\0';
            return output_buffer;
        }

        try {
            // Clear the buffer
            cout_buffer.str("");
            cout_buffer.clear();

            std::string command_str(cmd);
            std::istringstream is(command_str);
            std::string token;
            is >> std::skipws >> token;

            if (token == "position") {
                handle_position(g_pos, is, g_states);
                cout_buffer << "ok" << std::endl;
            }
            else if (token == "go") {
                handle_go(g_pos, is, g_states);
                Threads.main()->wait_for_search_finished();

                // Use main thread directly since we're single-threaded
                Thread* mainThread = Threads.main();
                if (mainThread && !mainThread->rootMoves.empty()) {
                    Move bestMove = mainThread->rootMoves[0].pv[0];
                    if (bestMove != MOVE_NONE) {
                        std::string moveStr = UCI::move(g_pos, bestMove);
                        cout_buffer << "bestmove " << moveStr;

                        // Add ponder move if available
                        if (mainThread->rootMoves[0].pv.size() > 1) {
                            Move ponderMove = mainThread->rootMoves[0].pv[1];
                            cout_buffer << " ponder " << UCI::move(g_pos, ponderMove);
                        }
                        cout_buffer << std::endl;
                    }
                }
            }
            else if (token == "setoption") {
                handle_setoption(is);
                cout_buffer << "ok" << std::endl;
            }
            else if (token == "isready") {
                cout_buffer << "readyok" << std::endl;
            }
            else if (token == "uci") {
                cout_buffer << "id name Fairy-Stockfish (Janggi)" << std::endl;
                cout_buffer << "id author Fairy-Stockfish developers" << std::endl;
                cout_buffer << "uciok" << std::endl;
            }
            else if (token == "ucinewgame") {
                Search::clear();
                g_states = StateListPtr(new std::deque<StateInfo>(1));
                auto it = variants.find("janggi");
                if (it != variants.end()) {
                    g_pos.set(it->second, it->second->startFen, false, &g_states->back(), Threads.main());
                }
                cout_buffer << "ok" << std::endl;
            }
            else if (token == "quit") {
                Threads.stop = true;
                cout_buffer << "ok" << std::endl;
            }
            else if (token.empty()) {
                // Empty command, do nothing
            }
            else {
                cout_buffer << "Unknown command: " << command_str << std::endl;
            }

            std::string output = cout_buffer.str();
            size_t len = std::min(output.length(), sizeof(output_buffer) - 1);
            std::memcpy(output_buffer, output.c_str(), len);
            output_buffer[len] = '\0';

            return output_buffer;
        }
        catch (const std::exception& e) {
            std::snprintf(output_buffer, sizeof(output_buffer), "error: Exception - %s", e.what());
            return output_buffer;
        }
        catch (...) {
            std::strncpy(output_buffer, "error: Unknown exception", sizeof(output_buffer) - 1);
            output_buffer[sizeof(output_buffer) - 1] = '\0';
            return output_buffer;
        }
    }

    // Clean shutdown
    __declspec(dllexport) void stockfish_cleanup() {
        std::lock_guard<std::mutex> lock(g_engine_mutex);

        if (!g_initialized) {
            return;
        }

        try {
            Threads.set(0);
            if (old_cout_streambuf) {
                std::cout.rdbuf(old_cout_streambuf);
                old_cout_streambuf = nullptr;
            }
            g_initialized = false;
        }
        catch (...) {
            // Ignore exceptions during cleanup
        }
    }
}
