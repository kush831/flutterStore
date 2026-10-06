import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/image_picking.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/end_points.dart';
import '../../../core/network/json_reader.dart';
import '../../../core/storage/app_prefs.dart';
import '../../../core/storage/session_store.dart';
import '../../../core/storage/storage_providers.dart';

/// d/M/yyyy, exactly what the API expects (digits are always ASCII, whatever the phone's language).
String stripeDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

class StripeField {
  const StripeField({required this.key, required this.label, required this.type, this.max, this.display = true});

  final String key;
  final String label;
  final String type; // "select_dob" → a date picker, otherwise text
  final int? max;
  final bool display;

  bool get isDate => type == 'select_dob';

  factory StripeField.fromJson(JsonReader r) => StripeField(
    key: r.text('key'),
    label: r.text('displayText'),
    type: r.text('type'),
    max: r.integer('max'),
    display: r.flag('display'),
  );
}

class UploadDocType {
  const UploadDocType({required this.id, required this.name, this.requiresFront = false, this.requiresBack = false});

  final int id;
  final String name;
  final bool requiresFront;
  final bool requiresBack;

  /// The front slot always exists (a type that says nothing still needs something to upload).
  bool get showFront => requiresFront || !requiresBack;
  bool get showBack => requiresBack;

  factory UploadDocType.fromJson(JsonReader r) => UploadDocType(
    id: r.integer('id') ?? 0,
    name: r.text('type'),
    requiresFront: r.flag('requiresFront'),
    requiresBack: r.flag('requiresBack'),
  );
}

class DocumentsRepository {
  DocumentsRepository(this._api, this._session, this._prefs);

  final ApiClient _api;
  final SessionStore _session;
  final AppPrefs _prefs;

  /// These endpoints also carry the merchant keys explicitly (as Jetpack does).
  Map<String, String> get _keys => {'publicKey': _session.publicKey, 'secretKey': _session.secretKey};

  String get _segment => _prefs.businessSegmentId; // note the API's spelling: "bussiness_segment_id"

  Future<List<StripeField>> stripeFields() async {
    final root = await _api.postForm(EndPoints.stripeRequiredDetails, {'bussiness_segment_id': _segment}, _keys);
    return [for (final f in root.list('data', StripeField.fromJson)) if (f.display && f.key.isNotEmpty) f];
  }

  /// Throws AppException (the server's message on a refusal).
  Future<String> submitStripe(Map<String, String> values, {required String ip}) async {
    final root = await _api.postForm(
      EndPoints.stripeSubmit,
      {...values, 'bussiness_segment_id': _segment, 'ip_address': ip},
      _keys,
    );
    return root.text('message');
  }

  Future<List<UploadDocType>> uploadTypes() async {
    final root = await _api.postForm(EndPoints.uploadDocumentTypes, {'bussiness_segment_id': _segment}, _keys);
    return root.list('data', UploadDocType.fromJson);
  }

  Future<String> uploadDocument({required int typeId, PickedPhoto? front, PickedPhoto? back}) async {
    final root = await _api.postMultipart(
      EndPoints.uploadDocumentImages,
      fields: {'bussiness_segment_id': _segment, 'document_type_id': typeId},
      files: [
        if (front != null) ('document_front', UploadFile(bytes: front.bytes, filename: 'document_front.jpg')),
        if (back != null) ('document_back', UploadFile(bytes: back.bytes, filename: 'document_back.jpg')),
      ],
      headers: _keys,
    );
    return root.text('message');
  }
}

final documentsRepositoryProvider = Provider<DocumentsRepository>(
      (ref) => DocumentsRepository(ref.watch(apiClientProvider), ref.watch(sessionStoreProvider), ref.watch(appPrefsProvider)),
);

final stripeFieldsProvider = FutureProvider.autoDispose<List<StripeField>>((ref) => ref.watch(documentsRepositoryProvider).stripeFields());

final uploadTypesProvider = FutureProvider.autoDispose<List<UploadDocType>>((ref) => ref.watch(documentsRepositoryProvider).uploadTypes());