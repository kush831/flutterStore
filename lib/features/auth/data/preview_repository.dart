import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/end_points.dart';

class PreviewMerchant {
  const PreviewMerchant({required this.publicKey, required this.secretKey, this.primaryColor = '', this.name = ''});

  final String publicKey;
  final String secretKey;
  final String primaryColor; // "#RRGGBB" of the store app
  final String name;
}

class PreviewRepository {
  PreviewRepository(this._api);

  final ApiClient _api;

  /// Throws AppException (the server's message on a wrong PIN).
  Future<PreviewMerchant> verifyPin(String pin) async {
    final root = await _api.postJson(
      EndPoints.previewLogin,
      {'calling_from': 'STORE', 'access_pin': pin},
      headers: {'access_pin': pin},
    );
    final d = root.sub('data');
    return PreviewMerchant(
      publicKey: d.text('merchantPublicKey'),
      secretKey: d.text('merchantSecretKey'),
      primaryColor: d.text('primaryColorStore'),
      name: d.text('businessName'),
    );
  }
}

final previewRepositoryProvider = Provider<PreviewRepository>((ref) => PreviewRepository(ref.watch(apiClientProvider)));