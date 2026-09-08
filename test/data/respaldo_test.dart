import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganado/data/db/base_datos.dart';
import 'package:ganado/data/respaldo.dart';

/// La deuda de respaldo no es un contador guardado: se calcula comparando los
/// sellos de creacion contra la fecha del ultimo respaldo. Estas pruebas
/// verifican justamente que no haya nada que se pueda desincronizar.
void main() {
  late BaseDatos db;

  setUp(() => db = BaseDatos(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String> altaDeUno() async {
    final u = await db.crearUbicacion(nombre: 'El Zacatal', tipo: 'potrero');
    return db.altaAnimal(
      sexo: 'macho',
      origen: 'comprado',
      proposito: 'comercial',
      ubicacionId: u,
      fecha: 20260908,
    );
  }

  test('una base recien creada no debe nada', () async {
    expect(await deudaDeRespaldo(db), 0);
    expect(await animalesSinRespaldar(db), 0);
  });

  test('cada alta sube la deuda', () async {
    await altaDeUno();
    // Un alta escribe el animal y dos eventos: movimiento y proposito.
    expect(await deudaDeRespaldo(db), greaterThanOrEqualTo(3));
    expect(await animalesSinRespaldar(db), 1);
  });

  test('respaldar deja la deuda en cero', () async {
    await altaDeUno();
    await altaDeUno();
    expect(await animalesSinRespaldar(db), 2);

    await marcarRespaldado(db);

    expect(await deudaDeRespaldo(db), 0);
    expect(await animalesSinRespaldar(db), 0);
  });

  test('lo que se registra despues del respaldo vuelve a contar', () async {
    await altaDeUno();
    await marcarRespaldado(db);

    // El sello del respaldo se guarda en milisegundos; sin esperar, un alta
    // inmediata podria caer en el mismo milisegundo y no contarse.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await altaDeUno();

    expect(await animalesSinRespaldar(db), 1);
  });

  test('el umbral de bloqueo son diez registros', () {
    // Si alguien lo cambia sin querer, que falle una prueba y no la jornada.
    expect(umbralDeuda, 10);
  });

  test('sin respaldos previos no hay fecha que mostrar', () async {
    expect(await fechaUltimoRespaldo(db), isNull);
    await marcarRespaldado(db);
    expect(await fechaUltimoRespaldo(db), isNotNull);
  });
}
