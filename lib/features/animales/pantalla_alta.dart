import 'package:flutter/material.dart';

import '../../comun/fechas.dart';
import '../../comun/tema.dart';
import '../../data/db/base_datos.dart';
import '../../domain/reglas/categoria.dart';
import '../escaneo/pantalla_escaneo.dart';
import '../escaneo/pantalla_teclado.dart';

/// Alta de animal.
///
/// La meta es registrar un animal en menos de quince segundos, y todo el diseno
/// de esta pantalla sale de ahi:
///
///   - Solo el sexo es obligatorio elegirlo. Todo lo demas viene con un valor.
///   - La ubicacion y el proposito se recuerdan del alta anterior, porque en
///     una jornada se dan de alta veinte animales seguidos al mismo potrero.
///   - La fecha de nacimiento no se pide de entrada. Es la unica que volveria
///     laborioso el alta de un lote comprado, y el rancho mira el peso, no la
///     categoria.
///   - El arete es opcional: **el animal existe antes que el arete**.
class PantallaAlta extends StatefulWidget {
  const PantallaAlta({super.key, required this.db, this.numeroArete});

  final BaseDatos db;

  /// Cuando se llega aqui desde un escaneo de un arete que no existia.
  final String? numeroArete;

  @override
  State<PantallaAlta> createState() => _PantallaAltaState();
}

class _PantallaAltaState extends State<PantallaAlta> {
  String? _sexo;
  String? _numero;
  String? _ubicacionId;
  String _proposito = 'comercial';
  String _origen = 'comprado';
  int? _mesesAprox;
  double? _pesoKg;
  final _apodo = TextEditingController();
  final _descripcion = TextEditingController();

  // Datos de la compra. Se capturan aqui y no en otra pantalla porque el
  // momento natural para saber a cuanto salio un becerro es cuando lo estas
  // dando de alta, con el arete en la mano.
  final _vendedor = TextEditingController();
  final _precioKilo = TextEditingController();
  late int _fechaCompra = hoyAaaammdd();
  List<String> _vendedoresPrevios = const [];

  List<Ubicacion> _ubicaciones = const [];
  bool _guardando = false;
  bool _resaltarFaltantes = false;

  @override
  void initState() {
    super.initState();
    _numero = widget.numeroArete;
    _cargarPreferencias();
  }

  @override
  void dispose() {
    for (final c in [_apodo, _descripcion, _vendedor, _precioKilo]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Lo que costo este animal, calculado al vuelo mientras se captura.
  ///
  /// Se muestra en pantalla a proposito: ver "212 kg x $62 = $13,144" antes de
  /// guardar es lo que permite cachar un dedazo en el precio o en el peso.
  double? get _costoCalculado {
    final precio = double.tryParse(_precioKilo.text.trim());
    if (precio == null || precio <= 0) return null;
    final peso = _pesoKg;
    if (peso == null || peso <= 0) return null;
    return peso * precio;
  }

  Future<void> _cargarPreferencias() async {
    final ubis = await widget.db.verUbicaciones().first;
    final ultimaUbicacion = await widget.db.leerAjuste('ultimaUbicacionId');
    final ultimoProposito = await widget.db.leerAjuste('ultimoProposito');
    final vendedores = await widget.db.vendedoresUsados();
    final ultimoVendedor = await widget.db.leerAjuste('ultimoVendedor');
    final ultimoPrecio = await widget.db.leerAjuste('ultimoPrecioKilo');
    if (!mounted) return;

    setState(() {
      _vendedoresPrevios = vendedores;
      // Se recuerdan del alta anterior: en una descarga de camion los cinco
      // becerros vienen del mismo senor y al mismo precio.
      if (_vendedor.text.isEmpty && ultimoVendedor != null) {
        _vendedor.text = ultimoVendedor;
      }
      if (_precioKilo.text.isEmpty && ultimoPrecio != null) {
        _precioKilo.text = ultimoPrecio;
      }
      _ubicaciones = ubis;
      _proposito = ultimoProposito ?? 'comercial';
      // Se recuerda el ultimo lugar usado, pero no se inventa uno: si el
      // usuario nunca ha elegido, el animal queda sin lugar y ya.
      _ubicacionId =
          ubis.any((u) => u.id == ultimaUbicacion) ? ultimaUbicacion : null;
    });
  }

  Future<void> _escanear() async {
    final numero = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const PantallaEscaneo()),
    );
    if (numero == null || !mounted) return;

    final ocupado = await widget.db.animalPorArete(numero);
    if (!mounted) return;
    if (ocupado != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Paleta.alerta,
          content: Text(
            'El arete $numero ya lo trae otro animal.',
            style: const TextStyle(fontSize: 17),
          ),
        ),
      );
      return;
    }
    setState(() => _numero = numero);
  }

  Future<void> _aMano() async {
    final numero = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaTeclado(inicial: _numero ?? ''),
      ),
    );
    if (numero != null && mounted) setState(() => _numero = numero);
  }

  Future<void> _nuevaUbicacion() async {
    final nombre = await showDialog<String>(
      context: context,
      builder: (_) => const _DialogoUbicacion(),
    );
    if (nombre == null || !mounted) return;

    final id = await widget.db.crearUbicacion(nombre: nombre, tipo: 'potrero');
    final ubis = await widget.db.verUbicaciones().first;
    if (!mounted) return;
    setState(() {
      _ubicaciones = ubis;
      _ubicacionId = id;
    });
  }

  /// Que falta para poder guardar.
  ///
  /// Un boton gris que no dice por que esta gris es un boton descompuesto:
  /// el usuario lo pica, no pasa nada, y concluye que la app no sirve. Aqui el
  /// boton siempre se puede picar y, si falta algo, lo dice por su nombre.
  List<String> get _faltantes => [
        if (_sexo == null) 'el sexo',
      ];

  Future<void> _elegirFechaCompra() async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _comoFecha(_fechaCompra),
      firstDate: DateTime(hoy.year - 5),
      lastDate: hoy,
      helpText: 'Cuándo lo compraste',
    );
    if (elegida == null || !mounted) return;
    setState(() => _fechaCompra = hoyAaaammdd(elegida));
  }

  DateTime _comoFecha(int aaaammdd) => DateTime(
        aaaammdd ~/ 10000,
        (aaaammdd ~/ 100) % 100,
        aaaammdd % 100,
      );

  Future<void> _guardar() async {
    if (_guardando) return;


    if (_faltantes.isNotEmpty) {
      setState(() => _resaltarFaltantes = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Paleta.alerta,
          content: Text(
            'Falta ${_faltantes.join(' y ')}.',
            style: const TextStyle(fontSize: 18),
          ),
        ),
      );
      return;
    }

    setState(() => _guardando = true);

    final hoy = hoyAaaammdd();

    // La edad aproximada se convierte a fecha de nacimiento y se marca como
    // estimada, para que no se confunda nunca con una fecha real.
    final int? nacimiento;
    final String precision;
    if (_mesesAprox != null) {
      nacimiento = sumaMeses(hoy, -_mesesAprox!);
      precision = 'estimada';
    } else {
      nacimiento = null;
      precision = 'desconocida';
    }

    try {
      final id = await widget.db.altaAnimal(
        sexo: _sexo!,
        origen: _origen,
        proposito: _proposito,
        ubicacionId: _ubicacionId,
        fecha: hoy,
        numeroArete: _numero,
        apodo: _apodo.text.trim().isEmpty ? null : _apodo.text.trim(),
        fechaNacimiento: nacimiento,
        nacimientoPrecision: precision,
        nacimientoNota: _mesesAprox == null
            ? null
            : 'Edad aproximada de $_mesesAprox meses al darlo de alta',
        descripcionFisica: _descripcion.text.trim().isEmpty
            ? null
            : _descripcion.text.trim(),
      );

      if (_pesoKg != null) {
        await widget.db.registrarPeso(
          animalId: id,
          kilos: _pesoKg!,
          fecha: _origen == 'comprado' ? _fechaCompra : hoy,
          tipoPesaje: _origen == 'comprado' ? 'compra' : 'rutina',
        );
      }

      final vendedor = _vendedor.text.trim();
      if (_origen == 'comprado' && vendedor.isNotEmpty) {
        final precio = double.tryParse(_precioKilo.text.trim());
        // El viaje se arma solo: mismo dia y mismo vendedor caen en la misma
        // compra sin que nadie tenga que crearla.
        final compra = await widget.db.compraDelDia(
          fecha: _fechaCompra,
          vendedor: vendedor,
          formaCalculo: 'porKilo',
          precioPorKilo: precio,
        );
        await widget.db.agregarAnimalALote(
          loteCompraId: compra,
          animalId: id,
        );
        await widget.db.escribirAjuste('ultimoVendedor', vendedor);
        if (precio != null) {
          await widget.db.escribirAjuste(
            'ultimoPrecioKilo',
            _precioKilo.text.trim(),
          );
        }
      }

      // Se recuerdan para el siguiente animal: en una jornada se dan de alta
      // veinte seguidos al mismo potrero.
      if (_ubicacionId != null) {
        await widget.db.escribirAjuste('ultimaUbicacionId', _ubicacionId!);
      }
      await widget.db.escribirAjuste('ultimoProposito', _proposito);

      if (mounted) Navigator.pop(context, id);
    } on Exception catch (e) {
      // Un fallo al guardar no puede quedarse callado: sin esto, el boton
      // parece que no hace nada y no hay forma de saber por que.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Paleta.alerta,
            content: Text(
              'No se pudo guardar: $e',
              style: const TextStyle(fontSize: 17),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo animal')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                children: [
                  _Seccion(
                    titulo: 'Sexo',
                    obligatorio: true,
                    falta: _resaltarFaltantes && _sexo == null,
                    hijo: Row(
                      children: [
                        Expanded(
                          child: _Opcion(
                            etiqueta: 'HEMBRA',
                            activo: _sexo == 'hembra',
                            onTap: () => setState(() => _sexo = 'hembra'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Opcion(
                            etiqueta: 'MACHO',
                            activo: _sexo == 'macho',
                            onTap: () => setState(() => _sexo = 'macho'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _Seccion(
                    titulo: 'Arete',
                    subtitulo: 'Opcional. El animal existe antes que el arete.',
                    hijo: Column(
                      children: [
                        if (_numero != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Paleta.fondoSuave,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _numero!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        if (_numero != null) const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: BotonGrande(
                                etiqueta: _numero == null
                                    ? 'ESCANEAR'
                                    : 'ESCANEAR OTRO',
                                icono: Icons.qr_code_scanner,
                                onPressed: _escanear,
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
                      ],
                    ),
                  ),
                  _Seccion(
                    titulo: 'Dónde está',
                    subtitulo: 'Opcional. Si lo dejas en blanco, queda en '
                        '"Sin lugar" y se lo asignas después.',
                    hijo: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _Chip(
                          etiqueta: 'Sin lugar',
                          activo: _ubicacionId == null,
                          onTap: () => setState(() => _ubicacionId = null),
                        ),
                        for (final u in _ubicaciones)
                          _Chip(
                            etiqueta: u.nombre,
                            activo: _ubicacionId == u.id,
                            onTap: () => setState(() => _ubicacionId = u.id),
                          ),
                        _Chip(
                          etiqueta: '+ Nuevo lugar',
                          activo: false,
                          onTap: _nuevaUbicacion,
                        ),
                      ],
                    ),
                  ),
                  _Seccion(
                    titulo: 'Propósito',
                    hijo: Row(
                      children: [
                        Expanded(
                          child: _Opcion(
                            etiqueta: 'COMERCIAL',
                            activo: _proposito == 'comercial',
                            onTap: () =>
                                setState(() => _proposito = 'comercial'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Opcion(
                            etiqueta: 'PIE DE CRÍA',
                            activo: _proposito == 'pieDeCria',
                            onTap: () =>
                                setState(() => _proposito = 'pieDeCria'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _Seccion(
                    titulo: 'Cómo entró',
                    hijo: Row(
                      children: [
                        Expanded(
                          child: _Opcion(
                            etiqueta: 'COMPRADO',
                            activo: _origen == 'comprado',
                            onTap: () => setState(() => _origen = 'comprado'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Opcion(
                            etiqueta: 'NACIÓ AQUÍ',
                            activo: _origen == 'nacido',
                            onTap: () => setState(() => _origen = 'nacido'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_origen == 'comprado')
                    _Seccion(
                      titulo: 'La compra',
                      subtitulo: 'Opcional, pero es el único momento en que se '
                          'sabe a cuánto salió.',
                      hijo: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FilaFecha(
                            fecha: _fechaCompra,
                            onCambiar: _elegirFechaCompra,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _vendedor,
                            style: const TextStyle(fontSize: 20),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'A quién se lo compraste',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          if (_vendedoresPrevios.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final v in _vendedoresPrevios)
                                    ActionChip(
                                      label: Text(
                                        v,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      onPressed: () =>
                                          setState(() => _vendedor.text = v),
                                    ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _precioKilo,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              prefixText: r'$ ',
                              suffixText: 'por kg',
                              labelText: 'Precio por kilo',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          _Cuenta(
                            pesoKg: _pesoKg,
                            precioKilo:
                                double.tryParse(_precioKilo.text.trim()),
                            total: _costoCalculado,
                          ),
                        ],
                      ),
                    ),
                  _Seccion(
                    titulo: 'Edad aproximada',
                    subtitulo:
                        'Opcional. Solo sirve para calcular la categoria; '
                        'sin ella el animal queda sin clasificar y ya.',
                    hijo: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _Chip(
                          etiqueta: 'No sé',
                          activo: _mesesAprox == null,
                          onTap: () => setState(() => _mesesAprox = null),
                        ),
                        for (final m in [3, 6, 9, 12, 18, 24, 36])
                          _Chip(
                            etiqueta: _edadEnPalabras(m),
                            activo: _mesesAprox == m,
                            onTap: () => setState(() => _mesesAprox = m),
                          ),
                      ],
                    ),
                  ),
                  _Seccion(
                    titulo: 'Peso',
                    subtitulo: 'Opcional, en kilos.',
                    hijo: TextField(
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'kg',
                      ),
                      onChanged: (v) =>
                          setState(() => _pesoKg = double.tryParse(v.trim())),
                    ),
                  ),
                  _Seccion(
                    titulo: 'Apodo y señas',
                    subtitulo: 'Opcional. Ayuda a reconocerlo sin arete.',
                    hijo: Column(
                      children: [
                        TextField(
                          controller: _apodo,
                          style: const TextStyle(fontSize: 19),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Apodo',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _descripcion,
                          maxLines: 2,
                          style: const TextStyle(fontSize: 19),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Color, señas, cuernos',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_faltantes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Falta ${_faltantes.join(' y ')}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Paleta.alerta,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  BotonGrande(
                    etiqueta: _guardando ? 'GUARDANDO...' : 'GUARDAR',
                    icono: Icons.check,
                    onPressed: _guardando ? null : _guardar,
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

/// Los meses, dichos como los diria una persona.
///
/// Dividir entre doce y decir "anios" hacia que 12 y 18 meses se vieran los dos
/// como "1 anios": dos botones distintos con la misma etiqueta.
String _edadEnPalabras(int meses) => switch (meses) {
      < 12 => '$meses meses',
      12 => '1 año',
      18 => 'año y medio',
      _ => '${meses ~/ 12} años',
    };

class _Seccion extends StatelessWidget {
  const _Seccion({
    required this.titulo,
    required this.hijo,
    this.subtitulo,
    this.obligatorio = false,
    this.falta = false,
  });

  final String titulo;
  final String? subtitulo;
  final Widget hijo;
  final bool obligatorio;

  /// Se intento guardar y este campo era el que faltaba.
  final bool falta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: falta ? Paleta.alerta : Paleta.texto,
                ),
              ),
              if (obligatorio)
                const Text(
                  ' *',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Paleta.alerta,
                  ),
                ),
            ],
          ),
          if (subtitulo != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitulo!,
                style: const TextStyle(fontSize: 15, color: Paleta.textoSuave),
              ),
            ),
          const SizedBox(height: 10),
          hijo,
        ],
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({
    required this.etiqueta,
    required this.activo,
    required this.onTap,
  });

  final String etiqueta;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: alturaBoton,
      child: Material(
        color: activo ? Paleta.accion : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: activo ? Paleta.accion : Paleta.borde,
                width: 2.5,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                etiqueta,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: activo ? Colors.white : Paleta.texto,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.etiqueta,
    required this.activo,
    required this.onTap,
  });

  final String etiqueta;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: activo ? Paleta.accion : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          // Altura de sobra para un dedo con guante.
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: activo ? Paleta.accion : Paleta.borde,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              etiqueta,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: activo ? Colors.white : Paleta.texto,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogoUbicacion extends StatefulWidget {
  const _DialogoUbicacion();

  @override
  State<_DialogoUbicacion> createState() => _DialogoUbicacionState();
}

class _DialogoUbicacionState extends State<_DialogoUbicacion> {
  final _nombre = TextEditingController();

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo potrero'),
      content: TextField(
        controller: _nombre,
        autofocus: true,
        style: const TextStyle(fontSize: 20),
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          // El nombre es el que usa el dueno, nunca "Potrero 1".
          hintText: 'El Zacatal',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(fontSize: 18)),
        ),
        TextButton(
          onPressed: () {
            final n = _nombre.text.trim();
            if (n.isNotEmpty) Navigator.pop(context, n);
          },
          child: const Text('Crear', style: TextStyle(fontSize: 18)),
        ),
      ],
    );
  }
}


/// La fecha de la compra, con un boton grande para cambiarla.
///
/// Por omision es hoy, porque lo normal es capturar el mismo dia. Pero se puede
/// mover: a veces el ganado llega el sabado y se captura el lunes, y la fecha
/// del hecho es la del sabado.
class _FilaFecha extends StatelessWidget {
  const _FilaFecha({required this.fecha, required this.onCambiar});

  final int fecha;
  final VoidCallback onCambiar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Paleta.fondoSuave,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onCambiar,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.event, size: 26, color: Paleta.textoSuave),
              const SizedBox(width: 12),
              const Text(
                'Comprado el',
                style: TextStyle(fontSize: 17, color: Paleta.textoSuave),
              ),
              const Spacer(),
              Text(
                formateaAaaammdd(fecha),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.edit, size: 22, color: Paleta.textoSuave),
            ],
          ),
        ),
      ),
    );
  }
}

/// La multiplicacion, a la vista.
///
/// Ver "212 kg x $62 = $13,144" antes de guardar es lo que permite cachar un
/// dedazo en el peso o en el precio. Cuando falta un factor lo dice, en vez de
/// mostrar un cero que se lee como si el animal hubiera salido gratis.
class _Cuenta extends StatelessWidget {
  const _Cuenta({
    required this.pesoKg,
    required this.precioKilo,
    required this.total,
  });

  final double? pesoKg;
  final double? precioKilo;
  final double? total;

  @override
  Widget build(BuildContext context) {
    final listo = total != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: listo ? const Color(0xFFE8F3EC) : Paleta.fondoSuave,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: listo ? Paleta.accion : Paleta.borde,
          width: listo ? 2 : 1.5,
        ),
      ),
      child: listo
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${pesoKg!.toStringAsFixed(0)} kg  ×  '
                  '\$${precioKilo!.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 17,
                    color: Paleta.textoSuave,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${total!.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: Paleta.accion,
                  ),
                ),
              ],
            )
          : Text(
              pesoKg == null && precioKilo == null
                  ? 'Pon el peso y el precio por kilo y aquí sale lo que costó.'
                  : pesoKg == null
                      ? 'Falta el peso para poder sacar la cuenta.'
                      : 'Falta el precio por kilo para poder sacar la cuenta.',
              style: const TextStyle(fontSize: 16, color: Paleta.textoSuave),
            ),
    );
  }
}
