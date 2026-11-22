/// Build-time configuration from `--dart-define-from-file=config/<flavor>.json`.
/// No URLs or keys are hard-coded anywhere else (STANDARDS §6).
class Env {
  const Env({required this.flavor, required this.apiBaseUrl});

  factory Env.fromDefines() => const Env(
    flavor: String.fromEnvironment('FLAVOR', defaultValue: 'local'),
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:8000',
    ),
  );

  final String flavor;
  final String apiBaseUrl;

  bool get isLocal => flavor == 'local';
}
