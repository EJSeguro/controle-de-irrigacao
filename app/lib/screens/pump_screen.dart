import 'package:flutter/material.dart';

class PumpScreen extends StatelessWidget {
  const PumpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status Atual',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _statusRow(context, 'Bomba', false),
                const SizedBox(height: 8),
                _infoRow('Tempo ligada', '—'),
                _infoRow('Consumo atual', '— L/min'),
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
                _infoRow('Potência da bomba', '12 V'),
                _infoRow('Diâmetro da tubulação', '20 mm'),
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

  Widget _statusRow(BuildContext context, String label, bool ativo) {
    return Row(
      children: [
        Icon(Icons.circle, size: 12, color: ativo ? Colors.green : Colors.red),
        const SizedBox(width: 8),
        Text('$label: ${ativo ? "Ligada" : "Desligada"}'),
      ],
    );
  }
}
