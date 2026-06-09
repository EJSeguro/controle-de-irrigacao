import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/system_provider.dart';

class PumpScreen extends StatelessWidget {
  const PumpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final system = context.watch<SystemProvider>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: SwitchListTile(
            title: const Text('Bomba'),
            subtitle: Text(system.bombaDesligadaManual
                ? 'Desligada manualmente'
                : system.bombaLigada
                    ? 'Ligada'
                    : 'Desligada'),
            value: system.bombaLigada,
            onChanged: (v) {
              if (v) {
                system.ligarBomba();
              } else {
                system.desligarBombaManual();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Bomba desligada manualmente. Sistema desligado.'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            secondary: Icon(
              Icons.water_damage,
              color: system.bombaLigada ? Colors.green : Colors.grey,
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
                Text('Status Atual',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _infoRow('Tempo ligada', system.bombaLigada ? '2 min 30 s' : '—'),
                _infoRow('Consumo atual', system.bombaLigada ? '7,5 L/min' : '— L/min'),
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
                Text('Último Ligamento',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _infoRow('Data', '07/06/2026'),
                _infoRow('Hora', '14:22'),
                _infoRow('Tempo ligado', '2 min 30 s'),
                _infoRow('Consumo do ciclo', '18,75 L'),
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
                Text('Parâmetros para Cálculo',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _infoRow('Potência da bomba', '${system.potenciaBomba.toStringAsFixed(0)} V'),
                _infoRow('Diâmetro da tubulação', '${system.diametroTubulacao.toStringAsFixed(0)} mm'),
                _infoRow('Vazão estimada', '~16 L/min'),
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
