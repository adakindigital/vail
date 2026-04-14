/// App-wide constants. No magic strings or numbers elsewhere in the codebase.
class AppConstants {
  static const String appName = 'Vail';
  static const String appVersion = '0.1.0';
  static const String buildPhase = 'Phase 1 — Foundation';

  static const List<String> modelTiers = [
    'vail-lite',
    'vail',
    'vail-pro',
    'vail-max',
  ];

  static const String defaultModel = 'vail-lite';

  /// Maximum messages to hold in memory per session before trimming display history.
  static const int maxDisplayMessages = 100;

  /// Human-readable display name for each model tier — shown in Settings and the chat header.
  static String modelDisplayName(String tier) => switch (tier) {
        'vail-lite' => 'VAIL.LITE',
        'vail' => 'VAIL.CORE',
        'vail-pro' => 'VAIL.PRO',
        'vail-max' => 'VAIL.MAX',
        _ => tier.toUpperCase(),
      };

  /// One-line capability description shown on the upgrade prompt.
  static String modelDescription(String tier) => switch (tier) {
        'vail-lite' => 'Fast, everyday tasks — always free.',
        'vail' => 'Balanced reasoning and extended context.',
        'vail-pro' => 'Advanced reasoning, longer context, priority routing.',
        'vail-max' => 'Maximum capability — complex, multi-step tasks.',
        _ => 'Vail model tier.',
      };

  /// Whether a tier requires a paid plan to activate.
  static bool isPremiumTier(String tier) =>
      tier == 'vail-pro' || tier == 'vail-max';

  /// Whether a tier is not yet available — shown as "coming soon" in pickers.
  static bool isComingSoonTier(String tier) => tier == 'vail-max';
}
