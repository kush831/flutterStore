import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/config/app_env.dart';

class SetupCheckScreen extends StatelessWidget {
  const SetupCheckScreen({super.key});

  String _sizeClass(double w) =>
      w >= 1440 ? 'large (desktop)' : w >= 1024 ? 'expanded (sidebar)' : w >= 600 ? 'medium (rail)' : 'compact (phone)';

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Icon(Icons.check_circle_rounded, size: 56, color: scheme.primary),
                const SizedBox(height: 12),
                Text('Setup OK', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(AppEnv.appName, style: TextStyle(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 24),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snap) => Column(
                    children: [
                      _row('Flavor', AppEnv.flavor.isEmpty ? '(none)' : AppEnv.flavor),
                      _row('Package', snap.data?.packageName ?? '…'),
                      _row('Version', snap.hasData ? '${snap.data!.version}+${snap.data!.buildNumber}' : '…'),
                      _row('Base URL', AppEnv.baseUrl),
                      _row('OneSignal', AppEnv.oneSignalAppId.isEmpty ? '(missing)' : 'configured'),
                      _row('Platform', kIsWeb ? 'web' : defaultTargetPlatform.name),
                      _row('Window', '${w.round()} px · ${_sizeClass(w)}'),
                      _row('Theme', Theme.of(context).brightness.name),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 90, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))),
        Expanded(child: SelectableText(v)),
      ],
    ),
  );
}