/// Este archivo sirve como sustituto de dart:html para plataformas móviles.
/// Proporciona implementaciones ficticias de clases web-only para que el código
/// compile en Android/iOS/desktop sin errores.
library;

import 'dart:async';
import 'dart:typed_data';

// ─── window / localStorage ───────────────────────────────────────────────────

class Window {
  final LocalStorage localStorage = LocalStorage();
  // ignore: avoid_unused_constructor_parameters
  void open(String url, String name, [String? options]) {}
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

// ─── BroadcastChannel ────────────────────────────────────────────────────────

class BroadcastChannel {
  // ignore: avoid_unused_constructor_parameters
  BroadcastChannel(String name);
  Stream<dynamic> get onMessage => const Stream.empty();
  void postMessage(dynamic message) {}
  void close() {}
}

// ─── FileUploadInputElement / File / FileList ─────────────────────────────────

class File {
  final String name;
  File(this.name);
}

class FileList {
  final List<File> _files;
  FileList([List<File>? files]) : _files = files ?? const [];
  bool get isEmpty => _files.isEmpty;
  File operator [](int index) => _files[index];
}

class FileUploadInputElement {
  String accept = '';
  FileList? files;
  Stream<dynamic> get onChange => const Stream.empty();
  void click() {}
}

// ─── FileReader ───────────────────────────────────────────────────────────────

class FileReader {
  dynamic result;
  Stream<dynamic> get onLoad => const Stream.empty();
  // ignore: avoid_unused_constructor_parameters
  void readAsArrayBuffer(File file) {}
}

// ─── Blob / Url / AnchorElement / Document ────────────────────────────────────

class Blob {
  // ignore: avoid_unused_constructor_parameters
  Blob(List<dynamic> parts, [dynamic options]);
}

class Url {
  // ignore: avoid_unused_constructor_parameters
  static String createObjectUrlFromBlob(Blob blob) => '';
  // ignore: avoid_unused_constructor_parameters
  static void revokeObjectUrl(String url) {}
}

class CssStyleDeclaration {
  String display = '';
}

class AnchorElement {
  String? href;
  String? download;
  final CssStyleDeclaration style = CssStyleDeclaration();
  AnchorElement({this.href});
  // ignore: avoid_unused_constructor_parameters
  void setAttribute(String name, String value) {}
  void click() {}
  void remove() {}
}

class _ElementList {
  // ignore: avoid_unused_constructor_parameters
  void add(AnchorElement element) {}
}

class _Body {
  final _ElementList children = _ElementList();
}

class Document {
  final _Body? body = _Body();
  
  // ignore: avoid_unused_constructor_parameters
  dynamic createElement(String tag) {
    if (tag == 'a') return AnchorElement();
    return null;
  }
}

final Document document = Document();
