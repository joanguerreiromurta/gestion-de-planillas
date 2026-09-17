import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/app_database.dart';
import '../models/retiro.dart';
import '../services/sync_service.dart';
import 'config_screen.dart';
import 'nuevo_retiro_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Retiro> _retirosHoy = [];
  SyncStatus _syncStatus = SyncStatus.alDia;
  bool _cargando = true;

  final _formatoHora = DateFormat('HH:mm');
  final _formatoMoneda = NumberFormat.currency(locale: 'es_AR', symbol: r'$');
  final _formatoLitros = NumberFormat('#,##0', 'es_AR');

  @override
  void initState() {
    super.initState();
    SyncService.instance.iniciarEscuchaDeConexion();
    SyncService.instance.status.listen((status) {
      if (!mounted) return;
      setState(() => _syncStatus = status);
      // Se recarga la lista tanto si termino bien como si quedo algo
      // pendiente: aunque el resultado global sea "error", puede haber
      // otros retiros que sí se hayan sincronizado y hay que reflejarlo.
      if (status == SyncStatus.alDia || status == SyncStatus.error) {
        _cargarRetirosHoy();
      }
    });
    _cargarRetirosHoy();
    SyncService.instance.sincronizarPendientes();
  }

  Future<void> _cargarRetirosHoy() async {
    final retiros = await AppDatabase.instance.retirosDelDia(DateTime.now());
    if (!mounted) return;
    setState(() {
      _retirosHoy = retiros;
      _cargando = false;
    });
  }

  double get _totalLitros =>
      _retirosHoy.fold(0, (suma, r) => suma + r.litros);

  double get _totalImporte =>
      _retirosHoy.fold(0, (suma, r) => suma + r.importe);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Retiros de hoy'),
        actions: [
          _SyncBadge(
            status: _syncStatus,
            pendientes: _retirosHoy.where((r) => !r.sincronizado).length,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configuracion',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ConfigScreen(onGuardado: () {
                  Navigator.of(context).pop();
                }),
              ),
            ),
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await SyncService.instance.sincronizarPendientes();
                await _cargarRetirosHoy();
              },
              child: Column(
                children: [
                  _ResumenDelDia(
                    totalLitros: _formatoLitros.format(_totalLitros),
                    totalImporte: _formatoMoneda.format(_totalImporte),
                    cantidad: _retirosHoy.length,
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _retirosHoy.isEmpty
                        ? ListView(
                            children: const [
                              Padding(
                                padding: EdgeInsets.all(32),
                                child: Text(
                                  'Todavia no cargaste retiros hoy.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.black54),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            itemCount: _retirosHoy.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final r = _retirosHoy[i];
                              return ListTile(
                                title: Text(r.generador),
                                subtitle: Text(
                                  '${r.direccion}\n${_formatoLitros.format(r.litros)} L · ${_formatoMoneda.format(r.importe)}',
                                ),
                                isThreeLine: true,
                                leading: Text(_formatoHora.format(r.fecha)),
                                trailing: Icon(
                                  r.sincronizado
                                      ? Icons.cloud_done
                                      : Icons.cloud_upload_outlined,
                                  color: r.sincronizado
                                      ? Colors.green
                                      : Colors.orange,
                                  size: 20,
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final guardado = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const NuevoRetiroScreen()),
          );
          if (guardado == true) _cargarRetirosHoy();
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuevo retiro'),
      ),
    );
  }
}

class _ResumenDelDia extends StatelessWidget {
  const _ResumenDelDia({
    required this.totalLitros,
    required this.totalImporte,
    required this.cantidad,
  });

  final String totalLitros;
  final String totalImporte;
  final int cantidad;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Metrica(valor: '$cantidad', etiqueta: 'Retiros'),
          _Metrica(valor: totalLitros, etiqueta: 'Litros'),
          _Metrica(valor: totalImporte, etiqueta: 'Total'),
        ],
      ),
    );
  }
}

class _Metrica extends StatelessWidget {
  const _Metrica({required this.valor, required this.etiqueta});

  final String valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(valor, style: Theme.of(context).textTheme.headlineSmall),
        Text(etiqueta, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.status, required this.pendientes});

  final SyncStatus status;
  final int pendientes;

  @override
  Widget build(BuildContext context) {
    // "error" con 0 pendientes reales (ya se resolvieron solos en un
    // reintento posterior) se muestra igual que "al dia", para no dejar
    // una nube naranja pegada sin que haya nada realmente atascado.
    final estadoEfectivo =
        status == SyncStatus.error && pendientes == 0 ? SyncStatus.alDia : status;

    final (icon, color, tooltip) = switch (estadoEfectivo) {
      SyncStatus.sincronizando => (
          Icons.sync,
          Colors.white,
          'Sincronizando...'
        ),
      SyncStatus.alDia => (Icons.cloud_done, Colors.white, 'Todo al dia'),
      SyncStatus.error => (
          Icons.cloud_off,
          Colors.amber,
          pendientes == 1
              ? '1 retiro sin sincronizar, se reintentara'
              : '$pendientes retiros sin sincronizar, se reintentara'
        ),
      SyncStatus.sinConfigurar => (
          Icons.warning_amber,
          Colors.amber,
          'Falta configurar la sincronizacion'
        ),
    };
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Tooltip(
        message: tooltip,
        child: Icon(icon, color: color),
      ),
    );
  }
}
