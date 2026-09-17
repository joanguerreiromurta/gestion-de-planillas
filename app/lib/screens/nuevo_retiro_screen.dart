import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../models/cliente.dart';
import '../models/retiro.dart';
import '../services/config_service.dart';
import '../services/sync_service.dart';

class NuevoRetiroScreen extends StatefulWidget {
  const NuevoRetiroScreen({super.key});

  @override
  State<NuevoRetiroScreen> createState() => _NuevoRetiroScreenState();
}

class _NuevoRetiroScreenState extends State<NuevoRetiroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _direccionCtrl = TextEditingController();
  final _litrosCtrl = TextEditingController();
  final _importeCtrl = TextEditingController();
  TextEditingController? _generadorFieldCtrl;
  bool _guardando = false;

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final chofer = await ConfigService.instance.getChofer() ?? '';
    final retiro = Retiro(
      id: const Uuid().v4(),
      fecha: DateTime.now(),
      chofer: chofer,
      generador: (_generadorFieldCtrl?.text ?? '').trim(),
      direccion: _direccionCtrl.text.trim(),
      litros: double.parse(_litrosCtrl.text.replaceAll(',', '.')),
      importe: double.parse(_importeCtrl.text.replaceAll(',', '.')),
    );

    await AppDatabase.instance.insertRetiro(retiro);
    // Dispara la sincronizacion en segundo plano; si no hay señal, el
    // retiro ya quedo guardado y se sincroniza mas tarde solo.
    unawaited(SyncService.instance.sincronizarPendientes());

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _direccionCtrl.dispose();
    _litrosCtrl.dispose();
    _importeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo retiro')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Autocomplete<Cliente>(
                displayStringForOption: (c) => c.nombre,
                optionsBuilder: (textEditingValue) async {
                  if (textEditingValue.text.trim().isEmpty) {
                    return const Iterable<Cliente>.empty();
                  }
                  return AppDatabase.instance
                      .buscarClientes(textEditingValue.text.trim());
                },
                onSelected: (cliente) {
                  _direccionCtrl.text = cliente.direccion;
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onSubmitted) {
                  _generadorFieldCtrl = controller;
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Generador',
                      border: OutlineInputBorder(),
                      helperText: 'Escribi para buscar un cliente cargado',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Obligatorio'
                        : null,
                  );
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _direccionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Direccion',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _litrosCtrl,
                decoration: const InputDecoration(
                  labelText: 'Litros retirados',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: _validarNumero,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _importeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Importe abonado',
                  border: OutlineInputBorder(),
                  prefixText: '\$ ',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: _validarNumero,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar retiro'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validarNumero(String? v) {
    if (v == null || v.trim().isEmpty) return 'Obligatorio';
    final n = double.tryParse(v.replaceAll(',', '.'));
    if (n == null || n < 0) return 'Numero invalido';
    return null;
  }
}
