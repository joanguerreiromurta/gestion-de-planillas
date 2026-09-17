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

function guardarRetiro(datos) {
  if (!datos.id || !datos.fecha || !datos.chofer || !datos.generador) {
    return { status: 'error', mensaje: 'Faltan campos obligatorios' };
  }

  var hoja = obtenerOCrearHoja();
  if (idYaExiste(hoja, datos.id)) {
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
