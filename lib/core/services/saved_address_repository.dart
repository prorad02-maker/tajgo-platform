import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_address.dart';

/// Сохранённые адреса клиента.
///
/// Источник истины — Firestore `users/{uid}/addresses`; параллельно ведётся
/// безопасный локальный кэш (SharedPreferences) для offline-показа и ручного
/// оформления без сети. Адреса — персональные, но не критические данные, поэтому
/// владелец пишет их напрямую (Rules ограничивают доступ владельцем).
class SavedAddressRepository {
  SavedAddressRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('addresses');

  Stream<List<SavedAddress>> addressesStream(String uid) {
    return _col(uid).snapshots().map((snapshot) {
      final list = snapshot.docs.map(SavedAddress.fromDoc).toList()
        ..sort(
          (a, b) => (b.updatedAt ?? DateTime(2000)).compareTo(
            a.updatedAt ?? DateTime(2000),
          ),
        );
      _writeCache(uid, list);
      return list;
    });
  }

  Future<List<SavedAddress>> cachedAddresses(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(uid));
      if (raw == null) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(SavedAddress.fromCacheJson)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(String uid, SavedAddress address) async {
    final ref = address.id.isEmpty
        ? _col(uid).doc()
        : _col(uid).doc(address.id);
    await ref.set({
      ...address.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> delete(String uid, String id) => _col(uid).doc(id).delete();

  Future<void> _writeCache(String uid, List<SavedAddress> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey(uid),
        jsonEncode(list.map((a) => a.toCacheJson()).toList()),
      );
    } catch (_) {
      // кэш не критичен
    }
  }

  String _cacheKey(String uid) => 'saved_addresses_$uid';
}
