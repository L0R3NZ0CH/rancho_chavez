import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../comun/fechas.dart';
import '../../comun/tema.dart';
import '../../data/db/base_datos.dart';
import '../../data/repos/compras.dart';
import '../../domain/reglas/costo_compra.dart';
import '../animales/pantalla_alta.dart';
import '../animales/pantalla_ficha.dart';
import '../escaneo/pantalla_escaneo.dart';

/// El detalle de una compra: sus animales y lo que costo cada uno.
class PantallaLoteCompra extends StatefulWidget {
  const PantallaLoteCompra({super.key, required this.db, required this.loteId});

  final BaseDatos db;
  final String loteId;

  @override
  State<PantallaLoteCompra> createState() => _PantallaLoteCompraState();
}

class _PantallaLoteCompraState extends State<PantallaLoteCompra> {
  CompraConCostos? _compra;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final compra = await RepoCompras(widget.db).verCompra(widget.loteId);
    if (!mounted) return;
    setState(() {
      _compra = compra;
      _cargando = false;
    });
  }

  Future<void> _meterAlLote(String animalId) async {
    await widget.db.agregarAnimalALote(
      loteCompraId: widget.loteId,
      animalId: animalId,
    );
    await _cargar();
  }

  /// Agregar escaneando el arete.
  ///
  /// Si el arete no esta registrado se va al alta con el numero ya puesto. No
  /// se da por hecho que el animal exista: en una compra, lo normal es que sea
  /// nuevo.
  Future<void> _agregarEscaneando() async {
    final numero = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const PantallaEscaneo()),
    );
    if (numero == null || !mounted) return;

    final existente = await widget.db.animalPorArete(numero);
    if (!mounted) return;

    if (existente != null) {
      final yaEsta = (await widget.db.animalesDelLote(widget.loteId))
          .any((f) => f.animalId == existente.id);
      if (!mounted) return;

      if (yaEsta) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Paleta.aviso,
            content: Text(
              'Ese animal ya esta en esta compra.',
              style: TextStyle(fontSize: 17),
            ),
          ),
        );
        return;
      }
      await _meterAlLote(existente.id);
      return;
    }

    await _altaYMeter(numeroArete: numero);
  }

  /// Agregar un animal que **no trae arete**.
  ///
  /// Los becerros comprados llegan sin identificar. Obligar a escanear para
  /// poder meterlos a la compra seria contradecir la regla del proyecto: el
  /// animal existe antes que el arete.
  Future<void> _agregarSinArete() => _altaYMeter();

  Future<void> _altaYMeter({String? numeroArete}) async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaAlta(db: widget.db, numeroArete: numeroArete),
      ),
    );
    if (id == null || !mounted) return;
    await _meterAlLote(id);
  }

  Future<void> _editarTrato(RenglonCompra r) async {
    final cambio = await showDialog<_Trato>(
      context: context,
      builder: (_) => _DialogoTrato(renglon: r),
    );
    if (cambio == null || !mounted) return;

    await widget.db.ajustarTratoDelAnimal(
      loteCompraId: widget.loteId,
      animalId: r.animal.id,
      vendedor: Value(cambio.vendedor),
      formaCalculo: Value(cambio.forma),
      precioPorKilo: Value(cambio.precioPorKilo),
      precioPorCabeza: Value(cambio.precioPorCabeza),
    );
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final compra = _compra;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          compra == null ? 'Compra' : formateaAaaammdd(compra.lote.fecha),
        ),
      ),
      body: SafeArea(
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : compra == null
                ? const Center(
                    child: Text('No se encontro la compra',
                        style: TextStyle(fontSize: 18)),
                  )
                : Column(
                    children: [
                      _Resumen(compra: compra),
                      Expanded(
                        child: compra.renglones.isEmpty
                            ? const _Vacio()
                            : ListView.separated(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                itemCount: compra.renglones.length,
                                separatorBuilder: (_, _) => const Divider(
                                  height: 1,
                                  color: Paleta.borde,
                                ),
                                itemBuilder: (context, i) => _Renglon(
                                  renglon: compra.renglones[i],
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PantallaFicha(
                                        db: widget.db,
                                        animalId:
                                            compra.renglones[i].animal.id,
                                      ),
                                    ),
                                  ).then((_) => _cargar()),
                                  onTrato: () =>
                                      _editarTrato(compra.renglones[i]),
                                ),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: BotonGrande(
                                etiqueta: 'ESCANEAR',
                                icono: Icons.qr_code_scanner,
                                onPressed: _agregarEscaneando,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: BotonGrande(
                                etiqueta: 'SIN ARETE',
                                icono: Icons.add,
                                contorno: true,
                                onPressed: _agregarSinArete,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

String _pesos(double v) => '\$${v.toStringAsFixed(2)}';

class _Vacio extends StatelessWidget {
  const _Vacio();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Text(
          'Todavia no hay animales en esta compra.\n\n'
          'Escanea el arete de cada uno, o usa SIN ARETE si llegaron sin '
          'identificar. El vendedor y el precio ya estan puestos; solo se '
          'cambian a los que se hayan comprado aparte.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: Paleta.textoSuave),
        ),
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.compra});

  final CompraConCostos compra;

  @override
  Widget build(BuildContext context) {
    final r = compra.resumen;
    final porKilo = compra.lote.formaCalculo == 'porKilo';

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
            compra.lote.vendedor +
                (compra.lote.lugar == null ? '' : '  ·  ${compra.lote.lugar}'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _pesos(r.total),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${compra.cabezas} cabezas',
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
                  ? 'Por kilo a ${_pesos(compra.lote.precioPorKilo ?? 0)}'
                  : 'Por cabeza',
              if (compra.kilosTotales > 0)
                '${compra.kilosTotales.toStringAsFixed(0)} kg',
            ].join('  ·  '),
            style: const TextStyle(fontSize: 16, color: Paleta.textoSuave),
          ),
          if (r.desconocidos > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Paleta.aviso,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                // El total no incluye a los que no se saben, y hay que decirlo:
                // si no, se leeria como si estuviera completo.
                'Ese total es de ${r.conocidos} de ${compra.cabezas}. '
                '${compra.faltaPesar > 0 ? '${compra.faltaPesar} sin pesar. ' : ''}'
                '${compra.faltaPrecio > 0 ? '${compra.faltaPrecio} sin precio. ' : ''}',
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
    required this.onTrato,
  });

  final RenglonCompra renglon;
  final VoidCallback onTap;
  final VoidCallback onTrato;

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  c.seSabe ? _pesos(c.total!) : 'No se sabe',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: c.seSabe ? Paleta.texto : Paleta.aviso,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    switch (c.falta) {
                      FaltaDato.peso => 'falta pesarlo',
                      FaltaDato.precio => 'falta el precio',
                      null => renglon.pesoCompraKg == null
                          ? ''
                          : '${renglon.pesoCompraKg!.toStringAsFixed(0)} kg',
                    },
                    style: const TextStyle(
                      fontSize: 16,
                      color: Paleta.textoSuave,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              renglon.vendedor + (renglon.tratoPropio ? '  ·  trato aparte' : ''),
              style: TextStyle(
                fontSize: 15,
                color: renglon.tratoPropio ? Paleta.accion : Paleta.textoSuave,
                fontWeight:
                    renglon.tratoPropio ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      trailing: IconButton(
        tooltip: 'Cambiar vendedor o precio',
        iconSize: 28,
        icon: const Icon(Icons.edit_outlined),
        onPressed: onTrato,
      ),
    );
  }
}

/// Lo que devuelve el dialogo de trato.
class _Trato {
  const _Trato({
    this.vendedor,
    this.forma,
    this.precioPorKilo,
    this.precioPorCabeza,
  });

  final String? vendedor;
  final String? forma;
  final double? precioPorKilo;
  final double? precioPorCabeza;
}

class _DialogoTrato extends StatefulWidget {
  const _DialogoTrato({required this.renglon});

  final RenglonCompra renglon;

  @override
  State<_DialogoTrato> createState() => _DialogoTratoState();
}

class _DialogoTratoState extends State<_DialogoTrato> {
  late final _vendedor =
      TextEditingController(text: widget.renglon.vendedor);
  late final _precioKilo = TextEditingController(
    text: widget.renglon.precioPorKilo?.toStringAsFixed(2) ?? '',
  );
  late final _precioCabeza = TextEditingController(
    text: widget.renglon.precioPorCabeza?.toStringAsFixed(2) ?? '',
  );
  late String _forma =
      widget.renglon.forma == FormaCotizacion.porCabeza
          ? 'porCabeza'
          : 'porKilo';

  @override
  void dispose() {
    _vendedor.dispose();
    _precioKilo.dispose();
    _precioCabeza.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Trato de ${widget.renglon.titulo}'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'A quien le compraste este',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _vendedor,
              style: const TextStyle(fontSize: 19),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            const Text(
              'Como se cotizo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'porKilo', label: Text('Por kilo')),
                ButtonSegment(value: 'porCabeza', label: Text('Por cabeza')),
              ],
              selected: {_forma},
              onSelectionChanged: (s) => setState(() => _forma = s.first),
            ),
            const SizedBox(height: 16),
            if (_forma == 'porKilo')
              TextField(
                controller: _precioKilo,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixText: r'$ ',
                  suffixText: 'por kg',
                ),
              )
            else
              TextField(
                controller: _precioCabeza,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixText: r'$ ',
                  suffixText: 'este animal',
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(fontSize: 18)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            _Trato(
              vendedor: _vendedor.text.trim().isEmpty
                  ? null
                  : _vendedor.text.trim(),
              forma: _forma,
              precioPorKilo: _forma == 'porKilo'
                  ? double.tryParse(_precioKilo.text.trim())
                  : null,
              precioPorCabeza: _forma == 'porCabeza'
                  ? double.tryParse(_precioCabeza.text.trim())
                  : null,
            ),
          ),
          child: const Text('Guardar', style: TextStyle(fontSize: 18)),
        ),
      ],
    );
  }
}
