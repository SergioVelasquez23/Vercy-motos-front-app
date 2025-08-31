import '../models/negocio_info.dart';
import '../services/negocio_info_service.dart';

class NegocioInfoCache {
  static NegocioInfo? _info;
  static Future<NegocioInfo?> getNegocioInfo() async {
    if (_info != null) return _info;
    final service = NegocioInfoService();
    _info = await service.getNegocioInfo();
    return _info;
  }
  static void clear() => _info = null;
}
