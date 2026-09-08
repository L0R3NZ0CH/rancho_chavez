import 'package:flutter/material.dart';

import '../../comun/fechas.dart';
import '../../comun/tema.dart';
import '../../data/db/base_datos.dart';
import '../../data/repos/compras.dart';
import '../animales/pantalla_alta.dart';
import '../animales/pantalla_ficha.dart';
import '../escaneo/pantalla_escaneo.dart';

/// El detalle de un lote de compra: sus animales y lo que costo cada uno.
class PantallaLoteCompra extends StatefulWidget {
  const PantallaLoteCompra({super.key, required this.db, required this.loteId});

  final BaseDatos db;
  final String loteId;

  @override
  State<PantallaLoteCompra> createState() => _PantallaLoteCompraState();
}

class _PantallaLoteCompraState extends State<PantallaLoteCompra> {
  LoteConCostos? _lote;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final lote = await RepoCompras(widget.db).verLote(widget.loteId);
    if (!mounted) return;
    setState(() {
      _lote = lote;
      _cargando = false;
    });
  }

  /// Agregar un animal al lote escaneando su arete.
  ///
  /// Si el arete no existe, se va derecho al alta: en una descarga de camion,
  /// lo normal es que todos sean animales nuevos.
  Future<void> _agregar() async {
    final numero = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const PantallaEscaneo()),
    );
    if (numero == null || !mounted) return;

    final existente = await widget.db.animalPorArete(numero);
    if (!mounted) return;

    if (existente != null) {
      final yaEnLote = (await widget.db.animalesDelLote(widget.loteId))
          .any((f) => f.animalId == existente.id);
      if (!mounted) return;

      if (yaEnLote) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Paleta.aviso,
            content: Text(
              'Ese animal ya esta en este lote.',
              style: TextStyle(fontSize: 17),
            ),
          ),
        );
        return;
      }

      await widget.db.agregarAnimalALote(
        loteCompraId: widget.loteId,
        animalId: existente.id,
      );
      await _cargar();
      return;
    }

    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaAlta(db: widget.db, numeroArete: numero),
      ),
    );
    if (id == null || !mounted) return;

    await widget.db.agregarAnimalALote(
      loteCompraId: widget.loteId,
      animalId: id,
    );
    await _cargar();
  }

  Future<void> _precioIndividual(RenglonCompra r) async {
    final valor = await showDialog<double>(
      context: context,
      builder: (_) => _DialogoPrecio(actual: r.costo.costoBase),
    );
    if (valor == null || !mounted) return;

    await widget.db.fijarCostoIndividual(
      loteCompraId: widget.loteId,
      animalId: r.animal.id,
      costo: valor,
    );
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final lote = _lote;

    return Scaffold(
      appBar: AppBar(title: Text(lote?.lote.vendedor ?? 'Compra')),
      body: SafeArea(
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : lote == null
                ? const Center(
                    child: Text('No se encontro la compra',
                        style: TextStyle(fontSize: 18)),
                  )
                : Column(
                    children: [
                      _Resumen(lote: lote),
                      Expanded(
                        child: lote.renglones.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(28),
                                  child: Text(
                                    'Todavia no hay animales en esta compra.\n\n'
                                    'Escanea el arete de cada uno para irlos '
                                    'metiendo. El precio y el vendedor ya '
                                    'estan puestos, no hay que repetirlos.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Paleta.textoSuave,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                itemCount: lote.renglones.length,
                                separatorBuilder: (_, _) => const Divider(
                                  height: 1,
                                  color: Paleta.borde,
                                ),
                                itemBuilder: (context, i) => _Renglon(
                                  renglon: lote.renglones[i],
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PantallaFicha(
                                        db: widget.db,
                                        animalId:
                                            lote.renglones[i].animal.id,
                                      ),
                                    ),
                                  ).then((_) => _cargar()),
                                  onPrecio: () =>
                                      _precioIndividual(lote.renglones[i]),
                                ),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: BotonGrande(
                          etiqueta: 'AGREGAR ANIMAL',
                          icono: Icons.qr_code_scanner,
                          onPressed: _agregar,
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

String _pesos(double v) => '\$${v.toStringAsFixed(2)}';

class _Resumen extends StatelessWidget {
  const _Resumen({required this.lote});

  final LoteConCostos lote;

  @override
  Widget build(BuildContext context) {
    final porKilo = lote.lote.formaCalculo == 'porKilo';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Paleta.fondoSuave,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formateaAaaammdd(lote.lote.fecha) +
                (lote.lote.lugar == null ? '' : '  ·  ${lote.lote.lugar}'),
            style: const TextStyle(fontSize: 16, color: Paleta.textoSuave),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _pesos(lote.total),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${lote.cabezas} cabezas',
                style: const TextStyle(
                  fontSize: 18,
                  color: Paleta.textoSuave,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [
              porKilo
                  ? 'Por kilo a ${_pesos(lote.lote.precioPorKilo ?? 0)}'
                  : 'Por cabeza',
              if (lote.gastos > 0) 'Gastos ${_pesos(lote.gastos)}',
              if (lote.kilosTotales > 0)
                '${lote.kilosTotales.toStringAsFixed(0)} kg',
              if (lote.cabezas > 0)
                'Promedio ${_pesos(lote.costoPromedio)}',
            ].join('  ·  '),
            style: const TextStyle(fontSize: 16, color: Paleta.textoSuave),
          ),
          if (lote.prorrateados > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Paleta.aviso,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                porKilo
                    ? '${lote.prorrateados} sin pesar: su costo es un reparto, '
                        'no un dato real. Se arregla pesandolos.'
                    : '${lote.prorrateados} con costo repartido del total.',
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Renglon extends StatelessWidget {
  const _Renglon({
    required this.renglon,
    required this.onTap,
    required this.onPrecio,
  });

  final RenglonCompra renglon;
  final VoidCallback onTap;
  final VoidCallback onPrecio;

  @override
  Widget build(BuildContext context) {
    final c = renglon.costo;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      title: Text(
        renglon.titulo,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Text(
              _pesos(c.total),
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: c.esProrrateado ? Paleta.aviso : Paleta.texto,
              ),
            ),
            if (c.esProrrateado)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.calculate_outlined,
                    size: 19, color: Paleta.aviso),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                renglon.pesoCompraKg == null
                    ? 'sin pesar'
                    : '${renglon.pesoCompraKg!.toStringAsFixed(0)} kg',
                style: const TextStyle(
                  fontSize: 16,
                  color: Paleta.textoSuave,
                ),
              ),
            ),
          ],
        ),
      ),
      trailing: IconButton(
        tooltip: 'Precio individual',
        iconSize: 28,
        icon: const Icon(Icons.edit_outlined),
        onPressed: onPrecio,
      ),
    );
  }
}

class _DialogoPrecio extends StatefulWidget {
  const _DialogoPrecio({required this.actual});

  final double actual;

  @override
  State<_DialogoPrecio> createState() => _DialogoPrecioState();
}

class _DialogoPrecioState extends State<_DialogoPrecio> {
  late final _campo =
      TextEditingController(text: widget.actual.toStringAsFixed(2));

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Precio de este animal'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Se usa tal cual y gana sobre el calculo del lote. Para cuando '
            'ese animal se negocio aparte.',
            style: TextStyle(fontSize: 16, color: Paleta.textoSuave),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _campo,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              prefixText: r'$ ',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(fontSize: 18)),
        ),
        TextButton(
          onPressed: () {
            final v = double.tryParse(_campo.text.trim());
            if (v != null && v >= 0) Navigator.pop(context, v);
          },
          child: const Text('Guardar', style: TextStyle(fontSize: 18)),
        ),
      ],
    );
  }
}
