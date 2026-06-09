import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/leitura.dart';
import '../services/database_service.dart';
import '../services/mqtt_service.dart';

class SystemProvider extends ChangeNotifier {
  final MqttService _mqtt;
  final DatabaseService _db;

  String? _usuarioEmail;

  SystemProvider(this._mqtt, this._db) {
    _setupMqttCallbacks();
  }

  Future<void> inicarSessao(String email) async {
    _usuarioEmail = email;
    _leituras.clear();
    _historicoConsumo.clear();
    _ultimaLeitura = null;
    _consumoUltimoCiclo = 0;
    _resultadoAntes = null;
    _resultadoDepois = null;
    _resultadoTempoBomba = null;
    _sistemaLigado = false;
    _bombaLigada = false;
    _bombaDesligadaManual = false;
    _sessaoAtiva = false;
    final temDados = await _db.usuarioTemDados(email);
    if (!temDados) {
      await _db.sembrarDadosMock(email);
    }
    await Future.wait([
      _carregarLeituras(),
      _carregarConsumos(),
      _carregarConfig(),
    ]);
    notifyListeners();
  }

  Future<void> _carregarLeituras() async {
    final saved = await _db.carregarLeituras(usuarioEmail: _usuarioEmail);
    _leituras.addAll(saved);
    if (_leituras.isNotEmpty) _ultimaLeitura = _leituras.first;
  }

  Future<void> _carregarConsumos() async {
    final saved = await _db.carregarConsumos(usuarioEmail: _usuarioEmail);
    _historicoConsumo.addAll(saved);
  }

  Future<void> _carregarConfig() async {
    final cfg = await _db.carregarConfigs(usuarioEmail: _usuarioEmail);
    _intervaloLeitura = int.tryParse(cfg['intervalo_leitura'] ?? '') ?? 30;
    _unidadeIntervalo = cfg['unidade_intervalo'] ?? 'min';
    _potenciaBomba = double.tryParse(cfg['potencia_bomba'] ?? '') ?? 12;
    _diametroTubulacao = double.tryParse(cfg['diametro_tubulacao'] ?? '') ?? 20;
  }

  bool _sistemaLigado = false;
  bool _bombaLigada = false;
  bool _bombaDesligadaManual = false;
  bool _sessaoAtiva = false;
  bool _mqttConectado = false;
  bool _mqttConectando = false;
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
  bool get mqttConectando => _mqttConectando;
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
        final record = ConsumoRecord(
          data: DateTime.now(),
          litros: _consumoUltimoCiclo,
          tempoSegundos: _resultadoTempoBomba!,
        );
        _historicoConsumo.insert(0, record);
        _db.salvarConsumo(record, usuarioEmail: _usuarioEmail ?? '');
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
    _db.salvarLeitura(leitura, usuarioEmail: _usuarioEmail ?? '');
    notifyListeners();
  }

  String _calcularStatus(int umidade) {
    if (umidade < 20) return 'Muito seco';
    if (umidade < 45) return 'Seco';
    if (umidade < 65) return 'Ideal';
    if (umidade < 85) return 'Úmido';
    return 'Encharcado';
  }

  Future<void> conectarMqtt() async {
    _mqttConectando = true;
    notifyListeners();
    for (int tentativa = 0; tentativa < 3; tentativa++) {
      final ok = await _mqtt.connect();
      if (ok) {
        _mqttConectando = false;
        notifyListeners();
        return;
      }
      if (tentativa < 2) {
        await Future.delayed(Duration(seconds: (tentativa + 1) * 2));
      }
    }
    _mqttConectando = false;
    notifyListeners();
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
    if (_mqttConectado) {
      if (_unidadeIntervalo == 'min' && valor >= 1) {
        _mqtt.setConfig(valor * 60);
      } else if (_unidadeIntervalo == 'h' && valor >= 1) {
        _mqtt.setConfig(valor * 3600);
      }
    }
    _db.salvarConfig('intervalo_leitura', valor.toString(), usuarioEmail: _usuarioEmail ?? '');
    notifyListeners();
  }

  void setUnidadeIntervalo(String unidade) {
    _unidadeIntervalo = unidade;
    _db.salvarConfig('unidade_intervalo', unidade, usuarioEmail: _usuarioEmail ?? '');
    notifyListeners();
  }

  void setPotenciaBomba(double valor) {
    _potenciaBomba = valor;
    _db.salvarConfig('potencia_bomba', valor.toString(), usuarioEmail: _usuarioEmail ?? '');
    notifyListeners();
  }

  void setDiametroTubulacao(double valor) {
    _diametroTubulacao = valor;
    _db.salvarConfig('diametro_tubulacao', valor.toString(), usuarioEmail: _usuarioEmail ?? '');
    notifyListeners();
  }
}
