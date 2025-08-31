import 'package:flutter/material.dart';
import '../services/network_discovery_service.dart';
import '../config/api_config_new.dart';

/// Widget que muestra el estado actual de la conexión de red
/// y permite reconectar manualmente
class NetworkStatusWidget extends StatefulWidget {
  final bool showFullDetails;
  final VoidCallback? onStatusChanged;
  
  const NetworkStatusWidget({
    Key? key,
    this.showFullDetails = false,
    this.onStatusChanged,
  }) : super(key: key);

  @override
  _NetworkStatusWidgetState createState() => _NetworkStatusWidgetState();
}

class _NetworkStatusWidgetState extends State<NetworkStatusWidget> 
    with SingleTickerProviderStateMixin {
  
  final _networkService = NetworkDiscoveryService();
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  
  String? _currentServerIp;
  String? _baseUrl;
  String? _environment;
  bool _isConnected = false;
  bool _isSearching = false;
  String _statusMessage = 'Verificando conexión...';
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_animationController);
    
    _checkNetworkStatus();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  /// Verificar el estado actual de la red
  Future<void> _checkNetworkStatus() async {
    setState(() {
      _isSearching = true;
      _statusMessage = 'Verificando conexión...';
    });
    
    try {
      // Inicializar ApiConfig
      final apiConfig = ApiConfig();
      await apiConfig.initialize();
      
      // Obtener información de configuración
      _environment = apiConfig.environmentName;
      _baseUrl = apiConfig.baseUrl;
      
      // Verificar si hay una IP del servidor conocida
      _currentServerIp = _networkService.lastKnownServerIp;
      
      if (_currentServerIp != null) {
        _isConnected = true;
        _statusMessage = 'Conectado al servidor';
      } else {
        _isConnected = false;
        _statusMessage = 'No hay servidor conocido';
      }
      
    } catch (e) {
      _isConnected = false;
      _statusMessage = 'Error de configuración: ${e.toString()}';
    }
    
    setState(() {
      _isSearching = false;
    });
    
    // Notificar cambio de estado
    widget.onStatusChanged?.call();
  }
  
  /// Buscar servidor manualmente
  Future<void> _searchForServer() async {
    setState(() {
      _isSearching = true;
      _statusMessage = 'Buscando servidor...';
    });
    
    _animationController.repeat();
    
    try {
      // Limpiar cache y buscar de nuevo
      _networkService.clearCache();
      final serverIp = await _networkService.discoverServerIp();
      
      if (serverIp != null) {
        _currentServerIp = serverIp;
        _isConnected = true;
        _statusMessage = 'Servidor encontrado!';
        
        // Actualizar base URL
        final baseUrl = await _networkService.getServerBaseUrl();
        if (baseUrl != null) {
          _baseUrl = baseUrl;
        }
        
        // Mostrar feedback positivo
        _showSnackBar('✅ Servidor encontrado en $serverIp', Colors.green);
        
      } else {
        _isConnected = false;
        _statusMessage = 'No se encontró servidor';
        _showSnackBar('❌ No se encontró ningún servidor', Colors.orange);
      }
      
    } catch (e) {
      _isConnected = false;
      _statusMessage = 'Error en búsqueda: ${e.toString()}';
      _showSnackBar('❌ Error: ${e.toString()}', Colors.red);
    }
    
    _animationController.stop();
    _animationController.reset();
    
    setState(() {
      _isSearching = false;
    });
    
    // Notificar cambio de estado
    widget.onStatusChanged?.call();
  }
  
  /// Mostrar mensaje en SnackBar
  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
  
  /// Construir indicador de estado simple
  Widget _buildSimpleStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _isConnected ? Colors.green.shade100 : Colors.orange.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isConnected ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _isSearching
              ? SizedBox(
                  width: 12,
                  height: 12,
                  child: AnimatedBuilder(
                    animation: _rotationAnimation,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _rotationAnimation.value * 2.0 * 3.14159,
                        child: Icon(
                          Icons.sync,
                          size: 12,
                          color: Colors.blue.shade600,
                        ),
                      );
                    },
                  ),
                )
              : Icon(
                  _isConnected ? Icons.wifi : Icons.wifi_off,
                  size: 12,
                  color: _isConnected ? Colors.green.shade600 : Colors.orange.shade600,
                ),
          const SizedBox(width: 4),
          Text(
            _isConnected ? 'Online' : 'Buscando...',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: _isConnected ? Colors.green.shade700 : Colors.orange.shade700,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Construir panel de detalles completo
  Widget _buildDetailedStatus() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con estado
            Row(
              children: [
                _isSearching
                    ? AnimatedBuilder(
                        animation: _rotationAnimation,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _rotationAnimation.value * 2.0 * 3.14159,
                            child: Icon(
                              Icons.sync,
                              color: Colors.blue.shade600,
                            ),
                          );
                        },
                      )
                    : Icon(
                        _isConnected ? Icons.cloud_done : Icons.cloud_off,
                        color: _isConnected ? Colors.green : Colors.orange,
                        size: 28,
                      ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estado de Conexión',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _statusMessage,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _isConnected ? Colors.green.shade700 : Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            const Divider(),
            
            // Detalles de configuración
            _buildInfoRow('Ambiente', _environment ?? 'No configurado'),
            _buildInfoRow('Servidor IP', _currentServerIp ?? 'No detectado'),
            _buildInfoRow('URL Base', _baseUrl ?? 'No disponible'),
            _buildInfoRow('Cache', _networkService.hasValidCache ? 'Válido' : 'No válido'),
            
            const SizedBox(height: 16),
            
            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSearching ? null : _searchForServer,
                    icon: const Icon(Icons.search, size: 18),
                    label: Text(_isSearching ? 'Buscando...' : 'Buscar Servidor'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isSearching ? null : _checkNetworkStatus,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Actualizar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  /// Construir fila de información
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return widget.showFullDetails 
        ? _buildDetailedStatus() 
        : _buildSimpleStatus();
  }
}

/// Widget flotante que se puede usar en cualquier pantalla
class FloatingNetworkStatus extends StatefulWidget {
  const FloatingNetworkStatus({Key? key}) : super(key: key);

  @override
  _FloatingNetworkStatusState createState() => _FloatingNetworkStatusState();
}

class _FloatingNetworkStatusState extends State<FloatingNetworkStatus> {
  bool _showDetails = false;
  
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      right: 10,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _showDetails = !_showDetails;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: _showDetails ? 300 : null,
          child: NetworkStatusWidget(
            showFullDetails: _showDetails,
            onStatusChanged: () {
              // Opcional: hacer algo cuando cambie el estado
            },
          ),
        ),
      ),
    );
  }
}
