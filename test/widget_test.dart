import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sksnacks/app.dart';
import 'package:sksnacks/features/auth/auth_providers.dart';
import 'package:sksnacks/features/auth/auth_state.dart';
import 'package:sksnacks/l10n/app_copy.dart';

void main() {
  testWidgets('App loads login scaffold', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_FakeAuth.new),
        ],
        child: const SkSnacksApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.text(Copy.loginTitle), findsOneWidget);
  });
}

class _FakeAuth extends AuthController {
  @override
  AuthSession? build() => null;
}
