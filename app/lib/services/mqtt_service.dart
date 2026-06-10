import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:mqtt_client/mqtt_client.dart';
import 'mqtt_client_platform.dart';

/// Serviço de comunicação MQTT com o broker HiveMQ Cloud.
/// Gerencia conexão TLS/WebSocket, assinatura de tópicos e callbacks de mensagens.
class MqttService {
  // ── Credenciais do broker ─────────────────────────────────
  static const String host = 'bcf945890f214ca89c3846609fd07a6b.s1.eu.hivemq.cloud';
  static const int port = 8883;
  static const String webHost =
      'wss://bcf945890f214ca89c3846609fd07a6b.s1.eu.hivemq.cloud:8884/mqtt';
  static const int webPort = 8884;
  static const String user = 'sensor_umidade';
  static const String pass = 'Senha1234567890';
  static const String clientId = 'AppControleIrrigacao';

  static const String topicoSensor = 'sensor_umidade';
  static const String topicoBomba = 'Bomba';
  static const String topicoComando = 'sensor/comando';
  static const String topicoStatus = 'esp32/status';
  static const String topicoResultado = 'sensor/resultado';
  static const String topicoConfig = 'sensor/config';

  // ── Estado interno ────────────────────────────────────────
  MqttClient? _client;
  StreamSubscription? _sub;

  bool _conectado = false;
  bool get conectado => _conectado;

  // ── Callbacks expostos ────────────────────────────────────
  void Function(Map<String, dynamic> payload)? onLeituraSensor;
  void Function(Map<String, dynamic> payload)? onResultadoSessao;
  void Function(String status)? onStatusBomba;
  void Function(bool online)? onConexaoEsp;
  void Function(bool conectado)? onConexaoMqtt;

  // ── Conexão ───────────────────────────────────────────────
  Future<bool> connect() async {
    if (kIsWeb) {
      _client = createMqttClient(webHost, clientId);
      _client!.port = webPort;
    } else {
      _client = createMqttClient(host, clientId);
      _client!.port = port;
    }
    _client!.keepAlivePeriod = 30;
    _client!.logging(on: false);

    _client!.autoReconnect = true;
    _client!.resubscribeOnAutoReconnect = true;

    _client!.connectionMessage = MqttConnectMessage()
        .withWillTopic(topicoStatus)
        .withWillMessage('offline')
        .withWillQos(MqttQos.atLeastOnce)
        .startClean();

    try {
      await _client!.connect(user, pass).timeout(const Duration(seconds: 30));
    } on TimeoutException {
      _conectado = false;
      onConexaoMqtt?.call(false);
      return false;
    } catch (e) {
      debugPrint('MQTT connection error: $e');
      _conectado = false;
      onConexaoMqtt?.call(false);
      return false;
    }

    final status = _client!.connectionStatus;
    if (status == null || status.state != MqttConnectionState.connected) {
      _conectado = false;
      onConexaoMqtt?.call(false);
      return false;
    }

    _conectado = true;
    onConexaoMqtt?.call(true);

    _inscreverTopicos();
    _escutarMensagens();
    return true;
  }

  // ── Assinatura de tópicos ────────────────────────────────
  void _inscreverTopicos() {
    if (_client == null) return;
    _client!.subscribe(topicoSensor, MqttQos.atMostOnce);
    _client!.subscribe(topicoBomba, MqttQos.atLeastOnce);
    _client!.subscribe(topicoStatus, MqttQos.atLeastOnce);
    _client!.subscribe(topicoResultado, MqttQos.atMostOnce);
  }

  // ── Escuta de mensagens ──────────────────────────────────
  void _escutarMensagens() {
    _sub?.cancel();
    _sub = _client?.updates?.listen(_processarMensagem);
  }

  // ── Roteamento de mensagens por tópico ───────────────────
  void _processarMensagem(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final msg in messages) {
      final topic = msg.topic;
      final payload = msg.payload as MqttPublishMessage;
      final bytes = payload.payload.message;
      final texto = utf8.decode(bytes);

      if (topic == topicoSensor) {
        _processarSensor(texto);
      } else if (topic == topicoResultado) {
        _processarResultado(texto);
      } else if (topic == topicoBomba) {
        onStatusBomba?.call(texto.trim().toUpperCase());
      } else if (topic == topicoStatus) {
        final status = texto.trim().toLowerCase();
        onConexaoEsp?.call(status == 'online');
      }
    }
  }

  // ── Parse de mensagens ───────────────────────────────────
  void _processarSensor(String texto) {
    try {
      final data = jsonDecode(texto) as Map<String, dynamic>;
      onLeituraSensor?.call(data);
    } catch (_) {}
  }

  void _processarResultado(String texto) {
    try {
      final data = jsonDecode(texto) as Map<String, dynamic>;
      onResultadoSessao?.call(data);
    } catch (_) {}
  }

  // ── Publicação ───────────────────────────────────────────
  void sendComando(String comando) {
    _publicar(topicoComando, comando);
  }

  void setBomba(bool ligar) {
    _publicar(topicoBomba, ligar ? 'ON' : 'OFF', retain: true);
  }

  void setConfig(int intervaloSegundos) {
    final payload = jsonEncode({'intervalo_s': intervaloSegundos});
    _publicar(topicoConfig, payload);
  }

  // ── Publicação no broker ─────────────────────────────────
  void _publicar(String topico, String mensagem, {bool retain = false}) {
    if (_client == null || !_conectado) return;
    final builder = MqttClientPayloadBuilder();
    builder.addUTF8String(mensagem);
    _client!.publishMessage(topico, MqttQos.atMostOnce, builder.payload!,
        retain: retain);
  }

  // ── Desconexão ───────────────────────────────────────────
  void disconnect() {
    _sub?.cancel();
    _client?.disconnect();
    _conectado = false;
    onConexaoMqtt?.call(false);
  }

  void dispose() {
    disconnect();
  }
}
