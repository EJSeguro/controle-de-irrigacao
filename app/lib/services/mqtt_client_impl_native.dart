import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

MqttClient buildMqttClient(String server, String clientId) {
  final client = MqttServerClient(server, clientId);
  client.secure = true;
  client.onBadCertificate = (_) => true;
  return client;
}
