import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/system_provider.dart';

class ReadingsScreen extends StatelessWidget {
  const ReadingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final system = context.watch<SystemProvider>();
    final leituras = system.leituras;

    if (leituras.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 64,
                color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('Nenhuma leitura ainda.',
                style: Theme.of(context).textTheme.bodyLarge),
            const Text('Faça uma leitura rápida na tela Métricas.'),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: leituras.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final l = leituras[i];
        final isManual = l.tipo == 'manual';

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l.horaFormatada,
                        style: Theme.of(context).textTheme.bodySmall),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isManual
                            ? Colors.blue.withValues(alpha: 0.15)
                            : Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isManual ? 'Manual' : 'Automática',
                        style: TextStyle(
                          fontSize: 12,
                          color: isManual ? Colors.blue : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _infoCol('Umidade', '${l.umidade}%'),
                    const SizedBox(width: 32),
                    _infoCol('Status', l.statusSolo),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoCol(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}
