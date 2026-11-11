class PrivacyLinks {
  static const supportEmail = 'kisdice@gmail.com';
  static final policy = Uri.parse(
    'https://docs.google.com/document/d/12JLNcAreiReO43MiFt1oDoG8l_LDdohP0uS5coyL_Mw/edit',
  );
  static final deletionRequest = Uri(
    scheme: 'mailto',
    path: supportEmail,
    query: 'subject=${Uri.encodeComponent('장기 한수 계정 및 데이터 삭제 요청')}'
        '&body=${Uri.encodeComponent('장기 한수 계정 및 관련 데이터 삭제를 요청합니다.\n\n앱 로그인에 사용한 이메일: \n요청 내용: \n\n비밀번호나 인증 코드는 보내지 마세요.')}',
  );
}
