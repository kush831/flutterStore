import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/network/error_text.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../data/pos_checkout_models.dart';
import '../data/pos_checkout_repository.dart';

/// Attach a customer to the order. Returns the choice, or null when closed.
Future<PosCustomer?> showCustomerSheet(BuildContext context) {
  const body = _CustomerSheet();
  if (MediaQuery.sizeOf(context).width >= 600) {
    return showDialog<PosCustomer>(context: context, builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480, maxHeight: 720), child: body)));
  }
  return showModalBottomSheet<PosCustomer>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => body);
}

class _CustomerSheet extends ConsumerStatefulWidget {
  const _CustomerSheet();

  @override
  ConsumerState<_CustomerSheet> createState() => _CustomerSheetState();
}

class _CustomerSheetState extends ConsumerState<_CustomerSheet> {
  final _search = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  Timer? _debounce;
  List<PosCustomerUser> _found = const [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _typed(String v) {
    _debounce?.cancel();
    if (v.trim().length < 2) {
      setState(() {
        _found = const [];
        _loading = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() {
        _loading = true;
        _error = null;
      });
      try {
        final r = await ref.read(posCheckoutRepositoryProvider).users(v);
        if (mounted && _search.text.trim() == v.trim()) setState(() => _found = r);
      } catch (e) {
        if (mounted) setState(() => _error = errorText(e, ref.read(stringsProvider)));
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final manualReady = _name.text.trim().isNotEmpty && _phone.text.trim().isNotEmpty;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(context.str('pos_posaddcustomerscreen_title'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: tk.text1)), Text(context.str('pos_posaddcustomerscreen_subtitle'), style: TextStyle(color: tk.text2))])),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ]),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                onTap: () => Navigator.pop(context, PosCustomer.walk),
                leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: context.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.person_outline_rounded, color: context.primary)),
                title: Text(context.str('pos_posaddcustomerscreen_walk_in'), style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(context.str('pos_posaddcustomerscreen_walk_in_sub')),
              ),
            ),
            const SizedBox(height: 14),
            TextField(controller: _search, onChanged: _typed, decoration: InputDecoration(hintText: context.str('pos_posstaffscreen_enter_phone_placeholder'), prefixIcon: const Icon(Icons.search_rounded))),
            if (_loading) const Padding(padding: EdgeInsets.all(12), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)))),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: tk.danger))),
            for (final u in _found)
              ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => Navigator.pop(context, PosCustomer(name: u.name, phone: u.phone)),
                leading: CircleAvatar(backgroundColor: context.primary.withValues(alpha: 0.12), child: Text(u.name.trim().isEmpty ? '·' : u.name.trim()[0].toUpperCase(), style: TextStyle(color: context.primary, fontWeight: FontWeight.w800))),
                title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(u.phone.isEmpty ? context.str('pos_posaddcustomerscreen_no_phone') : u.phone),
              ),
            const Divider(height: 28),
            TextField(controller: _name, textCapitalization: TextCapitalization.words, onChanged: (_) => setState(() {}), decoration: InputDecoration(hintText: context.str('pos_posaddcustomerscreen_title'), prefixIcon: const Icon(Icons.person_add_alt_1_outlined))),
            const SizedBox(height: 10),
            TextField(controller: _phone, keyboardType: TextInputType.phone, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))], onChanged: (_) => setState(() {}), decoration: InputDecoration(hintText: context.str('pos_posstaffscreen_enter_phone_placeholder'), prefixIcon: const Icon(Icons.phone_outlined))),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)), child: Text(context.str('pos_poscheckoutscreen_cancel')))),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: FilledButton(onPressed: manualReady ? () => Navigator.pop(context, PosCustomer(name: _name.text.trim(), phone: _phone.text.trim())) : null, style: FilledButton.styleFrom(minimumSize: const Size(0, 48)), child: Text(context.str('pos_posaddcustomerscreen_title')))),
            ]),
          ],
        ),
      ),
    );
  }
}