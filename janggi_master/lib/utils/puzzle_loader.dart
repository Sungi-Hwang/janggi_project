import 'dart:convert';
import 'package:flutter/services.dart';

/// 묘수풀이 퍼즐 데이터 모델
class Puzzle {
  final String id;
  final int difficulty;  // 1=1수, 2=2수, 3=3수
  final int mateIn;
  final String title;
  final String fen;
  final List<String> solution;  // 정답 수순
  final String toMove;  // "blue" or "red"
  final String source;

  Puzzle({
    required this.id,
    required this.difficulty,
    required this.mateIn,
    required this.title,
    required this.fen,
    required this.solution,
    required this.toMove,
    required this.source,
  });

  factory Puzzle.fromJson(Map<String, dynamic> json) {
    return Puzzle(
      id: json['id'] as String,
      difficulty: json['difficulty'] as int,
      mateIn: json['mateIn'] as int,
      title: json['title'] as String,
      fen: json['fen'] as String,
      solution: List<String>.from(json['solution']),
      toMove: json['toMove'] as String,
      source: json['source'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'difficulty': difficulty,
    'mateIn': mateIn,
    'title': title,
    'fen': fen,
    'solution': solution,
    'toMove': toMove,
    'source': source,
  };
}

/// 퍼즐 카테고리
class PuzzleCategory {
  final String name;
  final String description;
  final int count;

  PuzzleCategory({
    required this.name,
    required this.description,
    required this.count,
  });

  factory PuzzleCategory.fromJson(Map<String, dynamic> json) {
    return PuzzleCategory(
      name: json['name'] as String,
      description: json['description'] as String,
      count: json['count'] as int,
    );
  }
}

/// 퍼즐 데이터 로더
class PuzzleLoader {
  static List<Puzzle>? _puzzles;
  static Map<String, PuzzleCategory>? _categories;
  
  /// 퍼즐 데이터 로드
  static Future<void> load() async {
    if (_puzzles != null) return;  // 이미 로드됨
    
    try {
      final jsonString = await rootBundle.loadString('assets/puzzles/puzzles.json');
      final data = json.decode(jsonString) as Map<String, dynamic>;
      
      // 카테고리 로드
      final categoriesData = data['categories'] as Map<String, dynamic>;
      _categories = categoriesData.map((key, value) => 
        MapEntry(key, PuzzleCategory.fromJson(value as Map<String, dynamic>))
      );
      
      // 퍼즐 로드
      final puzzlesData = data['puzzles'] as List<dynamic>;
      _puzzles = puzzlesData
          .map((p) => Puzzle.fromJson(p as Map<String, dynamic>))
          .toList();
      
    } catch (e) {
      print('Failed to load puzzles: $e');
      _puzzles = [];
      _categories = {};
    }
  }
  
  /// 전체 퍼즐 목록
  static List<Puzzle> get all => _puzzles ?? [];
  
  /// 카테고리별 퍼즐 가져오기
  static List<Puzzle> getByMateIn(int mateIn) {
    return all.where((p) => p.mateIn == mateIn).toList();
  }
  
  /// 1수 외통 퍼즐
  static List<Puzzle> get mate1 => getByMateIn(1);
  
  /// 2수 외통 퍼즐
  static List<Puzzle> get mate2 => getByMateIn(2);
  
  /// 3수 외통 퍼즐
  static List<Puzzle> get mate3 => getByMateIn(3);
  
  /// ID로 퍼즐 가져오기
  static Puzzle? getById(String id) {
    try {
      return all.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
  
  /// 인덱스로 퍼즐 가져오기
  static Puzzle? getByIndex(int index) {
    if (index < 0 || index >= all.length) return null;
    return all[index];
  }
  
  /// 카테고리 정보
  static Map<String, PuzzleCategory> get categories => _categories ?? {};
  
  /// 총 퍼즐 수
  static int get totalCount => all.length;
  
  /// 랜덤 퍼즐
  static Puzzle? getRandom({int? mateIn}) {
    final list = mateIn != null ? getByMateIn(mateIn) : all;
    if (list.isEmpty) return null;
    return list[(DateTime.now().millisecondsSinceEpoch % list.length)];
  }
}
