# Planilla de Google — configuración

## 1. Crear la planilla

1. Crear una planilla nueva en Google Sheets (ej. "Retiros — [Nombre del cliente]").
2. No hace falta crear la hoja `Retiros` a mano: el script la crea sola con los
   encabezados correctos la primera vez que recibe un retiro.

## 2. Publicar el script de sincronización

1. En la planilla: `Extensiones → Apps Script`.
2. Borrar el contenido de `Código.gs` y pegar el contenido de `Code.gs` de esta carpeta.
3. Guardar el proyecto (ícono de disquete).
4. `Implementar → Nueva implementación`.
5. Tipo: **Aplicación web**.
6. Configuración:
   - Ejecutar como: **Yo** (tu cuenta de Google).
   - Quién tiene acceso: **Cualquier usuario**.
     (Necesario para que la app del celular pueda escribir sin loguearse con
     una cuenta de Google. El acceso de *lectura* a la planilla en sí sigue
     restringido a quien vos compartas la planilla.)
7. Autorizar los permisos que pide Google la primera vez.
8. Copiar la **URL de la aplicación web** (`.../exec`) — esa es la URL que se
   carga en la pantalla de configuración de la app del chofer.

### ⚠️ Actualizar el script cuando cambia el código

Pegar el código nuevo en `Código.gs` y guardar **no alcanza**. La URL `/exec`
publicada sigue sirviendo una foto fija del código tal como estaba en el
momento del último deploy, aunque el archivo se haya editado después.
Cada vez que se actualiza `Code.gs` hay que:

1. `Implementar → Gestionar implementaciones`.
2. Ícono de lápiz (editar) sobre la implementación activa.
3. En "Versión", elegir **Nueva versión**.
4. `Implementar`.

La URL `/exec` no cambia, así que no hace falta tocar nada en la app.

## 3. Estructura de la hoja `Retiros`

| Columna | Contenido |
| --- | --- |
| ID | Identificador único generado en el celular (evita duplicados) |
| Fecha | dd/mm/aaaa |
| Hora | hh:mm |
| Chofer | Nombre configurado en el celular |
| Generador | Cliente cargado |
| Direccion | Dirección del retiro |
| Litros | Litros retirados |
| Importe | Importe abonado |
| Recibido | Fecha y hora en que el servidor recibió el dato |

Esta hoja es de solo lectura desde la app: la administración puede filtrar,
ordenar o exportar a Excel (`Archivo → Descargar → Microsoft Excel`), pero no
hace falta tocarla a mano.

El script también crea sola una hoja **`Log`**, con una fila por cada pedido
que recibe (llegue bien o no): fecha/hora, el cuerpo recibido tal cual, y el
resultado (`ok`, `duplicado` o `error` + motivo). Sirve para diagnosticar sin
tener que entrar al panel de Ejecuciones de Apps Script.

## 4. Hoja de totales (opcional, se arma una sola vez)

Para ver los totales del día por chofer sin tocar la hoja `Retiros`, crear una
segunda hoja llamada `Totales` con esta fórmula en A1:

```
=QUERY(Retiros!A2:I, "select D, sum(G), sum(H) where D is not null group by D label sum(G) 'Litros', sum(H) 'Importe'", 0)
```

Agrupa por chofer (columna D). Para acotarlo al día de hoy, se puede agregar
`and B = '"&TEXT(TODAY(),"dd/mm/yyyy")&"'` a la condición `where`.

## 5. Actualizar el listado de clientes de la app

El listado de clientes que ve el chofer al escribir en "Generador" **no** se
lee de esta planilla: viaja precargado dentro de la app (`assets/clientes_seed.json`
en el proyecto Flutter), porque tiene que estar disponible sin conexión desde
el primer uso. Para actualizarlo:

1. Editar `app/assets/clientes_seed.json` con el listado real de clientes.
2. Generar una nueva versión del APK e instalarla en los celulares.

Si la lista de clientes cambia con frecuencia, es una de las primeras cosas a
resolver distinto en la Etapa 2 (por ejemplo, descargándola desde el servidor
en vez de precargarla).
