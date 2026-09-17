import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../brand/brand_providers.dart';
import '../../brand/kitsch_widgets.dart';
import '../../l10n/app_copy.dart';
import 'auth_providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  bool _busy = false;
  String? _error;

  Future<void> _google() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final err =
        await ref.read(authControllerProvider.notifier).signInWithGoogle();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brandName =
        ref.watch(brandConfigProvider).asData?.value.displayName ?? 'SHSnacks';

    return Scaffold(
      body: KitschBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  Copy.loginTitle,
                  style: GoogleFonts.bangers(
                    fontSize: 48,
                    letterSpacing: 1.2,
                    color: scheme.primary,
                    shadows: [
                      Shadow(
                        color: scheme.outline.withValues(alpha: 0.35),
                        offset: const Offset(3, 3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                KitschRibbon(label: '$brandName · Google se kholo'),
                const SizedBox(height: 16),
                KitschSticker(
                  color: scheme.surface,
                  child: Text(
                    'Continue with Google. Pehla account primary owner banega; '
                    'baaki emails Settings se add hongi. Baithak platform emails silent rehte hain.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _google,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Text(_busy ? '...' : 'Continue with Google'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(color: scheme.error),
                  ),
                ],
                const Spacer(),
                Center(
                  child: Text(
                    Copy.appTagline,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Powered by Baithak',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.55),
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
