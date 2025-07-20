import '../models/mesa.dart';
import '../services/mesa_service.dart';

class MesaController {
  final MesaService _service = MesaService();
  List<Mesa> _mesas = [];

  List<Mesa> get mesas => _mesas;

  Future<List<Mesa>> getMesas() async {
    try {
      print('🎯 MesaController: Obteniendo mesas...');
      _mesas = await _service.getMesas();
      print('🎯 MesaController: ${_mesas.length} mesas obtenidas');
      _mesas.forEach((mesa) {
        print('🎯 Mesa cargada - ID: ${mesa.id}, Nombre: ${mesa.nombre}');
      });
      return _mesas;
    } catch (e) {
      print('❌ Error en MesaController.getMesas: $e');
      throw Exception('Error al obtener mesas: $e');
    }
  }

  Future<Mesa> crearMesa(String nombre) async {
    try {
      print('🎯 MesaController: Creando mesa con nombre: $nombre');
      final mesa = Mesa(
        id: '', // El ID será asignado por el backend
        nombre: nombre,
        ocupada: false,
        productos: [],
        total: 0.0,
      );
      final mesaCreada = await _service.createMesa(mesa);
      print('🎯 MesaController: Mesa creada con ID: ${mesaCreada.id}');
      return mesaCreada;
    } catch (e) {
      print('❌ Error en MesaController.crearMesa: $e');
      throw Exception('Error al crear mesa: $e');
    }
  }

  Future<Mesa> actualizarMesa(Mesa mesa, String nuevoNombre) async {
    try {
      print(
        '🎯 MesaController: Actualizando mesa - ID: ${mesa.id}, Nuevo nombre: $nuevoNombre',
      );
      if (mesa.id.isEmpty) {
        throw Exception('No se puede actualizar una mesa sin ID');
      }

      // Crear una nueva instancia de Mesa con el nombre actualizado
      final mesaActualizar = mesa.copyWith(nombre: nuevoNombre);
      final mesaActualizada = await _service.updateMesa(mesaActualizar);

      print(
        '🎯 MesaController: Mesa actualizada - ID: ${mesaActualizada.id}, Nombre: ${mesaActualizada.nombre}',
      );
      return mesaActualizada;
    } catch (e) {
      print('❌ Error en MesaController.actualizarMesa: $e');
      throw Exception('Error al actualizar mesa: $e');
    }
  }

  Future<void> eliminarMesa(String id) async {
    try {
      print('🎯 MesaController: Eliminando mesa con ID: $id');
      if (id.isEmpty) {
        throw Exception('No se puede eliminar una mesa sin ID');
      }
      await _service.deleteMesa(id);
      print('🎯 MesaController: Mesa eliminada correctamente - ID: $id');
    } catch (e) {
      print('❌ Error en MesaController.eliminarMesa: $e');
      throw Exception('Error al eliminar mesa: $e');
    }
  }

  Future<void> vaciarMesa(String id) async {
    try {
      final mesa = await _service.getMesaById(id);
      // Crear una nueva instancia de Mesa con los valores reseteados
      final mesaVacia = mesa.copyWith(
        productos: [],
        total: 0.0,
        ocupada: false,
      );
      await _service.updateMesa(mesaVacia);
    } catch (e) {
      print('❌ Error en MesaController.vaciarMesa: $e');
      throw Exception('Error al vaciar mesa: $e');
    }
  }

  Future<void> moverMesa(Mesa origen, Mesa destino) async {
    try {
      // Verificar que la mesa destino no esté ocupada
      if (destino.ocupada) {
        throw Exception('La mesa destino está ocupada');
      }

      // Crear nueva instancia de la mesa destino con los datos actualizados
      final mesaDestinoActualizada = destino.copyWith(
        productos: List.from(origen.productos),
        total: origen.total,
        ocupada: true,
        pedidoActual: origen.pedidoActual,
      );

      // Actualizar mesa destino
      await _service.updateMesa(mesaDestinoActualizada);

      // Vaciar mesa origen
      await vaciarMesa(origen.id);
    } catch (e) {
      print('❌ Error en MesaController.moverMesa: $e');
      throw Exception('Error al mover mesa: $e');
    }
  }
}
