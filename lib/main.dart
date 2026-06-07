import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';
import 'core/theme/app_theme.dart';
import 'features/dashboard/screens/home_screen.dart';
import 'features/sync/background_worker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicialização segura do Workmanager para rodar em segundo plano
  try {
    await Workmanager().initialize(
      callbackDispatcher,
    );
    
    // Agenda tarefa recorrente a cada 24 horas
    await Workmanager().registerPeriodicTask(
      'sync-daily-task',
      'syncDailyTask',
      frequency: const Duration(hours: 24),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
    );
  } catch (e) {
    debugPrint('Workmanager não pôde ser iniciado: $e');
  }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Controle Financeiro Premium',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}
