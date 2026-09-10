import 'package:flutter/material.dart';

import '../../comun/confirmar.dart';
import '../../comun/fechas.dart';
import '../../comun/tema.dart';
import '../../data/db/base_datos.dart';
import '../../data/repos/ventas.dart';
import '../animales/pantalla_ficha.dart';
import '../escaneo/pantalla_escaneo.dart';
import 'dialogo_peso.dart';
import 'ficha_venta.dart';
import 'pantalla_resumen_venta.dart';

/// La pantalla de trabajo de una venta.
///
/// **Nada es obligatorio para empezar.** Se abre y se pesa de inmediato; el
/// comprador y el precio se llenan cuando se pueda. El trato casi siempre se
/// acuerda antes de subir el primer animal a la báscula, pero se puede cambiar
/// o quedar pendiente, y un olvido no debe convertirse en un bloqueo a media
/// manga.
///
/// El ritmo importa más que cualquier otra cosa aquí: una venta son veinte o
/// treinta animales, y el ciclo es **escanear, pesar, siguiente** sin tocar
/// nada más. Por eso, al guardar un peso, la cámara vuelve a abrirse sola.
class PantallaVenta extends StatefulWidget {
  const PantallaVenta({super.key, required this.db, required this.ventaId});

  final BaseDatos db;
  final String ventaId;

  @override
  State<PantallaVenta> createState() => _PantallaVentaState();
}

class _PantallaVentaState extends State<PantallaVenta> {
  VentaArmada? _venta;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final v = await RepoVentas(widget.db).verVenta(widget.ventaId);
    if (!mounted) return;
    setState(() {
      _venta = v;
      _cargando = false;
    });
  }

  /// El ciclo: escanear, pesar, y de regreso a la cámara.
  ///
  /// Se repite solo hasta que el usuario cancela. Picar un botón por cada
  /// animal, treinta veces, es lo que hace que la gente vuelva al cuaderno.
  Future<void> _cicloDeEscaneo() async {
    var seguir = true;
    while (seguir) {
      if (!mounted) return;
      final numero = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const PantallaEscaneo()),
      );
      if (numero == null) return;

      seguir = await _agregarYPesar(numero);
    }
  }

  /// Devuelve false cuando hay que salir del ciclo.
  Future<bool> _agregarYPesar(String numero) async {
    final animal = await widget.db.animalPorArete(numero);
    if (!mounted) return false;

    if (animal == null) {
      if (!mounted) return false;
      // No se vende un animal que nunca existio.
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Ese arete no está en el sistema'),
          content: Text(
            'El arete $numero no corresponde a ningún animal.\n\n'
            'Dalo de alta primero desde la pantalla de inicio.',
            style: const TextStyle(fontSize: 17),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Entendido', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      );
      return mounted;
    }

    final yaEsta = (await widget.db.animalesDeVenta(widget.ventaId))
        .any((f) => f.animalId == animal.id);
    if (!mounted) return false;

    if (yaEsta) {
      // Escanear dos veces el mismo pasa cuando se van treinta seguidos. Se
      // avisa y la camara sigue de frente: volver a pedir el peso arriesgaria
      // pisar uno bueno con un dedazo. Para corregirlo esta la lista, donde se
      // hace mirando y sin prisa.
      final peso = await widget.db.pesoDeVenta(animal.id);
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Paleta.aviso,
          duration: const Duration(seconds: 2),
          content: Text(
            peso == null
                ? 'El $numero ya está en la lista, sin pesar.'
                : 'El $numero ya está en la lista, pesó '
                    '${peso.toStringAsFixed(0)} kg.',
            style: const TextStyle(fontSize: 17),
          ),
        ),
      );
      return mounted;
    }

    // Hereda el precio del ultimo que se le puso, que casi siempre es el mismo
    // trato para todo el camion.
    final ultimo = _venta?.renglones
        .where((r) => r.precioPorKilo != null)
        .lastOrNull
        ?.precioPorKilo;
    await widget.db.agregarAnimalAVenta(
      ventaId: widget.ventaId,
      animalId: animal.id,
      precioPorKilo: ultimo,
    );
    if (!mounted) return false;

    final kilos = await pedirPeso(context, titulo: numero);
    if (kilos == null || !mounted) {
      await _cargar();
      return false;
    }

    await widget.db.registrarPeso(
      animalId: animal.id,
      kilos: kilos,
      fecha: _venta?.venta.fecha ?? hoyAaaammdd(),
      tipoPesaje: 'venta',
    );
    await _cargar();
    return mounted;
  }

  Future<void> _aMano() async {
    final numero = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const PantallaEscaneo()),
    );
    if (numero == null || !mounted) return;
    await _agregarYPesar(numero);
  }

  Future<void> _precioATodos() async {
    final precio = await pedirNumero(
      context,
      titulo: 'Precio por kilo',
      explicacion: 'Se le pone a los ${_venta?.cabezas ?? 0} animales de esta '
          'venta. A los que se hayan negociado aparte les cambias el suyo '
          'después, en su renglón.',
      sufijo: 'por kg',
      prefijo: r'$ ',
    );
    if (precio == null || !mounted) return;

    await widget.db.precioParaTodos(
      ventaId: widget.ventaId,
      precioPorKilo: precio,
    );
    await _cargar();
  }

  /// Corregir el peso de un renglon, mirando la lista y sin prisa.
  Future<void> _pesoDeUno(RenglonVenta r) async {
    final kilos = await pedirPeso(
      context,
      titulo: r.titulo,
      inicial: r.pesoVentaKg,
    );
    if (kilos == null || !mounted) return;

    await widget.db.registrarPeso(
      animalId: r.animal.id,
      kilos: kilos,
      fecha: _venta?.venta.fecha ?? hoyAaaammdd(),
      tipoPesaje: 'venta',
    );
    await _cargar();
  }

  Future<void> _precioDeUno(RenglonVenta r) async {
    final precio = await pedirNumero(
      context,
      titulo: 'Precio de ${r.titulo}',
      explicacion: 'Solo para este animal.',
      sufijo: 'por kg',
      prefijo: r'$ ',
      inicial: r.precioPorKilo,
    );
    if (precio == null || !mounted) return;

    await widget.db.fijarPrecioDeVenta(
      ventaId: widget.ventaId,
      animalId: r.animal.id,
      precioPorKilo: precio,
    );
    await _cargar();
  }

  Future<void> _quitar(RenglonVenta r) async {
    final ok = await confirmarBorrado(
      context,
      titulo: 'Quitar de la venta',
      mensaje: 'Se quita ${r.titulo} de esta venta.\n\n'
          'El animal NO se borra ni se vende.',
      etiquetaBoton: 'Quitar',
    );
    if (!(ok ?? false) || !mounted) return;

    await widget.db.quitarAnimalDeVenta(
      ventaId: widget.ventaId,
      animalId: r.animal.id,
    );
    await _cargar();
  }

  Future<void> _datosDeLaVenta() async {
    final v = _venta;
    if (v == null) return;

    final compradores = await widget.db.compradoresUsados();
    if (!mounted) return;

    final datos = await mostrarFichaVenta(
      context,
      venta: v.venta,
      compradoresPrevios: compradores,
    );
    if (datos == null || !mounted) return;

    await widget.db.actualizarVenta(
      ventaId: widget.ventaId,
      comprador: datos.comprador,
      destino: datos.destino,
      fecha: datos.fecha,
    );
    await _cargar();
  }

  /// Reabrir una venta cerrada por error.
  ///
  /// Sin esto, cerrar de mas dejaba a los animales dados de baja para siempre.
  Future<void> _reabrir() async {
    final v = _venta;
    if (v == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Reabrir la venta'),
        content: Text(
          'Los ${v.cabezas} animales vuelven al hato y a sus potreros, y '
          'puedes seguir agregando.\n\n'
          'El historial de la venta se conserva.',
          style: const TextStyle(fontSize: 17),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar', style: TextStyle(fontSize: 18)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Reabrir', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
    if (!(ok ?? false) || !mounted) return;

    await widget.db.reabrirVenta(widget.ventaId);
    await _cargar();
  }

  Future<void> _cerrar() async {
    final v = _venta;
    if (v == null) return;

    final faltan = <String>[
      if (v.sinPesar > 0) '${v.sinPesar} sin pesar',
      if (v.total.sinImporte > 0) '${v.total.sinImporte} sin precio',
    ];

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cerrar la venta'),
        content: Text(
          [
            'Se van a dar de baja ${v.cabezas} '
                '${v.cabezas == 1 ? 'animal' : 'animales'}.',
            'Salen del hato y de los conteos de los potreros. Su historial se '
                'conserva completo.',
            if (faltan.isNotEmpty)
              'Ojo: quedan ${faltan.join(' y ')}. Se pueden cerrar así, pero '
                  'esos no van a contar en el total.',
          ].join('\n\n'),
          style: const TextStyle(fontSize: 17),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar', style: TextStyle(fontSize: 18)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text(
              'Cerrar la venta',
              style: TextStyle(
                fontSize: 18,
                color: Paleta.alerta,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (!(ok ?? false) || !mounted) return;

    await widget.db.cerrarVenta(widget.ventaId);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final v = _venta;

    if (_cargando) {
      return Scaffold(
        appBar: AppBar(title: const Text('Venta')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (v == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Venta')),
        body: const Center(
          child: Text('No se encontró la venta',
              style: TextStyle(fontSize: 18)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(v.venta.comprador ?? 'Venta sin comprador'),
        actions: [
          IconButton(
            tooltip: 'Comprador y fecha',
            iconSize: 30,
            icon: const Icon(Icons.edit_note),
            onPressed: _datosDeLaVenta,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _Totales(
              venta: v,
              onPrecioATodos: _precioATodos,
              onResumen: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PantallaResumenVenta(
                    db: widget.db,
                    ventaId: widget.ventaId,
                  ),
                ),
              ),
            ),
            Expanded(
              child: v.renglones.isEmpty
                  ? const _Vacio()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: v.renglones.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: Paleta.borde),
                      itemBuilder: (context, i) => _Renglon(
                        renglon: v.renglones[i],
                        cerrada: v.cerrada,
                        onPrecio: () => _precioDeUno(v.renglones[i]),
                        onPeso: () => _pesoDeUno(v.renglones[i]),
                        onQuitar: () => _quitar(v.renglones[i]),
                        // Ver el historial antes de ponerle precio: cuanto
                        // costo, cuanto pesaba, que se le hizo.
                        onFicha: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PantallaFicha(
                              db: widget.db,
                              animalId: v.renglones[i].animal.id,
                            ),
                          ),
                        ).then((_) => _cargar()),
                      ),
                    ),
            ),
            if (v.cerrada)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: BotonGrande(
                  etiqueta: 'REABRIR LA VENTA',
                  icono: Icons.lock_open,
                  contorno: true,
                  onPressed: _reabrir,
                ),
              ),
            if (!v.cerrada)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: BotonGrande(
                            etiqueta: 'ESCANEAR Y PESAR',
                            icono: Icons.qr_code_scanner,
                            onPressed: _cicloDeEscaneo,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: BotonGrande(
                            etiqueta: 'A MANO',
                            icono: Icons.dialpad,
                            contorno: true,
                            onPressed: _aMano,
                          ),
                        ),
                      ],
                    ),
                    if (v.cabezas > 0) ...[
                      const SizedBox(height: 10),
                      BotonGrande(
                        etiqueta: 'CERRAR LA VENTA',
                        icono: Icons.check,
                        contorno: true,
                        color: Paleta.alerta,
                        onPressed: _cerrar,
                      ),
                    ],
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
          'Escanea el arete, escribe el peso, y la cámara vuelve sola para el '
          'siguiente.\n\n'
          'El comprador y el precio los pones cuando quieras: antes, a medias '
          'o al final.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: Paleta.textoSuave),
        ),
      ),
    );
  }
}

class _Totales extends StatelessWidget {
  const _Totales({
    required this.venta,
    required this.onPrecioATodos,
    required this.onResumen,
  });

  final VentaArmada venta;
  final VoidCallback onPrecioATodos;
  final VoidCallback onResumen;

  @override
  Widget build(BuildContext context) {
    final t = venta.total;
    final faltan = t.sinImporte;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Paleta.fondoSuave,
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        onTap: venta.cabezas == 0 ? null : onResumen,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _pesos(t.importe),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${venta.cabezas} '
                  '${venta.cabezas == 1 ? 'cabeza' : 'cabezas'}  ·  '
                  '${t.kilos.toStringAsFixed(0)} kg',
                  style: const TextStyle(
                    fontSize: 17,
                    color: Paleta.textoSuave,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (t.conDiferencia > 0) ...[
            const SizedBox(height: 4),
            Text(
              '${t.diferencia >= 0 ? '+' : ''}${_pesos(t.diferencia)} contra lo '
              'que costaron  ·  ${t.conDiferencia} de ${venta.cabezas}',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: t.diferencia >= 0 ? Paleta.accion : Paleta.alerta,
              ),
            ),
          ],
          if (faltan > 0 || venta.sinPesar > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Paleta.aviso,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                // El total no incluye a los que faltan, y hay que decirlo: si
                // no, se leeria como si estuviera completo.
                '${[
                  if (venta.sinPesar > 0) '${venta.sinPesar} sin pesar',
                  if (faltan > 0) '$faltan sin precio',
                ].join('  ·  ')}. '
                'Ese total es de ${t.conImporte} de ${venta.cabezas}.',
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
          ],
          if (!venta.cerrada && venta.cabezas > 0) ...[
            const SizedBox(height: 12),
            BotonGrande(
              etiqueta: 'PONER EL MISMO PRECIO A TODOS',
              icono: Icons.price_change_outlined,
              contorno: true,
              onPressed: onPrecioATodos,
            ),
          ],
          if (venta.cabezas > 0) ...[
            const SizedBox(height: 10),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'VER EL RESUMEN',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Paleta.textoSuave,
                    letterSpacing: 0.5,
                  ),
                ),
                Icon(Icons.chevron_right, size: 20, color: Paleta.textoSuave),
              ],
            ),
          ],
        ],
        ),
      ),
      ),
    );
  }
}

/// Un renglón de la venta: arete, peso, precio y total. Nada más.
class _Renglon extends StatelessWidget {
  const _Renglon({
    required this.renglon,
    required this.cerrada,
    required this.onPrecio,
    required this.onPeso,
    required this.onQuitar,
    required this.onFicha,
  });

  final RenglonVenta renglon;
  final bool cerrada;
  final VoidCallback onPeso;
  final VoidCallback onPrecio;
  final VoidCallback onQuitar;
  final VoidCallback onFicha;

  @override
  Widget build(BuildContext context) {
    final r = renglon.resultado;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: InkWell(
              onTap: onFicha,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  renglon.titulo,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                InkWell(
                  onTap: cerrada ? null : onPeso,
                  child: Row(
                    children: [
                      Text(
                        renglon.pesoVentaKg == null
                            ? 'sin pesar'
                            : '${renglon.pesoVentaKg!.toStringAsFixed(0)} kg',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color:
                              renglon.pesado ? Paleta.texto : Paleta.aviso,
                        ),
                      ),
                      if (!cerrada) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.edit,
                          size: 16,
                          color: Paleta.textoSuave,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: InkWell(
              onTap: cerrada ? null : onPrecio,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                constraints: const BoxConstraints(minHeight: 56),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: renglon.precioPorKilo == null
                        ? Paleta.aviso
                        : Paleta.borde,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  renglon.precioPorKilo == null
                      ? '\$ __'
                      : _pesos(renglon.precioPorKilo!),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: renglon.precioPorKilo == null
                        ? Paleta.aviso
                        : Paleta.texto,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                r.importe == null ? '—' : _pesos(r.importe!),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          if (!cerrada)
            IconButton(
              tooltip: 'Quitar de la venta',
              iconSize: 24,
              icon: const Icon(Icons.close),
              onPressed: onQuitar,
            ),
        ],
      ),
    );
  }
}
