import 'package:apporio_store_30sept/features/pos/data/pos_models.dart';

import '../../../core/router/routes.dart';

String bearerToken(String t){
  final s = t.trim();
  return s.toLowerCase().startsWith('bearer ') ? s : 'Bearer $s';
}

String phoneForLogin(String dial, String number){
  final d = dial.trim();
  final code = d.isEmpty ? '' : (d.startsWith('+') ? d : '+$d');
  return '$code${number.trim()}';
}

bool posLoginReady(String phone,String pin)=>phone.trim().length>=6 && pin.trim().length==4;
String posEntryRoute(PosActiveSession? session)=> (session!=null && session.isActive) ? Routes.pos : Routes.posOpenSession;