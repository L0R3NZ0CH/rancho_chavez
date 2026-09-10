import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganado/data/db/base_datos.dart';

/// Los aretes se reparten y se vuelven a usar.
///
/// La unicidad aplica **solo entre animales que siguen en el rancho**. Bloquear
/// un número para siempre porque hace dos años lo trajo un becerro que ya se
/// vendió obligaría a inventar números, y eso ensucia más que reutilizar.
void main() {
  late BaseDatos db;

  setUp(() => db = BaseDatos(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String> unPotrero() =>
      db.crearUbicacion(nombre: 'El Río', tipo: 'potrero');

  Future<String> conArete(String potrero, String arete) => db.altaAnimal(
        sexo: 'macho',
        origen: 'comprado',
        proposito: 'comercial',
        ubicacionId: potrero,
        fecha: 20260101,
        numeroArete: arete,
      );

  Future<void> vender(String animalId) async {
    final venta = await db.crearVenta(fecha: 20260601);
    await db.agregarAnimalAVenta(ventaId: venta, animalId: animalId);
    await db.cerrarVenta(venta);
  }

  test('un número que nunca se usó está libre', () async {
    expect(await db.areteOcupadoPor('001409870222'), isNull);
  });

  test('un animal que sigue en el rancho ocupa su arete', () async {
    final p = await unPotrero();
    final a = await conArete(p, '001409870222');

    final ocupado = await db.areteOcupadoPor('001409870222');
    expect(ocupado, isNotNull);
    expect(ocupado!.animal.id, a);
    expect(ocupado.deBaja, isFalse);
  });

  test('un animal vendido marca el arete como reutilizable', () async {
    // Este era el bug: el arete de un animal que ya salió del hato seguia
    // bloqueando, y no habia forma de volver a usar el numero.
    final p = await unPotrero();
    final a = await conArete(p, '001409870222');
    await vender(a);

    final ocupado = await db.areteOcupadoPor('001409870222');
    expect(ocupado, isNotNull);
    expect(ocupado!.deBaja, isTrue);
  });

  group('reutilizar el número', () {
    test('el arete viejo se retira y el nuevo animal se queda con él',
        () async {
      final p = await unPotrero();
      final viejo = await conArete(p, '001409870222');
      await vender(viejo);

      await db.retirarAretePorNumero(
        numero: '001409870222',
        fecha: 20260910,
      );
      final nuevo = await db.altaAnimal(
        sexo: 'hembra',
        origen: 'comprado',
        proposito: 'comercial',
        ubicacionId: p,
        fecha: 20260910,
        numeroArete: '001409870222',
      );

      // El numero ahora apunta al nuevo.
      expect((await db.animalPorArete('001409870222'))!.id, nuevo);
      expect(await db.areteOcupadoPor('001409870222'), isNotNull);
      expect((await db.areteOcupadoPor('001409870222'))!.deBaja, isFalse);
    });

    test('el animal que se fue conserva el arete que trajo', () async {
      // No se borra: se marca retirado. Su historial no se puede quedar sin el
      // numero que traia.
      final p = await unPotrero();
      final viejo = await conArete(p, '001409870222');
      await vender(viejo);
      await db.retirarAretePorNumero(
        numero: '001409870222',
        fecha: 20260910,
      );

      final suyos = await (db.select(db.aretes)
            ..where((a) => a.animalId.equals(viejo)))
          .get();
      expect(suyos, hasLength(1));
      expect(suyos.single.numero, '001409870222');
      expect(suyos.single.fechaRetiro, 20260910);
      expect(suyos.single.motivoRetiro, 'reutilizado');
    });

    test('el nuevo no hereda nada del viejo', () async {
      final p = await unPotrero();
      final viejo = await conArete(p, '001409870222');
      await db.registrarPeso(animalId: viejo, kilos: 300, fecha: 20260101);
      await vender(viejo);
      await db.retirarAretePorNumero(
        numero: '001409870222',
        fecha: 20260910,
      );

      final nuevo = await db.altaAnimal(
        sexo: 'hembra',
        origen: 'comprado',
        proposito: 'comercial',
        ubicacionId: p,
        fecha: 20260910,
        numeroArete: '001409870222',
      );

      final eventos = await db.verEventos(nuevo).first;
      expect(eventos.where((e) => e.tipo == 'peso'), isEmpty);
      expect(eventos.where((e) => e.tipo == 'baja'), isEmpty);
    });
  });

  test('retirar por número no toca aretes de otros animales', () async {
    final p = await unPotrero();
    final otro = await conArete(p, '999999999999');
    await db.retirarAretePorNumero(numero: '001409870222', fecha: 20260910);

    expect((await db.areteVigente(otro))!.fechaRetiro, isNull);
  });
}
