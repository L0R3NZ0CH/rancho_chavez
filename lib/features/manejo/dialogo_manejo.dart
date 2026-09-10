import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../comun/tema.dart';
import '../../data/db/base_datos.dart';

/// Lo que se le hizo al animal hoy.
typedef Apunte = ({
  double? pesoKg,
  bool banado,
  bool desparasitado,
  String? otro,
  String? nuevoLugarId,
});

/// Registrar un manejo.
///
/// **Es un apunte, no una edición.** Lo que se hizo antes no se toca: si hoy lo
/// bañaste y el mes pasado también, quedan los dos, cada uno con su fecha. Esa
/// es la diferencia entre un control y una casilla que alguien va pisando.
Future<Apunte?> registrarManejo(
  BuildContext context, {
  required String titulo,
  required List<Ubicacion> lugares,
  String? lugarActualId,
}) {
  return showDialog<Apunte>(
    context: context,
    builder: (_) => _DialogoManejo(
      titulo: titulo,
      lugares: lugares,
      lugarActualId: lugarActualId,
    ),
  );
}

class _DialogoManejo extends StatefulWidget {
  const _DialogoManejo({
    required this.titulo,
    required this.lugares,
    required this.lugarActualId,
  });

  final String titulo;
  final List<Ubicacion> lugares;
  final String? lugarActualId;

  @override
  State<_DialogoManejo> createState() => _DialogoManejoState();
}

class _DialogoManejoState extends State<_DialogoManejo> {
  final _peso = TextEditingController();
  final _otro = TextEditingController();
  bool _banado = false;
  bool _desparasitado = false;
  String? _nuevoLugar;

  @override
  void dispose() {
    _peso.dispose();
    _otro.dispose();
    super.dispose();
  }

  bool get _hayAlgo =>
      _peso.text.trim().isNotEmpty ||
      _banado ||
      _desparasitado ||
      _otro.text.trim().isNotEmpty ||
      _nuevoLugar != null;

  @override
  Widget build(BuildContext context) {
    final otrosLugares =
        widget.lugares.where((u) => u.id != widget.lugarActualId).toList();

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(widget.titulo, style: const TextStyle(fontSize: 22)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _peso,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              style:
                  const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Peso',
                suffixText: 'kg',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            _Casilla(
              etiqueta: 'Bañado',
              valor: _banado,
              onCambio: (v) => setState(() => _banado = v),
            ),
            _Casilla(
              etiqueta: 'Desparasitado',
              valor: _desparasitado,
              onCambio: (v) => setState(() => _desparasitado = v),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _otro,
              style: const TextStyle(fontSize: 19),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Otro',
                hintText: 'Lo que le hayas hecho',
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (otrosLugares.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Cambiar de lugar',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final u in otrosLugares)
                    ChoiceChip(
                      label: Text(
                        u.nombre,
                        style: const TextStyle(fontSize: 16),
                      ),
                      selected: _nuevoLugar == u.id,
                      onSelected: (s) =>
                          setState(() => _nuevoLugar = s ? u.id : null),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(fontSize: 18)),
        ),
        TextButton(
          onPressed: _hayAlgo
              ? () => Navigator.pop(context, (
                    pesoKg: double.tryParse(
                      _peso.text.trim().replaceAll(',', '.'),
                    ),
                    banado: _banado,
                    desparasitado: _desparasitado,
                    otro: _otro.text.trim().isEmpty ? null : _otro.text.trim(),
                    nuevoLugarId: _nuevoLugar,
                  ))
              : null,
          child: const Text(
            'Apuntar',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _Casilla extends StatelessWidget {
  const _Casilla({
    required this.etiqueta,
    required this.valor,
    required this.onCambio,
  });

  final String etiqueta;
  final bool valor;
  final ValueChanged<bool> onCambio;

  @override
  Widget build(BuildContext context) {
    // Toda la fila es tocable: con guante, apuntarle al cuadrito es pedir mucho.
    return InkWell(
      onTap: () => onCambio(!valor),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            Checkbox(value: valor, onChanged: (v) => onCambio(v ?? false)),
            const SizedBox(width: 4),
            Text(
              etiqueta,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Paleta.texto,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
