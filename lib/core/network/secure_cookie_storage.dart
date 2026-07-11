import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// [Storage] backend for [PersistCookieJar] that keeps the session cookies
/// (the only credential this app has — there are no bearer tokens) in the
/// platform keystore/keychain instead of plain files, matching the
/// protection [SecureStorage] already gives the cached user profile.
class SecureCookieStorage implements Storage {
  static const _prefix = 'ss_cookie.';
  static const _indexKey = '${_prefix}__index__';

  static const _fss = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Set<String> _index = {};

  @override
  Future<void> init(bool persistSession, bool ignoreExpires) async {
    final raw = await _fss.read(key: _indexKey);
    if (raw != null) {
      _index = (jsonDecode(raw) as List).cast<String>().toSet();
    }
  }

  @override
  Future<String?> read(String key) => _fss.read(key: _encode(key));

  @override
  Future<void> write(String key, String value) async {
    await _fss.write(key: _encode(key), value: value);
    if (_index.add(key)) {
      await _writeIndex();
    }
  }

  @override
  Future<void> delete(String key) async {
    await _fss.delete(key: _encode(key));
    if (_index.remove(key)) {
      await _writeIndex();
    }
  }

  /// Deletes every cookie key this storage has ever written, not just the
  /// keys the jar happens to pass in — the jar's in-memory index can be
  /// stale (e.g. a forced logout right after cold start), and a leftover
  /// entry here would defeat the point of storing sessions securely.
  @override
  Future<void> deleteAll(List<String> keys) async {
    final all = {..._index, ...keys};
    for (final key in all) {
      await _fss.delete(key: _encode(key));
    }
    _index.clear();
    await _fss.delete(key: _indexKey);
  }

  Future<void> _writeIndex() =>
      _fss.write(key: _indexKey, value: jsonEncode(_index.toList()));

  // Cookie-jar keys embed hostnames/paths (dots, slashes); base64url-encode
  // them so they're always safe as EncryptedSharedPreferences/Keychain keys.
  String _encode(String key) => _prefix + base64Url.encode(utf8.encode(key));
}
