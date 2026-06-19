import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/cliente.dart';
import '../models/cotizacion.dart';
import '../models/factura_compra.dart';
import '../models/pedido_asesor.dart';
import '../widgets/app_shell.dart';
import '../screens/detalle_factura_compra_screen.dart';

import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/dashboard_screen_v2.dart';
import '../screens/facturacion_screen.dart';
import '../screens/facturas_list_screen.dart';
import '../screens/crear_factura_compra_screen.dart';
import '../screens/clientes_list_screen.dart';
import '../screens/cliente_form_screen.dart';
import '../screens/cotizaciones_list_screen.dart';
import '../screens/cotizacion_form_screen.dart';
import '../screens/cuadre_caja_screen.dart';
import '../screens/abrir_caja_screen.dart';
import '../screens/cerrar_caja_screen.dart';
import '../screens/reportes_screen.dart';
import '../screens/informes_productos_screen.dart';
import '../screens/pedidos_screen_fusion.dart';
import '../screens/gastos_screen.dart';
import '../screens/tipos_gasto_screen.dart';
import '../screens/ingresos_caja_screen.dart';
import '../screens/traslados_screen.dart';
import '../screens/bodegas_screen.dart';
import '../screens/asesor_pedidos_screen.dart';
import '../screens/admin_pedidos_asesor_screen.dart';
import '../screens/proveedores_list_screen.dart';
import '../screens/compras_list_screen.dart';
import '../screens/gastos_list_screen.dart';
import '../screens/productos_list_screen.dart';
import '../screens/productos_screen.dart';
import '../screens/cartera_screen.dart';
import '../screens/deudas_list_screen.dart';
import '../screens/cuentas_por_cobrar_screen.dart';
import '../screens/cuentas_por_pagar_screen.dart';
import '../screens/gastos_programados_screen.dart';
import '../screens/alertas_screen.dart';
import '../screens/autorizaciones_screen.dart';
import '../screens/eliminar_pedidos_screen.dart';
import '../screens/fe_documentos_screen.dart';
import '../screens/documentos_pendientes_screen.dart';
import '../screens/matias_test_screen.dart';
import '../screens/configuracion_screen.dart';

/// GoRouter configurado con un ShellRoute que mantiene la sidebar y topbar
/// persistentes mientras se navega entre pantallas.
///
/// Las rutas fuera del shell (login) no muestran sidebar.
final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/dashboard', builder: (c, s) => const DashboardScreenV2()),
        GoRoute(
          path: '/facturar',
          builder: (c, s) => FacturacionScreen(pedidoAsesor: s.extra as PedidoAsesor?),
        ),
        GoRoute(path: '/asesor-pedidos', builder: (c, s) => const AsesorPedidosScreen()),
        GoRoute(path: '/admin-pedidos-asesor', builder: (c, s) => const AdminPedidosAsesorScreen()),
        GoRoute(path: '/clientes', builder: (c, s) => ClientesListScreen()),
        GoRoute(
          path: '/clientes/form',
          builder: (c, s) => ClienteFormScreen(cliente: s.extra as Cliente?),
        ),
        GoRoute(path: '/cotizaciones', builder: (c, s) => CotizacionesListScreen()),
        GoRoute(
          path: '/cotizaciones/form',
          builder: (c, s) => CotizacionFormScreen(cotizacion: s.extra as Cotizacion?),
        ),
        GoRoute(path: '/productos-lista', builder: (c, s) => const ProductosListScreen()),
        GoRoute(path: '/productos', builder: (c, s) => ProductosScreen()),
        GoRoute(path: '/traslados', builder: (c, s) => const TrasladosScreen()),
        GoRoute(path: '/bodegas', builder: (c, s) => const BodegasScreen()),
        GoRoute(path: '/cuadre_caja', builder: (c, s) => CuadreCajaScreen()),
        GoRoute(path: '/abrir_caja', builder: (c, s) => AbrirCajaScreen()),
        GoRoute(path: '/cerrar_caja', builder: (c, s) => const CerrarCajaScreen()),
        GoRoute(path: '/compras', builder: (c, s) => const ComprasListScreen()),
        GoRoute(
          path: '/facturas-compras',
          builder: (c, s) => CrearFacturaCompraScreen(facturaParaEditar: s.extra as FacturaCompra?),
        ),
        GoRoute(
          path: '/facturas-compras/detalle',
          builder: (c, s) => DetalleFacturaCompraScreen(factura: s.extra as FacturaCompra),
        ),
        GoRoute(path: '/gastos', builder: (c, s) => GastosScreen(mostrarFormulario: true)),
        GoRoute(path: '/tipos-gasto', builder: (c, s) => const TiposGastoScreen()),
        GoRoute(path: '/gastos-lista', builder: (c, s) => const GastosListScreen()),
        GoRoute(path: '/proveedores', builder: (c, s) => const ProveedoresListScreen()),
        GoRoute(path: '/cartera', builder: (c, s) => const CarteraScreen()),
        GoRoute(path: '/deudas', builder: (c, s) => const DeudasListScreen()),
        GoRoute(path: '/cuentas-por-cobrar', builder: (c, s) => const CuentasPorCobrarScreen()),
        GoRoute(path: '/cuentas-por-pagar', builder: (c, s) => const CuentasPorPagarScreen()),
        GoRoute(path: '/gastos-programados', builder: (c, s) => const GastosProgramadosScreen()),
        GoRoute(path: '/alertas', builder: (c, s) => const AlertasScreen()),
        GoRoute(path: '/autorizaciones', builder: (c, s) => const AutorizacionesScreen()),
        GoRoute(path: '/ingresos-caja', builder: (c, s) => IngresosCajaScreen()),
        GoRoute(path: '/pedidos', builder: (c, s) => const PedidosScreenFusion()),
        GoRoute(path: '/pedidos_rt', builder: (c, s) => const PedidosScreenFusion()),
        GoRoute(path: '/pedidos_cancelados', builder: (c, s) => const PedidosScreenFusion()),
        GoRoute(path: '/pedidos_cortesia', builder: (c, s) => const PedidosScreenFusion()),
        GoRoute(path: '/pedidos_internos', builder: (c, s) => const PedidosScreenFusion()),
        GoRoute(
          path: '/facturas-lista',
          builder: (c, s) => FacturasListScreen(filtroInicial: s.extra as String?),
        ),
        GoRoute(
          path: '/facturas',
          builder: (c, s) => FacturasListScreen(filtroInicial: s.extra as String?),
        ),
        GoRoute(path: '/eliminar-pedidos', builder: (c, s) => const EliminarPedidosScreen()),
        GoRoute(path: '/reportes', builder: (c, s) => const ReportesScreen()),
        GoRoute(path: '/reportes/ventas', builder: (c, s) => const ReportesScreen(initialReportIndex: 1)),
        GoRoute(path: '/reportes/productos', builder: (c, s) => const ReportesScreen(initialReportIndex: 2)),
        GoRoute(path: '/reportes/pedidos', builder: (c, s) => const ReportesScreen(initialReportIndex: 3)),
        GoRoute(path: '/reportes/clientes', builder: (c, s) => const ReportesScreen(initialReportIndex: 4)),
        GoRoute(path: '/informes/productos', builder: (c, s) => const InformesProductosScreen()),
        GoRoute(path: '/facturacion-electronica', builder: (c, s) => const FEDocumentosScreen()),
        GoRoute(path: '/documentos-pendientes', builder: (c, s) => const DocumentosPendientesScreen()),
        GoRoute(path: '/matias-test', builder: (c, s) => const MatiasTestScreen()),
        GoRoute(path: '/configuracion', builder: (c, s) => const ConfiguracionScreen()),
      ],
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64),
          const SizedBox(height: 16),
          Text('Ruta no encontrada: ${state.uri}'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go('/dashboard'),
            child: const Text('Volver al dashboard'),
          ),
        ],
      ),
    ),
  ),
);
