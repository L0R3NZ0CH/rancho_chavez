import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganado/data/db/base_datos.dart';

/// El viaje completo de una venta: abrir, meter animales, pesar, poner precio,
/// cerrar. Y sobre todo: que al cerrar el animal **salga del hato y de los
/// conteos** sin que se borre nada.
void main() {
  late BaseDatos db;

  setUp(() => db = BaseDatos(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String> unPotrero() =>
      db.crearUbicacion(nombre: 'El Río', tipo: 'potrero');

  Future<String> unAnimal(String potrero, String arete) => db.altaAnimal(
        sexo: 'macho',
        origen: 'comprado',
        proposito: 'comercial',
        ubicacionId: potrero,
        fecha: 20260608,
        numeroArete: arete,
      );

  test('una venta nace vacia y sin nada obligatorio', () async {
    final venta = await db.crearVenta(fecha: 20260908);
    final v = await db.venta(venta);

    expect(v!.comprador, isNull);
    expect(v.cerradoEn, isNull);
    expect(await db.animalesDeVenta(venta), isEmpty);
  });

  group('armar la venta', () {
    test('se le meten animales y se les pesa', () async {
      final p = await unPotrero();
      final a = await unAnimal(p, '001409870222');
      final venta = await db.crearVenta(fecha: 20260908);

      await db.agregarAnimalAVenta(ventaId: venta, animalId: a);
      await db.registrarPeso(
        animalId: a,
        kilos: 250,
        fecha: 20260908,
        tipoPesaje: 'venta',
      );

      expect(await db.animalesDeVenta(venta), hasLength(1));
      expect(await db.pesoDeVenta(a), 250);
    });

    test('el peso de venta no pisa al de compra', () async {
      // Los dos son hechos distintos y los dos tienen que quedar.
      final p = await unPotrero();
      final a = await unAnimal(p, '001409870222');
      await db.registrarPeso(
        animalId: a,
        kilos: 180,
        fecha: 20260608,
        tipoPesaje: 'compra',
      );
      await db.registrarPeso(
        animalId: a,
        kilos: 250,
        fecha: 20260908,
        tipoPesaje: 'venta',
      );

      expect(await db.pesoDeCompra(a), 180);
      expect(await db.pesoDeVenta(a), 250);
    });

    test('el precio a todos llena la columna de un jalon', () async {
      final p = await unPotrero();
      final venta = await db.crearVenta(fecha: 20260908);
      for (final n in ['111111111111', '222222222222', '333333333333']) {
        await db.agregarAnimalAVenta(
          ventaId: venta,
          animalId: await unAnimal(p, n),
        );
      }

      await db.precioParaTodos(ventaId: venta, precioPorKilo: 75);

      final filas = await db.animalesDeVenta(venta);
      expect(filas.every((f) => f.precioPorKilo == 75), isTrue);
    });

    test('el precio de uno gana sobre el de todos', () async {
      final p = await unPotrero();
      final a = await unAnimal(p, '111111111111');
      final b = await unAnimal(p, '222222222222');
      final venta = await db.crearVenta(fecha: 20260908);
      await db.agregarAnimalAVenta(ventaId: venta, animalId: a);
      await db.agregarAnimalAVenta(ventaId: venta, animalId: b);

      await db.precioParaTodos(ventaId: venta, precioPorKilo: 75);
      await db.fijarPrecioDeVenta(
        ventaId: venta,
        animalId: b,
        precioPorKilo: 58,
      );

      final filas = await db.animalesDeVenta(venta);
      expect(filas.firstWhere((f) => f.animalId == a).precioPorKilo, 75);
      expect(filas.firstWhere((f) => f.animalId == b).precioPorKilo, 58);
    });

    test('quitar un animal de la venta no lo vende ni lo borra', () async {
      final p = await unPotrero();
      final a = await unAnimal(p, '001409870222');
      final venta = await db.crearVenta(fecha: 20260908);
      await db.agregarAnimalAVenta(ventaId: venta, animalId: a);

      await db.quitarAnimalDeVenta(ventaId: venta, animalId: a);

      expect(await db.animalesDeVenta(venta), isEmpty);
      expect((await db.verAnimales().first).single.id, a);
      expect(await db.animalPorArete('001409870222'), isNotNull);
    });
  });

  group('cerrar la venta', () {
    test('da de baja a los animales y los saca de los conteos', () async {
      final p = await unPotrero();
      final a = await unAnimal(p, '111111111111');
      final b = await unAnimal(p, '222222222222');
      expect(await db.animalesEnUbicacion(p), 2);

      final venta = await db.crearVenta(fecha: 20260908);
      await db.agregarAnimalAVenta(ventaId: venta, animalId: a);

      await db.cerrarVenta(venta);

      // El vendido ya no cuenta en el potrero; el otro si.
      expect(await db.animalesEnUbicacion(p), 1);
      expect(await db.animalesDadosDeBaja(), {a});
      expect((await db.venta(venta))!.cerradoEn, isNotNull);

      // Y el que sigue en el rancho no se toco.
      expect(await db.animalPorArete('222222222222'), isNotNull);
      expect((await db.animal(b))!.eliminadoEn, isNull);
    });

    test('el animal vendido no se borra: su historial queda entero', () async {
      final p = await unPotrero();
      final a = await unAnimal(p, '001409870222');
      final venta = await db.crearVenta(fecha: 20260908);
      await db.agregarAnimalAVenta(ventaId: venta, animalId: a);

      await db.cerrarVenta(venta);

      final animal = await db.animal(a);
      expect(animal, isNotNull);
      expect(animal!.eliminadoEn, isNull);

      final tipos = (await db.verEventos(a).first).map((e) => e.tipo).toSet();
      expect(tipos, contains('movimiento'));
      expect(tipos, contains('baja'));
    });

    test('la baja queda con su motivo y ligada a la venta', () async {
      final p = await unPotrero();
      final a = await unAnimal(p, '001409870222');
      final venta = await db.crearVenta(fecha: 20260908);
      await db.agregarAnimalAVenta(ventaId: venta, animalId: a);

      await db.cerrarVenta(venta);

      final baja = await db.select(db.eventoBajas).getSingle();
      expect(baja.motivo, 'venta');
      expect(baja.loteVentaId, venta);
    });

    test('una venta a medias no da de baja a nadie', () async {
      // El borrador se puede abandonar sin descuadrar el hato.
      final p = await unPotrero();
      final a = await unAnimal(p, '001409870222');
      final venta = await db.crearVenta(fecha: 20260908);
      await db.agregarAnimalAVenta(ventaId: venta, animalId: a);

      expect(await db.animalesDadosDeBaja(), isEmpty);
      expect(await db.animalesEnUbicacion(p), 1);
    });
  });

  test('los compradores se recuerdan para autocompletar', () async {
    final venta = await db.crearVenta(fecha: 20260908);
    await db.actualizarVenta(
      ventaId: venta,
      comprador: 'Ana Lilia',
      destino: null,
      fecha: 20260908,
    );
    expect(await db.compradoresUsados(), ['Ana Lilia']);
  });
}
