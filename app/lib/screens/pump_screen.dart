import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/system_provider.dart';

class PumpScreen extends StatelessWidget {
  const PumpScreen({super.key});

  String _formatarTempo(int segundos) {
    final min = segundos ~/ 60;
    final s = segundos % 60;
    if (min > 0) return '$min min ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final system = context.watch<SystemProvider>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: SwitchListTile(
            title: const Text('Bomba'),
            subtitle: Text(!system.sessaoAtiva
                ? 'Sistema desligado'
                : system.bombaDesligadaManual
                    ? 'Desligada manualmente'
                    : system.bombaLigada
                        ? 'Ligada'
                        : 'Desligada'),
            value: system.bombaLigada,
            onChanged: (v) {
              if (v) {
                if (!system.sessaoAtiva) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ligue o sistema na aba Sensor primeiro.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
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
                Text('Último Ciclo',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                if (system.resultadoAntes != null) ...[
                  _infoRow('Umidade antes', '${system.resultadoAntes}%'),
                  _infoRow('Umidade depois', '${system.resultadoDepois}%'),
                  _infoRow('Tempo bomba ligada', _formatarTempo(system.resultadoTempoBomba ?? 0)),
                  _infoRow('Consumo do ciclo', '${system.consumoUltimoCiclo.toStringAsFixed(1)} L'),
                ] else ...[
                  Text('Nenhum ciclo concluído ainda.',
                      style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                ],
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
                _infoRow('Potência da bomba', '${system.potenciaBomba.toStringAsFixed(0)} W'),
                _infoRow('Diâmetro da tubulação', '${system.diametroTubulacao.toStringAsFixed(0)} mm'),
                _infoRow('Vazão estimada', '~${system.vazaoEstimada.toStringAsFixed(1)} L/min'),
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
