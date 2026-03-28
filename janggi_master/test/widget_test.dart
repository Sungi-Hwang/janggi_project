import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:janggi_master/main.dart';
import 'package:janggi_master/providers/monetization_provider.dart';
import 'package:janggi_master/providers/settings_provider.dart';
import 'package:janggi_master/services/monetization_service.dart';
import 'package:janggi_master/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('main menu smoke test', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final settingsService = SettingsService();
    await settingsService.init();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(settingsService),
          ),
          ChangeNotifierProvider(
            create: (_) => MonetizationProvider(MonetizationService()),
          ),
        ],
        child: const MyApp(),
      ),
    );

    await tester.pump();

    expect(find.byType(MainMenu), findsOneWidget);
    expect(find.text('Janggi Hansu'), findsOneWidget);
  });
}
