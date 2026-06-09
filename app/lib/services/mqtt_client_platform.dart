import 'package:mqtt_client/mqtt_client.dart';
import 'mqtt_client_impl_native.dart'
    if (dart.library.html) 'mqtt_client_impl_web.dart';

MqttClient createMqttClient(String server, String clientId) {
  return buildMqttClient(server, clientId);
}
