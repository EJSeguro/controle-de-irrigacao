import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/system_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/mqtt_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()..init()),
        ChangeNotifierProvider(create: (_) => SystemProvider(MqttService(), DatabaseService())),
      ],
      child: const IrrigacaoApp(),
    ),
  );
}

class IrrigacaoApp extends StatelessWidget {
  const IrrigacaoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Controle de Irrigação',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: Consumer<AuthService>(
        builder: (_, auth, _) {
          if (auth.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (auth.isAuthenticated) {
            return const HomeScreen();
          }
          return const AuthScreen();
        },
      ),
    );
  }
}
