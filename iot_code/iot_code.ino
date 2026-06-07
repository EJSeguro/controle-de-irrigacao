#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

const char* WIFI_SSID = "Eduardo 2.4";
const char* WIFI_PASS = "99131386";

const char* MQTT_HOST = "bcf945890f214ca89c3846609fd07a6b.s1.eu.hivemq.cloud";
const int   MQTT_PORT = 8883;
const char* MQTT_USER = "sensor_umidade";
const char* MQTT_PASS = "Senha1234567890";
const char* CLIENT_ID = "ESP32_Sensor_Solo";

const char* TOPICO_SENSOR         = "sensor_umidade";
const char* TOPICO_BOMBA          = "Bomba";
const char* TOPICO_SENSOR_COMANDO = "sensor/comando";
const char* TOPICO_STATUS         = "esp32/status"; // ← novo

const int SENSOR_PIN = 34;
const int BOMBA_PIN  = 26;
const int LED_STATUS = 2;

const int VALOR_SECO  = 4095;
const int VALOR_UMIDO = 1200;
const int AMOSTRAS    = 10;

const unsigned long INTERVALO_MS = 30000;
unsigned long ultimaPublicacao   = 0;

WiFiClientSecure espClient;
PubSubClient     mqttClient(espClient);
bool bombaLigada = false;
bool sensorAtivo = false;

void ligarBomba() {
  if (!bombaLigada) {
    digitalWrite(BOMBA_PIN, HIGH);
    bombaLigada = true;
    mqttClient.publish(TOPICO_BOMBA, "ON", true);
    Serial.println(">> Bomba LIGADA");
  }
}

void desligarBomba() {
  if (bombaLigada) {
    digitalWrite(BOMBA_PIN, LOW);
    bombaLigada = false;
    mqttClient.publish(TOPICO_BOMBA, "OFF", true);
    Serial.println(">> Bomba DESLIGADA");
  }
}

void callbackMQTT(char* topico, byte* payload, unsigned int tamanho) {
  String mensagem = "";
  for (unsigned int i = 0; i < tamanho; i++) {
    mensagem += (char)payload[i];
  }
  mensagem.trim();
  mensagem.toUpperCase();

  Serial.println("Recebido [" + String(topico) + "]: " + mensagem);

  if (String(topico) == TOPICO_BOMBA) {
    if (mensagem == "ON")  ligarBomba();
    if (mensagem == "OFF") desligarBomba();
  }

  if (String(topico) == TOPICO_SENSOR_COMANDO) {
    if (mensagem == "LIGAR") {
      sensorAtivo = true;
      ultimaPublicacao = 0;
      Serial.println(">> Sensor ATIVADO");
    }
    if (mensagem == "DESLIGAR") {
      sensorAtivo = false;
      Serial.println(">> Sensor DESATIVADO");
    }
  }
}

void conectarWiFi() {
  if (WiFi.status() == WL_CONNECTED) return;
  Serial.print("Conectando ao Wi-Fi");
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  int tentativas = 0;
  while (WiFi.status() != WL_CONNECTED && tentativas < 40) {
    delay(500);
    Serial.print(".");
    tentativas++;
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWi-Fi conectado! IP: " + WiFi.localIP().toString());
  } else {
    Serial.println("\nFalha no Wi-Fi. Reiniciando...");
    ESP.restart();
  }
}

void conectarMQTT() {
  while (!mqttClient.connected()) {
    Serial.print("Conectando ao HiveMQ...");

    // LWT: broker publica "offline" automaticamente se ESP cair
    mqttClient.setWill(
      TOPICO_STATUS,  // tópico
      "offline",      // mensagem
      true,           // retain
      1               // QoS
    );

    if (mqttClient.connect(CLIENT_ID, MQTT_USER, MQTT_PASS)) {
      Serial.println(" Conectado!");
      digitalWrite(LED_STATUS, HIGH);

      // Avisa o app que está online
      mqttClient.publish(TOPICO_STATUS, "online", true); // retain=true

      mqttClient.subscribe(TOPICO_BOMBA);
      mqttClient.subscribe(TOPICO_SENSOR_COMANDO);
      mqttClient.publish(TOPICO_BOMBA, bombaLigada ? "ON" : "OFF", true);

      Serial.println("Status publicado: online");
    } else {
      Serial.print(" Falhou! Codigo: ");
      Serial.println(mqttClient.state());
      delay(3000);
    }
  }
}

int lerUmidade() {
  long soma = 0;
  for (int i = 0; i < AMOSTRAS; i++) {
    soma += analogRead(SENSOR_PIN);
    delay(50);
  }
  int leitura = soma / AMOSTRAS;
  return constrain(map(leitura, VALOR_SECO, VALOR_UMIDO, 0, 100), 0, 100);
}

String statusSolo(int umidade) {
  if (umidade < 20) return "muito_seco";
  if (umidade < 45) return "seco";
  if (umidade < 70) return "ideal";
  if (umidade < 90) return "umido";
  return "encharcado";
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n=== ESP32 Sensor de Solo ===");

  pinMode(BOMBA_PIN,  OUTPUT);
  pinMode(LED_STATUS, OUTPUT);
  digitalWrite(BOMBA_PIN,  LOW);
  digitalWrite(LED_STATUS, LOW);

  conectarWiFi();

  espClient.setInsecure();
  mqttClient.setServer(MQTT_HOST, MQTT_PORT);
  mqttClient.setCallback(callbackMQTT);
  mqttClient.setKeepAlive(60);
  mqttClient.setBufferSize(256);

  conectarMQTT();
  Serial.println("Pronto!\n");
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    digitalWrite(LED_STATUS, LOW);
    // Avisa offline antes de tentar reconectar
    // (pode não publicar se MQTT também caiu, mas o LWT cobre esse caso)
    mqttClient.publish(TOPICO_STATUS, "offline", true);
    conectarWiFi();
  }

  if (!mqttClient.connected()) {
    digitalWrite(LED_STATUS, LOW);
    conectarMQTT(); // LWT cuida do offline, aqui só reconecta
  }

  mqttClient.loop();

  if (sensorAtivo) {
    unsigned long agora = millis();
    if (agora - ultimaPublicacao >= INTERVALO_MS) {
      ultimaPublicacao = agora;

      int umidade   = lerUmidade();
      String status = statusSolo(umidade);

      StaticJsonDocument<128> doc;
      doc["umidade"] = umidade;
      doc["status"]  = status;
      doc["bomba"]   = bombaLigada ? "ON" : "OFF";

      char payload[128];
      serializeJson(doc, payload);

      if (mqttClient.publish(TOPICO_SENSOR, payload)) {
        Serial.println("Publicado: " + String(payload));
      } else {
        Serial.println("Falha ao publicar!");
      }
    }
  }

  delay(100);
}