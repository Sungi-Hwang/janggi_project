# Janggi Master (장기 마스터) 🐘

**Janggi Master** is a high-performance Korean Chess (Janggi) application built with **Flutter** and powered by the **Fairy-Stockfish** engine (C++). It offers a seamless cross-platform experience on **Android** and **Windows**.

## ✨ Key Features

*   **🤖 Strong AI Engine**:
    *   Powered by a custom-built **Stockfish** engine via Dart FFI.
    *   Adjustable difficulty levels (Level 1 ~ 8) suitable for beginners to pros.
    *   Optimized for mobile devices (ARM64) and Desktop (x64).
*   **📱 Modern UI/UX**:
    *   **Maximized Board**: Clean layout focusing 100% on the gameplay.
    *   **Smart Overlays**: Tap player info bars to see detailed captured piece summaries.
    *   **Glassmorphism**: Beautiful visual effects and animations.
*   **🧩 Puzzle Mode**:
    *   Analyze historical games (GIB files) to solve tactical puzzles.
*   **🖥️ Cross-Platform**:
    *   Supports Android (Mobile) & Windows (Desktop) with a single codebase.

## 🛠️ Technology Stack

*   **Frontend**: Flutter (Dart)
*   **Engine**: C++ (Fairy-Stockfish modified for Janggi)
*   **Integration**: Dart FFI (Foreign Function Interface)
*   **State Management**: Provider

## 🚀 Getting Started

### Prerequisites
*   Flutter SDK (3.x+)
*   Android Studio / Visual Studio (C++ Desktop development workload)

### Installation

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/Sungi-Hwang/janggi_project.git
    cd janggi_project
    ```

2.  **Get dependencies**:
    ```bash
    flutter pub get
    ```

3.  **Run the App**:
    *   **Android**: Connect your device and run:
        ```bash
        flutter run
        ```
    *   **Windows**:
        ```bash
        flutter run -d windows
        ```

## 📂 Project Structure

*   `lib/`: Flutter UI code (Screens, Widgets).
*   `engine/`: C++ source code for the Stockfish engine.
*   `android/`: Android native configuration (CMake & NDK).
*   `windows/`: Windows native configuration (CMake).

## 📝 License

This project utilizes the method of integrating Stockfish with Flutter.
Engine code is based on [Fairy-Stockfish](https://github.com/fairy-stockfish/Fairy-Stockfish) (GPLv3).

---
*Developed by Sungi Hwang*
