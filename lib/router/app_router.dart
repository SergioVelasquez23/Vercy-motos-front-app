import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../providers/user_provider.dart';
import '../models/cliente.dart';
import '../models/cotizacion.dart';
import '../models/factura_compra.dart';
import '../models/pedido_asesor.dart';
import '../widgets/app_shell.dart';
import 'deferred_screen.dart';
import '../screens/detalle_factura_compra_screen.dart' deferred as detalle_factura_compra;

import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/dashboard_screen_v2.dart' deferred as dashboard_screen_v2;
import '../screens/facturacion_screen.dart' deferred as facturacion;
import '../screens/facturas_list_screen.dart' deferred as facturas_list;
import '../screens/crear_factura_compra_screen.dart' deferred as crear_factura_compra;
import '../screens/clientes_list_screen.dart' deferred as clientes_list;
import '../screens/cliente_form_screen.dart' deferred as cliente_form;
import '../screens/cotizaciones_list_screen.dart' deferred as cotizaciones_list;
import '../screens/cotizacion_form_screen.dart' deferred as cotizacion_form;
import '../screens/cuadre_caja_screen.dart' deferred as cuadre_caja;
import '../screens/abrir_caja_screen.dart' deferred as abrir_caja;
import '../screens/cerrar_caja_screen.dart' deferred as cerrar_caja;
import '../screens/reportes_screen.dart' deferred as reportes;
import '../screens/informes_productos_screen.dart' deferred as informes_productos;
import '../screens/pedidos_screen_fusion.dart' deferred as pedidos_screen;
import '../screens/gastos_screen.dart' deferred as gastos;
import '../screens/tipos_gasto_screen.dart' deferred as tipos_gasto;
import '../screens/ingresos_caja_screen.dart' deferred as ingresos_caja;
import '../screens/traslados_screen.dart' deferred as traslados;
import '../screens/bodegas_screen.dart' deferred as bodegas;
import '../screens/asesor_pedidos_screen.dart' deferred as asesor_pedidos;
import '../screens/admin_pedidos_asesor_screen.dart' deferred as admin_pedidos_asesor;
import '../screens/proveedores_list_screen.dart' deferred as proveedores_list;
import '../screens/compras_list_screen.dart' deferred as compras_list;
import '../screens/importar_factura_compra_pdf_screen.dart' deferred as importar_factura_compra_pdf;
import '../screens/gastos_list_screen.dart' deferred as gastos_list;
import '../screens/productos_list_screen.dart' deferred as productos_list;
import '../screens/productos_screen.dart' deferred as productos;
import '../screens/editar_stock_simple_screen.dart' deferred as editar_stock_simple;
import '../screens/cartera_screen.dart' deferred as cartera;
import '../screens/deudas_list_screen.dart' deferred as deudas_list;
import '../screens/cuentas_por_cobrar_screen.dart' deferred as cuentas_por_cobrar;
import '../screens/cuentas_por_pagar_screen.dart' deferred as cuentas_por_pagar;
import '../screens/gastos_programados_screen.dart' deferred as gastos_programados;
import '../screens/alertas_screen.dart' deferred as alertas;
import '../screens/eliminar_pedidos_screen.dart' deferred as eliminar_pedidos;
import '../screens/fe_documentos_screen.dart' deferred as fe_documentos;
import '../screens/documentos_pendientes_screen.dart' deferred as documentos_pendientes;
import '../screens/matias_test_screen.dart' deferred as matias_test;
import '../screens/configuracion_screen.dart' deferred as configuracion;
import '../screens/libro_contable_screen.dart' deferred as libro_contable;
import '../screens/legal_screen.dart' deferred as legal;

// Pantalla de edición de stock simplificada (ver editar_stock_simple_screen.dart):
// solo para este correo. Duplicado a propósito en app_shell.dart (mismo criterio
// que usa notificaciones_provider.dart para su whitelist de traslados) en vez de
// una constante compartida — es un único valor usado en dos lugares, no vale la
// pena el archivo extra.
const _emailEditarStockAutorizado = 'francia@gmail.com';

GoRouter buildAppRouter(UserProvider userProvider) => GoRouter(
  initialLocation: '/splash',
  refreshListenable: userProvider,
  redirect: (context, state) {
    final path = state.uri.path;
    final isPublic = path == '/login' || path == '/splash';
    if (!userProvider.isAuthenticated && !isPublic) return '/login';

    // Los asesores no pueden acceder a facturación ni a la lista de admin
    if (userProvider.isAuthenticated && userProvider.isAsesor) {
      const rutasBloqueasAsesor = ['/facturar', '/admin-pedidos-asesor'];
      if (rutasBloqueasAsesor.contains(path)) return '/asesor-pedidos';
    }

    // Ruta de un solo usuario: bloquear por URL directa además de solo
    // ocultar el ítem del menú (ver app_shell.dart).
    if (userProvider.isAuthenticated &&
        path == '/editar-stock' &&
        userProvider.userEmail?.trim().toLowerCase() != _emailEditarStockAutorizado) {
      return '/dashboard';
    }

    return null;
  },
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
        GoRoute(path: '/dashboard', builder: (c, s) => DeferredScreen(loader: dashboard_screen_v2.loadLibrary, builder: () => dashboard_screen_v2.DashboardScreenV2())),
        GoRoute(
          path: '/facturar',
          builder: (c, s) => DeferredScreen(loader: facturacion.loadLibrary, builder: () {
            final extra = s.extra;
            if (extra is Map<String, dynamic>) {
              return facturacion.FacturacionScreen(
                pedidoAsesor: extra['pedidoAsesor'] as PedidoAsesor?,
                trasladoId: extra['trasladoId'] as String?,
                cotizacion: extra['cotizacion'] as Cotizacion?,
              );
            }
            if (extra is Cotizacion) {
              return facturacion.FacturacionScreen(cotizacion: extra);
            }
            return facturacion.FacturacionScreen(pedidoAsesor: extra as PedidoAsesor?);
          }),
        ),
        GoRoute(
          path: '/facturar-envios',
          builder: (c, s) => DeferredScreen(loader: facturacion.loadLibrary, builder: () {
            final extra = s.extra;
            if (extra is Map<String, dynamic>) {
              return facturacion.FacturacionScreen(
                pedidoAsesor: extra['pedidoAsesor'] as PedidoAsesor?,
                trasladoId: extra['trasladoId'] as String?,
                cotizacion: extra['cotizacion'] as Cotizacion?,
                tipoCaja: 'ENVIOS',
              );
            }
            if (extra is Cotizacion) {
              return facturacion.FacturacionScreen(cotizacion: extra, tipoCaja: 'ENVIOS');
            }
            return facturacion.FacturacionScreen(pedidoAsesor: extra as PedidoAsesor?, tipoCaja: 'ENVIOS');
          }),
        ),
        GoRoute(path: '/asesor-pedidos', builder: (c, s) => DeferredScreen(loader: asesor_pedidos.loadLibrary, builder: () => asesor_pedidos.AsesorPedidosScreen())),
        GoRoute(path: '/admin-pedidos-asesor', builder: (c, s) => DeferredScreen(loader: admin_pedidos_asesor.loadLibrary, builder: () => admin_pedidos_asesor.AdminPedidosAsesorScreen())),
        GoRoute(path: '/clientes', builder: (c, s) => DeferredScreen(loader: clientes_list.loadLibrary, builder: () => clientes_list.ClientesListScreen())),
        GoRoute(
          path: '/clientes/form',
          builder: (c, s) => DeferredScreen(loader: cliente_form.loadLibrary, builder: () => cliente_form.ClienteFormScreen(cliente: s.extra as Cliente?)),
        ),
        GoRoute(path: '/cotizaciones', builder: (c, s) => DeferredScreen(loader: cotizaciones_list.loadLibrary, builder: () => cotizaciones_list.CotizacionesListScreen())),
        GoRoute(
          path: '/cotizaciones/form',
          builder: (c, s) => DeferredScreen(loader: cotizacion_form.loadLibrary, builder: () => cotizacion_form.CotizacionFormScreen(cotizacion: s.extra as Cotizacion?)),
        ),
        GoRoute(path: '/productos-lista', builder: (c, s) => DeferredScreen(loader: productos_list.loadLibrary, builder: () => productos_list.ProductosListScreen())),
        GoRoute(path: '/productos', builder: (c, s) => DeferredScreen(loader: productos.loadLibrary, builder: () => productos.ProductosScreen())),
        GoRoute(path: '/editar-stock', builder: (c, s) => DeferredScreen(loader: editar_stock_simple.loadLibrary, builder: () => editar_stock_simple.EditarStockSimpleScreen())),
        GoRoute(path: '/traslados', builder: (c, s) => DeferredScreen(loader: traslados.loadLibrary, builder: () => traslados.TrasladosScreen())),
        GoRoute(path: '/bodegas', builder: (c, s) => DeferredScreen(loader: bodegas.loadLibrary, builder: () => bodegas.BodegasScreen())),
        GoRoute(path: '/cuadre_caja', builder: (c, s) => DeferredScreen(loader: cuadre_caja.loadLibrary, builder: () => cuadre_caja.CuadreCajaScreen())),
        GoRoute(path: '/abrir_caja', builder: (c, s) => DeferredScreen(loader: abrir_caja.loadLibrary, builder: () => abrir_caja.AbrirCajaScreen())),
        GoRoute(path: '/cerrar_caja', builder: (c, s) => DeferredScreen(loader: cerrar_caja.loadLibrary, builder: () => cerrar_caja.CerrarCajaScreen())),
        GoRoute(path: '/compras', builder: (c, s) => DeferredScreen(loader: compras_list.loadLibrary, builder: () => compras_list.ComprasListScreen())),
        GoRoute(
          path: '/facturas-compras',
          builder: (c, s) => DeferredScreen(loader: crear_factura_compra.loadLibrary, builder: () => crear_factura_compra.CrearFacturaCompraScreen(facturaParaEditar: s.extra as FacturaCompra?)),
        ),
        GoRoute(
          path: '/facturas-compras/importar-pdf',
          builder: (c, s) => DeferredScreen(loader: importar_factura_compra_pdf.loadLibrary, builder: () => importar_factura_compra_pdf.ImportarFacturaCompraPdfScreen()),
        ),
        GoRoute(
          path: '/facturas-compras/detalle',
          builder: (c, s) => DeferredScreen(loader: detalle_factura_compra.loadLibrary, builder: () => detalle_factura_compra.DetalleFacturaCompraScreen(factura: s.extra as FacturaCompra)),
        ),
        GoRoute(path: '/gastos', builder: (c, s) => DeferredScreen(loader: gastos.loadLibrary, builder: () => gastos.GastosScreen(mostrarFormulario: true))),
        GoRoute(path: '/tipos-gasto', builder: (c, s) => DeferredScreen(loader: tipos_gasto.loadLibrary, builder: () => tipos_gasto.TiposGastoScreen())),
        GoRoute(path: '/gastos-lista', builder: (c, s) => DeferredScreen(loader: gastos_list.loadLibrary, builder: () => gastos_list.GastosListScreen())),
        GoRoute(path: '/proveedores', builder: (c, s) => DeferredScreen(loader: proveedores_list.loadLibrary, builder: () => proveedores_list.ProveedoresListScreen())),
        GoRoute(path: '/cartera', builder: (c, s) => DeferredScreen(loader: cartera.loadLibrary, builder: () => cartera.CarteraScreen())),
        GoRoute(path: '/deudas', builder: (c, s) => DeferredScreen(loader: deudas_list.loadLibrary, builder: () => deudas_list.DeudasListScreen())),
        GoRoute(path: '/cuentas-por-cobrar', builder: (c, s) => DeferredScreen(loader: cuentas_por_cobrar.loadLibrary, builder: () => cuentas_por_cobrar.CuentasPorCobrarScreen())),
        GoRoute(path: '/cuentas-por-pagar', builder: (c, s) => DeferredScreen(loader: cuentas_por_pagar.loadLibrary, builder: () => cuentas_por_pagar.CuentasPorPagarScreen())),
        GoRoute(path: '/gastos-programados', builder: (c, s) => DeferredScreen(loader: gastos_programados.loadLibrary, builder: () => gastos_programados.GastosProgramadosScreen())),
        GoRoute(path: '/alertas', builder: (c, s) => DeferredScreen(loader: alertas.loadLibrary, builder: () => alertas.AlertasScreen())),
        GoRoute(path: '/ingresos-caja', builder: (c, s) => DeferredScreen(loader: ingresos_caja.loadLibrary, builder: () => ingresos_caja.IngresosCajaScreen())),
        GoRoute(path: '/pedidos', builder: (c, s) => DeferredScreen(loader: pedidos_screen.loadLibrary, builder: () => pedidos_screen.PedidosScreenFusion())),
        GoRoute(path: '/pedidos_rt', builder: (c, s) => DeferredScreen(loader: pedidos_screen.loadLibrary, builder: () => pedidos_screen.PedidosScreenFusion())),
        GoRoute(path: '/pedidos_cancelados', builder: (c, s) => DeferredScreen(loader: pedidos_screen.loadLibrary, builder: () => pedidos_screen.PedidosScreenFusion())),
        GoRoute(path: '/pedidos_cortesia', builder: (c, s) => DeferredScreen(loader: pedidos_screen.loadLibrary, builder: () => pedidos_screen.PedidosScreenFusion())),
        GoRoute(path: '/pedidos_internos', builder: (c, s) => DeferredScreen(loader: pedidos_screen.loadLibrary, builder: () => pedidos_screen.PedidosScreenFusion())),
        GoRoute(
          path: '/facturas-lista',
          builder: (c, s) => DeferredScreen(loader: facturas_list.loadLibrary, builder: () => facturas_list.FacturasListScreen(filtroInicial: s.extra as String?)),
        ),
        GoRoute(
          path: '/facturas',
          builder: (c, s) => DeferredScreen(loader: facturas_list.loadLibrary, builder: () => facturas_list.FacturasListScreen(filtroInicial: s.extra as String?)),
        ),
        GoRoute(path: '/eliminar-pedidos', builder: (c, s) => DeferredScreen(loader: eliminar_pedidos.loadLibrary, builder: () => eliminar_pedidos.EliminarPedidosScreen())),
        GoRoute(path: '/reportes', builder: (c, s) => DeferredScreen(loader: reportes.loadLibrary, builder: () => reportes.ReportesScreen())),
        GoRoute(path: '/reportes/ventas', builder: (c, s) => DeferredScreen(loader: reportes.loadLibrary, builder: () => reportes.ReportesScreen(initialReportIndex: 1))),
        GoRoute(path: '/reportes/productos', builder: (c, s) => DeferredScreen(loader: reportes.loadLibrary, builder: () => reportes.ReportesScreen(initialReportIndex: 2))),
        GoRoute(path: '/reportes/pedidos', builder: (c, s) => DeferredScreen(loader: reportes.loadLibrary, builder: () => reportes.ReportesScreen(initialReportIndex: 3))),
        GoRoute(path: '/reportes/clientes', builder: (c, s) => DeferredScreen(loader: reportes.loadLibrary, builder: () => reportes.ReportesScreen(initialReportIndex: 4))),
        GoRoute(
          path: '/informes/productos',
          builder: (c, s) => DeferredScreen(loader: informes_productos.loadLibrary, builder: () => informes_productos.InformesProductosScreen(initialTipoCaja: s.extra as String?)),
        ),
        // Las 5 pantallas de reportes contables se fusionaron en una sola
        // (LibroContableScreen con tabs) — las rutas viejas se conservan como
        // deep-links directos al tab que corresponde, en el mismo orden que
        // _LibroContableScreenState._tabs: 0 Resumen, 1 Ventas y Gastos,
        // 2 Costeo, 3 Rentabilidad, 4 Comparación, 5 Anomalías.
        GoRoute(path: '/libro-contable', builder: (c, s) => DeferredScreen(loader: libro_contable.loadLibrary, builder: () => libro_contable.LibroContableScreen())),
        GoRoute(
          path: '/costeo-inventario',
          builder: (c, s) => DeferredScreen(loader: libro_contable.loadLibrary, builder: () => libro_contable.LibroContableScreen(initialTabIndex: 2)),
        ),
        GoRoute(
          path: '/rentabilidad',
          builder: (c, s) => DeferredScreen(loader: libro_contable.loadLibrary, builder: () => libro_contable.LibroContableScreen(initialTabIndex: 3)),
        ),
        GoRoute(
          path: '/comparativo-periodos',
          builder: (c, s) => DeferredScreen(loader: libro_contable.loadLibrary, builder: () => libro_contable.LibroContableScreen(initialTabIndex: 4)),
        ),
        GoRoute(
          path: '/anomalias',
          builder: (c, s) => DeferredScreen(loader: libro_contable.loadLibrary, builder: () => libro_contable.LibroContableScreen(initialTabIndex: 5)),
        ),
        GoRoute(path: '/facturacion-electronica', builder: (c, s) => DeferredScreen(loader: fe_documentos.loadLibrary, builder: () => fe_documentos.FEDocumentosScreen())),
        GoRoute(path: '/documentos-pendientes', builder: (c, s) => DeferredScreen(loader: documentos_pendientes.loadLibrary, builder: () => documentos_pendientes.DocumentosPendientesScreen())),
        GoRoute(path: '/matias-test', builder: (c, s) => DeferredScreen(loader: matias_test.loadLibrary, builder: () => matias_test.MatiasTestScreen())),
        GoRoute(path: '/configuracion', builder: (c, s) => DeferredScreen(loader: configuracion.loadLibrary, builder: () => configuracion.ConfiguracionScreen())),
        GoRoute(path: '/legal', builder: (c, s) => DeferredScreen(loader: legal.loadLibrary, builder: () => legal.LegalScreen())),
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
