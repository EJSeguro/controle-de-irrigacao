import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/system_provider.dart';

class SensorScreen extends StatelessWidget {
  const SensorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final system = context.watch<SystemProvider>();
    final ultima = system.ultimaLeitura;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: SwitchListTile(
            title: const Text('Sensor'),
            subtitle: Text(system.sessaoAtiva
                ? 'Sessão ativa'
                : system.mqttConectado
                    ? 'Aguardando comando'
                    : 'MQTT desconectado'),
            value: system.sessaoAtiva,
            onChanged: (v) {
              if (v) {
                system.toggleSistema();
              } else {
                system.desligarSistema();
              }
            },
            secondary: Icon(
              Icons.sensors,
              color: system.sessaoAtiva ? Colors.green : Colors.grey,
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
                if (ultima != null) ...[
                  _infoRow('Data/hora', ultima.horaFormatada),
                  _infoRow('Umidade', '${ultima.umidade}%'),
                  _infoRow('Status do solo', ultima.statusSolo),
                  _infoRow('Tipo', ultima.tipo == 'manual' ? 'Manual' : 'Automática'),
                ] else ...[
                  Text('Nenhuma leitura recebida.',
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
                Text('Última Sessão',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                if (system.resultadoAntes != null) ...[
                  _infoRow('Umidade antes de regar', '${system.resultadoAntes}%'),
                  _infoRow('Umidade depois de regar', '${system.resultadoDepois}%'),
                  _infoRow('Tempo bomba ligada', '${system.resultadoTempoBomba ?? 0} seg'),
                ] else ...[
                  Text('Nenhuma sessão concluída ainda.',
                      style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                ],
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
