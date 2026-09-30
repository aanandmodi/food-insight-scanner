import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'firebase_bootstrap.dart';

class SessionChangedException implements Exception {
  @override
  String toString() => 'Your account changed. Please try again.';
}

class UserSession extends ChangeNotifier {
  static final instance = UserSession._();
  UserSession._() {
    FirebaseBootstrap.ready.addListener(_attach);
    _attach();
  }
  StreamSubscription<User?>? _subscription;
  String? _uid;
  int _revision = 0;
  String? get uid => _uid;
  void _attach() {
    if (!FirebaseBootstrap.ready.value || _subscription != null) return;
    _change(FirebaseAuth.instance.currentUser);
    _subscription = FirebaseAuth.instance.authStateChanges().listen(_change);
  }

  void _change(User? user) {
    if (_uid == user?.uid) return;
    _uid = user?.uid;
    _revision++;
    notifyListeners();
  }

  SessionToken capture() {
    // Firebase updates currentUser before delivering the stream event.
    if (FirebaseBootstrap.ready.value) {
      _change(FirebaseAuth.instance.currentUser);
    }
    final owner = _uid;
    if (owner == null) throw StateError('Please sign in to access your data.');
    return SessionToken._(owner, _revision, this);
  }

  /// Invalidate in-flight work before initiating sign-out.
  void invalidate() {
    _revision++;
  }
}

class SessionToken {
  final String uid;
  final int revision;
  final UserSession _session;
  SessionToken._(this.uid, this.revision, this._session);
  bool get isActive => _session.uid == uid && _session._revision == revision;
  void check() {
    if (!isActive) throw SessionChangedException();
  }
}
