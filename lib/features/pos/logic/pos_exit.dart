import 'package:apporio_store_30sept/core/auth/auth_controller.dart';
import 'package:apporio_store_30sept/features/pos/data/pos_repository.dart';
import 'package:apporio_store_30sept/features/pos/logic/pos_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';

Future<void> posExit(BuildContext context, WidgetRef ref) async{
  final staff = ref.read(posAuthProvider).staff;
  await ref.read(posRepositoryProvider).logout(staff?.business.id?? '');
  final auth = ref.read(posAuthProvider.notifier);
  final target = ref.read(authControllerProvider).loggedIn? Routes.more : Routes.welcome;
  if(!context.mounted) return;
  context.go(target);
  await auth.signOut();
}