import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/system_provider.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  late TextEditingController _intervaloCtrl;
  late TextEditingController _potenciaCtrl;
  late TextEditingController _diametroCtrl;
  late String _unidade;

  @override
  void initState() {
    super.initState();
    final s = context.read<SystemProvider>();
    _intervaloCtrl = TextEditingController(text: s.intervaloLeitura.toString());
    _potenciaCtrl = TextEditingController(text: s.potenciaBomba.toStringAsFixed(0));
    _diametroCtrl = TextEditingController(text: s.diametroTubulacao.toStringAsFixed(0));
    _unidade = s.unidadeIntervalo;
  }

  @override
  void dispose() {
    _intervaloCtrl.dispose();
    _potenciaCtrl.dispose();
    _diametroCtrl.dispose();
    super.dispose();
  }

  void _salvar() {
    final system = context.read<SystemProvider>();
    final intervalo = int.tryParse(_intervaloCtrl.text) ?? 0;
    final potencia = double.tryParse(_potenciaCtrl.text) ?? 0;
    final diametro = double.tryParse(_diametroCtrl.text) ?? 0;

    system.setIntervalo(intervalo);
    system.setUnidadeIntervalo(_unidade);
    system.setPotenciaBomba(potencia);
    system.setDiametroTubulacao(diametro);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configurações salvas')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final system = context.watch<SystemProvider>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sensor', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _intervaloCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Intervalo',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'min', label: Text('min')),
                        ButtonSegment(value: 'h', label: Text('h')),
                      ],
                      selected: {_unidade},
                      onSelectionChanged: (v) => setState(() => _unidade = v.first),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (system.intervaloLeitura <= 0)
                  Text('Intervalo deve ser maior que zero.',
                      style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
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
                Text('Bomba', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _potenciaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Potência (W)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _diametroCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Diâmetro da tubulação (mm)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
                if (system.potenciaBomba <= 0 || system.diametroTubulacao <= 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Potência e diâmetro devem ser maiores que zero.',
                        style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: _salvar,
            child: const Text('Salvar Configurações'),
          ),
        ),
      ],
    );
  }
}
