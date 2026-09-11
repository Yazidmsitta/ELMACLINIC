/// A transport-independent error exposed by repository implementations.
class AppFailure implements Exception {
  const AppFailure(this.message);
  final String message;
}

String friendlyError(Object error) => error is AppFailure
    ? error.message
    : 'Une erreur est survenue. Veuillez réessayer.';
