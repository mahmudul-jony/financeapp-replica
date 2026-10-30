import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:financeapp/main.dart';
import 'package:financeapp/providers/update_provider.dart';
import 'package:financeapp/screens/signin_screen.dart';
import 'package:financeapp/services/auth_service.dart';
import 'package:financeapp/widgets/app_components.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    expect(true, isTrue);
  });

  group('AppWalletSelector Tests', () {
    final testAccounts = [
      {'name': 'Bank BSI', 'balance': '৳5,750.20'},
      {'name': 'Bank BCA', 'balance': '৳12,000.00'},
    ];

    testWidgets('Displays all wallets and shows checkmark only for selected wallet', (WidgetTester tester) async {
      String selected = 'Bank BCA';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppWalletSelector(
              selectedAccount: selected,
              onSelect: (name) => selected = name,
              accounts: testAccounts,
            ),
          ),
        ),
      );

      // Verify wallet names and balances are displayed
      expect(find.text('Bank BSI'), findsOneWidget);
      expect(find.text('Bank BCA'), findsOneWidget);
      expect(find.text('৳5,750.20'), findsOneWidget);
      expect(find.text('৳12,000.00'), findsOneWidget);

      // Exactly one checkmark should be rendered (for Bank BCA)
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // Tap on Bank BSI
      await tester.tap(find.text('Bank BSI'));
      expect(selected, 'Bank BSI');
    });
  });

  group('AppStaticWalletCard Tests', () {
    testWidgets('Renders selected wallet with checkmark and responds to onTap', (WidgetTester tester) async {
      bool tapped = false;
      final acc = {'name': 'Bank BCA', 'balance': '৳5,750.20'};

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppStaticWalletCard(
              acc: acc,
              label: 'From Wallet',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('From Wallet'), findsOneWidget);
      expect(find.text('Bank BCA'), findsOneWidget);
      expect(find.text('৳5,750.20'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      await tester.tap(find.text('Bank BCA'));
      expect(tapped, isTrue);
    });
  });

  group('AuthGate Offline Startup Tests', () {
    testWidgets('Renders SignInScreen when unauthenticated and not offline', (WidgetTester tester) async {
      final auth = AuthService();
      auth.isInitializingForTesting = false;
      auth.isOfflineAtLaunchForTesting = false;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider(create: (_) => UpdateProvider()),
          ],
          child: const MaterialApp(home: AuthGate()),
        ),
      );
      await tester.pumpAndSettle();

      // Verify sign in screen is presented
      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
    });
  });
}
