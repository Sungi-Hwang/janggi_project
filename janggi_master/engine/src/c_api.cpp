
#include <iostream>
#include <string>
#include <sstream>
#include <vector>
#include <cstring>
#include <mutex>

#ifdef __ANDROID__
#include <android/log.h>
#define LOG_TAG "StockfishEngine"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#else
#define LOGD(...) fprintf(stderr, __VA_ARGS__); fprintf(stderr, "\n")
#define LOGE(...) fprintf(stderr, __VA_ARGS__); fprintf(stderr, "\n")
#endif

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
static bool g_threads_initialized_command = false;
static bool g_threads_initialized_analyze = false;

// A buffer to capture the engine's output
std::stringstream cout_buffer;
std::streambuf* old_cout_streambuf = nullptr;

class NullBuffer : public std::streambuf {
protected:
    int overflow(int c) override { return traits_type::not_eof(c); }
};

class ScopedCoutRedirect {
public:
    explicit ScopedCoutRedirect(std::streambuf* replacement)
        : old_buf_(std::cout.rdbuf(replacement)) {}
    ~ScopedCoutRedirect() { std::cout.rdbuf(old_buf_); }

private:
    std::streambuf* old_buf_;
};

static NullBuffer g_null_buffer;

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
        LOGD("[POSITION] Using variant: %s", variant_name.c_str());
        auto it = variants.find(variant_name);
        if (it == variants.end()) {
            LOGE("error: variant not found");
            return;
        }
        fen = it->second->startFen;
        LOGD("[POSITION] startFen: %s", fen.c_str());
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
        LOGE("error: variant not found");
        return;
    }

    states = StateListPtr(new std::deque<StateInfo>(1));
    pos.set(it->second, fen, Options["UCI_Chess960"], &states->back(), Threads.main(), sfen);

    // Parse move list (if any)
    int move_count = 0;
    while (is >> token) {
        LOGD("[MOVE_PARSE] Parsing move: %s", token.c_str());
        m = UCI::to_move(pos, token);
        if (m == MOVE_NONE) {
            LOGE("[MOVE_PARSE] Invalid move, stopping: %s", token.c_str());
            break;
        }
        // LOGD("[MOVE_PARSE] Valid move, applying...");
        states->emplace_back();
        pos.do_move(m, states->back());
        move_count++;
    }
    LOGD("[MOVE_PARSE] Applied %d moves. Side to move: %s", move_count, (pos.side_to_move() == WHITE ? "WHITE" : "BLACK"));
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

// Cross-platform export macro
#ifdef _WIN32
    #define EXPORT __declspec(dllexport)
#else
    #define EXPORT __attribute__((visibility("default")))
#endif

extern "C" {

    // Initializes the engine
    EXPORT void stockfish_init() {
        std::lock_guard<std::mutex> lock(g_engine_mutex);

        // Prevent double initialization
        if (g_initialized) {
            LOGD("info string Engine already initialized");
            return;
        }

        try {
            // Full initialization - do it all here non-blocking
            LOGD("[INIT] Starting pieceMap.init()...");
            pieceMap.init();
            LOGD("[INIT] pieceMap.init() done");

            LOGD("[INIT] Starting variants.init()...");
            variants.init();
            LOGD("[INIT] variants.init() done");

            // Initialize UCI first (this sets default options)
            LOGD("[INIT] Starting UCI::init()...");
            UCI::init(Options);
            LOGD("[INIT] UCI::init() done");

            // CRITICAL: Set variant AFTER UCI init (UCI::init sets default to "chess")
            LOGD("[INIT] Setting options...");
            Options["UCI_Variant"] = std::string("janggi");
            Options["Threads"] = 1;
            Options["Hash"] = 16;  // Small hash table for faster init
            LOGD("[INIT] Options set");

            // Bitboards::init() is REQUIRED - cannot skip!
            LOGD("[INIT] Starting Bitboards::init()...");
            Bitboards::init();
            LOGD("[INIT] Bitboards::init() done");

            LOGD("[INIT] Starting Position::init()...");
            Position::init();
            LOGD("[INIT] Position::init() done");

            LOGD("[INIT] Starting PSQT::init()...");
            auto it = variants.find(Options["UCI_Variant"]);
            if (it != variants.end()) {
                PSQT::init(it->second);
            }
            LOGD("[INIT] PSQT::init() done");

            LOGD("[INIT] All done!");
            g_threads_initialized_command = false;
            g_threads_initialized_analyze = false;
            g_states = StateListPtr(new std::deque<StateInfo>(1));
            g_initialized = true;
        }
        catch (const std::exception& e) {
            LOGE("Init exception: %s", e.what());
            g_initialized = false;
        }
        catch (...) {
            LOGE("Unknown init exception");
            g_initialized = false;
        }
    }

    // Sends a command to the engine and returns the output
    EXPORT const char* stockfish_command(const char* cmd) {
        std::lock_guard<std::mutex> lock(g_engine_mutex);

        // LOGD("[CMD] Received command: '%s'", cmd ? cmd : "NULL");

        // Check initialization
        if (!g_initialized) {
            LOGE("error: Engine not initialized");
            std::strncpy(output_buffer, "error: Engine not initialized", sizeof(output_buffer) - 1);
            output_buffer[sizeof(output_buffer) - 1] = '\0';
            return output_buffer;
        }

        // Lazy initialization of threads and position on first command
        if (!g_threads_initialized_command) {
            try {
                LOGD("[LAZY] Initializing threads...");
                
                LOGD("[LAZY] Threads.set(1)...");
                Threads.set(1);
                LOGD("[LAZY] Threads.set done!");

                LOGD("[LAZY] Search::clear()...");
                Search::clear();

                LOGD("[LAZY] Setting initial janggi position...");
                auto it = variants.find("janggi");
                if (it != variants.end()) {
                    const Variant* v = it->second;
                    g_pos.set(v, v->startFen, false, &g_states->back(), Threads.main());
                }

                LOGD("[LAZY] Thread initialization SUCCESS!");
                g_threads_initialized_command = true;
            } catch (const std::exception& e) {
                LOGE("error: Thread init failed - %s", e.what());
                std::snprintf(output_buffer, sizeof(output_buffer),
                    "error: Thread init failed - %s", e.what());
                return output_buffer;
            }
        }

        // Validate input
        if (cmd == nullptr) {
            LOGE("error: Null command");
            std::strncpy(output_buffer, "error: Null command", sizeof(output_buffer) - 1);
            output_buffer[sizeof(output_buffer) - 1] = '\0';
            return output_buffer;
        }

        LOGD("[CMD] Processing: '%s'", cmd);

        try {
            // Clear the buffer
            cout_buffer.str("");
            cout_buffer.clear();

            std::string command_str(cmd);
            std::istringstream is(command_str);
            std::string token;
            is >> std::skipws >> token;

            if (token == "position") {
                LOGD("[CMD] Handling position...");
                handle_position(g_pos, is, g_states);
                
                // Debug: Print board state to verify FEN parsing
                LOGD("[DEBUG] Internal FEN: %s", g_pos.fen().c_str());
                
                std::stringstream ss;
                ss << g_pos;
                LOGD("[DEBUG] Board Visual:\n%s", ss.str().c_str());

                cout_buffer << "ok" << std::endl;
                LOGD("[CMD] Position handled");
            }
            else if (token == "go") {
                LOGD("[CMD] Handling go...");
                handle_go(g_pos, is, g_states);
                
                LOGD("[CMD] Waiting for search finished...");
                Threads.main()->wait_for_search_finished();
                LOGD("[CMD] Search finished!");

                // Use main thread directly since we're single-threaded
                Thread* mainThread = Threads.main();
                if (mainThread && !mainThread->rootMoves.empty()) {
                    Move bestMove = mainThread->rootMoves[0].pv[0];
                    if (bestMove != MOVE_NONE) {
                        std::string moveStr = UCI::move(g_pos, bestMove);
                        cout_buffer << "bestmove " << moveStr;
                        LOGD("[CMD] Found bestmove: %s", moveStr.c_str());

                        // Add ponder move if available
                        if (mainThread->rootMoves[0].pv.size() > 1) {
                            Move ponderMove = mainThread->rootMoves[0].pv[1];
                            cout_buffer << " ponder " << UCI::move(g_pos, ponderMove);
                        }
                        cout_buffer << std::endl;
                    } else {
                        LOGD("[CMD] bestMove is MOVE_NONE");
                    }
                } else {
                    LOGD("[CMD] No root moves found!");
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
                LOGD("[CMD] Handling ucinewgame...");
                Search::clear();
                g_states = StateListPtr(new std::deque<StateInfo>(1));
                auto it = variants.find("janggi");
                if (it != variants.end()) {
                    g_pos.set(it->second, it->second->startFen, false, &g_states->back(), Threads.main());
                }
                cout_buffer << "ok" << std::endl;
                LOGD("[CMD] ucinewgame done");
            }
            else if (token == "quit") {
                Threads.stop = true;
                cout_buffer << "ok" << std::endl;
            }
            else if (token.empty()) {
                // Empty command, do nothing
            }
            else {
                LOGD("[CMD] Unknown command: %s", command_str.c_str());
                cout_buffer << "Unknown command: " << command_str << std::endl;
            }

            std::string output = cout_buffer.str();
            // LOGD("[CMD] Output: '%s'", output.c_str());
            size_t len = std::min(output.length(), sizeof(output_buffer) - 1);
            std::memcpy(output_buffer, output.c_str(), len);
            output_buffer[len] = '\0';

            return output_buffer;
        }
        catch (const std::exception& e) {
            LOGE("error: Exception - %s", e.what());
            std::snprintf(output_buffer, sizeof(output_buffer), "error: Exception - %s", e.what());
            return output_buffer;
        }
        catch (...) {
            LOGE("error: Unknown exception");
            std::strncpy(output_buffer, "error: Unknown exception", sizeof(output_buffer) - 1);
            output_buffer[sizeof(output_buffer) - 1] = '\0';
            return output_buffer;
        }
    }

    // Analyze a position and return score + bestmove
    // Returns: "cp 300 bestmove e9f9" or "mate 5 bestmove a1a2" or "error: ..."
    EXPORT const char* stockfish_analyze(const char* fen, int depth) {
        std::lock_guard<std::mutex> lock(g_engine_mutex);

        // LOGD("[ANALYZE] FEN: %s, depth: %d", fen ? fen : "NULL", depth);

        // Check initialization
        if (!g_initialized) {
            LOGE("[ANALYZE] Engine not initialized");
            std::strncpy(output_buffer, "error: Engine not initialized", sizeof(output_buffer) - 1);
            output_buffer[sizeof(output_buffer) - 1] = '\0';
            return output_buffer;
        }

        // Lazy initialization of threads (same as stockfish_command)
        if (!g_threads_initialized_analyze) {
            try {
                LOGD("[ANALYZE] Lazy init threads...");
                Threads.set(1);
                Search::clear();
                auto it = variants.find("janggi");
                if (it != variants.end()) {
                    const Variant* v = it->second;
                    g_pos.set(v, v->startFen, false, &g_states->back(), Threads.main());
                }
                g_threads_initialized_analyze = true;
                LOGD("[ANALYZE] Thread init done");
            } catch (const std::exception& e) {
                LOGE("[ANALYZE] Thread init failed: %s", e.what());
                std::snprintf(output_buffer, sizeof(output_buffer), "error: Thread init failed - %s", e.what());
                return output_buffer;
            }
        }

        if (fen == nullptr) {
            LOGE("[ANALYZE] Null FEN");
            std::strncpy(output_buffer, "error: Null FEN", sizeof(output_buffer) - 1);
            output_buffer[sizeof(output_buffer) - 1] = '\0';
            return output_buffer;
        }

        try {
            // Clear search state before each analysis to prevent memory corruption
            Search::clear();
            
            // Set up position from FEN
            auto it = variants.find("janggi");
            if (it == variants.end()) {
                LOGE("[ANALYZE] Janggi variant not found");
                std::strncpy(output_buffer, "error: Janggi variant not found", sizeof(output_buffer) - 1);
                output_buffer[sizeof(output_buffer) - 1] = '\0';
                return output_buffer;
            }

            // Create fresh state for each analysis
            g_states = StateListPtr(new std::deque<StateInfo>(1));
            g_pos.set(it->second, fen, false, &g_states->back(), Threads.main());

            // LOGD("[ANALYZE] Position set, starting search depth=%d", depth);

            // Set up search limits
            Search::LimitsType limits;
            limits.startTime = now();
            limits.depth = depth;

            // Suppress verbose search info output during API analysis calls.
            ScopedCoutRedirect silence_stdout(&g_null_buffer);

            // Start search
            Threads.start_thinking(g_pos, g_states, limits, false);
            Threads.main()->wait_for_search_finished();

            // Extract score from rootMoves
            Thread* mainThread = Threads.main();
            if (mainThread == nullptr || mainThread->rootMoves.empty()) {
                LOGE("[ANALYZE] No root moves");
                std::strncpy(output_buffer, "error: No root moves", sizeof(output_buffer) - 1);
                output_buffer[sizeof(output_buffer) - 1] = '\0';
                return output_buffer;
            }

            Value score = mainThread->rootMoves[0].score;
            Move bestMove = mainThread->rootMoves[0].pv[0];

            // Build output string
            std::stringstream ss;

            // Check if it's a mate score
            if (score >= VALUE_MATE_IN_MAX_PLY) {
                // Positive mate: we are winning
                int mateIn = (VALUE_MATE - score + 1) / 2;
                ss << "mate " << mateIn;
            } else if (score <= VALUE_MATED_IN_MAX_PLY) {
                // Negative mate: we are losing
                int mateIn = (-VALUE_MATE - score) / 2;
                ss << "mate " << mateIn;
            } else {
                // Centipawn score
                ss << "cp " << static_cast<int>(score);
            }

            // Add best move
            if (bestMove != MOVE_NONE) {
                ss << " bestmove " << UCI::move(g_pos, bestMove);
            }

            std::string output = ss.str();
            // LOGD("[ANALYZE] Result: %s", output.c_str());
            std::strncpy(output_buffer, output.c_str(), sizeof(output_buffer) - 1);
            output_buffer[sizeof(output_buffer) - 1] = '\0';
            return output_buffer;

        } catch (const std::exception& e) {
            LOGE("[ANALYZE] Exception: %s", e.what());
            std::snprintf(output_buffer, sizeof(output_buffer), "error: Exception - %s", e.what());
            return output_buffer;
        } catch (...) {
            LOGE("[ANALYZE] Unknown exception");
            std::strncpy(output_buffer, "error: Unknown exception", sizeof(output_buffer) - 1);
            output_buffer[sizeof(output_buffer) - 1] = '\0';
            return output_buffer;
        }
    }

    // Clean shutdown
    EXPORT void stockfish_cleanup() {
        std::lock_guard<std::mutex> lock(g_engine_mutex);

        if (!g_initialized) {
            return;
        }

        try {
            Search::clear();
            Threads.set(0);
            if (old_cout_streambuf) {
                std::cout.rdbuf(old_cout_streambuf);
                old_cout_streambuf = nullptr;
            }
            g_threads_initialized_command = false;
            g_threads_initialized_analyze = false;
            g_states = StateListPtr(new std::deque<StateInfo>(1));
            g_initialized = false;
        }
        catch (...) {
            // Ignore exceptions during cleanup
        }
    }
}
