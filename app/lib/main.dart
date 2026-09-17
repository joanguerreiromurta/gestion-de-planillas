import 'package:flutter/material.dart';

import 'db/app_database.dart';
import 'screens/config_screen.dart';
import 'screens/home_screen.dart';
import 'services/config_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.instance.seedClientesSiVacio();
  runApp(const RetirosApp());
}

class RetirosApp extends StatelessWidget {
  const RetirosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Registro de Retiros',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const _Arranque(),
    );
  }
}

class _Arranque extends StatefulWidget {
  const _Arranque();

  @override
  State<_Arranque> createState() => _ArranqueState();
}

class _ArranqueState extends State<_Arranque> {
  bool? _configurado;

  @override
  void initState() {
    super.initState();
    _verificarConfiguracion();
  }

  Future<void> _verificarConfiguracion() async {
    final ok = await ConfigService.instance.estaConfigurado();
    if (!mounted) return;
    setState(() => _configurado = ok);
  }

  @override
  Widget build(BuildContext context) {
    if (_configurado == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_configurado == false) {
      return ConfigScreen(
        onGuardado: () => setState(() => _configurado = true),
      );
    }
    return const HomeScreen();
  }
}
