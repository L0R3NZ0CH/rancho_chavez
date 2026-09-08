import 'package:flutter/material.dart';

import '../../comun/fechas.dart';
import '../../comun/tema.dart';
import '../../data/db/base_datos.dart';
import 'pantalla_lote.dart';
import 'pantalla_nueva_compra.dart';

/// La lista de compras.
class PantallaCompras extends StatelessWidget {
  const PantallaCompras({super.key, required this.db});

  final BaseDatos db;

  Future<void> _nueva(BuildContext context) async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => PantallaNuevaCompra(db: db)),
    );
    if (id == null || !context.mounted) return;

    // Se entra derecho al lote: lo siguiente que quiere hacer el usuario es
    // empezar a escanear animales.
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaLoteCompra(db: db, loteId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compras')),
      body: SafeArea(
        child: StreamBuilder<List<LoteCompra>>(
          stream: db.verLotesCompra(),
          builder: (context, snap) {
            final lotes = snap.data ?? const <LoteCompra>[];

            return Column(
              children: [
                Expanded(
                  child: lotes.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(28),
                            child: Text(
                              'Todavia no hay compras registradas.\n\n'
                              'Registra el viaje una vez —vendedor, lugar y '
                              'precio— y luego le vas metiendo los animales. '
                              'Al que se le haya comprado a otro, se le cambia '
                              'el vendedor.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                color: Paleta.textoSuave,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: lotes.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1, color: Paleta.borde),
                          itemBuilder: (context, i) => _Renglon(
                            lote: lotes[i],
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PantallaLoteCompra(
                                  db: db,
                                  loteId: lotes[i].id,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: BotonGrande(
                    etiqueta: 'NUEVA COMPRA',
                    icono: Icons.add_shopping_cart,
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
}

class _Renglon extends StatelessWidget {
  const _Renglon({required this.lote, required this.onTap});

  final LoteCompra lote;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      title: Text(
        lote.vendedor,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '${formateaAaaammdd(lote.fecha)}'
          '${lote.lugar == null ? '' : '  ·  ${lote.lugar}'}  ·  '
          '${lote.formaCalculo == 'porKilo' ? 'por kilo a \$${lote.precioPorKilo?.toStringAsFixed(2) ?? '?'}' : 'por cabeza'}',
          style: const TextStyle(fontSize: 17, color: Paleta.textoSuave),
        ),
      ),
      trailing: const Icon(Icons.chevron_right, size: 30),
    );
  }
}
