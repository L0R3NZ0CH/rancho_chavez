import 'package:flutter/material.dart';

import '../data/db/base_datos.dart';
import 'fechas.dart';
import 'tema.dart';

/// Si el número de arete se puede usar en un animal nuevo.
///
/// La unicidad del arete aplica **solo entre animales que siguen en el rancho**.
/// Los aretes se reparten y se vuelven a usar: bloquear un número para siempre
/// porque hace dos años lo trajo un becerro que ya se vendió obligaría a
/// inventar números, y a la larga eso ensucia más que reutilizar.
///
/// Tres respuestas posibles:
///
///   - **Libre** — se usa y ya.
///   - **Lo trae un animal que sigue en el rancho** — se bloquea. Dos animales
///     vivos con el mismo arete es un error que después no se puede desenredar.
///   - **Lo trajo uno que ya salió del hato** — se pregunta. Si se acepta, el
///     arete viejo se marca como retirado (no se borra: el historial del animal
///     que se fue conserva el arete que trajo) y el número queda libre.
Future<bool> areteSePuedeUsar(
  BuildContext context,
  BaseDatos db,
  String numero,
) async {
  final ocupado = await db.areteOcupadoPor(numero);
  if (ocupado == null) return true;
  if (!context.mounted) return false;

  final quien = ocupado.animal.apodo ?? 'otro animal';

  if (!ocupado.deBaja) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Paleta.alerta,
        content: Text(
          'El arete $numero lo trae $quien, que sigue en el rancho.',
          style: const TextStyle(fontSize: 17),
        ),
      ),
    );
    return false;
  }

  final reusar = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Ese arete ya se usó'),
      content: Text(
        'El $numero lo trajo un animal que ya salió del hato.\n\n'
        '¿Se lo pones a este?',
        style: const TextStyle(fontSize: 17),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('No', style: TextStyle(fontSize: 18)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: const Text(
            'Sí, úsalo',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  if (!(reusar ?? false)) return false;

  await db.retirarAretePorNumero(numero: numero, fecha: hoyAaaammdd());
  return true;
}
