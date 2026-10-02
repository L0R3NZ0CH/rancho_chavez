import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganado/data/db/base_datos.dart';

/// Las fotos de un animal.
///
/// Lo que estas pruebas cuidan es una regla que se rompe sin ruido: **un animal
/// con fotos siempre tiene exactamente una principal**. Si se queda sin
/// ninguna, la ficha no sabe cuál enseñar; si se queda con dos, enseña la que
/// le toque por azar.
void main() {
  late BaseDatos db;

  setUp(() => db = BaseDatos(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String> unAnimal() => db.altaAnimal(
        sexo: 'macho',
        origen: 'comprado',
        proposito: 'comercial',
        fecha: 20260101,
        categoria: 'becerro',
      );

  /// Cuántas están marcadas como principal.
  Future<int> principales(String animalId) async =>
      (await db.fotosDe(animalId)).where((f) => f.esPrincipal).length;

  test('un animal nace sin fotos', () async {
    final a = await unAnimal();
    expect(await db.fotosDe(a), isEmpty);
    expect(await db.fotoPrincipal(a), isNull);
  });

  test('la primera foto queda de principal sola', () async {
    final a = await unAnimal();
    await db.agregarFoto(animalId: a, rutaRelativa: 'fotos/una.jpg');

    final principal = await db.fotoPrincipal(a);
    expect(principal!.rutaRelativa, 'fotos/una.jpg');
    expect(principal.esPrincipal, isTrue);
  });

  test('las siguientes se apilan sin quitarle el lugar a la primera', () async {
    final a = await unAnimal();
    await db.agregarFoto(animalId: a, rutaRelativa: 'fotos/una.jpg');
    await db.agregarFoto(animalId: a, rutaRelativa: 'fotos/dos.jpg');

    expect(await db.fotosDe(a), hasLength(2));
    expect((await db.fotoPrincipal(a))!.rutaRelativa, 'fotos/una.jpg');
    expect(await principales(a), 1);
  });

  test('cambiar la principal deja solo una', () async {
    final a = await unAnimal();
    await db.agregarFoto(animalId: a, rutaRelativa: 'fotos/una.jpg');
    await db.agregarFoto(animalId: a, rutaRelativa: 'fotos/dos.jpg');

    final dos = (await db.fotosDe(a))
        .firstWhere((f) => f.rutaRelativa == 'fotos/dos.jpg');
    await db.marcarFotoPrincipal(animalId: a, fotoId: dos.id);

    expect((await db.fotoPrincipal(a))!.rutaRelativa, 'fotos/dos.jpg');
    expect(await principales(a), 1);
  });

  group('borrar', () {
    test('la foto sale de la lista pero el renglón se queda', () async {
      final a = await unAnimal();
      await db.agregarFoto(animalId: a, rutaRelativa: 'fotos/una.jpg');
      final foto = (await db.fotosDe(a)).single;

      await db.eliminarFoto(animalId: a, fotoId: foto.id);

      expect(await db.fotosDe(a), isEmpty);
      // Regla 3: nada se borra de la base.
      final crudo = await db.select(db.fotos).getSingle();
      expect(crudo.eliminadoEn, isNotNull);
    });

    test('borrar la principal asciende a otra', () async {
      // Sin esto, el animal se quedaria con fotos pero sin ninguna principal, y
      // la ficha no sabria cual ensenar.
      final a = await unAnimal();
      await db.agregarFoto(animalId: a, rutaRelativa: 'fotos/una.jpg');
      await db.agregarFoto(animalId: a, rutaRelativa: 'fotos/dos.jpg');

      final principal = (await db.fotoPrincipal(a))!;
      await db.eliminarFoto(animalId: a, fotoId: principal.id);

      final quedan = await db.fotosDe(a);
      expect(quedan, hasLength(1));
      expect(quedan.single.rutaRelativa, 'fotos/dos.jpg');
      expect(await principales(a), 1);
    });

    test('borrar la última no deja ninguna principal colgando', () async {
      final a = await unAnimal();
      await db.agregarFoto(animalId: a, rutaRelativa: 'fotos/una.jpg');
      final foto = (await db.fotosDe(a)).single;

      await db.eliminarFoto(animalId: a, fotoId: foto.id);

      expect(await db.fotoPrincipal(a), isNull);
      expect(await principales(a), 0);
    });

    test('volver a agregar después de borrar todas vuelve a dar principal',
        () async {
      final a = await unAnimal();
      await db.agregarFoto(animalId: a, rutaRelativa: 'fotos/una.jpg');
      final foto = (await db.fotosDe(a)).single;
      await db.eliminarFoto(animalId: a, fotoId: foto.id);

      await db.agregarFoto(animalId: a, rutaRelativa: 'fotos/dos.jpg');

      expect((await db.fotoPrincipal(a))!.rutaRelativa, 'fotos/dos.jpg');
      expect(await principales(a), 1);
    });
  });

  test('las fotos de un animal no se mezclan con las de otro', () async {
    final a = await unAnimal();
    final b = await unAnimal();
    await db.agregarFoto(animalId: a, rutaRelativa: 'fotos/a.jpg');
    await db.agregarFoto(animalId: b, rutaRelativa: 'fotos/b.jpg');

    expect((await db.fotosDe(a)).single.rutaRelativa, 'fotos/a.jpg');
    expect((await db.fotosDe(b)).single.rutaRelativa, 'fotos/b.jpg');
    // Las dos son principales: cada una de lo suyo.
    expect(await principales(a), 1);
    expect(await principales(b), 1);
  });

  test('se guarda la ruta relativa, nunca la absoluta', () async {
    // La carpeta de datos cambia de lugar al reinstalar y al restaurar un
    // respaldo: una ruta absoluta quedaria rota.
    final a = await unAnimal();
    await db.agregarFoto(animalId: a, rutaRelativa: 'fotos/una.jpg');

    final ruta = (await db.fotosDe(a)).single.rutaRelativa;
    expect(ruta.startsWith('fotos'), isTrue);
    expect(ruta.contains(':'), isFalse);
  });
}
