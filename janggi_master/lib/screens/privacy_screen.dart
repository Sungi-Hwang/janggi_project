import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../privacy/privacy_links.dart';

/// Deliberately requires neither a provider nor an authenticated session.
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _opening = false;

  Future<void> _open(Uri uri) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) _showFallback();
    } catch (_) {
      if (mounted) _showFallback();
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _showFallback() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('외부 앱을 열지 못했습니다. 아래 주소를 복사해 이용해 주세요.'),
    ));
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('주소를 복사했습니다.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('개인정보 및 계정·데이터 삭제')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text('장기 한수 개인정보 안내', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        const Text('개인정보 처리에 관한 안내는 아래 처리방침에서 확인할 수 있습니다.'),
        TextButton(
          onPressed: _opening ? null : () => _open(PrivacyLinks.policy),
          child: const Text('개인정보처리방침 열기'),
        ),
        SelectableText(PrivacyLinks.policy.toString()),
        TextButton(
          onPressed: () => _copy(PrivacyLinks.policy.toString()),
          child: const Text('처리방침 주소 복사'),
        ),
        const Divider(height: 32),
        Text('계정 및 관련 데이터 삭제 요청',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        const Text('앱 로그인 여부와 관계없이 아래 이메일로 삭제를 요청할 수 있습니다. '
            '앱 로그인에 사용한 이메일과 삭제 요청 내용을 적어 주세요. '
            '본인 확인 및 처리 범위 확인을 위한 안내를 받을 수 있습니다. '
            '비밀번호나 인증 코드는 보내지 마세요.'),
        const SizedBox(height: 12),
        const SelectableText(PrivacyLinks.supportEmail),
        FilledButton.icon(
          onPressed:
              _opening ? null : () => _open(PrivacyLinks.deletionRequest),
          icon: const Icon(Icons.mail_outline),
          label: const Text('삭제 요청 메일 작성'),
        ),
        const Text('메일 작성 화면만 엽니다. 내용을 확인하고 직접 전송해야 요청이 전달됩니다. '
            '이 버튼을 누르는 것만으로 계정이나 데이터가 삭제되지는 않습니다.'),
        TextButton(
          onPressed: () => _copy(PrivacyLinks.supportEmail),
          child: const Text('문의 이메일 복사'),
        ),
        const Divider(height: 32),
        const Text('앱 삭제나 로그아웃은 서버 계정·데이터 삭제와 다릅니다. '
            '커뮤니티 게시물 숨기기도 계정 삭제와 다릅니다. '
            'Google Play 구독이 있다면 계정 삭제 요청과 별도로 '
            'Google Play의 정기 결제 메뉴에서 해지해야 합니다.'),
      ]),
    );
  }
}
