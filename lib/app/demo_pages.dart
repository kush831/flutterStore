import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/design/adaptive_page.dart';
import '../core/design/design_tokens.dart';
import '../core/design/status_pill.dart';
import '../core/design/theme_controller.dart';
import '../core/router/routes.dart';
import '../core/strings/language_selector.dart';
import '../core/strings/strings_controller.dart';
import '../core/strings/strings_scope.dart';

/// Metric cards + a list card: enough to judge spacing, tables and both themes.
class DemoPage extends StatelessWidget {
  const DemoPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AdaptivePage(
      title: title,
      subtitle: 'Demo content · Step 2',
      scroll: true,
      actions: [
        const ThemeToggleButton(),
        FilledButton.icon(
          onPressed: () => context.push(Routes.design),
          icon: const Icon(Icons.palette_outlined, size: 18),
          label: const Text('Design showcase'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final cols = box.maxWidth >= 900 ? 4 : 2;
              const gap = 12.0;
              final w = (box.maxWidth - gap * (cols - 1)) / cols;
              Widget metric(String label, String value, IconData icon) => SizedBox(
                width: w,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, size: 20, color: context.primary),
                        const SizedBox(height: 10),
                        Text(label, style: TextStyle(fontSize: 13, color: tk.text2)),
                        const SizedBox(height: 2),
                        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              );
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  metric('Sales today', '₹18,420', Icons.payments_outlined),
                  metric('New orders', '4', Icons.receipt_long_outlined),
                  metric('Preparing', '7', Icons.soup_kitchen_outlined),
                  metric('Low stock', '3', Icons.inventory_2_outlined),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < 5; i++) ...[
                  ListTile(
                    onTap: () => context.push(Routes.orderDetail('${4821 - i}')),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text('Order #${4821 - i}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('3 items · ₹${640 + i * 120}', style: TextStyle(color: tk.text2)),
                    trailing: StatusPill(
                      ['New', 'Preparing', 'Ready', 'Delivered', 'Cancelled'][i],
                      tone: [PillTone.warning, PillTone.info, PillTone.success, PillTone.neutral, PillTone.danger][i],
                    ),
                  ),
                  if (i < 4) const Divider(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A detail page: tests the back button and the sidebar highlight on a child route.
class DemoDetailPage extends StatelessWidget {
  const DemoDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) => AdaptivePage(
    title: 'Order #$id',
    subtitle: 'Detail page',
    fallbackRoute: Routes.orders,
    scroll: true,
    maxWidth: 800,
    actions: [OutlinedButton(onPressed: () {}, child: const Text('Reject')), FilledButton(onPressed: () {}, child: const Text('Accept'))],
    child: const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('Order details will be built in Step 15.'))),
  );
}

/// Every component in both themes: review before we build screens.
class DesignShowcasePage extends StatelessWidget {
  const DesignShowcasePage({super.key});

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    Widget section(String title, Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: tk.text3)),
              const SizedBox(height: 14),
              child,
              section(
                'LANGUAGE',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LanguageSelector(),
                    const SizedBox(height: 16),
                    // real server keys: translated in every language
                    Text(context.str('common_allscreen_saveChanges'), style: const TextStyle(fontSize: 16)),
                    Text(context.str('common_allscreen_try_again'), style: const TextStyle(fontSize: 16)),
                    Text(context.str('common_allscreen_cancel_button'), style: const TextStyle(fontSize: 16)),
                    // a key that does not exist: shows the key name and lands in /dev/strings
                    Text(context.str('demo_this_key_is_missing'), style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 12),
                    Consumer(
                      builder: (context, ref, _) {
                        final s = ref.watch(stringsProvider);
                        return Text(
                          'language: ${s.code}  ·  source: ${s.source.name}  ·  keys: ${s.strings.length}',
                          style: TextStyle(fontSize: 12, color: context.tk.text2),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: () => context.push('/dev/strings'), child: const Text('Open /dev/strings')),
                    const SizedBox(height: 12),
                    // RTL check: the icon, text and chevron mirror in Arabic
                    const Row(children: [Icon(Icons.storefront_outlined), SizedBox(width: 12), Expanded(child: Text('Spice Garden')), Icon(Icons.chevron_right)]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return AdaptivePage(
      title: 'Design showcase',
      subtitle: 'Buttons, inputs, pills, dialogs in the current theme',
      fallbackRoute: Routes.home,
      scroll: true,
      maxWidth: 900,
      actions: const [ThemeToggleButton()],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          section(
            'BUTTONS',
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton(onPressed: () {}, child: const Text('Filled')),
                OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
                TextButton(onPressed: () {}, child: const Text('Text')),
                const FilledButton(onPressed: null, child: Text('Disabled')),
              ],
            ),
          ),
          section(
            'INPUTS',
            const Column(
              children: [
                TextField(decoration: InputDecoration(labelText: 'Store name', hintText: 'Spice Garden')),
                SizedBox(height: 12),
                TextField(decoration: InputDecoration(labelText: 'Email', errorText: 'Enter a valid email')),
              ],
            ),
          ),
          section(
            'STATUS PILLS',
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusPill('Neutral'),
                StatusPill('Primary', tone: PillTone.primary),
                StatusPill('Success', tone: PillTone.success, icon: Icons.check_rounded),
                StatusPill('Warning', tone: PillTone.warning),
                StatusPill('Danger', tone: PillTone.danger),
                StatusPill('Info', tone: PillTone.info),
              ],
            ),
          ),
          section(
            'OVERLAYS',
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order accepted'))),
                  child: const Text('Snackbar'),
                ),
                OutlinedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Reject this order?'),
                      content: const Text('The customer will be notified.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Reject')),
                        OutlinedButton(onPressed: () => context.push('/dev/api'), child: const Text('API test')),
                      ],
                    ),
                  ),
                  child: const Text('Dialog'),
                ),
                OutlinedButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    builder: (_) => const Padding(padding: EdgeInsets.fromLTRB(24, 0, 24, 40), child: Text('A bottom sheet.\nOn wide screens it stays 640 px wide.')),
                  ),
                  child: const Text('Bottom sheet'),
                ),
              ],
            ),
          ),
          section(
            'CONTROLS',
            Row(
              children: [
                Switch(value: true, onChanged: (_) {}),
                const SizedBox(width: 16),
                Switch(value: false, onChanged: (_) {}),
                const SizedBox(width: 16),
                const Chip(label: Text('Chip')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}