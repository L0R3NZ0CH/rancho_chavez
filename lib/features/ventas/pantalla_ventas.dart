import 'package:flutter/material.dart';

import '../../comun/confirmar.dart';
import '../../comun/fechas.dart';
import '../../comun/tema.dart';
import '../../data/db/base_datos.dart';
import 'pantalla_venta.dart';

/// La lista de ventas.
///
/// Las abiertas van arriba y se ven distintas: una venta a medias es trabajo
/// sin terminar, no un registro.
class PantallaVentas extends StatelessWidget {
  const PantallaVentas({super.key, required this.db});

  final BaseDatos db;

  Future<void> _nueva(BuildContext context) async {
    final id = await db.crearVenta(fecha: hoyAaaammdd());
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaVenta(db: db, ventaId: id),
      ),
    );
  }

  Future<void> _borrar(BuildContext context, LoteVenta venta) async {
    final cerrada = venta.cerradoEn != null;
    final ok = await confirmarBorrado(
      context,
      titulo: 'Borrar esta venta',
      mensaje: cerrada
          ? 'Se borra el registro de la venta.\n\nLos animales que se '
              'vendieron NO regresan al hato: siguen dados de baja.'
          : 'Se borra esta venta a medias.\n\nLos animales NO se venden ni se '
              'borran: siguen en el hato.',
    );
    if (!(ok ?? false) || !context.mounted) return;
    await db.eliminarVenta(venta.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ventas')),
      body: SafeArea(
        child: StreamBuilder<List<LoteVenta>>(
          stream: db.verVentas(),
          builder: (context, snap) {
            final ventas = snap.data ?? const <LoteVenta>[];
            final abiertas =
                ventas.where((v) => v.cerradoEn == null).toList();
            final cerradas =
                ventas.where((v) => v.cerradoEn != null).toList();

            return Column(
              children: [
                Expanded(
                  child: ventas.isEmpty
                      ? const _Vacio()
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          children: [
                            for (final v in abiertas)
                              _Renglon(
                                venta: v,
                                onTap: () => _abrir(context, v),
                                onBorrar: () => _borrar(context, v),
                              ),
                            if (abiertas.isNotEmpty && cerradas.isNotEmpty)
                              const Padding(
                                padding: EdgeInsets.fromLTRB(4, 18, 4, 8),
                                child: Text(
                                  'Cerradas',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Paleta.textoSuave,
                                  ),
                                ),
                              ),
                            for (final v in cerradas)
                              _Renglon(
                                venta: v,
                                onTap: () => _abrir(context, v),
                                onBorrar: () => _borrar(context, v),
                              ),
                          ],
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: BotonGrande(
                    etiqueta: 'NUEVA VENTA',
                    icono: Icons.sell_outlined,
                    onPressed: () => _nueva(context),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _abrir(BuildContext context, LoteVenta v) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaVenta(db: db, ventaId: v.id),
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Text(
          'Todavía no hay ventas.\n\n'
          'Abre una nueva y empieza a pesar de inmediato. El comprador y el '
          'precio se ponen cuando quieras.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: Paleta.textoSuave),
        ),
      ),
    );
  }
}

class _Renglon extends StatelessWidget {
  const _Renglon({
    required this.venta,
    required this.onTap,
    required this.onBorrar,
  });

  final LoteVenta venta;
  final VoidCallback onTap;
  final VoidCallback onBorrar;

  @override
  Widget build(BuildContext context) {
    final abierta = venta.cerradoEn == null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: abierta ? const Color(0xFFFFF4E0) : Paleta.fondoSuave,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 84),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: abierta ? Paleta.aviso : Paleta.borde,
                width: abierta ? 2 : 1.5,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        venta.comprador ?? 'Sin comprador',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: venta.comprador == null
                              ? Paleta.textoSuave
                              : Paleta.texto,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        abierta
                            ? '${formateaAaaammdd(venta.fecha)}  ·  sin cerrar'
                            : formateaAaaammdd(venta.fecha),
                        style: TextStyle(
                          fontSize: 16,
                          color: abierta ? Paleta.aviso : Paleta.textoSuave,
                          fontWeight:
                              abierta ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Borrar la venta',
                  iconSize: 26,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onBorrar,
                ),
                const Icon(Icons.chevron_right, size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
