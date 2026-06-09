import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/system_provider.dart';
import '../services/auth_service.dart';
import 'metrics_screen.dart';
import 'sensor_screen.dart';
import 'pump_screen.dart';
import 'config_screen.dart';
import 'readings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final _screens = const [
    MetricsScreen(),
    SensorScreen(),
    PumpScreen(),
    ConfigScreen(),
    ReadingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SystemProvider>().conectarMqtt();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conectando ao MQTT...'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final system = context.watch<SystemProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Controle de Irrigação'),
        actions: [
          GestureDetector(
            onTap: () {
              if (!system.mqttConectado && !system.mqttConectando) {
                system.conectarMqtt();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tentando conectar ao MQTT...'),
                    duration: Duration(seconds: 5),
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: system.mqttConectando
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.circle,
                      size: 12,
                      color: system.mqttConectado ? Colors.green : Colors.red,
                    ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Métricas',
          ),
          NavigationDestination(
            icon: Icon(Icons.sensors_outlined),
            selectedIcon: Icon(Icons.sensors),
            label: 'Sensor',
          ),
          NavigationDestination(
            icon: Icon(Icons.water_damage_outlined),
            selectedIcon: Icon(Icons.water_damage),
            label: 'Bomba',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Config',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Leituras',
          ),
        ],
      ),
    );
  }
}
