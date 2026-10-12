import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_scope.dart';

/// The camera: the first barcode or QR code it reads closes the screen and goes back to Search. Jetpack's BarcodeScannerScreen.
class PosBarcodeScannerScreen extends StatefulWidget {
  const PosBarcodeScannerScreen({super.key});

  @override
  State<PosBarcodeScannerScreen> createState() => _PosBarcodeScannerScreenState();
}

class _PosBarcodeScannerScreenState extends State<PosBarcodeScannerScreen> {
  // started by hand, so a refused camera permission can be handled on this screen (and retried)
  final _controller = MobileScannerController(autoStart: false, detectionSpeed: DetectionSpeed.noDuplicates);
  bool _torch = false;
  bool _denied = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    try {
      await _controller.start();
      if (mounted) setState(() => _denied = false);
    } catch (_) {
      if (mounted) setState(() => _denied = true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final b in capture.barcodes) {
      final v = b.rawValue;
      if (v != null && v.trim().isNotEmpty) {
        _done = true;
        HapticFeedback.mediumImpact();
        context.pop(v);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (!_denied) MobileScanner(controller: _controller, onDetect: _onDetect),
          if (!_denied)
            Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 3), borderRadius: BorderRadius.circular(24)),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                IconButton(onPressed: () => context.canPop() ? context.pop() : context.go(Routes.posSearch), icon: const Icon(Icons.close_rounded, color: Colors.white)),
                const Spacer(),
                if (!_denied)
                  IconButton(
                    onPressed: () async {
                      await _controller.toggleTorch();
                      if (mounted) setState(() => _torch = !_torch);
                    },
                    icon: Icon(_torch ? Icons.flash_on_rounded : Icons.flash_off_rounded, color: Colors.white),
                  ),
              ]),
            ),
          ),
          if (!_denied)
            Align(
              alignment: const Alignment(0, 0.72),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(50)),
                child: Text(context.str('pos_possearchscreen_scan_hint'), style: const TextStyle(color: Colors.white)),
              ),
            ),
          if (_denied)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.no_photography_outlined, size: 56, color: Colors.white70),
                  const SizedBox(height: 14),
                  Text(context.str('pos_possearchscreen_camera_permission'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 18),
                  FilledButton(onPressed: _start, style: FilledButton.styleFrom(backgroundColor: context.primary), child: Text(context.str('pos_possearchscreen_grant_permission'))),
                  const SizedBox(height: 8),
                  TextButton(onPressed: () => context.canPop() ? context.pop() : context.go(Routes.posSearch), child: Text(context.str('pos_posmorescreen_cancel'), style: TextStyle(color: tk.text3))),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}