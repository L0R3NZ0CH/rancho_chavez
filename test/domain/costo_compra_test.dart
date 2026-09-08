import 'package:flutter_test/flutter_test.dart';
import 'package:ganado/domain/reglas/costo_compra.dart';

void main() {
  group('cotizado por kilo', () {
    test('el costo es el peso por el precio del kilo', () {
      final c = costoDelAnimal(const CompraDeAnimal(
        forma: FormaCotizacion.porKilo,
        precioPorKilo: 62,
        pesoCompraKg: 212,
      ));
      expect(c.seSabe, isTrue);
      expect(c.total, closeTo(13144, 0.001));
    });

    test('sin pesar no se sabe, y no se inventa un numero', () {
      // Es el caso que motivo quitar el prorrateo: un hueco visible se tapa
      // yendo a pesar al animal; una cifra falsa se arrastra para siempre.
      final c = costoDelAnimal(const CompraDeAnimal(
        forma: FormaCotizacion.porKilo,
        precioPorKilo: 62,
      ));
      expect(c.seSabe, isFalse);
      expect(c.total, isNull);
      expect(c.falta, FaltaDato.peso);
    });

    test('sin precio tampoco se sabe, y lo dice', () {
      final c = costoDelAnimal(const CompraDeAnimal(
        forma: FormaCotizacion.porKilo,
        pesoCompraKg: 212,
      ));
      expect(c.falta, FaltaDato.precio);
    });

    test('un peso o un precio en cero se tratan como si faltaran', () {
      expect(
        costoDelAnimal(const CompraDeAnimal(
          forma: FormaCotizacion.porKilo,
          precioPorKilo: 0,
          pesoCompraKg: 212,
        )).falta,
        FaltaDato.precio,
      );
      expect(
        costoDelAnimal(const CompraDeAnimal(
          forma: FormaCotizacion.porKilo,
          precioPorKilo: 62,
          pesoCompraKg: 0,
        )).falta,
        FaltaDato.peso,
      );
    });
  });

  group('cotizado por cabeza', () {
    test('el costo es el precio de ese animal', () {
      final c = costoDelAnimal(const CompraDeAnimal(
        forma: FormaCotizacion.porCabeza,
        precioPorCabeza: 9500,
      ));
      expect(c.total, 9500);
    });

    test('no depende del peso', () {
      final c = costoDelAnimal(const CompraDeAnimal(
        forma: FormaCotizacion.porCabeza,
        precioPorCabeza: 9500,
        pesoCompraKg: 180,
      ));
      expect(c.total, 9500);
    });

    test('sin precio no se sabe', () {
      final c = costoDelAnimal(const CompraDeAnimal(
        forma: FormaCotizacion.porCabeza,
        pesoCompraKg: 180,
      ));
      expect(c.falta, FaltaDato.precio);
    });
  });

  group('sumar lo de un viaje', () {
    test('suma solo lo que se sabe y cuenta aparte lo que falta', () {
      // Un total que incluyera ceros por los que faltan se leeria como si
      // estuviera completo, y no lo esta.
      final r = sumaCostos([
        const CostoAnimal.conocido(13144),
        const CostoAnimal.conocido(9500),
        const CostoAnimal.desconocido(FaltaDato.peso),
      ]);
      expect(r.total, closeTo(22644, 0.001));
      expect(r.conocidos, 2);
      expect(r.desconocidos, 1);
    });

    test('una lista vacia da cero sin reventar', () {
      final r = sumaCostos([]);
      expect(r.total, 0);
      expect(r.conocidos, 0);
      expect(r.desconocidos, 0);
    });

    test('si no se sabe ninguno, el total es cero pero se ve que falta todo',
        () {
      final r = sumaCostos([
        const CostoAnimal.desconocido(FaltaDato.peso),
        const CostoAnimal.desconocido(FaltaDato.precio),
      ]);
      expect(r.total, 0);
      expect(r.conocidos, 0);
      expect(r.desconocidos, 2);
    });
  });

  group('lo propio gana sobre lo heredado', () {
    test('el vendedor del animal manda sobre el de la compra', () {
      // En un mismo viaje se le pueden comprar dos becerros a un senor y tres
      // a otro. El animal que traiga vendedor propio usa el suyo.
      expect(propioOHeredado('Don Chuy', 'Don Beto'), 'Don Chuy');
    });

    test('sin dato propio se hereda el de la compra', () {
      expect(propioOHeredado(null, 'Don Beto'), 'Don Beto');
    });

    test('si no hay ninguno de los dos, no hay dato', () {
      expect(propioOHeredado<String>(null, null), isNull);
    });

    test('sirve igual para el precio', () {
      expect(propioOHeredado<double>(70, 62), 70);
      expect(propioOHeredado<double>(null, 62), 62);
    });
  });
}
