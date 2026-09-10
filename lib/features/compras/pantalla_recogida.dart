import 'package:flutter/material.dart';

import '../../comun/confirmar.dart';
import '../../comun/dialogo_captura.dart';
import '../../comun/fechas.dart';
import '../../comun/tema.dart';
import '../../data/db/base_datos.dart';
import '../../data/repos/compras.dart';
import '../escaneo/pantalla_escaneo.dart';
import '../ventas/dialogo_peso.dart';

/// La pantalla de una compra, con el vendedor enfrente.
///
/// El vendedor está esperando su dinero. Todo lo que la app pida capturar en
/// ese momento se lo está quitando a él, y por eso el orden importa más que
/// cualquier otra cosa:
///
/// **Primera vuelta, a las prisas:** escanear, peso, categoría, siguiente. Nada
/// más. La cámara vuelve sola.
///
/// **Segunda vuelta, ya en la casa:** precio, vendedor, dónde los recogiste,
/// características, y mandarlos a un lugar del rancho.
///
/// El vendedor y el precio se **arrastran** del renglón anterior, como las
/// series de una app de ejercicio: pones el primero y los de abajo lo heredan.
/// Si el tercero es de otro señor, lo cambias y de ahí para abajo se arrastra
/// el nuevo, porque los animales vienen agrupados por dueño.
class PantallaRecogida extends StatefulWidget {
  const PantallaRecogida({super.key, required this.db, required this.compraId});

  final BaseDatos db;
  final String compraId;

  @override
  State<PantallaRecogida> createState() => _PantallaRecogidaState();
}

class _PantallaRecogidaState extends State<PantallaRecogida> {
  CompraConCostos? _compra;
  bool _cargando = true;

  /// Los renglones que el usuario ya reviso en la segunda vuelta.
  final _listos = <String>{};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final c = await RepoCompras(widget.db).verCompra(widget.compraId);
    if (!mounted) return;
    setState(() {
      _compra = c;
      _cargando = false;
    });
  }

  // -------------------------------------------------------------- primera vuelta

  /// Escanear, pesar, categorizar, y de regreso a la cámara.
  Future<void> _ciclo() async {
    var seguir = true;
    while (seguir) {
      if (!mounted) return;
      final numero = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const PantallaEscaneo()),
      );
      if (numero == null) return;
      seguir = await _capturar(numeroArete: numero);
    }
  }

  /// Sin arete: se salta la cámara y pide una seña para poder distinguirlo
  /// después, porque el arete normalmente tarda en llegar.
  Future<void> _sinArete() => _capturar();

  Future<bool> _capturar({String? numeroArete}) async {
    if (numeroArete != null) {
      final existente = await widget.db.animalPorArete(numeroArete);
      if (!mounted) return false;
      if (existente != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Paleta.aviso,
            content: Text(
              'El arete $numeroArete ya es de un animal tuyo.',
              style: const TextStyle(fontSize: 17),
            ),
          ),
        );
        return mounted;
      }
    }

    final sinArete = numeroArete == null;
    final n = _compra?.renglones.length ?? 0;

    if (!mounted) return false;
    final captura = await capturaRapida(
      context,
      titulo: numeroArete ?? 'Sin arete #${n + 1}',
      pedirSena: sinArete,
    );
    if (captura == null || !mounted) return false;

    // El vendedor y el precio se arrastran del ultimo renglon capturado.
    final ultimo = _compra?.renglones.lastOrNull;

    final animalId = await widget.db.altaAnimal(
      sexo: captura.categoria.sexo!.texto,
      origen: 'comprado',
      proposito: 'comercial',
      fecha: _compra?.lote.fecha ?? hoyAaaammdd(),
      categoria: captura.categoria.texto,
      apodo: captura.sena,
      descripcionFisica: captura.sena,
    );

    if (numeroArete != null) {
      await widget.db.ponerArete(
        animalId: animalId,
        numero: numeroArete,
        fecha: _compra?.lote.fecha ?? hoyAaaammdd(),
      );
    }

    if (captura.pesoKg != null) {
      await widget.db.registrarPeso(
        animalId: animalId,
        kilos: captura.pesoKg!,
        fecha: _compra?.lote.fecha ?? hoyAaaammdd(),
        tipoPesaje: 'compra',
      );
    }

    await widget.db.agregarAnimalALote(
      loteCompraId: widget.compraId,
      animalId: animalId,
      vendedor: ultimo?.tratoPropio == true ? ultimo?.vendedor : null,
      precioPorKilo: ultimo?.precioPorKilo,
    );

    await _cargar();
    return mounted;
  }

  // -------------------------------------------------------------- segunda vuelta

  Future<void> _precio(RenglonCompra r) async {
    final precio = await pedirNumero(
      context,
      titulo: 'Precio de ${r.titulo}',
      explicacion: 'Por kilo. Se arrastra a los de abajo que no tengan.',
      prefijo: r'$ ',
      sufijo: 'por kg',
      inicial: r.precioPorKilo,
    );
    if (precio == null || !mounted) return;

    await _arrastrar(r, precioPorKilo: precio);
  }

  Future<void> _vendedor(RenglonCompra r) async {
    final previos = await widget.db.vendedoresUsados();
    if (!mounted) return;

    final nombre = await showDialog<String>(
      context: context,
      builder: (_) => _DialogoVendedor(inicial: r.vendedor, previos: previos),
    );
    if (nombre == null || !mounted) return;

    await _arrastrar(r, vendedor: nombre);
  }

  /// Aplica el cambio a este renglón y lo arrastra a los de abajo.
  ///
  /// Los de abajo solo lo heredan si todavía no se han marcado como listos: si
  /// ya los revisaste, no te los vuelvo a mover.
  Future<void> _arrastrar(
    RenglonCompra r, {
    String? vendedor,
    double? precioPorKilo,
  }) async {
    final renglones = _compra?.renglones ?? const <RenglonCompra>[];
    final desde = renglones.indexWhere((x) => x.animal.id == r.animal.id);
    if (desde < 0) return;

    for (var i = desde; i < renglones.length; i++) {
      final actual = renglones[i];
      if (i != desde && _listos.contains(actual.animal.id)) continue;

      await widget.db.ajustarTrato(
        loteCompraId: widget.compraId,
        animalId: actual.animal.id,
        vendedor: vendedor,
        precioPorKilo: precioPorKilo,
      );
    }
    await _cargar();
  }

  Future<void> _quitar(RenglonCompra r) async {
    final ok = await confirmarBorrado(
      context,
      titulo: 'Quitar de la recogida',
      mensaje: 'Se quita ${r.titulo} de esta compra.\n\n'
          'El animal se queda en el hato. Si lo capturaste por error, bórralo '
          'desde su ficha.',
      etiquetaBoton: 'Quitar',
    );
    if (!(ok ?? false) || !mounted) return;

    await widget.db.quitarAnimalDeCompra(
      loteCompraId: widget.compraId,
      animalId: r.animal.id,
    );
    await _cargar();
  }

  Future<void> _datos() async {
    final c = _compra;
    if (c == null) return;

    final donde = await showDialog<String>(
      context: context,
      builder: (_) => _DialogoLugarRecogida(inicial: c.lote.lugar),
    );
    if (donde == null || !mounted) return;

    await widget.db.actualizarLugarCompra(
      loteCompraId: widget.compraId,
      lugar: donde,
    );
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final c = _compra;

    if (_cargando) {
      return Scaffold(
        appBar: AppBar(title: const Text('Recogida')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (c == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Recogida')),
        body: const Center(
          child: Text('No se encontró la compra',
              style: TextStyle(fontSize: 18)),
        ),
      );
    }

    final listos = c.renglones.where((r) => _listos.contains(r.animal.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(formateaAaaammdd(c.lote.fecha)),
        actions: [
          IconButton(
            tooltip: 'Dónde los recogiste',
            iconSize: 30,
            icon: const Icon(Icons.place_outlined),
            onPressed: _datos,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _Resumen(
              compra: c,
              listos: listos.length,
            ),
            Expanded(
              child: c.renglones.isEmpty
                  ? const _Vacio()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: c.renglones.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: Paleta.borde),
                      itemBuilder: (context, i) {
                        final r = c.renglones[i];
                        return _Renglon(
                          renglon: r,
                          listo: _listos.contains(r.animal.id),
                          onPrecio: () => _precio(r),
                          onVendedor: () => _vendedor(r),
                          onQuitar: () => _quitar(r),
                          onListo: (v) => setState(() {
                            if (v) {
                              _listos.add(r.animal.id);
                            } else {
                              _listos.remove(r.animal.id);
                            }
                          }),
                        );
                      },
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
                      onPressed: _ciclo,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: BotonGrande(
                      etiqueta: 'SIN ARETE',
                      icono: Icons.add,
                      contorno: true,
                      onPressed: _sinArete,
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
          'Empieza a pesar.\n\n'
          'Escanea el arete, pon el peso y pica la categoría. La cámara vuelve '
          'sola para el siguiente.\n\n'
          'El precio, el vendedor y lo demás se ponen después, ya sin nadie '
          'esperando.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: Paleta.textoSuave),
        ),
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.compra, required this.listos});

  final CompraConCostos compra;
  final int listos;

  @override
  Widget build(BuildContext context) {
    final r = compra.resumen;

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _pesos(r.total),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${compra.cabezas} '
                  '${compra.cabezas == 1 ? 'cabeza' : 'cabezas'}  ·  '
                  '${compra.kilosTotales.toStringAsFixed(0)} kg',
                  style: const TextStyle(
                    fontSize: 17,
                    color: Paleta.textoSuave,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (compra.lote.lugar != null) ...[
            const SizedBox(height: 4),
            Text(
              'Recogidos en ${compra.lote.lugar}',
              style: const TextStyle(fontSize: 16, color: Paleta.textoSuave),
            ),
          ],
          if (compra.cabezas > 0) ...[
            const SizedBox(height: 8),
            Text(
              '$listos de ${compra.cabezas} listos',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: listos == compra.cabezas
                    ? Paleta.accion
                    : Paleta.textoSuave,
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
    required this.listo,
    required this.onPrecio,
    required this.onVendedor,
    required this.onQuitar,
    required this.onListo,
  });

  final RenglonCompra renglon;
  final bool listo;
  final VoidCallback onPrecio;
  final VoidCallback onVendedor;
  final VoidCallback onQuitar;
  final ValueChanged<bool> onListo;

  @override
  Widget build(BuildContext context) {
    final costo = renglon.costo;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  renglon.titulo,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Text(
                costo.seSabe ? _pesos(costo.total!) : '—',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Checkbox(
                value: listo,
                onChanged: (v) => onListo(v ?? false),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                '${renglon.categoria.etiqueta}  ·  '
                '${renglon.pesoCompraKg == null ? 'sin pesar' : '${renglon.pesoCompraKg!.toStringAsFixed(0)} kg'}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Paleta.textoSuave,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Quitar',
                iconSize: 22,
                icon: const Icon(Icons.close),
                onPressed: onQuitar,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _Campo(
                  etiqueta: renglon.precioPorKilo == null
                      ? '\$ __ por kg'
                      : '${_pesos(renglon.precioPorKilo!)} por kg',
                  vacio: renglon.precioPorKilo == null,
                  onTap: onPrecio,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Campo(
                  etiqueta: renglon.vendedor,
                  vacio: false,
                  onTap: onVendedor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Campo extends StatelessWidget {
  const _Campo({
    required this.etiqueta,
    required this.vacio,
    required this.onTap,
  });

  final String etiqueta;
  final bool vacio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: vacio ? Paleta.aviso : Paleta.borde,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          etiqueta,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: vacio ? Paleta.aviso : Paleta.texto,
          ),
        ),
      ),
    );
  }
}

class _DialogoVendedor extends StatefulWidget {
  const _DialogoVendedor({required this.inicial, required this.previos});

  final String inicial;
  final List<String> previos;

  @override
  State<_DialogoVendedor> createState() => _DialogoVendedorState();
}

class _DialogoVendedorState extends State<_DialogoVendedor> {
  late final _campo = TextEditingController(text: widget.inicial);

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('A quién se lo compraste'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Se arrastra a los de abajo que no hayas marcado como listos.',
            style: TextStyle(fontSize: 15, color: Paleta.textoSuave),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _campo,
            autofocus: true,
            style: const TextStyle(fontSize: 20),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          if (widget.previos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final v in widget.previos)
                    ActionChip(
                      label: Text(v, style: const TextStyle(fontSize: 16)),
                      onPressed: () => setState(() => _campo.text = v),
                    ),
                ],
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
            final n = _campo.text.trim();
            if (n.isNotEmpty) Navigator.pop(context, n);
          },
          child: const Text('Guardar', style: TextStyle(fontSize: 18)),
        ),
      ],
    );
  }
}

class _DialogoLugarRecogida extends StatefulWidget {
  const _DialogoLugarRecogida({required this.inicial});

  final String? inicial;

  @override
  State<_DialogoLugarRecogida> createState() => _DialogoLugarRecogidaState();
}

class _DialogoLugarRecogidaState extends State<_DialogoLugarRecogida> {
  late final _campo = TextEditingController(text: widget.inicial ?? '');

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Dónde los recogiste'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'El punto donde te los entregaron. No es un lugar de tu rancho: '
            'ese se lo pones cuando lleguen.',
            style: TextStyle(fontSize: 15, color: Paleta.textoSuave),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _campo,
            autofocus: true,
            style: const TextStyle(fontSize: 20),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(fontSize: 18)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _campo.text.trim()),
          child: const Text('Guardar', style: TextStyle(fontSize: 18)),
        ),
      ],
    );
  }
}
