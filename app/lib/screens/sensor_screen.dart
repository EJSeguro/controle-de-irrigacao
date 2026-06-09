import 'package:flutter/material.dart';

class SensorScreen extends StatefulWidget {
  const SensorScreen({super.key});

  @override
  State<SensorScreen> createState() => _SensorScreenState();
}

class _SensorScreenState extends State<SensorScreen> {
  bool _sensorLigado = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: SwitchListTile(
            title: const Text('Sensor'),
            subtitle: Text(_sensorLigado ? 'Fazendo leitura...' : 'Desligado'),
            value: _sensorLigado,
            onChanged: (v) => setState(() => _sensorLigado = v),
            secondary: Icon(
              Icons.sensors,
              color: _sensorLigado ? Colors.green : Colors.grey,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Última Leitura',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _infoRow('Data', '08/06/2026'),
                _infoRow('Hora', '19:30'),
                _infoRow('Umidade', '45%'),
                _infoRow('Status do solo', 'Seco'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Médias da Última Sessão',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _infoRow('Umidade antes de regar', '20%'),
                _infoRow('Umidade depois de regar', '65%'),
                _infoRow('Tempo bomba ligada', '45 seg'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
