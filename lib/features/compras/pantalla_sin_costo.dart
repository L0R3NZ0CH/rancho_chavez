import 'package:flutter/material.dart';

import '../../comun/fechas.dart';
import '../../comun/tema.dart';
import '../../data/db/base_datos.dart';
import '../../data/repos/pendientes.dart';
import '../../domain/reglas/costo_compra.dart';
import '../animales/pantalla_ficha.dart';
import '../ventas/dialogo_peso.dart';
import 'dialogo_precio_compra.dart';

/// Los animales comprados a los que les falta algo para saber cuánto costaron.
///
/// Un hueco que nadie ve nunca se tapa. Estos animales salen en blanco en el
/// resumen de la venta —que es lo correcto, porque no se sabe— pero desde aquí
/// se arregla en un toque.
class PantallaSinCosto extends StatelessWidget {
  const PantallaSinCosto({super.key, required this.db});

  final BaseDatos db;

  Future<void> _arreglar(BuildContext context, SinCosto p) async {
    if (p.falta == FaltaDato.peso) {
      final kilos = await pedirPeso(context, titulo: p.titulo);
      if (kilos == null) return;
      await db.registrarPeso(
        animalId: p.animal.id,
        kilos: kilos,
        fecha: hoyAaaammdd(),
        tipoPesaje: 'compra',
      );
      return;
    }

    final peso = await db.pesoDeCompra(p.animal.id);
    if (!context.mounted) return;

    final trato = await pedirPrecioDeCompra(
      context,
      titulo: p.titulo,
      formaInicial: p.forma,
      pesoCompraKg: peso,
    );
    if (trato == null) return;

    await db.ajustarTrato(
      loteCompraId: p.loteCompraId,
      animalId: p.animal.id,
      formaCalculo: trato.forma == FormaCotizacion.porCabeza
          ? 'porCabeza'
          : 'porKilo',
      precioPorKilo:
          trato.forma == FormaCotizacion.porKilo ? trato.precio : null,
      precioPorCabeza:
          trato.forma == FormaCotizacion.porCabeza ? trato.precio : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Falta el costo')),
      body: SafeArea(
        child: StreamBuilder<List<SinCosto>>(
          stream: RepoPendientes(db).verSinCosto(),
          builder: (context, snap) {
            final lista = snap.data ?? const <SinCosto>[];

            if (lista.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Text(
                    'Todos los animales comprados tienen su costo completo.\n\n'
                    'Eso quiere decir que al venderlos vas a poder ver cuánto '
                    'dio a ganar cada uno.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Paleta.textoSuave),
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: lista.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: Paleta.borde),
              itemBuilder: (context, i) {
                final p = lista[i];
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PantallaFicha(
                        db: db,
                        animalId: p.animal.id,
                      ),
                    ),
                  ),
                  title: Text(
                    p.titulo,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${p.queFalta}'
                      '${p.vendedor.isEmpty ? '' : '  ·  ${p.vendedor}'}',
                      style: const TextStyle(
                        fontSize: 17,
                        color: Paleta.aviso,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  trailing: SizedBox(
                    height: 56,
                    child: FilledButton(
                      onPressed: () => _arreglar(context, p),
                      style: FilledButton.styleFrom(
                        backgroundColor: Paleta.accion,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        p.falta == FaltaDato.peso ? 'PESAR' : 'PRECIO',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
