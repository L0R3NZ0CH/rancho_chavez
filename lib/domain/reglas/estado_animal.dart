/// Como se deriva el estado actual de un animal a partir de sus eventos.
///
/// Todas las derivaciones siguen el mismo patron: **gana el evento mas reciente
/// de su tipo**, ordenando por tres criterios, y los tres importan:
///
///   1. `fechaEvento` — la fecha del hecho. Es la verdad del rancho, y permite
///      capturar hoy el trabajo de ayer sin que quede fuera de lugar.
///   2. `creadoEn`    — desempata dos eventos con la misma fecha, capturados el
///      mismo dia.
///   3. `id`          — desempata lo que quede. Sin este tercer criterio, el
///      mismo dato podria dar respuestas distintas en dos celulares el dia que
///      haya sincronizacion.
///
/// Este archivo no sabe de drift ni de Flutter: recibe datos planos y devuelve
/// resultados, para poder probarse en milisegundos y leerse sin saber SQL.
library;

/// Lo minimo que necesita el ordenamiento.
///
/// Es clase y no record a proposito: en Dart los records no son subtipos por
/// tener campos de mas, asi que con records no se podria escribir una sola
/// funcion de ordenamiento que sirva para movimientos y para pesajes.
abstract class EventoBase {
  const EventoBase({
    required this.fechaEvento,
    required this.creadoEn,
    required this.id,
  });

  /// AAAAMMDD del hecho.
  final int fechaEvento;

  /// Instante UTC en milisegundos en que se capturo.
  final int creadoEn;

  final String id;
}

/// Un movimiento reducido a lo que hace falta para saber donde esta el animal.
class Movimiento extends EventoBase {
  const Movimiento({
    required super.fechaEvento,
    required super.creadoEn,
    required super.id,
    required this.ubicacionDestinoId,
  });

  final String ubicacionDestinoId;
}

/// Un pesaje reducido a lo que hace falta para saber cuanto peso.
class Pesaje extends EventoBase {
  const Pesaje({
    required super.fechaEvento,
    required super.creadoEn,
    required super.id,
    required this.kilos,
  });

  final double kilos;
}

/// Compara dos eventos por los tres criterios. Negativo si [a] es mas reciente.
int comparaEventos(EventoBase a, EventoBase b) {
  if (a.fechaEvento != b.fechaEvento) {
    return b.fechaEvento.compareTo(a.fechaEvento);
  }
  if (a.creadoEn != b.creadoEn) return b.creadoEn.compareTo(a.creadoEn);
  return b.id.compareTo(a.id);
}

/// El evento mas reciente de la lista, o null si esta vacia.
///
/// Recorre una sola vez en vez de ordenar: el resultado no depende del orden en
/// que vengan los eventos.
T? masReciente<T extends EventoBase>(List<T> eventos) {
  if (eventos.isEmpty) return null;
  var ganador = eventos.first;
  for (final e in eventos.skip(1)) {
    if (comparaEventos(e, ganador) < 0) ganador = e;
  }
  return ganador;
}

/// Donde esta parado el animal ahora.
///
/// Es el destino de su movimiento mas reciente. Devuelve null cuando el animal
/// no tiene ningun movimiento: no deberia pasar, porque el alta siempre emite
/// uno, pero la interfaz tiene que poder decir "sin ubicacion" en vez de
/// reventar.
({String ubicacionId, int desde})? ubicacionActual(
  List<Movimiento> movimientos,
) {
  final ultimo = masReciente(movimientos);
  if (ultimo == null) return null;
  return (ubicacionId: ultimo.ubicacionDestinoId, desde: ultimo.fechaEvento);
}

/// Cuanto peso la ultima vez, y cuando.
///
/// "Ultima vez" es por la fecha del pesaje, no por cuando se tecleo. Si manana
/// alguien captura un pesaje con fecha del mes pasado, ese **no** se vuelve el
/// ultimo: la historia se ordena por el hecho, no por la captura.
Pesaje? ultimoPeso(List<Pesaje> pesajes) => masReciente(pesajes);

/// Dias transcurridos entre dos fechas AAAAMMDD.
///
/// Se convierte a dias julianos en vez de usar DateTime.difference, para que un
/// cambio de horario de verano no reste ni sume un dia.
int diasEntre(int desde, int hasta) => _juliano(hasta) - _juliano(desde);

int _juliano(int aaaammdd) {
  final anio = aaaammdd ~/ 10000;
  final mes = (aaaammdd ~/ 100) % 100;
  final dia = aaaammdd % 100;

  final a = (14 - mes) ~/ 12;
  final y = anio + 4800 - a;
  final m = mes + 12 * a - 3;

  return dia +
      (153 * m + 2) ~/ 5 +
      365 * y +
      y ~/ 4 -
      y ~/ 100 +
      y ~/ 400 -
      32045;
}
