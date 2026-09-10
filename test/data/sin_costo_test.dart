import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganado/data/db/base_datos.dart';
import 'package:ganado/data/repos/pendientes.dart';
import 'package:ganado/domain/reglas/costo_compra.dart';

/// Un hueco que nadie ve nunca se tapa.
///
/// Estas pruebas cuidan que la lista de pendientes diga la verdad: que salgan
/// los que de verdad les falta algo, y **que no salgan** los que están
/// completos o los que se compraron por cabeza y por eso no llevan peso.
void main() {
  late BaseDatos db;

  setUp(() => db = BaseDatos(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<({String compra, String animal})> comprado({
    double? precioLote,
    double? peso,
    String forma = 'porKilo',
  }) async {
    final compra = await db.crearLoteCompra(
      fecha: 20260101,
      vendedor: 'Don Chuy',
      formaCalculo: forma,
      precioPorKilo: precioLote,
    );
    final animal = await db.altaAnimal(
      sexo: 'macho',
      origen: 'comprado',
      proposito: 'comercial',
      fecha: 20260101,
      categoria: 'becerro',
    );
    await db.agregarAnimalALote(loteCompraId: compra, animalId: animal);
    if (peso != null) {
      await db.registrarPeso(
        animalId: animal,
        kilos: peso,
        fecha: 20260101,
        tipoPesaje: 'compra',
      );
    }
    return (compra: compra, animal: animal);
  }

  Future<List<SinCosto>> pendientes() =>
      RepoPendientes(db).verSinCosto().first;

  test('un animal con peso y precio no es pendiente', () async {
    await comprado(precioLote: 62, peso: 180);
    expect(await pendientes(), isEmpty);
  });

  test('sin precio aparece, y dice que falta el precio', () async {
    final c = await comprado(peso: 180);
    final lista = await pendientes();

    expect(lista, hasLength(1));
    expect(lista.single.animal.id, c.animal);
    expect(lista.single.falta, FaltaDato.precio);
    expect(lista.single.queFalta, 'falta el precio');
  });

  test('sin pesar aparece, y dice que falta pesarlo', () async {
    await comprado(precioLote: 62);
    final lista = await pendientes();

    expect(lista.single.falta, FaltaDato.peso);
    expect(lista.single.queFalta, 'falta pesarlo');
  });

  group('comprado por cabeza', () {
    test('no pide peso: no se compró así', () async {
      // Este era el punto del dueno: el pie de cria se compra por cabeza y ni
      // siquiera se pesa. Sin la opcion, aparecia para siempre diciendo
      // "falta pesarlo" y nunca se iba a pesar.
      final c = await comprado(forma: 'porCabeza');
      await db.ajustarTrato(
        loteCompraId: c.compra,
        animalId: c.animal,
        formaCalculo: 'porCabeza',
        precioPorCabeza: 18000,
      );

      expect(await pendientes(), isEmpty);
    });

    test('sin precio sí aparece', () async {
      await comprado(forma: 'porCabeza');
      final lista = await pendientes();

      expect(lista.single.falta, FaltaDato.precio);
    });
  });

  group('quién no cuenta', () {
    test('un animal nacido en el rancho no es pendiente', () async {
      // Nunca se compró: no hay costo que falte.
      await db.altaAnimal(
        sexo: 'hembra',
        origen: 'nacido',
        proposito: 'comercial',
        fecha: 20260101,
        categoria: 'becerra',
      );
      expect(await pendientes(), isEmpty);
    });

    test('un animal vendido sale de la lista', () async {
      // La lista es de pendientes del hato de hoy, no un archivo historico.
      final c = await comprado(peso: 180);
      expect(await pendientes(), hasLength(1));

      final venta = await db.crearVenta(fecha: 20260601);
      await db.agregarAnimalAVenta(ventaId: venta, animalId: c.animal);
      await db.cerrarVenta(venta);

      expect(await pendientes(), isEmpty);
    });

    test('un animal borrado sale de la lista', () async {
      final c = await comprado(peso: 180);
      await db.eliminarAnimal(c.animal);
      expect(await pendientes(), isEmpty);
    });

    test('si se borra la compra, deja de contar', () async {
      final c = await comprado(peso: 180);
      await db.eliminarCompra(c.compra);
      expect(await pendientes(), isEmpty);
    });
  });

  test('ponerle el precio lo saca de la lista', () async {
    final c = await comprado(peso: 180);
    expect(await pendientes(), hasLength(1));

    await db.ajustarTrato(
      loteCompraId: c.compra,
      animalId: c.animal,
      precioPorKilo: 62,
    );

    expect(await pendientes(), isEmpty);
  });

  test('pesarlo lo saca de la lista', () async {
    final c = await comprado(precioLote: 62);
    expect(await pendientes(), hasLength(1));

    await db.registrarPeso(
      animalId: c.animal,
      kilos: 180,
      fecha: 20260101,
      tipoPesaje: 'compra',
    );

    expect(await pendientes(), isEmpty);
  });
}
