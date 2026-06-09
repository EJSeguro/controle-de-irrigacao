import 'package:flutter/foundation.dart';

class SystemProvider extends ChangeNotifier {
  bool _sistemaLigado = false;
  bool _bombaLigada = false;
  bool _bombaDesligadaManual = false;

  int _intervaloLeitura = 30;
  String _unidadeIntervalo = 'min';
  double _potenciaBomba = 12;
  double _diametroTubulacao = 20;

  bool get sistemaLigado => _sistemaLigado;
  bool get bombaLigada => _bombaLigada;
  bool get bombaDesligadaManual => _bombaDesligadaManual;
  int get intervaloLeitura => _intervaloLeitura;
  String get unidadeIntervalo => _unidadeIntervalo;
  double get potenciaBomba => _potenciaBomba;
  double get diametroTubulacao => _diametroTubulacao;

  bool get configValida =>
      _intervaloLeitura > 0 && _potenciaBomba > 0 && _diametroTubulacao > 0;

  String? get configError {
    if (_intervaloLeitura <= 0) return 'Configure o intervalo de leitura do sensor.';
    if (_potenciaBomba <= 0) return 'Configure a potência da bomba.';
    if (_diametroTubulacao <= 0) return 'Configure o diâmetro da tubulação.';
    return null;
  }

  void toggleSistema() {
    if (_sistemaLigado) {
      _sistemaLigado = false;
      _bombaLigada = false;
    } else {
      _sistemaLigado = true;
      if (!_bombaDesligadaManual) {
        _bombaLigada = true;
      }
    }
    notifyListeners();
  }

  void desligarSistema() {
    _sistemaLigado = false;
    _bombaLigada = false;
    notifyListeners();
  }

  void ligarBomba() {
    _bombaDesligadaManual = false;
    _bombaLigada = true;
    _sistemaLigado = true;
    notifyListeners();
  }

  void desligarBombaManual() {
    _bombaDesligadaManual = true;
    _bombaLigada = false;
    _sistemaLigado = false;
    notifyListeners();
  }

  void setIntervalo(int valor) {
    _intervaloLeitura = valor;
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
