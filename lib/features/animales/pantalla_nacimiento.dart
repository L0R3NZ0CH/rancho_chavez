import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../comun/fechas.dart';
import '../../comun/tema.dart';
import '../../data/db/base_datos.dart';
import '../../domain/modelos/tipos.dart';

/// Un animal que nació en el rancho.
///
/// No se parece a una compra y por eso tiene su propia pantalla. No hay
/// vendedor ni precio, pero sí hay algo que en una compra casi nunca se sabe:
/// **la fecha de nacimiento de verdad**. Nació ese día y tú lo viste.
///
/// La fecha se elige en un calendario, no con botones de "3 meses, 6 meses".
/// Un becerro que nació ayer no cabe en ninguna opción redonda, y adivinar la
/// edad de un animal cuyo nacimiento presenciaste sería absurdo.
class PantallaNacimiento extends StatefulWidget {
  const PantallaNacimiento({super.key, required this.db});

  final BaseDatos db;

  @override
  State<PantallaNacimiento> createState() => _PantallaNacimientoState();
}

class _PantallaNacimientoState extends State<PantallaNacimiento> {
  Categoria? _categoria;
  late int _fechaNacimiento = hoyAaaammdd();
  String? _ubicacionId;
  double? _pesoKg;
  final _apodo = TextEditingController();
  final _senas = TextEditingController();

  List<Ubicacion> _lugares = const [];
  bool _abiertas = false;
  bool _guardando = false;
  bool _resaltar = false;

  @override
  void initState() {
    super.initState();
    widget.db.verUbicaciones().first.then((u) {
      if (mounted) setState(() => _lugares = u);
    });
  }

  @override
  void dispose() {
    _apodo.dispose();
    _senas.dispose();
    super.dispose();
  }

  List<String> get _faltantes => [
        if (_categoria == null) 'qué es',
      ];

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: DateTime(
        _fechaNacimiento ~/ 10000,
        (_fechaNacimiento ~/ 100) % 100,
        _fechaNacimiento % 100,
      ),
      firstDate: DateTime(hoy.year - 15),
      lastDate: hoy,
      helpText: 'Cuándo nació',
    );
    if (elegida == null || !mounted) return;
    setState(() => _fechaNacimiento = hoyAaaammdd(elegida));
  }

  Future<void> _guardar() async {
    if (_guardando) return;

    if (_faltantes.isNotEmpty) {
      setState(() => _resaltar = true);
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
    try {
      final id = await widget.db.altaAnimal(
        // El sexo sale de la categoria: nadie va a marcar "becerro" y "hembra".
        sexo: _categoria!.sexo!.texto,
        origen: 'nacido',
        proposito: 'comercial',
        fecha: _fechaNacimiento,
        categoria: _categoria!.texto,
        ubicacionId: _ubicacionId,
        fechaNacimiento: _fechaNacimiento,
        nacimientoPrecision: 'exacta',
        apodo: _apodo.text.trim().isEmpty ? null : _apodo.text.trim(),
        descripcionFisica:
            _senas.text.trim().isEmpty ? null : _senas.text.trim(),
      );

      if (_pesoKg != null) {
        await widget.db.registrarPeso(
          animalId: id,
          kilos: _pesoKg!,
          fecha: _fechaNacimiento,
          tipoPesaje: 'nacimiento',
        );
      }

      if (mounted) Navigator.pop(context, id);
    } on Exception catch (e) {
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
      appBar: AppBar(title: const Text('Nació en el rancho')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                children: [
                  _Seccion(
                    titulo: 'Cuándo nació',
                    hijo: Material(
                      color: Paleta.fondoSuave,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _elegirFecha,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 68),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              const Icon(Icons.event,
                                  size: 28, color: Paleta.textoSuave),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  formateaAaaammdd(_fechaNacimiento),
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const Icon(Icons.edit,
                                  size: 22, color: Paleta.textoSuave),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  _Seccion(
                    titulo: 'Qué es',
                    obligatorio: true,
                    falta: _resaltar && _categoria == null,
                    hijo: Column(
                      children: [
                        for (final c in Categoria.principales)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _Opcion(
                              etiqueta: c.etiqueta.toUpperCase(),
                              activo: _categoria == c,
                              onTap: () => setState(() => _categoria = c),
                            ),
                          ),
                        if (_abiertas)
                          for (final c in Categoria.otras)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _Opcion(
                                etiqueta: c.etiqueta.toUpperCase(),
                                activo: _categoria == c,
                                onTap: () => setState(() => _categoria = c),
                              ),
                            )
                        else
                          SizedBox(
                            height: 56,
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () =>
                                  setState(() => _abiertas = true),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Paleta.textoSuave,
                                side: const BorderSide(
                                  color: Paleta.borde,
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                '+ otras',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  _Seccion(
                    titulo: 'Dónde está',
                    subtitulo: 'Opcional. Sin lugar queda en "Sin lugar".',
                    hijo: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _Chip(
                          etiqueta: 'Sin lugar',
                          activo: _ubicacionId == null,
                          onTap: () => setState(() => _ubicacionId = null),
                        ),
                        for (final u in _lugares)
                          _Chip(
                            etiqueta: u.nombre,
                            activo: _ubicacionId == u.id,
                            onTap: () => setState(() => _ubicacionId = u.id),
                          ),
                      ],
                    ),
                  ),
                  _Seccion(
                    titulo: 'Peso al nacer',
                    subtitulo: 'Opcional.',
                    hijo: TextField(
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        suffixText: 'kg',
                      ),
                      onChanged: (v) => _pesoKg =
                          double.tryParse(v.trim().replaceAll(',', '.')),
                    ),
                  ),
                  _Seccion(
                    titulo: 'Apodo y señas',
                    subtitulo: 'Opcional.',
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
                          controller: _senas,
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
      width: double.infinity,
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
                style: TextStyle(
                  fontSize: 20,
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
