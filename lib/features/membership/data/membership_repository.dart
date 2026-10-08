import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/end_points.dart';
import 'membership_models.dart';

class MembershipRepository {
  MembershipRepository(this._api);

  final ApiClient _api;

  Future<MembershipData> plans() async => MembershipData.fromJson(await _api.postForm(EndPoints.membershipPlans));

  /// Returns the server's message. A refusal throws AppException with its message.
  Future<String> purchase({required String planId, required String methodId, required String price}) async {
    final root = await _api.postForm(EndPoints.buyMembership, {'membership_plan_id': planId, 'payment_method_id': methodId, 'price': price});
    return root.text('message');
  }
}

final membershipRepositoryProvider = Provider<MembershipRepository>((ref) => MembershipRepository(ref.watch(apiClientProvider)));

final membershipProvider = FutureProvider.autoDispose<MembershipData>((ref) {
  ref.watch(userScopeProvider);
  return ref.watch(membershipRepositoryProvider).plans();
});