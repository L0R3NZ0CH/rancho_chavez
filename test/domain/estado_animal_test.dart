import 'package:flutter_test/flutter_test.dart';
import 'package:ganado/domain/reglas/estado_animal.dart';

Movimiento mov(int fecha, {int creado = 0, String id = 'a', String a = 'u1'}) =>
    Movimiento(
      fechaEvento: fecha,
      creadoEn: creado,
      id: id,
      ubicacionDestinoId: a,
    );

Pesaje peso(double kg, int fecha, {int creado = 0, String id = 'a'}) =>
    Pesaje(fechaEvento: fecha, creadoEn: creado, id: id, kilos: kg);

void main() {
  group('ubicacion actual', () {
    test('sin movimientos no hay ubicacion, y no revienta', () {
      expect(ubicacionActual([]), isNull);
    });

    test('gana el movimiento con la fecha mas reciente', () {
      final r = ubicacionActual([
        mov(20260101, a: 'zacatal'),
        mov(20260601, a: 'loma'),
        mov(20260301, a: 'arroyo'),
      ]);
      expect(r!.ubicacionId, 'loma');
      expect(r.desde, 20260601);
    });

    test('un movimiento capturado hoy con fecha vieja no se vuelve el actual',
        () {
      // El caso real: el lunes capturas el movimiento del viernes pasado.
      final r = ubicacionActual([
        mov(20260601, creado: 100, a: 'loma'),
        mov(20260520, creado: 999, a: 'arroyo'), // tecleado despues
      ]);
      expect(r!.ubicacionId, 'loma');
    });

    test('con la misma fecha desempata el orden de captura', () {
      final r = ubicacionActual([
        mov(20260601, creado: 100, a: 'loma'),
        mov(20260601, creado: 200, a: 'arroyo'),
      ]);
      expect(r!.ubicacionId, 'arroyo');
    });

    test('con la misma fecha y la misma captura desempata el id', () {
      // Sin este tercer criterio, dos celulares podrian derivar ubicaciones
      // distintas del mismo dato el dia que haya sincronizacion.
      final r = ubicacionActual([
        mov(20260601, creado: 100, id: 'aaa', a: 'loma'),
        mov(20260601, creado: 100, id: 'bbb', a: 'arroyo'),
      ]);
      expect(r!.ubicacionId, 'arroyo');
    });

    test('el resultado no depende del orden en que vengan los movimientos', () {
      final lista = [
        mov(20260101, creado: 1, id: 'a', a: 'zacatal'),
        mov(20260601, creado: 2, id: 'b', a: 'loma'),
        mov(20260301, creado: 3, id: 'c', a: 'arroyo'),
      ];
      final directo = ubicacionActual(lista)!.ubicacionId;
      final alReves = ubicacionActual(lista.reversed.toList())!.ubicacionId;
      expect(directo, alReves);
      expect(directo, 'loma');
    });
  });

  group('ultimo peso', () {
    test('sin pesajes devuelve null', () {
      expect(ultimoPeso([]), isNull);
    });

    test('gana el de la fecha mas reciente', () {
      final r = ultimoPeso([
        peso(180, 20260301),
        peso(215, 20260801),
        peso(200, 20260601),
      ]);
      expect(r!.kilos, 215);
      expect(r.fechaEvento, 20260801);
    });

    test('un pesaje viejo capturado despues no desplaza al ultimo', () {
      final r = ultimoPeso([
        peso(215, 20260801, creado: 10),
        peso(150, 20260101, creado: 999),
      ]);
      expect(r!.kilos, 215);
    });

    test('dos pesajes el mismo dia: gana el capturado despues', () {
      // Se pesa, se anota mal, se vuelve a pesar. El bueno es el segundo.
      final r = ultimoPeso([
        peso(205, 20260801, creado: 100),
        peso(215, 20260801, creado: 200),
      ]);
      expect(r!.kilos, 215);
    });
  });

  group('dias entre fechas', () {
    test('cuenta dias corridos', () {
      expect(diasEntre(20260901, 20260908), 7);
    });

    test('cruza fin de mes y fin de anio', () {
      expect(diasEntre(20260228, 20260301), 1);
      expect(diasEntre(20261231, 20270101), 1);
    });

    test('cuenta bien un anio bisiesto', () {
      expect(diasEntre(20240228, 20240301), 2); // 2024 es bisiesto
      expect(diasEntre(20260101, 20270101), 365);
      expect(diasEntre(20240101, 20250101), 366);
    });

    test('la misma fecha son cero dias', () {
      expect(diasEntre(20260908, 20260908), 0);
    });
  });
}
