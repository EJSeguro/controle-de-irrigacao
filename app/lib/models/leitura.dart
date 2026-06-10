/// Leitura de umidade do solo recebida do sensor (manual ou automática).
class Leitura {
  final DateTime data;
  final int umidade;
  final String statusSolo;
  final String tipo; // "manual" ou "automática"

  Leitura({
    required this.data,
    required this.umidade,
    required this.statusSolo,
    required this.tipo,
  });

  String get horaFormatada =>
      '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year} ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
}
