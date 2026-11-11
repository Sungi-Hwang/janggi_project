import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:janggi_master/community/public_display_name.dart';
import 'package:janggi_master/models/community_puzzle.dart';
import 'package:janggi_master/privacy/privacy_links.dart';
import 'package:janggi_master/screens/privacy_screen.dart';

void main() {
  test('public labels reject email fallbacks and malformed metadata', () {
    expect(publicDisplayName([' member@example.com ']), '익명 사용자');
    expect(publicDisplayName(['Name <member@example.com>']), '익명 사용자');
    expect(publicDisplayName([null, 12, '', '  순기  ']), '순기');
    expect(publicDisplayName(['a@b', '별명']), '별명');
  });

  test('legacy community authors do not display email addresses', () {
    final puzzle = CommunityPuzzle.fromJson({
      'author': {'display_name': 'old@example.com'},
    });
    expect(puzzle.authorName, '익명 사용자');
    expect(puzzle.copyWith(likeCount: 1).authorName, '익명 사용자');
  });

  test('deletion request is an explicit mail draft without account data', () {
    expect(PrivacyLinks.deletionRequest.scheme, 'mailto');
    expect(PrivacyLinks.deletionRequest.path, PrivacyLinks.supportEmail);
    expect(PrivacyLinks.deletionRequest.queryParameters['subject'],
        '장기 한수 계정 및 데이터 삭제 요청');
    expect(PrivacyLinks.deletionRequest.queryParameters['body'],
        contains('비밀번호나 인증 코드는 보내지 마세요.'));
    expect(PrivacyLinks.policy.scheme, 'https');
  });

  testWidgets('privacy screen is available without login or providers',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PrivacyScreen()));
    expect(find.text('장기 한수 개인정보 안내'), findsOneWidget);
    expect(find.text('삭제 요청 메일 작성'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('Google Play 구독'), 300,
        scrollable: find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable))
            .first);
    expect(find.textContaining('별도로'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
