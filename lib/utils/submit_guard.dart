/// Mixin que protege funciones de submit contra doble-clic / doble-envío.
///
/// El flag [_guardLock] es sincrónico (no depende de setState ni de un rebuild),
/// por lo que se establece en el mismo frame de evento que el primer click y
/// descarta cualquier llamada simultánea antes de que el siguiente frame se pinte.
///
/// Uso:
///   class _MyFormState extends State<MyForm> with SubmitGuard { ... }
///
///   onPressed: _isLoading ? null : () => runGuarded(_guardar),
mixin SubmitGuard {
  bool _guardLock = false;

  /// True mientras haya una operación de submit en curso.
  bool get submitInProgress => _guardLock;

  /// Ejecuta [action] una única vez a la vez.
  /// Llamadas concurrentes mientras [action] corre son descartadas silenciosamente.
  Future<void> runGuarded(Future<void> Function() action) async {
    if (_guardLock) return;
    _guardLock = true;
    try {
      await action();
    } finally {
      _guardLock = false;
    }
  }
}
