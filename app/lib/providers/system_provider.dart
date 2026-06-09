import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/leitura.dart';
import '../services/database_service.dart';
import '../services/mqtt_service.dart';

class ConsumoRecord {
  final DateTime data;
  final double litros;
  final int tempoSegundos;

  ConsumoRecord({
    required this.data,
    required this.litros,
    required this.tempoSegundos,
  });
}

class SystemProvider extends ChangeNotifier {
  final MqttService _mqtt;
  final DatabaseService _db;

  SystemProvider(this._mqtt, this._db) {
    _setupMqttCallbacks();
    _carregarLeituras();
  }

  Future<void> _carregarLeituras() async {
    final saved = await _db.carregarLeituras();
    _leituras.addAll(saved);
    if (_leituras.isNotEmpty) _ultimaLeitura = _leituras.first;
    notifyListeners();
  }

  bool _sistemaLigado = false;
  bool _bombaLigada = false;
  bool _bombaDesligadaManual = false;
  bool _sessaoAtiva = false;
  bool _mqttConectado = false;
  bool _espOnline = false;

  int _intervaloLeitura = 30;
  String _unidadeIntervalo = 'min';
  double _potenciaBomba = 12;
  double _diametroTubulacao = 20;

  int? _resultadoAntes;
  int? _resultadoDepois;
  int? _resultadoTempoBomba;

  final List<Leitura> _leituras = [];
  Leitura? _ultimaLeitura;

  final List<ConsumoRecord> _historicoConsumo = [];
  double _consumoUltimoCiclo = 0;

  bool get sistemaLigado => _sistemaLigado;
  bool get bombaLigada => _bombaLigada;
  bool get bombaDesligadaManual => _bombaDesligadaManual;
  bool get sessaoAtiva => _sessaoAtiva;
  bool get mqttConectado => _mqttConectado;
  bool get espOnline => _espOnline;
  int get intervaloLeitura => _intervaloLeitura;
  String get unidadeIntervalo => _unidadeIntervalo;
  double get potenciaBomba => _potenciaBomba;
  double get diametroTubulacao => _diametroTubulacao;
  List<Leitura> get leituras => List.unmodifiable(_leituras);
  Leitura? get ultimaLeitura => _ultimaLeitura;
  int? get resultadoAntes => _resultadoAntes;
  int? get resultadoDepois => _resultadoDepois;
  int? get resultadoTempoBomba => _resultadoTempoBomba;
  double get consumoUltimoCiclo => _consumoUltimoCiclo;
  List<ConsumoRecord> get historicoConsumo => List.unmodifiable(_historicoConsumo);

  static const double _coeficienteVazao = 0.0667;
  double get vazaoEstimada => _potenciaBomba * _diametroTubulacao * _coeficienteVazao;

  double get consumoHoje {
    final hoje = DateTime.now();
    return _historicoConsumo
        .where((r) =>
            r.data.year == hoje.year &&
            r.data.month == hoje.month &&
            r.data.day == hoje.day)
        .fold(0, (sum, r) => sum + r.litros);
  }

  double get consumoMes {
    final hoje = DateTime.now();
    return _historicoConsumo
        .where((r) => r.data.year == hoje.year && r.data.month == hoje.month)
        .fold(0, (sum, r) => sum + r.litros);
  }

  double get consumoAno {
    final hoje = DateTime.now();
    return _historicoConsumo
        .where((r) => r.data.year == hoje.year)
        .fold(0, (sum, r) => sum + r.litros);
  }

  bool get configValida =>
      _intervaloLeitura > 0 && _potenciaBomba > 0 && _diametroTubulacao > 0;

  String? get configError {
    if (_intervaloLeitura <= 0) return 'Configure o intervalo de leitura do sensor.';
    if (_potenciaBomba <= 0) return 'Configure a potência da bomba.';
    if (_diametroTubulacao <= 0) return 'Configure o diâmetro da tubulação.';
    return null;
  }

  void _setupMqttCallbacks() {
    _mqtt.onLeituraSensor = (data) {
      final umidade = data['umidade'] as int? ?? 0;
      final tipo = (data['tipo'] as String? ?? 'auto') == 'manual' ? 'manual' : 'automática';
      final statusStr = data['status'] as String?;
      _adicionarLeitura(umidade, tipo, statusSolo: statusStr);

      final bombaStatus = (data['bomba'] as String? ?? '').toUpperCase();
      if (bombaStatus == 'ON') {
        _bombaLigada = true;
      } else if (bombaStatus == 'OFF') {
        _bombaLigada = false;
      }
      notifyListeners();
    };

    _mqtt.onResultadoSessao = (data) {
      _resultadoAntes = data['antes'] as int?;
      _resultadoDepois = data['depois'] as int?;
      _resultadoTempoBomba = data['tempo_bomba'] as int?;
      _sessaoAtiva = false;

      if (_resultadoTempoBomba != null) {
        _consumoUltimoCiclo = vazaoEstimada * _resultadoTempoBomba! / 60;
        _historicoConsumo.insert(0, ConsumoRecord(
          data: DateTime.now(),
          litros: _consumoUltimoCiclo,
          tempoSegundos: _resultadoTempoBomba!,
        ));
      }

      notifyListeners();
    };

    _mqtt.onStatusBomba = (status) {
      _bombaLigada = status == 'ON';
      notifyListeners();
    };

    _mqtt.onConexaoEsp = (online) {
      _espOnline = online;
      notifyListeners();
    };

    _mqtt.onConexaoMqtt = (conectado) {
      _mqttConectado = conectado;
      notifyListeners();
    };
  }

  void _adicionarLeitura(int umidade, String tipo, {String? statusSolo}) {
    String status = statusSolo ?? _calcularStatus(umidade);

    final leitura = Leitura(
      data: DateTime.now(),
      umidade: umidade,
      statusSolo: status,
      tipo: tipo,
    );

    _leituras.insert(0, leitura);
    _ultimaLeitura = leitura;
    _db.salvarLeitura(leitura);
    notifyListeners();
  }

  String _calcularStatus(int umidade) {
    if (umidade < 20) return 'Muito seco';
    if (umidade < 45) return 'Seco';
    if (umidade < 65) return 'Ideal';
    if (umidade < 85) return 'Úmido';
    return 'Encharcado';
  }

  void conectarMqtt() {
    _mqtt.connect();
  }

  void desconectarMqtt() {
    _mqtt.disconnect();
  }

  void realizarLeituraRapida() {
    if (!_mqttConectado) {
      _adicionarLeitura(Random().nextInt(81) + 5, 'manual');
      return;
    }
    _mqtt.sendComando('LER');
  }

  void toggleSistema() {
    if (!_mqttConectado) {
      _sistemaLigado = !_sistemaLigado;
      if (!_sistemaLigado) _bombaLigada = false;
      notifyListeners();
      return;
    }

    if (_sistemaLigado) {
      _mqtt.sendComando('DESLIGAR');
      _sistemaLigado = false;
      _sessaoAtiva = false;
      _bombaLigada = false;
    } else {
      _mqtt.sendComando('LIGAR');
      _sistemaLigado = true;
      _sessaoAtiva = true;
      _resultadoAntes = null;
      _resultadoDepois = null;
      _resultadoTempoBomba = null;
    }
    notifyListeners();
  }

  void desligarSistema() {
    if (_mqttConectado) {
      _mqtt.sendComando('DESLIGAR');
    }
    _sistemaLigado = false;
    _sessaoAtiva = false;
    _bombaLigada = false;
    notifyListeners();
  }

  void ligarBomba() {
    _bombaDesligadaManual = false;
    _bombaLigada = true;
    _sistemaLigado = true;
    if (_mqttConectado) _mqtt.setBomba(true);
    notifyListeners();
  }

  void desligarBombaManual() {
    _bombaDesligadaManual = true;
    _bombaLigada = false;
    _sistemaLigado = false;
    if (_mqttConectado) _mqtt.setBomba(false);
    notifyListeners();
  }

  void setIntervalo(int valor) {
    _intervaloLeitura = valor;
    if (_mqttConectado && _unidadeIntervalo == 's' && valor >= 10) {
      _mqtt.setConfig(valor);
    } else if (_mqttConectado && _unidadeIntervalo == 'min') {
      _mqtt.setConfig(valor * 60);
    }
    notifyListeners();
  }

  void setUnidadeIntervalo(String unidade) {
    _unidadeIntervalo = unidade;
    notifyListeners();
  }

  void setPotenciaBomba(double valor) {
    _potenciaBomba = valor;
    notifyListeners();
  }

  void setDiametroTubulacao(double valor) {
    _diametroTubulacao = valor;
    notifyListeners();
  }
}
