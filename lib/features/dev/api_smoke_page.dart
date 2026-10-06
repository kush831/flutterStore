import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/config/app_env.dart';
import '../../core/design/adaptive_page.dart';
import '../../core/design/design_tokens.dart';
import '../../core/network/api_client.dart';
import '../../core/network/app_exception.dart';
import '../../core/network/end_points.dart';
import '../../core/network/json_reader.dart';
import '../../core/router/routes.dart';
import '../../core/storage/storage_providers.dart';

/// TEMPORARY: proves that headers, CORS and JSON parsing work against your real backend.
class ApiSmokePage extends ConsumerStatefulWidget {
  const ApiSmokePage({super.key});

  @override
  ConsumerState<ApiSmokePage> createState() => _ApiSmokePageState();
}

class _ApiSmokePageState extends ConsumerState<ApiSmokePage> {
  String _out = 'Tap a button.';
  bool _busy = false;

  Future<void> _run(String label, Future<JsonReader> Function(ApiClient api) call) async {
    setState(() {
      _busy = true;
      _out = 'Calling $label …';
    });
    final sw = Stopwatch()..start();
    String text;
    try {
      final r = await call(ref.read(apiClientProvider));
      text = '$label: OK in ${sw.elapsedMilliseconds} ms\n'
          'result: ${r.str('result')}\n'
          'message: ${r.str('message')}\n'
          'top-level keys: ${r.map.keys.join(', ')}';
    } on AppException catch (e) {
      text = '$label: FAILED after ${sw.elapsedMilliseconds} ms\n'
          'kind: ${e.kind.name}\n'
          'message: ${e.message}\n'
          'detail: ${e.detail ?? '-'}';
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _out = text;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final session = ref.watch(sessionStoreProvider);
    final callFrom = kIsWeb ? 'WEB' : defaultTargetPlatform.name.toUpperCase();

    return AdaptivePage(
      title: 'API smoke test',
      subtitle: 'Headers · CORS · JSON',
      fallbackRoute: Routes.home,
      scroll: true,
      maxWidth: 800,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                'Base URL: ${AppEnv.baseUrl}\n'
                    'Flavor: ${AppEnv.flavor}\n'
                    'Logged in: ${session.isLoggedIn}\n'
                    'Platform: ${kIsWeb ? 'web' : defaultTargetPlatform.name}',
                style: TextStyle(color: tk.text2, height: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run('configuration', (api) async {
                  final v = (await PackageInfo.fromPlatform()).version;
                  return api.postForm(
                    EndPoints.configuration,
                    {'call_from': callFrom, 'apk_version': v},
                    null,
                    false, // requireSuccess: show whatever the server answers
                  );
                }),
                child: const Text('POST configuration'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : () => _run('app strings', (api) => api.get(EndPoints.appStrings, requireSuccess: false)),
                child: const Text('GET app strings'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _busy
                  ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                  : SelectableText(_out, style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5)),
            ),
          ),
        ],
      ),
    );
  }
}