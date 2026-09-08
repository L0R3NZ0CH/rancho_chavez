# Ganado — control del hato

Aplicación Android para el control del ganado de un rancho en México. Uso
interno, sin servidor, funciona sin internet.

- Especificación completa: [`docs/proyecto-app-ganado.md`](docs/proyecto-app-ganado.md)
- Reglas de trabajo y del dominio: [`CLAUDE.md`](CLAUDE.md)

## Estado: fase 1

Ahora mismo el proyecto **no** es la aplicación de ganado. Es una prueba de
campo de una sola pantalla, para contestar si la cámara del celular alcanza a
leer los aretes SINIIGA reales antes de construir el resto.

Cómo hacer la prueba: [`docs/fase-1-prueba-de-campo.md`](docs/fase-1-prueba-de-campo.md)

**No captures animales de verdad todavía.** La tabla de la fase 1 es desechable
y se elimina al entrar a la fase 2.

## Cómo compilar

Requiere Flutter estable y el SDK de Android. En esta máquina viven en
`C:\dev\flutter` y `C:\dev\android-sdk`.

```bash
flutter pub get
dart run build_runner build      # genera el código de drift
flutter analyze
flutter test
flutter build apk --release      # queda en build/app/outputs/flutter-apk/
```

Cada vez que cambie una tabla de drift hay que volver a correr `build_runner`.

## Cómo está acomodado

```
lib/
  comun/      tema de alto contraste, botones grandes, fechas
  data/db/    tablas de drift, base de datos, migraciones
  features/   una carpeta por pantalla
test/         pruebas de la lógica pura, sin emulador
```

La lógica de dominio vive aparte de drift y de Flutter a propósito: recibe
datos planos y devuelve resultados, así que se prueba en milisegundos y se
puede leer sin saber SQL.

## Las cinco reglas que no se rompen

Existen para poder sincronizar entre varios celulares más adelante. Están
explicadas en la sección 4 de la especificación y resumidas en `CLAUDE.md`.

1. Toda llave primaria es un UUID generado en el dispositivo.
2. Todo registro lleva `creadoEn`, `modificadoEn` y `dispositivoId`.
3. Nada se borra: se marca con `eliminadoEn` y toda consulta filtra.
4. El estado se deriva de eventos con fecha. Nada de columnas mutables como
   `pesoActual` o `ubicacionActual`.
5. Cero totales guardados. Conteos y márgenes se calculan al momento.
