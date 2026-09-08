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

  List<Ubicacion> _ubicaciones = const [];
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _numero = widget.numeroArete;
    _cargarPreferencias();
  }

  @override
  void dispose() {
    _apodo.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _cargarPreferencias() async {
    final ubis = await widget.db.verUbicaciones().first;
    final ultimaUbicacion = await widget.db.leerAjuste('ultimaUbicacionId');
    final ultimoProposito = await widget.db.leerAjuste('ultimoProposito');
    if (!mounted) return;

    setState(() {
      _ubicaciones = ubis;
      _proposito = ultimoProposito ?? 'comercial';
      _ubicacionId = ubis.any((u) => u.id == ultimaUbicacion)
          ? ultimaUbicacion
          : (ubis.isNotEmpty ? ubis.first.id : null);
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

  Future<void> _guardar() async {
    if (_sexo == null || _ubicacionId == null || _guardando) return;
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
        ubicacionId: _ubicacionId!,
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
          fecha: hoy,
          tipoPesaje: _origen == 'comprado' ? 'compra' : 'rutina',
        );
      }

      // Se recuerdan para el siguiente animal: en una jornada se dan de alta
      // veinte seguidos al mismo potrero.
      await widget.db.escribirAjuste('ultimaUbicacionId', _ubicacionId!);
      await widget.db.escribirAjuste('ultimoProposito', _proposito);

      if (mounted) Navigator.pop(context, id);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listo = _sexo != null && _ubicacionId != null && !_guardando;

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
                    titulo: 'Donde esta',
                    obligatorio: true,
                    hijo: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final u in _ubicaciones)
                          _Chip(
                            etiqueta: u.nombre,
                            activo: _ubicacionId == u.id,
                            onTap: () => setState(() => _ubicacionId = u.id),
                          ),
                        _Chip(
                          etiqueta: '+ Nuevo potrero',
                          activo: false,
                          onTap: _nuevaUbicacion,
                        ),
                      ],
                    ),
                  ),
                  _Seccion(
                    titulo: 'Proposito',
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
                            etiqueta: 'PIE DE CRIA',
                            activo: _proposito == 'pieDeCria',
                            onTap: () =>
                                setState(() => _proposito = 'pieDeCria'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _Seccion(
                    titulo: 'Como entro',
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
                            etiqueta: 'NACIO AQUI',
                            activo: _origen == 'nacido',
                            onTap: () => setState(() => _origen = 'nacido'),
                          ),
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
                          etiqueta: 'No se',
                          activo: _mesesAprox == null,
                          onTap: () => setState(() => _mesesAprox = null),
                        ),
                        for (final m in [3, 6, 9, 12, 18, 24, 36])
                          _Chip(
                            etiqueta: m < 12 ? '$m meses' : '${m ~/ 12} anios',
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
                      onChanged: (v) => _pesoKg = double.tryParse(v.trim()),
                    ),
                  ),
                  _Seccion(
                    titulo: 'Apodo y senas',
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
                            hintText: 'Color, senas, cuernos',
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
              child: BotonGrande(
                etiqueta: _guardando ? 'GUARDANDO...' : 'GUARDAR',
                icono: Icons.check,
                onPressed: listo ? _guardar : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({
    required this.titulo,
    required this.hijo,
    this.subtitulo,
    this.obligatorio = false,
  });

  final String titulo;
  final String? subtitulo;
  final Widget hijo;
  final bool obligatorio;

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
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
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
