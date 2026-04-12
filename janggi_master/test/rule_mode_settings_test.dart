import 'package:flutter_test/flutter_test.dart';
import 'package:janggi_master/models/rule_mode.dart';
import 'package:janggi_master/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('settings service defaults to casual rule mode and persists changes',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final settings = SettingsService();
    await settings.init();
    expect(settings.ruleMode, RuleMode.casualDefault);

    await settings.setRuleMode(RuleMode.officialKja);

    final reloaded = SettingsService();
    await reloaded.init();
    expect(reloaded.ruleMode, RuleMode.officialKja);
  });
}
