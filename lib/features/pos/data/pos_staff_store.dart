import 'dart:convert';

import 'package:apporio_store_30sept/features/pos/data/pos_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/json_reader.dart';

class PosStaffStore {
  PosStaffStore._(this._p);

  final SharedPreferences _p;
  static const _key = 'pos_staff';

  static Future<PosStaffStore> load() async => PosStaffStore._(await SharedPreferences.getInstance());

  PosStaff? read(){
    final s = _p.getString(_key);
    if(s==null || s.isEmpty) return null;
    try{
      final m = jsonDecode(s);
      return m is Map ? PosStaff.fromJson(JsonReader(m)) : null;
    }
    catch(_)
    {
      return null;
    }
  }

  Future<void> save(Map<String,dynamic> raw) => _p.setString(_key, jsonEncode(raw));

  Future<void> clear() async {
    await _p.remove(_key);
    await _p.remove('pos_cart'); // the cart belongs to the staff member's shift
  }
}
