import 'package:shared_preferences/shared_preferences.dart';
import 'user_session.dart';

/// A captured namespace: an async operation cannot start writing to the next
/// account's keys. Legacy unowned preferences are intentionally never imported.
class UserPreferences {
  final SharedPreferences _prefs;
  final String uid;
  UserPreferences._(this._prefs, this.uid);
  static Future<UserPreferences> getInstance() async {
    final session = UserSession.instance.capture();
    final prefs = await SharedPreferences.getInstance();
    session.check();
    return UserPreferences._(prefs, session.uid);
  }

  String _key(String key) => 'user:$uid:$key';
  String? getString(String key) => _prefs.getString(_key(key));
  int? getInt(String key) => _prefs.getInt(_key(key));
  double? getDouble(String key) => _prefs.getDouble(_key(key));
  bool? getBool(String key) => _prefs.getBool(_key(key));
  List<String>? getStringList(String key) => _prefs.getStringList(_key(key));
  Future<bool> setString(String key, String value) =>
      _prefs.setString(_key(key), value);
  Future<bool> setInt(String key, int value) => _prefs.setInt(_key(key), value);
  Future<bool> setDouble(String key, double value) =>
      _prefs.setDouble(_key(key), value);
  Future<bool> setBool(String key, bool value) =>
      _prefs.setBool(_key(key), value);
  Future<bool> setStringList(String key, List<String> value) =>
      _prefs.setStringList(_key(key), value);
  Future<bool> remove(String key) => _prefs.remove(_key(key));
}
