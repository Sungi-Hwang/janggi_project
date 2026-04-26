class CommunityPuzzle {
  const CommunityPuzzle({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.title,
    required this.description,
    required this.fen,
    required this.solution,
    required this.mateIn,
    required this.toMove,
    required this.likeCount,
    required this.importCount,
    required this.reportCount,
    required this.createdAt,
    this.authorAvatarUrl,
    this.hasLiked = false,
  });

  factory CommunityPuzzle.fromJson(
    Map<String, dynamic> json, {
    bool hasLiked = false,
  }) {
    final profile = json['profiles'] is Map
        ? Map<String, dynamic>.from(json['profiles'] as Map)
        : <String, dynamic>{};
    final solution = json['solution'] is List
        ? List<String>.from(
            (json['solution'] as List).map((value) => value.toString()),
          )
        : <String>[];

    return CommunityPuzzle(
      id: json['id'] as String? ?? '',
      authorId: json['author_id'] as String? ?? '',
      authorName: (profile['display_name'] as String? ?? '익명 사용자').trim(),
      authorAvatarUrl: profile['avatar_url'] as String?,
      title: (json['title'] as String? ?? '공유 문제').trim(),
      description: (json['description'] as String? ?? '').trim(),
      fen: (json['fen'] as String? ?? '').trim(),
      solution: solution,
      mateIn: (json['mate_in'] as num?)?.toInt() ?? 1,
      toMove: json['to_move'] == 'red' ? 'red' : 'blue',
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      importCount: (json['import_count'] as num?)?.toInt() ?? 0,
      reportCount: (json['report_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      hasLiked: hasLiked,
    );
  }

  final String id;
  final String authorId;
  final String authorName;
  final String? authorAvatarUrl;
  final String title;
  final String description;
  final String fen;
  final List<String> solution;
  final int mateIn;
  final String toMove;
  final int likeCount;
  final int importCount;
  final int reportCount;
  final DateTime createdAt;
  final bool hasLiked;

  CommunityPuzzle copyWith({
    int? likeCount,
    int? importCount,
    int? reportCount,
    bool? hasLiked,
  }) {
    return CommunityPuzzle(
      id: id,
      authorId: authorId,
      authorName: authorName,
      authorAvatarUrl: authorAvatarUrl,
      title: title,
      description: description,
      fen: fen,
      solution: solution,
      mateIn: mateIn,
      toMove: toMove,
      likeCount: likeCount ?? this.likeCount,
      importCount: importCount ?? this.importCount,
      reportCount: reportCount ?? this.reportCount,
      createdAt: createdAt,
      hasLiked: hasLiked ?? this.hasLiked,
    );
  }

  Map<String, dynamic> toLocalPuzzle() {
    return <String, dynamic>{
      'title': title,
      'fen': fen,
      'solution': solution,
      'mateIn': mateIn,
      'toMove': toMove,
      'source': 'community',
      'communityPostId': id,
    };
  }
}

enum CommunityPuzzleSort {
  latest,
  likes,
}
