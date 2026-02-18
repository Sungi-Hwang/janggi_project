import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/board.dart';
import '../models/piece.dart';
import '../models/position.dart';
import '../providers/settings_provider.dart';
import '../screens/game_screen.dart' show GameMode, GameScreen;
import '../services/custom_puzzle_service.dart';
import '../utils/puzzle_share_codec.dart';
import 'custom_puzzle_record_screen.dart';
import '../widgets/janggi_board_widget.dart' show BoardLinesPainter;
import '../widgets/traditional_piece_widget.dart';

enum CustomPuzzleEditorMode {
  puzzleCreate,
  aiContinue,
}

class CustomPuzzleEditorScreen extends StatefulWidget {
  final CustomPuzzleEditorMode mode;

  const CustomPuzzleEditorScreen({
    super.key,
    this.mode = CustomPuzzleEditorMode.puzzleCreate,
  });

  @override
  State<CustomPuzzleEditorScreen> createState() =>
      _CustomPuzzleEditorScreenState();
}

class _CustomPuzzleEditorScreenState extends State<CustomPuzzleEditorScreen> {
  final Board _board = Board();
  final GlobalKey _boardDropKey = GlobalKey();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _shareCodeController = TextEditingController();

  bool _blueAtBottom = true;

  static final List<PieceType> _paletteTypes = <PieceType>[
    PieceType.general,
    PieceType.guard,
    PieceType.horse,
    PieceType.elephant,
    PieceType.chariot,
    PieceType.cannon,
    PieceType.soldier,
  ];

  static const Map<PieceType, int> _maxPieceCount = {
    PieceType.general: 1,
    PieceType.guard: 2,
    PieceType.horse: 2,
    PieceType.elephant: 2,
    PieceType.chariot: 2,
    PieceType.cannon: 2,
    PieceType.soldier: 5,
  };

  bool get _isAiContinueMode =>
      widget.mode == CustomPuzzleEditorMode.aiContinue;

  @override
  void initState() {
    super.initState();
    _applyDefaultSetup();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _shareCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf5e6d3),
      appBar: AppBar(
        title: Text(_isAiContinueMode ? '배치 이어하기 (AI)' : '나만의 묘수 생성'),
        backgroundColor: const Color(0xFF3e2723),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isAiContinueMode) ...[
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: '퍼즐 제목',
                    hintText: '예: 초포 희생 외통',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _shareCodeController,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '공유 코드 붙여넣기',
                    hintText: 'JM_PUZZLE_V1:...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildTopActionButton(
                      icon: Icons.file_download,
                      label: '불러오기',
                      onPressed: _importSharedText,
                    ),
                    const SizedBox(width: 6),
                    _buildTopActionButton(
                      icon: Icons.content_copy,
                      label: '현재 배치 내보내기',
                      onPressed: _copyCurrentSetupCode,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ] else ...[
                const SizedBox(height: 6),
              ],
              Row(
                children: [
                  _buildTopActionButton(
                    icon: Icons.cleaning_services,
                    label: '보드 비우기',
                    onPressed: () {
                      setState(() {
                        _board.clear();
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                  _buildTopActionButton(
                    icon: Icons.restart_alt,
                    label: '기본 배치',
                    onPressed: () {
                      setState(() {
                        _applyDefaultSetup();
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                  _buildTopActionButton(
                    icon: Icons.swap_vert,
                    label: '진형 변경',
                    onPressed: () {
                      setState(() {
                        _flipCurrentFormation();
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _blueAtBottom ? '현재 하단 진영: 초' : '현재 하단 진영: 한',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _buildPaletteSection(
                title: '초 기물 (드래그해서 배치)',
                color: PieceColor.blue,
              ),
              const SizedBox(height: 8),
              _buildPaletteSection(
                title: '한 기물 (드래그해서 배치)',
                color: PieceColor.red,
              ),
              const SizedBox(height: 12),
              _buildTrashArea(),
              const SizedBox(height: 12),
              AspectRatio(
                aspectRatio: 9 / 10,
                child: _buildEditorBoard(),
              ),
              const SizedBox(height: 14),
              if (_isAiContinueMode)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _startContinueWithAi,
                    icon: const Icon(Icons.smart_toy),
                    label: const Text('이어하기(AI)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _startRecording,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('퍼즐 기록 시작'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A4D1A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _startContinueWithAi,
                        icon: const Icon(Icons.smart_toy),
                        label: const Text('이어하기(AI)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A237E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              Text(
                _isAiContinueMode
                    ? '현재 배치에서 바로 AI 대국을 시작합니다.'
                    : '이어하기(AI): 현재 배치에서 바로 AI 대국을 시작합니다.',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _isAiContinueMode
                    ? '팁: 보드 기물을 탭하면 제거됩니다.'
                    : '팁: 보드 기물을 탭하면 제거됩니다. 시작 후에는 양측 수순을 기록하고, 체크메이트 시 자동 저장됩니다.',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaletteSection({
    required String title,
    required PieceColor color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _paletteTypes.map((type) {
                final piece = Piece(type: type, color: color);
                final remaining = _remainingPieceCount(color, type);
                final chip = _pieceChip(
                  piece,
                  countBadge: remaining,
                  disabled: remaining <= 0,
                );

                if (remaining <= 0) {
                  return Opacity(opacity: 0.35, child: chip);
                }

                return Draggable<_DragPiece>(
                  data: _DragPiece(piece: piece, from: null),
                  feedback: Material(
                    color: Colors.transparent,
                    child: _pieceChip(piece, size: 44, countBadge: remaining),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.35,
                    child: chip,
                  ),
                  child: chip,
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              '배치 가능 수량을 초과하면 드롭이 제한됩니다.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrashArea() {
    return DragTarget<_DragPiece>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        if (details.data.from != null) {
          setState(() {
            _board.setPiece(details.data.from!, null);
          });
        }
      },
      builder: (context, candidateData, rejectedData) {
        final active = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: active ? Colors.red.shade100 : Colors.red.shade50,
            border: Border.all(
              color: active ? Colors.red.shade700 : Colors.red.shade300,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.delete_outline, color: Colors.red),
              SizedBox(width: 8),
              Text(
                '여기로 드래그하면 기물 삭제',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEditorBoard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE6C8A0),
        border: Border.all(color: Colors.brown.shade700, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.hardEdge,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const margin = 34.0;
          final innerWidth = constraints.maxWidth - margin * 2;
          final innerHeight = constraints.maxHeight - margin * 2;
          final gridSpacing = (innerWidth / 8 < innerHeight / 9
                  ? innerWidth / 8
                  : innerHeight / 9)
              .toDouble();
          final boardWidth = gridSpacing * 8;
          final boardHeight = gridSpacing * 9;
          final startX = (constraints.maxWidth - boardWidth) / 2;
          final startY = (constraints.maxHeight - boardHeight) / 2;

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: RotatedBox(
                  quarterTurns: 1,
                  child: Image.asset(
                    'assets/images/janggi_pan.png',
                    fit: BoxFit.cover,
                    opacity: const AlwaysStoppedAnimation(0.78),
                  ),
                ),
              ),
              Positioned(
                left: startX,
                top: startY,
                child: CustomPaint(
                  size: Size(boardWidth, boardHeight),
                  painter: BoardLinesPainter(
                    gridSpacing: gridSpacing,
                    flipBoard: false,
                    lineColor: Colors.black87,
                  ),
                ),
              ),
              _buildBoardDropZone(
                startX: startX,
                startY: startY,
                boardWidth: boardWidth,
                boardHeight: boardHeight,
                gridSpacing: gridSpacing,
              ),
              ..._buildBoardPieces(
                startX: startX,
                startY: startY,
                gridSpacing: gridSpacing,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBoardDropZone({
    required double startX,
    required double startY,
    required double boardWidth,
    required double boardHeight,
    required double gridSpacing,
  }) {
    final tapRadius = gridSpacing * 0.52;

    return DragTarget<_DragPiece>(
      key: _boardDropKey,
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        final target = _snapDropToBoard(
          details.offset,
          gridSpacing: gridSpacing,
        );
        if (target == null) return;

        final dropped = details.data;
        final targetPiece = _board.getPiece(target);
        final errorMessage = _validateDropRule(
          dropped: dropped,
          target: target,
          targetPiece: targetPiece,
        );
        if (errorMessage != null) {
          _showSnack(errorMessage);
          return;
        }

        setState(() {
          final source = dropped.from;

          if (source != null && source != target && targetPiece != null) {
            _board.setPiece(source, targetPiece);
            _board.setPiece(target, dropped.piece);
            return;
          }

          if (source != null && source != target) {
            _board.setPiece(source, null);
          }
          _board.setPiece(target, dropped.piece);
        });
      },
      builder: (context, candidateData, rejectedData) {
        final hovering = candidateData.isNotEmpty;
        return Positioned(
          left: startX - tapRadius,
          top: startY - tapRadius,
          width: boardWidth + tapRadius * 2,
          height: boardHeight + tapRadius * 2,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            decoration: BoxDecoration(
              color: hovering
                  ? Colors.yellow.withValues(alpha: 0.08)
                  : Colors.transparent,
              border: hovering
                  ? Border.all(
                      color: Colors.yellow.withValues(alpha: 0.45),
                      width: 2,
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildBoardPieces({
    required double startX,
    required double startY,
    required double gridSpacing,
  }) {
    final widgets = <Widget>[];

    for (int rank = 0; rank < 10; rank++) {
      for (int file = 0; file < 9; file++) {
        final position = Position(file: file, rank: rank);
        final piece = _board.getPiece(position);
        if (piece == null) continue;

        final displayRank = 9 - position.rank;
        final centerX = startX + position.file * gridSpacing;
        final centerY = startY + displayRank * gridSpacing;
        final size = gridSpacing * 0.82;

        widgets.add(
          Positioned(
            left: centerX - size / 2,
            top: centerY - size / 2,
            width: size,
            height: size,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _board.setPiece(position, null);
                });
              },
              child: Draggable<_DragPiece>(
                data: _DragPiece(piece: piece, from: position),
                feedback: Material(
                  color: Colors.transparent,
                  child: _buildPieceToken(piece, size: gridSpacing * 0.88),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.25,
                  child: _buildPieceToken(piece, size: size),
                ),
                child: _buildPieceToken(piece, size: size),
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  Position? _snapDropToBoard(
    Offset globalOffset, {
    required double gridSpacing,
  }) {
    final ctx = _boardDropKey.currentContext;
    if (ctx == null) return null;

    final renderBox = ctx.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;

    final local = renderBox.globalToLocal(globalOffset);
    final tapRadius = gridSpacing * 0.52;
    final file = (((local.dx - tapRadius) / gridSpacing).round()).clamp(0, 8);
    final displayRank =
        (((local.dy - tapRadius) / gridSpacing).round()).clamp(0, 9);
    final rank = 9 - displayRank;

    return Position(file: file, rank: rank);
  }

  Widget _pieceChip(
    Piece piece, {
    double size = 34,
    int? countBadge,
    bool disabled = false,
  }) {
    final isBlue = piece.color == PieceColor.blue;
    final borderColor = isBlue ? Colors.blue.shade700 : Colors.red.shade700;
    final fillColor = isBlue ? Colors.blue.shade50 : Colors.red.shade50;
    final appliedBorder =
        disabled ? borderColor.withValues(alpha: 0.5) : borderColor;
    final appliedFill = disabled ? fillColor.withValues(alpha: 0.6) : fillColor;
    final text = _pieceLabel(piece.type, piece.color);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: appliedFill,
            shape: BoxShape.circle,
            border: Border.all(color: appliedBorder, width: 1.8),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              fontSize: size * 0.38,
              color: appliedBorder,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (countBadge != null)
          Positioned(
            right: -5,
            bottom: -5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Text(
                'x$countBadge',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPieceToken(Piece piece, {double size = 34}) {
    if (size >= 32) {
      return TraditionalPieceWidget(piece: piece, size: size);
    }
    return _pieceChip(piece, size: size);
  }

  String _pieceLabel(PieceType type, PieceColor color) {
    switch (type) {
      case PieceType.general:
        return color == PieceColor.blue ? '楚' : '漢';
      case PieceType.guard:
        return '士';
      case PieceType.horse:
        return '馬';
      case PieceType.elephant:
        return '象';
      case PieceType.chariot:
        return '車';
      case PieceType.cannon:
        return '包';
      case PieceType.soldier:
        return color == PieceColor.blue ? '卒' : '兵';
    }
  }

  int _countPieces(PieceColor color, PieceType type) {
    int count = 0;
    for (int rank = 0; rank < 10; rank++) {
      for (int file = 0; file < 9; file++) {
        final piece = _board.getPiece(Position(file: file, rank: rank));
        if (piece != null && piece.color == color && piece.type == type) {
          count++;
        }
      }
    }
    return count;
  }

  int _generalCount(PieceColor color) {
    return _countPieces(color, PieceType.general);
  }

  int _remainingPieceCount(PieceColor color, PieceType type) {
    final maxCount = _maxPieceCount[type] ?? 0;
    final current = _countPieces(color, type);
    final remaining = maxCount - current;
    return remaining < 0 ? 0 : remaining;
  }

  bool _isInsidePalace(Position pos, PieceColor color) {
    final inFileRange = pos.file >= 3 && pos.file <= 5;
    final isBottomSide = (color == PieceColor.blue && _blueAtBottom) ||
        (color == PieceColor.red && !_blueAtBottom);
    final inRankRange = isBottomSide
        ? (pos.rank >= 0 && pos.rank <= 2)
        : (pos.rank >= 7 && pos.rank <= 9);
    return inFileRange && inRankRange;
  }

  bool _isPalaceOnlyPiece(PieceType type) {
    return type == PieceType.general || type == PieceType.guard;
  }

  bool _isSoldierPlacementValid(PieceColor color, Position pos) {
    final isBottomSide = (color == PieceColor.blue && _blueAtBottom) ||
        (color == PieceColor.red && !_blueAtBottom);
    if (isBottomSide) {
      return pos.rank >= 3;
    }
    return pos.rank <= 6;
  }

  String _pieceTypeKorean(PieceType type) {
    switch (type) {
      case PieceType.general:
        return '궁';
      case PieceType.guard:
        return '사';
      case PieceType.horse:
        return '마';
      case PieceType.elephant:
        return '상';
      case PieceType.chariot:
        return '차';
      case PieceType.cannon:
        return '포';
      case PieceType.soldier:
        return '졸';
    }
  }

  String? _placementRuleError(Piece piece, Position pos) {
    if (_isPalaceOnlyPiece(piece.type) && !_isInsidePalace(pos, piece.color)) {
      return '${_pieceTypeKorean(piece.type)}은(는) 궁성 안에만 배치할 수 있습니다.';
    }
    if (piece.type == PieceType.soldier &&
        !_isSoldierPlacementValid(piece.color, pos)) {
      return '${piece.color == PieceColor.blue ? '초' : '한'} 졸/병은 후방 3줄에 배치할 수 없습니다.';
    }
    return null;
  }

  bool _canPieceBePlacedAt(Piece piece, Position pos) {
    return _placementRuleError(piece, pos) == null;
  }

  String? _validateDropRule({
    required _DragPiece dropped,
    required Position target,
    required Piece? targetPiece,
  }) {
    if (dropped.from == target) {
      return null;
    }

    final piece = dropped.piece;
    final placementError = _placementRuleError(piece, target);
    if (placementError != null) {
      return placementError;
    }

    if (dropped.from != null && targetPiece != null) {
      final source = dropped.from!;
      if (!_canPieceBePlacedAt(targetPiece, source)) {
        return '해당 위치로는 기물 교환이 불가능합니다.';
      }
    }

    if (dropped.from == null) {
      final maxCount = _maxPieceCount[piece.type] ?? 0;
      final current = _countPieces(piece.color, piece.type);
      final replacementCredit = targetPiece != null &&
              targetPiece.color == piece.color &&
              targetPiece.type == piece.type
          ? 1
          : 0;
      if (current - replacementCredit >= maxCount) {
        final side = piece.color == PieceColor.blue ? '초' : '한';
        return '$side ${_pieceTypeKorean(piece.type)}은(는) 최대 $maxCount개까지 배치할 수 있습니다.';
      }
    }

    return null;
  }

  String? _validateBoardForStart() {
    for (final color in PieceColor.values) {
      for (final type in _paletteTypes) {
        final maxCount = _maxPieceCount[type] ?? 0;
        final count = _countPieces(color, type);
        if (count > maxCount) {
          final side = color == PieceColor.blue ? '초' : '한';
          return '$side ${_pieceTypeKorean(type)} 개수가 최대치를 초과했습니다.';
        }
      }
    }

    for (int rank = 0; rank < 10; rank++) {
      for (int file = 0; file < 9; file++) {
        final pos = Position(file: file, rank: rank);
        final piece = _board.getPiece(pos);
        if (piece == null) continue;

        final placementError = _placementRuleError(piece, pos);
        if (placementError != null) {
          return placementError;
        }
      }
    }

    final blueGeneralCount = _generalCount(PieceColor.blue);
    final redGeneralCount = _generalCount(PieceColor.red);
    if (blueGeneralCount != 1 || redGeneralCount != 1) {
      return '초/한 궁은 각각 1개씩 있어야 합니다.';
    }

    return null;
  }

  void _applyDefaultSetup() {
    final temp = Board();
    temp.setupInitialPosition();
    _board.clear();

    for (int rank = 0; rank < 10; rank++) {
      for (int file = 0; file < 9; file++) {
        final piece = temp.getPiece(Position(file: file, rank: rank));
        if (piece == null) continue;

        final target = _blueAtBottom
            ? Position(file: file, rank: rank)
            : Position(file: file, rank: 9 - rank);
        _board.setPiece(target, piece);
      }
    }
  }

  void _flipCurrentFormation() {
    final flipped = Board();
    for (int rank = 0; rank < 10; rank++) {
      for (int file = 0; file < 9; file++) {
        final piece = _board.getPiece(Position(file: file, rank: rank));
        if (piece == null) continue;
        flipped.setPiece(
          Position(file: file, rank: 9 - rank),
          piece,
        );
      }
    }

    _board.clear();
    for (int rank = 0; rank < 10; rank++) {
      for (int file = 0; file < 9; file++) {
        final piece = flipped.getPiece(Position(file: file, rank: rank));
        if (piece != null) {
          _board.setPiece(Position(file: file, rank: rank), piece);
        }
      }
    }

    _blueAtBottom = !_blueAtBottom;
  }

  Board _toEngineBoard(Board source) {
    if (_blueAtBottom) {
      return source.copy();
    }

    final normalized = Board();
    for (int rank = 0; rank < 10; rank++) {
      for (int file = 0; file < 9; file++) {
        final piece = source.getPiece(Position(file: file, rank: rank));
        if (piece == null) continue;
        normalized.setPiece(
          Position(file: file, rank: 9 - rank),
          piece,
        );
      }
    }
    return normalized;
  }

  Future<void> _copyCurrentSetupCode() async {
    final bottomColor = _blueAtBottom ? PieceColor.blue : PieceColor.red;
    final code = PuzzleShareCodec.encodeSetupFromBoard(
      title: _titleController.text.trim(),
      board: _board.copy(),
      bottomColor: bottomColor,
    );
    await Clipboard.setData(ClipboardData(text: code));
    _showSnack('현재 배치 공유 코드가 복사되었습니다.');
  }

  Future<void> _importSharedText() async {
    String raw = _shareCodeController.text.trim();
    if (raw.isEmpty) {
      final clipboard = await Clipboard.getData('text/plain');
      raw = clipboard?.text?.trim() ?? '';
    }
    if (raw.isEmpty) {
      _showSnack('공유 코드를 붙여넣어 주세요.');
      return;
    }

    Map<String, dynamic> decoded;
    try {
      decoded = PuzzleShareCodec.decode(raw);
    } catch (_) {
      _showSnack('공유 코드 형식이 올바르지 않습니다.');
      return;
    }

    final fen = decoded['fen'] as String? ?? '';
    final parsedBoard = PuzzleShareCodec.parseFenBoard(fen);
    if (parsedBoard == null) {
      _showSnack('보드 정보를 읽을 수 없습니다.');
      return;
    }
    if (!mounted) return;

    final hasSolution = (decoded['solution'] as List).isNotEmpty;
    if (hasSolution) {
      final importDirectly = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('공유 퍼즐 불러오기'),
          content: const Text(
            '정답 수순이 포함된 퍼즐입니다.\n'
            '바로 가져오기하면 내 묘수 목록에 즉시 저장됩니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('배치만 불러오기'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('바로 가져오기'),
            ),
          ],
        ),
      );
      if (!mounted) return;

      if (importDirectly == true) {
        await _importFullPuzzle(decoded);
        return;
      }
    }

    setState(() {
      _applyBoardCopy(parsedBoard);
      _blueAtBottom = (decoded['toMove'] as String?) != 'red';
      final title = (decoded['title'] as String? ?? '').trim();
      if (title.isNotEmpty) {
        _titleController.text = title;
      }
    });

    _showSnack('공유 배치를 불러왔습니다.');
  }

  Future<void> _importFullPuzzle(Map<String, dynamic> decoded) async {
    final payload = PuzzleShareCodec.toSavablePuzzle(decoded);
    final solution = List<String>.from(payload['solution'] ?? <String>[]);
    if (solution.isEmpty) {
      _showSnack('정답 수순이 없는 코드입니다.');
      return;
    }

    final now = DateTime.now();
    final title = (payload['title'] as String?)?.trim() ?? '';
    final puzzle = <String, dynamic>{
      'id': CustomPuzzleService.nextId(),
      'title': title.isNotEmpty
          ? title
          : '공유 퍼즐 ${now.toIso8601String().substring(5, 16)}',
      'fen': payload['fen'],
      'solution': solution,
      'mateIn': payload['mateIn'],
      'toMove': payload['toMove'],
      'source': 'custom',
      'createdAt': now.toIso8601String(),
    };

    await CustomPuzzleService.addPuzzle(puzzle);
    if (!mounted) return;
    _showSnack('공유 퍼즐을 가져왔습니다.');
    Navigator.pop(context, true);
  }

  void _applyBoardCopy(Board source) {
    _board.clear();
    for (int rank = 0; rank < 10; rank++) {
      for (int file = 0; file < 9; file++) {
        final pos = Position(file: file, rank: rank);
        final piece = source.getPiece(pos);
        if (piece != null) {
          _board.setPiece(pos, piece);
        }
      }
    }
  }

  Future<void> _startRecording() async {
    final validationError = _validateBoardForStart();
    if (validationError != null) {
      _showSnack(validationError);
      return;
    }

    final bottomColor = _blueAtBottom ? PieceColor.blue : PieceColor.red;
    final engineBoard = _toEngineBoard(_board);
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CustomPuzzleRecordScreen(
          initialBoard: engineBoard,
          bottomColor: bottomColor,
          suggestedTitle: _titleController.text.trim(),
        ),
      ),
    );

    if (saved == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _startContinueWithAi() async {
    final validationError = _validateBoardForStart();
    if (validationError != null) {
      _showSnack(validationError);
      return;
    }

    final settings = context.read<SettingsProvider>();
    final playerColor = _blueAtBottom ? PieceColor.blue : PieceColor.red;
    final aiColor =
        playerColor == PieceColor.blue ? PieceColor.red : PieceColor.blue;
    final engineBoard = _toEngineBoard(_board);

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(
          gameMode: GameMode.vsAI,
          aiDifficulty: settings.aiDifficulty,
          aiThinkingTimeSec: settings.aiThinkingTime,
          aiColor: aiColor,
          initialBoard: engineBoard,
          initialStartingPlayer: playerColor,
        ),
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildTopActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          minimumSize: const Size(0, 38),
          visualDensity: const VisualDensity(vertical: -2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DragPiece {
  final Piece piece;
  final Position? from;

  const _DragPiece({
    required this.piece,
    required this.from,
  });
}
