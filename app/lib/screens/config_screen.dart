import 'package:flutter/material.dart';

import '../services/config_service.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key, required this.onGuardado});

  final VoidCallback onGuardado;

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _choferCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargarValoresActuales();
  }

  Future<void> _cargarValoresActuales() async {
    final chofer = await ConfigService.instance.getChofer();
    final url = await ConfigService.instance.getWebhookUrl();
    if (!mounted) return;
    setState(() {
      _choferCtrl.text = chofer ?? '';
      _urlCtrl.text = url ?? '';
    });
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    await ConfigService.instance.setChofer(_choferCtrl.text);
    await ConfigService.instance.setWebhookUrl(_urlCtrl.text);
    if (!mounted) return;
    setState(() => _guardando = false);
    widget.onGuardado();
  }

  @override
  void dispose() {
    _choferCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuracion inicial')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Estos datos se cargan una sola vez en el celular.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _choferCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del chofer',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'URL de sincronizacion (Google Apps Script)',
                  border: OutlineInputBorder(),
                  hintText: 'https://script.google.com/macros/s/.../exec',
                ),
                keyboardType: TextInputType.url,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
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
                    : const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
