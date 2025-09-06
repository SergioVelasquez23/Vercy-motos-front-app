/// Este archivo sirve como sustituto de dart:html para plataformas móviles
/// Proporciona una implementación ficticia de window.localStorage
///
/// Este archivo se usa cuando se compila para plataformas que no son web
library;

class Window {
  final LocalStorage localStorage = LocalStorage();
}

class LocalStorage {
  final Map<String, String> _storage = {};

  String? operator [](String key) => _storage[key];

  void operator []=(String key, String value) {
    _storage[key] = value;
  }

  void remove(String key) {
    _storage.remove(key);
  }
}

final Window window = Window();
