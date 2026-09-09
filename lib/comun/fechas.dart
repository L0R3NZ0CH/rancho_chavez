/// Las fechas de los hechos del rancho se guardan como AAAAMMDD, no como
/// instante UTC.
///
/// La razon es el tiempo de retiro: si la fecha de un tratamiento se guarda
/// como instante y el celular cruza una zona horaria o cambia el horario de
/// verano, la fecha puede correrse un dia. Ese dia decide si un animal se
/// puede vender o si el rastro lo decomisa.
int hoyAaaammdd([DateTime? ahora]) {
  final d = ahora ?? DateTime.now();
  return d.year * 10000 + d.month * 100 + d.day;
}

String formateaAaaammdd(int v) {
  final dia = (v % 100).toString().padLeft(2, '0');
  final mes = ((v ~/ 100) % 100).toString().padLeft(2, '0');
  final anio = (v ~/ 10000).toString();
  return '$dia/$mes/$anio';
}

/// Los dias, dichos como los diria una persona.
///
/// "hace 1 dias" se lee como un error de la app, y quien lo lee deja de confiar
/// en los demas numeros de la pantalla.
String diasEnPalabras(int dias) => switch (dias) {
      0 => 'hoy',
      1 => 'ayer',
      _ => 'hace $dias días',
    };

/// Instante de auditoria: milisegundos UTC desde la epoca.
int ahoraUtcMs() => DateTime.now().toUtc().millisecondsSinceEpoch;
