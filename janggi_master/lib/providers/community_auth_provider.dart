import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../community/community_config.dart';

class CommunityAuthProvider extends ChangeNotifier {
  CommunityAuthProvider() {
    if (!CommunityConfig.canUseSupabase) {
      return;
    }

    _session = _client.auth.currentSession;
    _authSubscription = _client.auth.onAuthStateChange.listen((state) {
      _session = state.session;
      if (_session != null) {
        unawaited(_syncProfile());
      }
      notifyListeners();
    });
  }

  SupabaseClient get _client => Supabase.instance.client;
  StreamSubscription<AuthState>? _authSubscription;

  Session? _session;
  bool _isBusy = false;
  String? _lastError;

  bool get isConfigured => CommunityConfig.canUseSupabase;
  bool get isGoogleConfigured => CommunityConfig.isGoogleConfigured;
  bool get isSignedIn => _session?.user != null;
  bool get isBusy => _isBusy;
  String? get lastError => _lastError;
  User? get user => _session?.user;

  String get displayName {
    final metadata = user?.userMetadata ?? const <String, dynamic>{};
    final name = metadata['full_name'] as String? ??
        metadata['name'] as String? ??
        metadata['email'] as String? ??
        user?.email ??
        'Google 사용자';
    return name.trim().isEmpty ? 'Google 사용자' : name;
  }

  Future<bool> ensureSignedIn() async {
    if (isSignedIn) {
      return true;
    }
    return signInWithGoogle();
  }

  Future<bool> signInWithGoogle() async {
    if (!isConfigured) {
      _lastError = 'Supabase 설정이 필요합니다.';
      notifyListeners();
      return false;
    }
    if (!isGoogleConfigured) {
      _lastError = 'Google Web Client ID 설정이 필요합니다.';
      notifyListeners();
      return false;
    }

    _setBusy(true);
    try {
      final googleSignIn = GoogleSignIn(
        scopes: const <String>['email', 'profile'],
        serverClientId: CommunityConfig.googleWebClientId,
        clientId: CommunityConfig.googleIosClientId.isEmpty
            ? null
            : CommunityConfig.googleIosClientId,
      );
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        _lastError = null;
        return false;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;
      if (idToken == null || accessToken == null) {
        _lastError = 'Google 인증 토큰을 받지 못했습니다.';
        return false;
      }

      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      _session = response.session;
      await _syncProfile();
      _lastError = null;
      notifyListeners();
      return true;
    } catch (error) {
      _lastError = 'Google 로그인에 실패했습니다: $error';
      notifyListeners();
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> signOut() async {
    if (!isConfigured) {
      return;
    }

    _setBusy(true);
    try {
      await _client.auth.signOut();
      await GoogleSignIn().signOut();
      _session = null;
      _lastError = null;
      notifyListeners();
    } catch (error) {
      _lastError = '로그아웃에 실패했습니다: $error';
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _syncProfile() async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      return;
    }

    final metadata = currentUser.userMetadata ?? const <String, dynamic>{};
    await _client.from('profiles').upsert(
      <String, dynamic>{
        'id': currentUser.id,
        'display_name': displayName,
        'avatar_url': metadata['avatar_url'] as String?,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'id',
    );
  }

  void _setBusy(bool value) {
    if (_isBusy == value) {
      return;
    }
    _isBusy = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
