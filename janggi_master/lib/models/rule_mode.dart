enum RuleMode {
  casualDefault,
  officialKja,
}

class RuleModeConfig {
  const RuleModeConfig({
    required this.engineVariantName,
    required this.storageValue,
    required this.label,
    required this.shortLabel,
    required this.description,
    required this.usesHistoricalEngineState,
    required this.usesEngineLegality,
    required this.appliesImmediateDrawRules,
    required this.allowsLocalStatusSupplements,
  });

  final String engineVariantName;
  final String storageValue;
  final String label;
  final String shortLabel;
  final String description;
  final bool usesHistoricalEngineState;
  final bool usesEngineLegality;
  final bool appliesImmediateDrawRules;
  final bool allowsLocalStatusSupplements;
}

const Map<RuleMode, RuleModeConfig> _ruleModeConfigs = {
  RuleMode.casualDefault: RuleModeConfig(
    engineVariantName: 'janggimodern',
    storageValue: 'casual_default',
    label: '캐주얼 (Kakao-style)',
    shortLabel: '캐주얼',
    description: '반복/50수는 즉시 무승부, 빅장/한수쉼/점수 판정은 유지',
    usesHistoricalEngineState: false,
    usesEngineLegality: false,
    appliesImmediateDrawRules: true,
    allowsLocalStatusSupplements: true,
  ),
  RuleMode.officialKja: RuleModeConfig(
    engineVariantName: 'janggi',
    storageValue: 'official_kja',
    label: '대한장기협회식',
    shortLabel: '협회식',
    description: '수순 이력 기반 판정과 AI를 협회식에 가깝게 적용',
    usesHistoricalEngineState: true,
    usesEngineLegality: true,
    appliesImmediateDrawRules: false,
    allowsLocalStatusSupplements: false,
  ),
};

extension RuleModeX on RuleMode {
  RuleModeConfig get config => _ruleModeConfigs[this]!;

  String get engineVariantName => config.engineVariantName;

  String get storageValue => config.storageValue;

  String get label => config.label;

  String get shortLabel => config.shortLabel;

  String get description => config.description;

  bool get usesHistoricalEngineState => config.usesHistoricalEngineState;

  bool get usesEngineLegality => config.usesEngineLegality;

  bool get appliesImmediateDrawRules => config.appliesImmediateDrawRules;

  bool get allowsLocalStatusSupplements => config.allowsLocalStatusSupplements;

  static RuleMode fromStorageValue(String? value) {
    for (final mode in RuleMode.values) {
      if (mode.storageValue == value) {
        return mode;
      }
    }
    return RuleMode.casualDefault;
  }
}
