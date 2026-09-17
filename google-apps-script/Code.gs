/**
 * Backend de sincronizacion del sistema de registro de retiros.
 * Se pega en un proyecto de Apps Script vinculado a la planilla de Google
 * y se publica como aplicacion web (ver README.md de esta carpeta).
 */

var HOJA_RETIROS = 'Retiros';
var COLUMNAS = ['ID', 'Fecha', 'Hora', 'Chofer', 'Generador', 'Direccion', 'Litros', 'Importe', 'Recibido'];

function doPost(e) {
  var lock = LockService.getScriptLock();
  lock.waitLock(30000);
  try {
    var datos = JSON.parse(e.postData.contents);
    var resultado = guardarRetiro(datos);
    return respuestaJson(resultado);
  } catch (error) {
    return respuestaJson({ status: 'error', mensaje: String(error) });
  } finally {
    lock.releaseLock();
  }
}

function doGet(e) {
  return respuestaJson({ status: 'ok', mensaje: 'Backend de retiros activo' });
}

/**
 * Prueba manual: seleccionar "pruebaManual" en el desplegable de funciones
 * de arriba del editor y apretar "Ejecutar". No depende del objeto "e" que
 * solo llega cuando lo invoca la app web, asi que sirve para probar la
 * escritura en la planilla sin pasar por la app ni por la URL publicada.
 * Despues de ejecutar, revisar "Registro de ejecucion" (Ver > Registros) o
 * el panel que aparece abajo del editor: ahi va a quedar el rastro de en
 * que paso fallo, si fallo.
 */
function pruebaManual() {
  var resultado = guardarRetiro({
    id: 'prueba-' + new Date().getTime(),
    fecha: new Date().toISOString(),
    chofer: 'Prueba manual',
    generador: 'Cliente de prueba',
    direccion: 'Direccion de prueba',
    litros: 100,
    importe: 5000,
  });
  Logger.log(JSON.stringify(resultado));
}

function guardarRetiro(datos) {
  Logger.log('guardarRetiro: recibido ' + JSON.stringify(datos));

  if (!datos.id || !datos.fecha || !datos.chofer || !datos.generador) {
    Logger.log('guardarRetiro: faltan campos obligatorios');
    return { status: 'error', mensaje: 'Faltan campos obligatorios' };
  }

  var hoja = obtenerOCrearHoja();
  Logger.log('guardarRetiro: hoja lista -> ' + hoja.getName());

  if (idYaExiste(hoja, datos.id)) {
    Logger.log('guardarRetiro: id duplicado, no se agrega fila');
    return { status: 'ok', duplicado: true };
  }

  var fecha = new Date(datos.fecha);
  hoja.appendRow([
    datos.id,
    Utilities.formatDate(fecha, Session.getScriptTimeZone(), 'dd/MM/yyyy'),
    Utilities.formatDate(fecha, Session.getScriptTimeZone(), 'HH:mm'),
    datos.chofer,
    datos.generador,
    datos.direccion || '',
    Number(datos.litros) || 0,
    Number(datos.importe) || 0,
    new Date(),
  ]);
  Logger.log('guardarRetiro: fila agregada en ' + hoja.getName());

  return { status: 'ok', duplicado: false };
}

function idYaExiste(hoja, id) {
  var ultimaFila = hoja.getLastRow();
  if (ultimaFila < 2) return false;
  var idsExistentes = hoja.getRange(2, 1, ultimaFila - 1, 1).getValues();
  for (var i = 0; i < idsExistentes.length; i++) {
    if (idsExistentes[i][0] === id) return true;
  }
  return false;
}

function obtenerOCrearHoja() {
  var libro = SpreadsheetApp.getActiveSpreadsheet();
  var hoja = libro.getSheetByName(HOJA_RETIROS);
  if (!hoja) {
    hoja = libro.insertSheet(HOJA_RETIROS);
  }
  if (hoja.getLastRow() === 0) {
    hoja.appendRow(COLUMNAS);
    hoja.setFrozenRows(1);
  }
  return hoja;
}

function respuestaJson(objeto) {
  return ContentService.createTextOutput(JSON.stringify(objeto))
    .setMimeType(ContentService.MimeType.JSON);
}
