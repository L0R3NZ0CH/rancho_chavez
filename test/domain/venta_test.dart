import 'package:flutter_test/flutter_test.dart';
import 'package:ganado/domain/reglas/venta.dart';

AnimalEnVenta animal({
  String id = 'a',
  double? pesoVenta,
  double? precio,
  int? fechaVenta,
  double? pesoCompra,
  double? costo,
  int? fechaCompra,
}) =>
    AnimalEnVenta(
      animalId: id,
      pesoVentaKg: pesoVenta,
      precioVentaPorKilo: precio,
      fechaVenta: fechaVenta,
      pesoCompraKg: pesoCompra,
      costoCompra: costo,
      fechaCompra: fechaCompra,
    );

void main() {
  group('lo que se cobra', () {
    test('es el peso de venta por el precio acordado', () {
      final r = calcularVenta(animal(pesoVenta: 250, precio: 75));
      expect(r.importe, closeTo(18750, 0.001));
    });

    test('sin precio no se sabe, y no se inventa un cero', () {
      // La columna del precio empieza vacia a proposito: el trato puede
      // llegar despues de pesar. Un cero se leeria como si se regalara.
      final r = calcularVenta(animal(pesoVenta: 250));
      expect(r.importe, isNull);
      expect(r.seSabeImporte, isFalse);
    });

    test('sin pesar tampoco se sabe', () {
      expect(calcularVenta(animal(precio: 75)).importe, isNull);
    });
  });

  group('la diferencia contra lo que costo', () {
    test('es lo que se cobra menos lo que costo', () {
      final r = calcularVenta(
        animal(pesoVenta: 250, precio: 75, costo: 11160),
      );
      expect(r.diferencia, closeTo(7590, 0.001));
    });

    test('puede salir negativa y se dice tal cual', () {
      // Si se perdio dinero, hay que verlo.
      final r = calcularVenta(
        animal(pesoVenta: 200, precio: 50, costo: 12000),
      );
      expect(r.diferencia, closeTo(-2000, 0.001));
    });

    test('un animal nacido en el rancho no tiene con que compararse', () {
      final r = calcularVenta(animal(pesoVenta: 250, precio: 75));
      expect(r.importe, isNotNull);
      expect(r.diferencia, isNull);
    });

    test('comprado sin capturar el precio tampoco', () {
      final r = calcularVenta(
        animal(pesoVenta: 250, precio: 75, pesoCompra: 180),
      );
      expect(r.diferencia, isNull);
      // Pero los kilos si se saben, porque hay los dos pesajes.
      expect(r.kilosGanados, closeTo(70, 0.001));
    });
  });

  group('lo que hizo el animal', () {
    test('los kilos que engordo', () {
      final r = calcularVenta(animal(pesoVenta: 250, pesoCompra: 180));
      expect(r.kilosGanados, closeTo(70, 0.001));
    });

    test('puede haber bajado de peso y se dice', () {
      final r = calcularVenta(animal(pesoVenta: 160, pesoCompra: 180));
      expect(r.kilosGanados, closeTo(-20, 0.001));
    });

    test('los dias que estuvo', () {
      final r = calcularVenta(
        animal(fechaCompra: 20260608, fechaVenta: 20260908),
      );
      expect(r.dias, 92);
    });

    test('la ganancia diaria', () {
      final r = calcularVenta(animal(
        pesoVenta: 250,
        pesoCompra: 180,
        fechaCompra: 20260608,
        fechaVenta: 20260908,
      ));
      expect(r.gananciaDiaria, closeTo(70 / 92, 0.0001));
    });

    test('vendido el mismo dia que se compro no da ganancia infinita', () {
      // Dividir entre cero dias daria infinito, y se pintaria como un numero.
      final r = calcularVenta(animal(
        pesoVenta: 200,
        pesoCompra: 180,
        fechaCompra: 20260908,
        fechaVenta: 20260908,
      ));
      expect(r.dias, 0);
      expect(r.gananciaDiaria, isNull);
    });

    test('sin fechas no hay dias ni ganancia diaria', () {
      final r = calcularVenta(animal(pesoVenta: 250, pesoCompra: 180));
      expect(r.dias, isNull);
      expect(r.gananciaDiaria, isNull);
    });
  });

  group('el total de la venta', () {
    test('suma solo lo que se sabe y cuenta aparte lo que falta', () {
      final animales = [
        animal(id: 'a', pesoVenta: 250, precio: 75, costo: 11160),
        animal(id: 'b', pesoVenta: 300, precio: 75, costo: 14000),
        animal(id: 'c', pesoVenta: 200), // sin precio
      ];
      final r = animales.map(calcularVenta).toList();
      final t = totalDeVenta(r, animales);

      expect(t.importe, closeTo(18750 + 22500, 0.001));
      expect(t.conImporte, 2);
      expect(t.sinImporte, 1);
      // Los kilos si cuentan a los tres: pesarlos es un hecho aparte del trato.
      expect(t.kilos, closeTo(750, 0.001));
    });

    test('la diferencia solo suma a los que tienen con que compararse', () {
      final animales = [
        animal(id: 'a', pesoVenta: 250, precio: 75, costo: 11160),
        animal(id: 'b', pesoVenta: 300, precio: 75), // nacido aqui
      ];
      final r = animales.map(calcularVenta).toList();
      final t = totalDeVenta(r, animales);

      expect(t.diferencia, closeTo(7590, 0.001));
      expect(t.conDiferencia, 1);
    });

    test('una venta vacia no truena', () {
      final t = totalDeVenta(const [], const []);
      expect(t.importe, 0);
      expect(t.conImporte, 0);
      expect(t.sinImporte, 0);
    });
  });
}
