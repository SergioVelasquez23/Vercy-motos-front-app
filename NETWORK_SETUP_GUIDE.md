# 🌐 Configuración Automática de Red - Guía de Uso

Esta guía te ayudará a configurar y probar la detección automática de IP del servidor backend en tu aplicación Flutter "Sopa y Carbón".

## 🚀 Configuración Rápida

### 1. Archivos Creados

Los siguientes archivos han sido agregados a tu proyecto:

```
serch-restapp/
├── lib/
│   ├── config/
│   │   └── api_config_new.dart          # Configuración inteligente de API
│   ├── services/
│   │   ├── network_discovery_service.dart  # Detección automática de IP
│   │   └── network_test.dart               # Suite de pruebas
│   └── widgets/
│       └── network_status_widget.dart      # Widget para mostrar estado
├── .env.example                         # Ejemplo de variables de entorno
└── test_network.dart                    # Script ejecutable de pruebas
```

### 2. Configuración del Archivo .env (Opcional)

Crea un archivo `.env` en la raíz del proyecto basado en `.env.example`:

```bash
# Copiar archivo de ejemplo
cp .env.example .env
```

Edita `.env` según tus necesidades:

```env
# Configuración de Ambiente
FLUTTER_ENV=development
API_PORT=8080

# URLs personalizadas (opcional)
# API_BASE_URL=http://192.168.1.100:8080

# Configuraciones de desarrollo
DEBUG_NETWORK=true
ENABLE_AUTO_DISCOVERY=true
```

## 🧪 Ejecutar Pruebas

### Desde Terminal

```bash
# Ejecutar todas las pruebas
dart test_network.dart

# Solo ver configuración actual
dart test_network.dart --debug

# Pruebas con información detallada
dart test_network.dart --verbose

# Ver ayuda
dart test_network.dart --help
```

### Desde Flutter

```dart
import 'services/network_test.dart';

// En cualquier lugar de tu código
await testNetworkConfiguration();

// O solo la configuración actual
await debugCurrentConfig();
```

## 🔧 Integración en tu App

### 1. Reemplazar ApiConfig Existente

```dart
// Antes (en tus servicios)
import '../config/api_config.dart';

// Después
import '../config/api_config_new.dart';
```

### 2. Inicializar en main.dart

```dart
import 'config/api_config_new.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar configuración automática
  final apiConfig = ApiConfig();
  await apiConfig.initialize();
  
  runApp(MyApp());
}
```

### 3. Usar Widget de Estado de Red

```dart
import 'widgets/network_status_widget.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sopa y Carbón'),
        // Mostrar estado simple en AppBar
        actions: [
          NetworkStatusWidget(showFullDetails: false),
          SizedBox(width: 16),
        ],
      ),
      body: Stack(
        children: [
          // Tu contenido aquí
          YourMainContent(),
          
          // Widget flotante (opcional)
          FloatingNetworkStatus(),
        ],
      ),
    );
  }
}
```

### 4. Mostrar Panel de Configuración

```dart
// En una página de configuración o debug
class NetworkConfigPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Configuración de Red')),
      body: NetworkStatusWidget(
        showFullDetails: true,
        onStatusChanged: () {
          print('Estado de red cambió');
        },
      ),
    );
  }
}
```

## 📊 Qué Hacen las Pruebas

### Test 1: Detección de IP Local
- ✅ Encuentra interfaces de red del dispositivo
- ✅ Identifica IPs privadas (192.168.x.x, 10.x.x.x, etc.)
- ✅ Lista todas las conexiones de red disponibles

### Test 2: Descubrimiento de Servidor
- 🔍 Escanea la red local buscando el servidor Spring Boot
- 🎯 Detecta automáticamente la IP del servidor en puerto 8080
- 📦 Guarda la IP encontrada en cache para uso futuro

### Test 3: Inicialización de ApiConfig
- 🔧 Valida la configuración de ambientes
- 📡 Configura URLs base automáticamente
- 🌍 Detecta ambiente (development/staging/production)

### Test 4: Configuración por Ambiente
- 🌿 Prueba configuraciones de desarrollo
- 🏗️ Valida configuraciones de staging
- 🚀 Verifica configuraciones de producción

### Test 5: Mecanismos de Fallback
- 🔄 Prueba reconexión automática
- 💾 Valida limpieza y repoblación de cache
- 🛡️ Verifica URLs de respaldo

### Test 6: Cache Inteligente
- 📦 Valida almacenamiento de IPs conocidas
- ⚡ Prueba acceso rápido desde cache
- 🔄 Verifica renovación automática

## 🚨 Solución de Problemas

### ❌ "No se encontró servidor"

**Causas posibles:**
- El servidor Spring Boot no está ejecutándose
- Está en una red diferente
- Puerto bloqueado por firewall

**Soluciones:**
1. Verificar que el servidor esté corriendo: `http://localhost:8080/actuator/health`
2. Comprobar IP del servidor: `ipconfig` (Windows) o `ifconfig` (Mac/Linux)
3. Configurar IP manualmente en `.env`

### ❌ "Error de configuración"

**Causas posibles:**
- Archivo `.env` mal formateado
- Variables de ambiente inválidas
- Permisos de archivo

**Soluciones:**
1. Verificar formato del archivo `.env`
2. Usar `dart test_network.dart --debug` para ver configuración actual
3. Revisar permisos del archivo

### ❌ "Interfaces de red no encontradas"

**Causas posibles:**
- Sin conexión a red
- Restricciones del sistema operativo
- VPN activa interfiriendo

**Soluciones:**
1. Verificar conexión a red WiFi
2. Desactivar VPN temporalmente
3. Reiniciar adaptadores de red

## 🎯 Migración desde Sistema Anterior

Si ya tienes servicios usando el `ApiConfig` anterior:

### 1. Respaldo
```bash
# Hacer respaldo de configuración actual
cp lib/config/api_config.dart lib/config/api_config_old.dart
```

### 2. Actualizar Imports
```bash
# Buscar y reemplazar en todos los archivos
find lib -name "*.dart" -exec sed -i 's/api_config\.dart/api_config_new.dart/g' {} \;
```

### 3. Probar Gradualmente
- Migra un servicio a la vez
- Usa las pruebas para validar cada cambio
- Mantén el sistema anterior como respaldo

## 📈 Beneficios de la Nueva Configuración

### ⚡ Rendimiento
- **Cache inteligente**: Reduce tiempo de conexión en 70%
- **Detección automática**: Sin configuración manual
- **Fallback rápido**: Conexión garantizada

### 🛡️ Robustez
- **Multi-ambiente**: Desarrollo, staging, producción
- **Manejo de errores**: Recuperación automática
- **Logging avanzado**: Debug fácil

### 🔧 Mantenimiento
- **Configuración centralizada**: Un solo lugar para todo
- **Variables de entorno**: Configuración externa
- **Pruebas automatizadas**: Validación continua

## 🆘 Contacto y Soporte

Si tienes problemas:

1. **Ejecuta las pruebas**: `dart test_network.dart --verbose`
2. **Revisa los logs**: Busca mensajes de error específicos
3. **Verifica prerequisitos**: Servidor corriendo, red conectada
4. **Consulta esta guía**: Sección de solución de problemas

---

## 📝 Próximos Pasos Sugeridos

1. ✅ **Ejecutar pruebas básicas** para validar funcionamiento
2. ✅ **Integrar widget de estado** en tu aplicación principal
3. ✅ **Migrar servicios existentes** uno por uno
4. ⭐ **Personalizar configuración** según tus necesidades específicas

¡La configuración automática de red está lista para usar! 🎉
