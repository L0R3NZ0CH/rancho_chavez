# Aplicación de control de ganado — documento del proyecto

Versión 2 del documento · Septiembre 2026

> **Correcciones de la versión 2.** Se corrigió la sección 1, que decía "arete electrónico" cuando
> la identificación es **óptica, por código de barras** (manda la sección 3). Se eliminó la categoría
> **novillo**. Se adelantó a la versión 1 un **evento de parto mínimo**, solo la fecha, para poder
> distinguir vaca de vaquilla. Se renombró **margen** a **diferencia compra-venta**, porque el
> alimento queda fuera del cálculo por decisión de diseño y el número no es un margen real.

---

## 1. Qué es y para quién

Aplicación móvil para llevar el control del ganado de un rancho, con identificación de animales
mediante la lectura del **código de barras impreso en el arete SINIIGA de bandera**.

> **Ojo al comprar equipo.** Esto **no** es radiofrecuencia. Lo que se lee es una imagen, no un chip.
> Si algún día hace falta comprar lector, tiene que ser un **lector óptico 2D de imagen**, nunca un
> bastón o una antena de radiofrecuencia, y nunca un láser de línea. Ver la sección 3.

El rancho maneja dos negocios al mismo tiempo:

- **Comercialización**: compra de becerros, becerras y vacas, engorda en pastoreo con apoyo de alimento, y venta.
- **Pie de cría**: vacas y toros propios que producen crías, con manejo sanitario regular (desparasitación y baños).

La aplicación es para uso interno del rancho, no es un producto para vender a terceros. Eso permite simplificar bastante: sin cuentas de usuario complejas, sin múltiples ranchos, sin cobros.

**Problema que resuelve.** Hoy todo se anota a mano. Se pierde el historial de cada animal, no se sabe cuánto costó y en cuánto se vendió realmente cada cabeza, y no hay control de qué animal ya está listo para vender después de un tratamiento.

---

## 2. Decisiones ya tomadas

| Tema | Decisión |
|---|---|
| Identificación | Código de barras impreso en el arete SINIIGA de bandera |
| Lectura | Cámara del celular primero; escáner Bluetooth 2D solo si hace falta |
| Plataforma | Android únicamente en la versión 1 |
| Tecnología | Flutter |
| Dispositivos | Un solo celular en la versión 1, con sincronización planeada para después |
| Almacenamiento | Base de datos local en el celular, sin servidor |
| Costeo de alimento | No se reparte por animal. Va como cuaderno de gastos aparte |

---

## 3. La lectura del arete

### Qué se va a leer

El código de barras impreso en el arete SINIIGA de bandera. El manual del SINIIGA contempla el sistema de identificación con código de barras únicamente en los identificadores visuales de bovinos, que es justamente este arete.

El número SINIIGA se compone de doce dígitos: dos de país (MX), dos de la entidad federativa y ocho del animal.

Esto simplifica mucho el diseño respecto a la alternativa de radiofrecuencia: **el código de barras contiene el mismo número que está impreso en la bandera**, así que hay un solo identificador para todo. No hay dos números distintos que reconciliar.

### Estrategia: cámara primero

La cámara del celular lee códigos de barras sin ningún hardware adicional. Costo cero, sin Bluetooth y sin emparejamiento.

**Hay que probar esto antes que nada.** Si funciona bien en el corral, no hace falta comprar equipo.

### Si la cámara no alcanza

Solo entonces se compra un escáner Bluetooth. Requisitos:

1. **Que sea lector 2D de imagen, no láser.** El láser barre una línea recta y se atora con superficies curvas. El arete de bandera es plástico curvo, sucio y a veces doblado. El de imagen toma una foto y decodifica, así que tolera mucho mejor la curvatura, la mugre y el ángulo. Cuesta prácticamente lo mismo.
2. **Modo teclado (HID)**. El escáner se comporta como un teclado inalámbrico y "escribe" el código en el campo de texto activo. Con esto la aplicación no necesita programar nada de Bluetooth.
3. Resistencia a polvo y a caídas.
4. Batería para una jornada completa.

Marcas comunes en México: Netum, Inateck, Eyoyo, o genéricos de proveedor local. Rango de precio aproximado: 600 a 2,000 pesos.

### Limitaciones que hay que asumir

**La suciedad impide la lectura.** A diferencia del chip de radiofrecuencia, que funciona aunque el arete esté embarrado, un código de barras sucio es ilegible y hay que limpiar el arete antes de leerlo. En el corral esto pasa seguido: lodo, rayones, decoloración por sol, aretes doblados.

**Consecuencia de diseño obligatoria:** la captura manual del número debe estar siempre a un toque de distancia, con teclado numérico grande. Si el usuario tiene que navegar tres pantallas para escribir un número, el día que fallen tres aretes seguidos abandona la aplicación.

**El animal debe estar sujeto.** El código de barras se lee de cerca y con el arete quieto, así que el animal tiene que estar en la manga o el corral. No se puede leer ganado suelto en el potrero. Para el uso previsto no representa problema, pero si algún día se quisiera contar un potrero completo sin manejar a los animales, eso solo lo permite la radiofrecuencia.

### Puerta abierta a radiofrecuencia

El modelo de datos incluye un campo para el código RFID, aunque quede vacío. No cuesta nada tenerlo y permite adoptar el arete electrónico más adelante sin rehacer nada.

---

## 4. Cinco reglas de diseño (para poder sincronizar después)

La versión 1 usa un solo celular, pero estas cinco reglas hay que respetarlas **desde el primer día**. No cuestan tiempo ahora y evitan rehacer todo cuando entre un segundo dispositivo.

**1. Identificadores únicos globales.**
Cada registro nace con un identificador que no depende de un contador. Si el animal número 47 lo creó un celular y el 47 lo creó otro, con contadores hay dos animales distintos con el mismo número y no hay forma de arreglarlo.

**2. Cada registro guarda cuándo se creó, cuándo se modificó y en qué dispositivo.**
Sin eso, al sincronizar no se sabe cuál versión es la buena.

**3. Nada se borra.**
Se marca como eliminado con su fecha. Un borrado real hace que el otro dispositivo "reviva" el registro al sincronizar, porque él todavía lo tiene.

**4. Todo se modela como eventos con fecha, no como estados.**
No se guarda "peso actual del animal", se guarda "el 3 de marzo pesó 180 kg". El estado actual siempre se calcula.

Esta es la regla más importante. Los eventos solo se agregan, nunca se pisan, así que dos dispositivos pueden registrar cosas distintas del mismo animal sin conflicto. Como beneficio adicional, el historial completo de cada animal sale gratis.

**5. Nada de totales guardados.**
El conteo del potrero, el inventario y la diferencia compra-venta se calculan al momento. Un número guardado se desincroniza; un cálculo no.

**Advertencia.** El respaldo en la nube no es sincronización. Dos celulares escribiendo sobre el mismo archivo compartido lo corrompen. El día que entre el segundo dispositivo se necesita un servidor de verdad, aunque sea el más económico.

---

## 5. Estructura de la información

### Animal

Es el registro central. **Existe antes que el arete**, porque los lotes comprados llegan sin identificar.

Datos de identidad:

- Identificador interno del sistema
- Número SINIIGA, que es el mismo que trae impreso el arete y el que devuelve el código de barras (puede estar vacío al principio)
- Código RFID, reservado para el futuro. Normalmente vacío.
- Nombre o apodo, si tiene
- Foto o fotos
- Descripción física corta: color, señas, cuernos, marcas

Datos básicos:

- Sexo
- Fecha de nacimiento, con marca de si es **real o estimada**. Los animales comprados se calculan por dentición, así que debe aceptarse una edad aproximada en vez de una fecha exacta.
- Raza o cruza
- Propósito: comercial o pie de cría. **Se puede cambiar**, porque una becerra comprada para vender puede quedarse de reemplazo.
- Madre y padre, cuando se conocen

Datos de origen:

- Cómo entró: comprado o nacido en el rancho
- Si fue comprado: vendedor, lugar de compra, fecha, costo
- Lote de compra al que perteneció

Estado:

- Activo, vendido, muerto, robado o sacrificado
- Fecha y motivo de la baja

### Estado "sin identificar"

Cuando llega un lote sin arete, cada animal se registra con foto, descripción física, vendedor y lugar de compra. Queda marcado como **pendiente de aretar**.

Después, cuando se le pone el arete, se busca al animal por su foto y descripción, se escanea el arete nuevo y queda ligado. El registro es el mismo desde el principio; solo se le agrega el identificador.

La pantalla de inicio debe tener un apartado automático de **pendientes de aretar** para que no se olviden.

### Ubicación

Un animal está en **una sola** ubicación a la vez.

- Nombre que usa el dueño: "El Zacatal", "Potrero del arroyo", "La loma". Nunca "Potrero 1".
- Tipo: potrero, corral, cuarentena, manga, o fuera del rancho (agostadero rentado, en tránsito, con el comprador)
- Hectáreas
- Tipo de pasto
- Capacidad máxima
- Notas

Como cada movimiento queda como evento con fecha, se obtiene gratis: cuántos animales hay ahora, cuántos días llevan ahí, la carga por hectárea, y cuánto lleva descansando un potrero vacío.

### Categoría

**La calcula el sistema, no la captura nadie.** De sexo, fecha de nacimiento, destete y parto salen:
becerro, becerra, destete, vaquilla, vaca, toro.

Si se deja manual, en seis meses hay "becerros" de tres años porque nadie los actualizó.

**Novillo se elimina.** En este rancho no se castra, así que la categoría no aplica y tampoco existe el
dato que la sustentaría.

**Vaca contra vaquilla se resuelve con el parto, no con la edad.** Vaca es la hembra con al menos un
parto registrado; vaquilla es la hembra sin parto. Por eso el evento de parto se adelanta a la versión 1.
Sin él, el pie de cría arranca mal etiquetado desde el primer día.

**Destete es un hecho con fecha**, no una etapa que se deduzca de la edad: hay becerros que se destetan
a los seis meses y otros a los diez. Se registra como evento y la categoría se deriva de él.

**El dueño fija los umbrales, el sistema calcula.** Los umbrales de edad (a cuántos meses deja de ser
becerro, a cuántos pasa a vaquilla) viven en Ajustes y se pueden cambiar cuando se quiera. Con esos
umbrales, más el sexo, el destete y el parto, el sistema calcula la categoría de cada animal. La
categoría nunca se teclea animal por animal.

**Se puede corregir un animal en concreto**, y la corrección se guarda como un evento con fecha y
motivo, no como una columna que se pisa. Así la regla 4 sigue en pie, queda el rastro de cuándo y por
qué se corrigió, y la pantalla puede mostrar que ese animal trae una categoría puesta a mano.

> **Pendiente de definir.** Los valores concretos de los umbrales. Y cómo se le llama a un macho entero
> de engorda ya crecido, que al quitar "novillo" se quedó sin categoría propia.

### Apartados

Agrupaciones libres que define el dueño. Un animal puede estar en **varios apartados a la vez**, y son independientes de dónde esté parado físicamente.

**Manuales.** Se crea "Lote venta marzo" y se le van metiendo animales escaneándolos. Para cosas temporales: un lote de venta, los que van al veterinario, los que ya apartó un comprador.

**Automáticos.** Un filtro guardado con nombre, que se actualiza solo. Por ejemplo: "hembras de más de dos años en El Zacatal", "todo lo que compré y no he vendido", "los que traen tiempo de retiro activo".

### Eventos

Todo lo que le pasa a un animal es un evento con fecha. Tipos:

- **Movimiento**: de qué ubicación a cuál
- **Peso**: kilos, y si fue al nacer, al destete o de rutina
- **Tratamiento**: producto, dosis, motivo, y **fecha en que termina el tiempo de retiro**.
  Los días de retiro se leen de la etiqueta del producto y se capturan tal cual en el catálogo.
  A eso se le suma un **margen de seguridad configurable, de dos días por omisión**, porque el costo
  de equivocarse por abajo es un decomiso. Solo se controla **retiro en carne**: el rancho no vende leche.
- **Vacuna**: no es un evento aparte. Las vacunas son un tipo de producto dentro del mismo catálogo
  de tratamientos, con sus propios días de retiro.
- **Destete**: la fecha en que se destetó. Alimenta el cálculo de categoría.
- **Parto**: solo la fecha. Es el mínimo que la versión 1 necesita para distinguir vaca de vaquilla.
  El resto de la reproducción (servicio, inseminación, diagnóstico de gestación) sigue en la versión 2.
- **Cambio de propósito**: pasó de comercial a pie de cría o al revés
- **Baja**: venta, muerte, robo o sacrificio, con motivo

### Lote de compra

- Fecha, vendedor, lugar de compra
- Costo total y forma de cálculo: por cabeza o por kilo
- Gastos asociados: flete, comisión, documentación
- Animales que trae
- Documentos: guía de tránsito, factura, foto del papel

### Lote de venta

- Fecha, comprador, destino
- Precio total y forma de cálculo: por cabeza o por kilo
- Animales que incluye
- **Validación obligatoria**: la aplicación bloquea la venta si algún animal todavía tiene tiempo de retiro activo
- Documentos

### Gastos de alimento

Cuaderno completamente independiente. **No se liga a ningún animal ni se reparte entre cabezas.**

- Fecha
- Tipo: rastrojo, fórmula, sal mineral, melaza, otro
- Cantidad y unidad
- Costo
- Proveedor
- Notas

Las compras son irregulares por naturaleza: una semana se gastan dos mil pesos, otra mil, a veces diez mil y luego nada por un buen rato. La aplicación solo debe registrarlas y mostrar totales por mes y por año.

---

## 6. Pantallas

### Inicio

Franja de apartados en la parte de arriba, con la posibilidad de agregar los propios:

> Todos · Por potrero · Por categoría · Pendientes de aretar · En retiro · Sin vender · Pie de cría · [ + ]

Debajo, la lista de animales del apartado seleccionado, con foto y número visual en grande.

**El botón de escanear va fijo abajo, siempre visible.** Es el ochenta por ciento del uso real: llegar a la manga, escanear, ver al animal.

### Ficha del animal

- Foto grande, número visual, apodo, categoría calculada
- Dónde está y desde cuándo
- Aviso llamativo si tiene tiempo de retiro activo
- Historial completo en orden cronológico
- Botones rápidos: mover, pesar, tratar, dar de baja
- Exportar historial a PDF, para enseñárselo al comprador o al veterinario

### Escanear

Pantalla mínima. Se escanea, aparece el animal. Si el arete no está registrado, ofrece darlo de alta o ligarlo a un animal pendiente de aretar.

**Debe incluir siempre, visible, la opción de escribir el número a mano** con teclado numérico grande. No es una alternativa escondida: es la salida obligatoria para cuando el arete esté sucio, rayado o doblado, que va a pasar seguido.

### Ubicaciones

Lista de potreros con cuántos animales tiene cada uno. Al entrar a uno: la lista de animales, la carga por hectárea, y el botón de mover un grupo completo a otro lado.

### Trabajo por lote

Esta pantalla ahorra horas. Los baños y las desparasitaciones se hacen a ochenta animales de golpe. **Si la aplicación obliga a escanear ochenta aretes, nadie la va a usar.**

Debe permitir: "aplicar tratamiento a todo el potrero El Zacatal", elegir producto, dosis y fecha, y destildar los que no entraron. La aplicación crea los ochenta eventos de un golpe y calcula el tiempo de retiro de cada uno.

Un minuto en vez de cuarenta.

### Compras y ventas

Registro de lotes, con la **diferencia compra-venta** calculada por animal y por lote.

Entran en el cálculo el costo de compra, el flete de compra y los tratamientos. **El alimento no entra**,
por la decisión de la sección 2. Por eso el número se llama diferencia compra-venta y no margen: llamarlo
margen invita a tomar decisiones de compra con un número que no incluye el costo más grande.

Cuando el costo de un animal no sea individual sino prorrateado del lote, la pantalla **lo marca
visualmente**, para que se note de un vistazo qué cifras son exactas y cuáles son un reparto.

### Alimento

Lista simple de compras con totales por mes y por año.

### Ajustes

Respaldo, restauración, catálogos de productos y proveedores, datos del rancho.

---

## 7. Alcance por versión

### Versión 1

- Alta de animal con arete escaneado, foto, categoría y propósito
- Alta de animales pendientes de aretar, y ligado posterior del arete
- Búsqueda por escaneo, por número visual o por apodo
- Ubicaciones y movimientos
- Apartados manuales y automáticos
- Registro de compra con costo
- Registro de venta con precio y diferencia compra-venta
- Tratamientos individuales y por lote, con tiempo de retiro y bloqueo de venta
- Gastos de alimento
- Inventario del hato
- Respaldo y restauración

### Versión 2

- Reproducción completa: servicios, inseminación, diagnóstico de gestación, fecha probable de parto, registro de parto
- Genealogía y árbol, para evitar consanguinidad
- Pesajes con báscula Bluetooth y ganancia diaria de peso
- Calendario de vacunas con recordatorios
- Reportes: porcentaje de parición, mortalidad, días abiertos, intervalo entre partos
- Exportación a hoja de cálculo

### Versión 3

- Sincronización entre varios dispositivos, con servidor
- Roles: el vaquero captura, el dueño ve reportes
- Documentación de guías de tránsito y trazabilidad
- Versión para iPhone, si hace falta

---

## 8. Riesgos y pendientes

**La lectura del código de barras.** Es el riesgo técnico principal. Hay que probar la cámara del celular contra aretes reales del rancho, incluyendo los sucios y viejos, antes de programar nada. Si la tasa de lectura es mala, se compra un escáner 2D. Y en cualquier caso, la captura manual debe estar siempre disponible.

**Adopción.** Si capturar un animal toma más de quince segundos, la aplicación se abandona y se vuelve al cuaderno. Cada pantalla debe medirse contra eso.

**Condiciones de campo.** Se usa con guantes, con una mano, bajo el sol y sin señal. Botones grandes, alto contraste, todo funcionando sin internet.

**Batería.** Un día de trabajo en el corral con lector conectado y cámara encendida consume mucho. Vale la pena considerar una batería portátil como parte del equipo.

**Respaldo.** Un solo celular es un solo punto de falla. El respaldo automático no es opcional.

Como no hay servidor, "automático" no puede significar que algo lo suba solo a la nube. Lo que sí se
puede hacer, y es lo que se va a hacer, es **fricción dura**: la app lleva una cuenta de los registros
creados desde el último respaldo, y cuando se cierra un trabajo por lote, se termina un alta de más de
diez animales o se cierra un lote de venta, aparece una pantalla que bloquea la navegación y no tiene
botón de regresar. Un solo botón: RESPALDAR AHORA.

Dos límites que hay que asumir, porque no se pueden esquivar:

- **Android no deja atrapar al usuario.** El botón de inicio y el cambiador de aplicaciones siempre
  ganan. Lo que sí se garantiza es que la deuda de respaldo vive en la base de datos, no en memoria:
  si se sale por el botón de inicio, la pantalla bloqueante es lo primero que ve al volver a abrir.
- **No se puede verificar que el archivo se haya enviado.** Android no le avisa a la app si WhatsApp
  realmente mandó el respaldo. Se verifica que el ZIP se haya escrito, que eso sí es seguro, y se le
  pregunta al usuario si ya salió. Si dice que todavía no, la deuda no se limpia.

**Migraciones.** Los datos de la fase 1 son desechables y su tabla se elimina al entrar a la fase 2.
De la fase 2 en adelante, cuando entra el primer animal de verdad, toda migración es sin pérdida de
datos, sostenida por tres cosas: versión de esquema numerada con su paso escrito (nunca
`deleteAllTables()`), pruebas de migración generadas que llenan la base vieja, la migran y verifican
que los datos siguen ahí, y una copia automática del archivo de base antes de correr cualquier
migración.

### Pendientes de definir

- Qué documentos hay que guardar por obligación legal: guías de tránsito, certificados zoosanitarios
- Si se necesita registrar el número de UPP del rancho
- Cuántos animales maneja el rancho hoy y cuántos podría manejar en tres años
- Si el vaquero va a usar la aplicación y en qué momento
- Los umbrales de edad de las categorías
- Cómo se le llama a un macho entero de engorda ya crecido, ahora que se quitó "novillo"

### Resueltos en la versión 2 del documento

- **Los animales sí se pesan al recibirlos.** Por eso el costo por cabeza es real y no prorrateado
  en la mayoría de los lotes de compra.
- **No hay animales castrados** en el rancho.
- **Solo se controla retiro en carne.**
- **Los gastos del lote de compra** se reparten por kilo o por cabeza, y se elige lote por lote.
- **Dentro de un mismo lote puede haber precios distintos por animal**, porque el precio varía por
  temporada y por peso final. El precio individual se captura a mano cuando exista.
- **Vendedores y compradores** son texto libre con autocompletado del historial, no un catálogo.
