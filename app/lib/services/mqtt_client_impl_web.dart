import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

MqttClient buildMqttClient(String server, String clientId) {
  return MqttBrowserClient(server, clientId);
}
