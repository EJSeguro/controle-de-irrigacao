import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/system_provider.dart';

class MetricsScreen extends StatelessWidget {
  const MetricsScreen({super.key});

  Future<void> _toggleSistema(BuildContext context) async {
    final system = context.read<SystemProvider>();

    if (system.sistemaLigado) {
      system.desligarSistema();
      return;
    }

    final erro = system.configError;
    if (erro != null) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Configuração incompleta'),
          content: Text(erro),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    system.toggleSistema();
  }

  @override
  Widget build(BuildContext context) {
    final system = context.watch<SystemProvider>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: SwitchListTile(
            title: const Text('Sistema'),
            value: system.sistemaLigado,
            onChanged: (_) => _toggleSistema(context),
            secondary: Icon(
              system.sistemaLigado
                  ? Icons.power_settings_new
                  : Icons.power_off,
              color: system.sistemaLigado ? Colors.green : Colors.red,
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
                Text('Consumo de Água',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                _consumoRow(context, 'Hoje', '12,5 L', Icons.today),
                const Divider(),
                _consumoRow(context, 'Este mês', '340 L', Icons.date_range),
                const Divider(),
                _consumoRow(context, 'Este ano', '2.850 L', Icons.calendar_month),
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
                Text('Última Leitura do Sensor',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _infoRow('Umidade', '45%'),
                _infoRow('Status do solo', 'Seco'),
                _infoRow('Data/hora', '08/06/2026 19:30'),
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
                Text('Status do Sistema',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _statusRow('Sensor', true),
                const SizedBox(height: 8),
                _statusRow('Bomba', system.bombaLigada),
                if (system.bombaDesligadaManual)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Bomba desligada manualmente. Ligue-a na tela Bomba para reativar.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        )),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _consumoRow(BuildContext context, String label, String valor, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label),
      trailing: Text(valor, style: const TextStyle(fontWeight: FontWeight.bold)),
      dense: true,
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))],
      ),
    );
  }

  Widget _statusRow(String label, bool ativo) {
    return Row(
      children: [
        Icon(Icons.circle, size: 12, color: ativo ? Colors.green : Colors.red),
        const SizedBox(width: 8),
        Text('$label: ${ativo ? "Ativo" : "Inativo"}'),
      ],
    );
  }
}
