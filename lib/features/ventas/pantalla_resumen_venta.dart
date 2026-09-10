import 'package:flutter/material.dart';

import '../../comun/fechas.dart';
import '../../comun/tema.dart';
import '../../data/db/base_datos.dart';
import '../../data/repos/ventas.dart';
import '../animales/pantalla_ficha.dart';

/// El resultado de la venta, animal por animal.
///
/// Es la única pantalla de la aplicación que no sirve para capturar sino para
/// **saber**: si la engorda valió la pena. Todo lo demás alimenta a esta.
///
/// Los animales sin costo de compra no traen ganancia. **No un cero: en
/// blanco**, con el motivo. Un cero se leería como que no ganaste nada, y lo
/// que pasa es que no hay con qué comparar.
class PantallaResumenVenta extends StatelessWidget {
  const PantallaResumenVenta({
    super.key,
    required this.db,
    required this.ventaId,
  });

  final BaseDatos db;
  final String ventaId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resumen')),
      body: SafeArea(
        child: FutureBuilder<VentaArmada?>(
          future: RepoVentas(db).verVenta(ventaId),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final v = snap.data!;
            final t = v.total;

            final kilosCompra = v.renglones.fold<double>(
              0,
              (s, r) => s + (r.datos.pesoCompraKg ?? 0),
            );

            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              children: [
                _Encabezado(venta: v),
                const SizedBox(height: 8),
                const _Titulos(),
                const Divider(height: 1, color: Paleta.borde),
                for (final r in v.renglones)
                  _Renglon(
                    renglon: r,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PantallaFicha(
                          db: db,
                          animalId: r.animal.id,
                        ),
                      ),
                    ),
                  ),
                const Divider(height: 1, color: Paleta.borde),
                _Totales(
                  cabezas: v.cabezas,
                  kilosCompra: kilosCompra,
                  kilosVenta: t.kilos,
                  ganancia: t.diferencia,
                  conGanancia: t.conDiferencia,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _pesos(double v) {
  final signo = v < 0 ? '-' : '';
  return '$signo\$${v.abs().toStringAsFixed(2)}';
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.venta});

  final VentaArmada venta;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Paleta.fondoSuave,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            venta.venta.comprador ?? 'Sin comprador',
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            formateaAaaammdd(venta.venta.fecha) +
                (venta.cerrada ? '' : '  ·  sin cerrar'),
            style: TextStyle(
              fontSize: 16,
              color: venta.cerrada ? Paleta.textoSuave : Paleta.aviso,
              fontWeight: venta.cerrada ? FontWeight.w400 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Titulos extends StatelessWidget {
  const _Titulos();

  @override
  Widget build(BuildContext context) {
    const estilo = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w800,
      color: Paleta.textoSuave,
      letterSpacing: 0.5,
    );

    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text('ARETE', style: estilo)),
          Expanded(
            flex: 3,
            child: Text('COMPRÓ', style: estilo, textAlign: TextAlign.right),
          ),
          Expanded(
            flex: 3,
            child: Text('VENDIÓ', style: estilo, textAlign: TextAlign.right),
          ),
          Expanded(
            flex: 4,
            child: Text('GANÓ', style: estilo, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _Renglon extends StatelessWidget {
  const _Renglon({required this.renglon, required this.onTap});

  final RenglonVenta renglon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = renglon.resultado;
    final ganancia = r.diferencia;
    final perdio = ganancia != null && ganancia < 0;
    final nacioAqui = renglon.datos.costoCompra == null &&
        renglon.datos.pesoCompraKg == null;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    renglon.titulo,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    renglon.datos.pesoCompraKg == null
                        ? '—'
                        : '${renglon.datos.pesoCompraKg!.toStringAsFixed(0)} kg',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 17),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    renglon.pesoVentaKg == null
                        ? '—'
                        : '${renglon.pesoVentaKg!.toStringAsFixed(0)} kg',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    ganancia == null ? '—' : _pesos(ganancia),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      // Perder dinero tiene que saltar a la vista y no
                      // confundirse con los demas renglones.
                      color: ganancia == null
                          ? Paleta.textoSuave
                          : (perdio ? Paleta.alerta : Paleta.accion),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _loQueHizo(r, nacioAqui),
                    style: TextStyle(
                      fontSize: 15,
                      color: nacioAqui ? Paleta.aviso : Paleta.textoSuave,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Los kilos que engordó y en cuántos días.
  ///
  /// Setenta kilos en noventa días y en trescientos no son lo mismo, y el
  /// número solo tiene sentido con el tiempo al lado.
  String _loQueHizo(dynamic r, bool nacioAqui) {
    if (nacioAqui) return 'Nació aquí: no hay con qué comparar';

    final kilos = r.kilosGanados as double?;
    final dias = r.dias as int?;
    final diaria = r.gananciaDiaria as double?;

    if (kilos == null) return 'Falta el peso de cuando lo recibiste';

    final partes = <String>[
      '${kilos >= 0 ? '+' : ''}${kilos.toStringAsFixed(0)} kg',
      if (dias != null) 'en $dias días',
      if (diaria != null) '${diaria.toStringAsFixed(2)} kg por día',
    ];
    return partes.join('  ·  ');
  }
}

class _Totales extends StatelessWidget {
  const _Totales({
    required this.cabezas,
    required this.kilosCompra,
    required this.kilosVenta,
    required this.ganancia,
    required this.conGanancia,
  });

  final int cabezas;
  final double kilosCompra;
  final double kilosVenta;
  final double ganancia;
  final int conGanancia;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 5,
                child: Text(
                  '$cabezas ${cabezas == 1 ? 'cabeza' : 'cabezas'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  '${kilosCompra.toStringAsFixed(0)} kg',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 17),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  '${kilosVenta.toStringAsFixed(0)} kg',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  _pesos(ganancia),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: ganancia < 0 ? Paleta.alerta : Paleta.accion,
                  ),
                ),
              ),
            ],
          ),
          if (conGanancia < cabezas) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Paleta.aviso,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                // El total no incluye a los que no tienen con que compararse.
                'Esa ganancia es de $conGanancia de $cabezas. Los demás no '
                'tienen costo de compra con qué comparar.',
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
