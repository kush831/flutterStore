import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/design/breakpoints.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/design/skeleton.dart';
import '../../../core/network/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/strings/strings_controller.dart';
import '../../../core/strings/strings_scope.dart';
import '../../splash/logic/config_controller.dart';
import '../../splash/ui/brand_widgets.dart';
import '../data/cms_repository.dart';

const _kReadingWidth = 720.0;

/// Terms, Privacy and any other page the store configures. Public: also reachable before login.
class CmsPageScreen extends ConsumerWidget {
  const CmsPageScreen({super.key, required this.slug});

  final String slug;

  void _back(BuildContext context, WidgetRef ref) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(ref.read(authControllerProvider).loggedIn ? Routes.home : Routes.welcome);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final on = onColor(context.primary);
    final async = ref.watch(cmsPageProvider(slug));
    final saved = ref.watch(appConfigProvider)?.cmsPages.where((p) => p.slug == slug).firstOrNull;

    final content = async.value;
    final title = (content?.title.isNotEmpty ?? false) ? content!.title : (saved?.title ?? '');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: on == Colors.white ? Brightness.light : Brightness.dark,
        statusBarBrightness: on == Colors.white ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: tk.surface,
        body: Column(
          children: [
            _Header(title: title, date: content?.updatedAt, onBack: () => _back(context, ref)),
            Expanded(
              child: async.when(
                loading: () => const _Loading(),
                error: (e, _) => _ErrorView(
                  message: errorText(e, ref.read(stringsProvider)),
                  onRetry: () => ref.invalidate(cmsPageProvider(slug)),
                ),
                data: (c) => c.isUrl ? _UrlView(url: c.body, title: c.title) : _HtmlView(html: c.body),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── brand header (option C) ──────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.date, required this.onBack});

  final String title;
  final DateTime? date;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final brand = context.primary;
    final on = onColor(brand);
    final wide = context.screen.isWide;
    final top = MediaQuery.paddingOf(context).top;

    final back = IconButton(
      onPressed: onBack,
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      style: IconButton.styleFrom(backgroundColor: on.withValues(alpha: 0.14)),
      icon: Icon(Icons.arrow_back_rounded, color: on),
    );
    final heading = title.isEmpty
        ? SkeletonPulse(child: SkeletonBox(width: 180, height: 28, radius: 8))
        : Text(title, style: TextStyle(color: on, fontSize: wide ? 30 : 26, fontWeight: FontWeight.w800, letterSpacing: -0.6, height: 1.15));
    final dateText = date == null ? null : MaterialLocalizations.of(context).formatMediumDate(date!);

    return ClipRRect(
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(wide ? 0 : 28)),
      child: ColoredBox(
        color: brand,
        child: BrandBackdrop(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kReadingWidth + 48),
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, top + 12, 24, wide ? 28 : 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    back,
                    SizedBox(height: wide ? 18 : 14),
                    heading,
                    if (dateText != null) ...[
                      const SizedBox(height: 6),
                      Text(dateText, style: TextStyle(color: on.withValues(alpha: 0.85), fontSize: 13)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── HTML content ─────────────────────────────────────────────────────────────

const _textTags = {'p', 'span', 'div', 'li', 'ul', 'ol', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'td', 'th', 'strong', 'b', 'em', 'i', 'u', 'blockquote', 'font', 'section', 'article', 'small', 'label'};

String _hex(Color c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

class _HtmlView extends StatelessWidget {
  const _HtmlView({required this.html});

  final String html;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final dark = context.isDark;
    final text = _hex(tk.text1);
    final link = _hex(context.primary);

    return SelectionArea(
      child: Scrollbar(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 40),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kReadingWidth),
              child: HtmlWidget(
                html,
                textStyle: TextStyle(fontSize: 15.5, height: 1.65, color: tk.text1),
                // CMS HTML often carries inline black text / white backgrounds: readable in dark mode too
                customStylesBuilder: dark
                    ? (element) {
                  final tag = element.localName;
                  if (tag == 'a') return {'color': link};
                  if (_textTags.contains(tag)) return {'color': text, 'background-color': 'transparent'};
                  return null;
                }
                    : (element) => element.localName == 'a' ? {'color': link} : null,
                onTapUrl: (url) async {
                  final uri = Uri.tryParse(url);
                  if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                  return true;
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── URL content ──────────────────────────────────────────────────────────────

class _UrlView extends StatelessWidget {
  const _UrlView({required this.url, required this.title});

  final String url;
  final String title;

  bool get _inAppWebView => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(url.trim());
    final valid = uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
    if (!valid) return _ErrorView(message: context.str('common_allscreen_something_went_wrong'));

    if (_inAppWebView) return _MobileWebView(uri: uri);

    // Web and desktop: a browser tab (a web view cannot be embedded the same way).
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: FilledButton.icon(
          onPressed: () => launchUrl(uri, mode: LaunchMode.externalApplication),
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: Text(title.isEmpty ? uri.host : title),
        ),
      ),
    );
  }
}

class _MobileWebView extends StatefulWidget {
  const _MobileWebView({required this.uri});

  final Uri uri;

  @override
  State<_MobileWebView> createState() => _MobileWebViewState();
}

class _MobileWebViewState extends State<_MobileWebView> {
  int _progress = 0;

  late final WebViewController _controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setNavigationDelegate(NavigationDelegate(onProgress: (p) => setState(() => _progress = p)))
    ..loadRequest(widget.uri);

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      WebViewWidget(controller: _controller),
      if (_progress < 100) LinearProgressIndicator(value: _progress == 0 ? null : _progress / 100, minHeight: 3),
    ],
  );
}

// ── states ───────────────────────────────────────────────────────────────────

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kReadingWidth),
        child: SkeletonPulse(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < 3; i++) ...[
                const SkeletonBox(width: 220, height: 20, radius: 6),
                const SizedBox(height: 14),
                const SkeletonBox(height: 13),
                const SizedBox(height: 9),
                const SkeletonBox(height: 13),
                const SizedBox(height: 9),
                const SkeletonBox(width: 300, height: 13),
                const SizedBox(height: 28),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 52, color: tk.text3),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: tk.text2, height: 1.4)),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              FilledButton.tonal(onPressed: onRetry, child: Text(context.str('common_allscreen_try_again'))),
            ],
          ],
        ),
      ),
    );
  }
}