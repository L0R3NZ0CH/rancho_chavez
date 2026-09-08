import 'package:flutter_test/flutter_test.dart';
import 'package:ganado/domain/reglas/costo_compra.dart';

AnimalDelLote animal(String id, {double? peso, double? individual}) =>
    AnimalDelLote(
      animalId: id,
      pesoCompraKg: peso,
      costoIndividual: individual,
    );

double sumaTotal(List<CostoAnimal> costos) =>
    costos.fold<double>(0, (s, c) => s + c.total);

void main() {
  group('compra por kilo', () {
    test('el costo sale del peso de recepcion y es real, no repartido', () {
      final r = calcularCostosLote(
        animales: [animal('a', peso: 200), animal('b', peso: 250)],
        forma: FormaCalculo.porKilo,
        precioPorKilo: 60,
        montoTotal: 27000,
      );

      expect(r[0].costoBase, 12000); // 200 kg x 60
      expect(r[1].costoBase, 15000); // 250 kg x 60
      expect(r.every((c) => !c.esProrrateado), isTrue);
    });

    test('un animal sin pesar queda marcado como prorrateado', () {
      // Este es el caso que hay que poder ver: es un hueco que se tapa yendo
      // a pesar al animal, no un destino.
      final r = calcularCostosLote(
        animales: [
          animal('pesado', peso: 200),
          animal('sinPesar'),
        ],
        forma: FormaCalculo.porKilo,
        precioPorKilo: 60,
        montoTotal: 20000,
      );

      final pesado = r.firstWhere((c) => c.animalId == 'pesado');
      final sinPesar = r.firstWhere((c) => c.animalId == 'sinPesar');

      expect(pesado.esProrrateado, isFalse);
      expect(pesado.costoBase, 12000);

      expect(sinPesar.esProrrateado, isTrue);
      expect(sinPesar.costoBase, 8000); // lo que sobro del total
    });
  });

  group('compra por cabeza', () {
    test('reparte parejo y lo marca como prorrateado', () {
      final r = calcularCostosLote(
        animales: [animal('a'), animal('b'), animal('c')],
        forma: FormaCalculo.porCabeza,
        montoTotal: 30000,
      );

      expect(r.every((c) => c.costoBase == 10000), isTrue);
      expect(r.every((c) => c.esProrrateado), isTrue);
    });
  });

  group('precio individual', () {
    test('gana sobre el calculo por kilo', () {
      final r = calcularCostosLote(
        animales: [
          animal('negociado', peso: 200, individual: 9000),
          animal('normal', peso: 200),
        ],
        forma: FormaCalculo.porKilo,
        precioPorKilo: 60,
        montoTotal: 21000,
      );

      expect(r[0].costoBase, 9000);
      expect(r[0].esProrrateado, isFalse);
      expect(r[1].costoBase, 12000);
    });

    test('gana sobre el reparto por cabeza', () {
      final r = calcularCostosLote(
        animales: [animal('caro', individual: 15000), animal('resto')],
        forma: FormaCalculo.porCabeza,
        montoTotal: 25000,
      );

      expect(r[0].costoBase, 15000);
      expect(r[0].esProrrateado, isFalse);
      expect(r[1].costoBase, 10000); // lo que quedo del total
    });
  });

  group('la suma tiene que cuadrar con lo que se pago', () {
    test('por cabeza', () {
      final r = calcularCostosLote(
        animales: [animal('a'), animal('b'), animal('c')],
        forma: FormaCalculo.porCabeza,
        montoTotal: 31000,
        gastos: 3000,
      );
      expect(sumaTotal(r), closeTo(34000, 0.001));
    });

    test('por kilo, con todos pesados', () {
      final r = calcularCostosLote(
        animales: [animal('a', peso: 200), animal('b', peso: 300)],
        forma: FormaCalculo.porKilo,
        precioPorKilo: 60,
        montoTotal: 30000,
        gastos: 2000,
      );
      expect(sumaTotal(r), closeTo(32000, 0.001));
    });

    test('por kilo, con uno sin pesar', () {
      final r = calcularCostosLote(
        animales: [animal('a', peso: 200), animal('b')],
        forma: FormaCalculo.porKilo,
        precioPorKilo: 60,
        montoTotal: 20000,
        gastos: 1000,
      );
      expect(sumaTotal(r), closeTo(21000, 0.001));
    });
  });

  group('gastos del lote', () {
    test('por cabeza se reparten parejo', () {
      final r = calcularCostosLote(
        animales: [animal('a', peso: 100), animal('b', peso: 300)],
        forma: FormaCalculo.porCabeza,
        montoTotal: 20000,
        gastos: 2000,
      );
      expect(r[0].gastosAsignados, 1000);
      expect(r[1].gastosAsignados, 1000);
    });

    test('por kilo cargan mas al animal mas pesado', () {
      final r = calcularCostosLote(
        animales: [animal('a', peso: 100), animal('b', peso: 300)],
        forma: FormaCalculo.porKilo,
        precioPorKilo: 50,
        montoTotal: 20000,
        gastos: 2000,
        prorrateoGastos: FormaProrrateo.porKilo,
      );
      expect(r[0].gastosAsignados, closeTo(500, 0.001));  // 100 de 400 kg
      expect(r[1].gastosAsignados, closeTo(1500, 0.001)); // 300 de 400 kg
    });

    test('si se pide por kilo pero no hay pesos, cae a por cabeza', () {
      // Antes que dividir entre cero o dejar los gastos fuera de la cuenta.
      final r = calcularCostosLote(
        animales: [animal('a'), animal('b')],
        forma: FormaCalculo.porCabeza,
        montoTotal: 20000,
        gastos: 2000,
        prorrateoGastos: FormaProrrateo.porKilo,
      );
      expect(r[0].gastosAsignados, 1000);
      expect(r[1].gastosAsignados, 1000);
    });
  });

  group('casos que no deben reventar', () {
    test('un lote vacio no truena', () {
      expect(
        calcularCostosLote(
          animales: const [],
          forma: FormaCalculo.porCabeza,
          montoTotal: 10000,
        ),
        isEmpty,
      );
    });

    test('nunca hay costos negativos', () {
      // Los precios individuales se pasaron del total del lote: alguien se
      // equivoco capturando. El reparto se va a cero, no a negativo.
      final r = calcularCostosLote(
        animales: [animal('caro', individual: 50000), animal('resto')],
        forma: FormaCalculo.porCabeza,
        montoTotal: 30000,
      );
      expect(r[1].costoBase, 0);
      expect(r.every((c) => c.total >= 0), isTrue);
    });

    test('sin gastos, nadie carga gastos', () {
      final r = calcularCostosLote(
        animales: [animal('a'), animal('b')],
        forma: FormaCalculo.porCabeza,
        montoTotal: 20000,
      );
      expect(r.every((c) => c.gastosAsignados == 0), isTrue);
    });

    test('por kilo sin precio por kilo cae al reparto y lo marca', () {
      final r = calcularCostosLote(
        animales: [animal('a', peso: 200), animal('b', peso: 300)],
        forma: FormaCalculo.porKilo,
        montoTotal: 25000,
      );
      expect(r.every((c) => c.esProrrateado), isTrue);
      expect(sumaTotal(r), closeTo(25000, 0.001));
    });
  });
}
