import 'package:flutter_test/flutter_test.dart';
import 'package:ganado/domain/reglas/arete.dart';

void main() {
  group('prefijo 484 de Mexico', () {
    test('lo quita cuando son 15 digitos que empiezan con 484', () {
      // El caso real: lo que devolvio un arete del rancho el 7 de septiembre
      // de 2026, contra los doce digitos impresos en su bandera.
      final r = normalizaArete('484001409870222');
      expect(r.numero, '001409870222');
      expect(r.prefijoQuitado, isTrue);
      expect(pareceSiniiga(r.numero), isTrue);
    });

    test('guarda el crudo completo aunque quite el prefijo', () {
      expect(normalizaArete('484001409870222').crudo, '484001409870222');
    });

    test('no toca un arete que ya viene con doce digitos', () {
      final r = normalizaArete('001409870222');
      expect(r.numero, '001409870222');
      expect(r.prefijoQuitado, isFalse);
    });

    test('no quita nada si son 15 digitos pero con otro prefijo', () {
      // Un prefijo distinto es un hallazgo que hay que ver, no algo que la app
      // deba adivinar por su cuenta.
      final r = normalizaArete('999001409870222');
      expect(r.numero, '999001409870222');
      expect(r.prefijoQuitado, isFalse);
      expect(pareceSiniiga(r.numero), isFalse);
    });

    test('no quita nada si empieza con 484 pero no son 15 digitos', () {
      // Un arete cuyo propio numero empiece con 484 no debe quedar mutilado.
      final r = normalizaArete('484001409870');
      expect(r.numero, '484001409870');
      expect(r.prefijoQuitado, isFalse);
    });

    test('limpia separadores antes de aplicar la regla', () {
      final r = normalizaArete('484 0014 0987 0222\n');
      expect(r.numero, '001409870222');
      expect(r.prefijoQuitado, isTrue);
    });

    test('aguanta un codigo vacio sin reventar', () {
      final r = normalizaArete('');
      expect(r.numero, '');
      expect(r.prefijoQuitado, isFalse);
    });

    test('el escaneo y la captura manual llegan al mismo numero', () {
      // Esta es la razon de ser de toda la regla: si estos dos no coinciden,
      // el mismo animal entra dos veces.
      final escaneado = normalizaArete('484001409870222').numero;
      final tecleado = normalizaArete('001409870222').numero;
      expect(escaneado, tecleado);
    });
  });

  group('forma del numero SINIIGA', () {
    test('acepta doce digitos', () {
      expect(pareceSiniiga('072400123456'), isTrue);
    });

    test('rechaza longitudes distintas de doce', () {
      expect(pareceSiniiga('07240012345'), isFalse);
      expect(pareceSiniiga('0724001234567'), isFalse);
    });

    test('rechaza si trae algo que no sea digito', () {
      expect(pareceSiniiga('07240012345X'), isFalse);
    });

    test('soloDigitos limpia prefijos, guiones y saltos de linea', () {
      expect(soloDigitos('MX-0724 0012 3456\n'), '072400123456');
    });
  });
}
