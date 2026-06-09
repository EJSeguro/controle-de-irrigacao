#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

// ============================================================
// Configurações de rede e MQTT
// ============================================================
const char* WIFI_SSID = "Eduardo 2.4";
const char* WIFI_PASS = "99131386";

const char* MQTT_HOST = "bcf945890f214ca89c3846609fd07a6b.s1.eu.hivemq.cloud";
const int   MQTT_PORT = 8883;
const char* MQTT_USER = "sensor_umidade";
const char* MQTT_PASS = "Senha1234567890";
const char* CLIENT_ID = "ESP32_Sensor_Solo";

// ============================================================
// Tópicos MQTT
// ============================================================
const char* TOPICO_SENSOR         = "sensor_umidade";
const char* TOPICO_BOMBA          = "Bomba";
const char* TOPICO_SENSOR_COMANDO = "sensor/comando";
const char* TOPICO_STATUS         = "esp32/status";
const char* TOPICO_CONFIG         = "sensor/config";

// ============================================================
// Pinos
// ============================================================
const int SENSOR_PIN = 34;
const int BOMBA_PIN  = 26;
const int LED_STATUS = 2;

// ============================================================
// Constantes do sensor
// ============================================================
const int VALOR_SECO  = 4095;
const int VALOR_UMIDO = 1200;
const int AMOSTRAS    = 10;

// ============================================================
// Temporização e watchdog
// ============================================================
const unsigned long COOLDOWN_LEITURA_MS = 10000;
const unsigned long WATCHDOG_BOMBA_MS   = 120000; // 2 min máx bomba ligada
unsigned long intervaloLeituraMs        = 30000;
unsigned long ultimaLeituraMs           = 0;

bool sistemaAtivo  = false;
bool bombaLigada   = false;
unsigned long bombaLigadaDesde = 0;

WiFiClientSecure espClient;
PubSubClient     mqttClient(espClient);

// ============================================================
// Protótipos
// ============================================================
void ligarBomba();
void desligarBomba();
int  lerUmidade();
String statusSolo(int umidade);
void publicarLeitura(int umidade, const String& tipo);

// ============================================================
// Controle da bomba
// ============================================================
void ligarBomba() {
  if (!sistemaAtivo) {
    Serial.println(">> Sistema inativo, Bomba ON ignorado");
    return;
  }
  if (bombaLigada) return;
  digitalWrite(BOMBA_PIN, HIGH);
  bombaLigada = true;
  bombaLigadaDesde = millis();
  mqttClient.publish(TOPICO_BOMBA, "ON", true);
  Serial.println(">> Bomba LIGADA");
}

void desligarBomba() {
  if (!bombaLigada) return;
  digitalWrite(BOMBA_PIN, LOW);
  bombaLigada = false;
  mqttClient.publish(TOPICO_BOMBA, "OFF", true);
  Serial.println(">> Bomba DESLIGADA");
}

// ============================================================
// Callback MQTT
// ============================================================
void callbackMQTT(char* topico, byte* payload, unsigned int tamanho) {
  String mensagem = "";
  for (unsigned int i = 0; i < tamanho; i++) {
    mensagem += (char)payload[i];
  }

  Serial.println("Recebido [" + String(topico) + "]: " + mensagem);

  // ── Bomba (app decide, ESP executa) ───────────────────────
  if (String(topico) == TOPICO_BOMBA) {
    mensagem.trim();
    mensagem.toUpperCase();
    if (mensagem == "ON") {
      ligarBomba();
    }
    if (mensagem == "OFF") {
      desligarBomba();
    }
  }

  // ── Comandos do sensor ───────────────────────────────────
  if (String(topico) == TOPICO_SENSOR_COMANDO) {
    mensagem.trim();
    mensagem.toUpperCase();

    if (mensagem == "LIGAR") {
      if (sistemaAtivo) {
        Serial.println(">> Sistema já ativo, ignorando");
        return;
      }
      sistemaAtivo = true;
      Serial.println(">> Sistema ATIVADO (app assume controle)");
    }

    else if (mensagem == "DESLIGAR") {
      sistemaAtivo = false;
      desligarBomba();
      Serial.println(">> Sistema DESATIVADO");
    }

    else if (mensagem == "LER") {
      unsigned long agora = millis();
      if (agora - ultimaLeituraMs < COOLDOWN_LEITURA_MS) {
        Serial.println(">> Cooldown ativo, ignorando leitura rápida");
        return;
      }
      Serial.println(">> Leitura rápida solicitada");
      int umidade = lerUmidade();
      publicarLeitura(umidade, "manual");
    }
  }

  // ── Configuração do intervalo ────────────────────────────
  if (String(topico) == TOPICO_CONFIG) {
    StaticJsonDocument<64> doc;
    DeserializationError err = deserializeJson(doc, mensagem);
    if (!err && doc.containsKey("intervalo_s")) {
      int val = doc["intervalo_s"];
      if (val >= 10) {
        intervaloLeituraMs = (unsigned long)val * 1000;
        Serial.print(">> Intervalo configurado: ");
        Serial.print(val);
        Serial.println("s");
      } else {
        Serial.println(">> Intervalo mínimo é 10s, ignorando");
      }
    }
  }
}

// ============================================================
// Conexões
// ============================================================
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

    if (mqttClient.connect(CLIENT_ID, MQTT_USER, MQTT_PASS, TOPICO_STATUS, 1, true, "offline")) {
      Serial.println(" Conectado!");
      digitalWrite(LED_STATUS, HIGH);

      mqttClient.publish(TOPICO_STATUS, "online", true);

      mqttClient.subscribe(TOPICO_BOMBA);
      mqttClient.subscribe(TOPICO_SENSOR_COMANDO);
      mqttClient.subscribe(TOPICO_CONFIG);
      mqttClient.publish(TOPICO_BOMBA, bombaLigada ? "ON" : "OFF", true);

      Serial.println("Status publicado: online");
    } else {
      Serial.print(" Falhou! Codigo: ");
      Serial.println(mqttClient.state());
      delay(3000);
    }
  }
}

// ============================================================
// Leitura do sensor de umidade
// ============================================================
int lerUmidade() {
  long soma = 0;
  for (int i = 0; i < AMOSTRAS; i++) {
    soma += analogRead(SENSOR_PIN);
    delay(50);
  }
  int leitura = soma / AMOSTRAS;
  int valor = constrain(map(leitura, VALOR_SECO, VALOR_UMIDO, 0, 100), 0, 100);
  ultimaLeituraMs = millis();
  return valor;
}

String statusSolo(int umidade) {
  if (umidade < 20) return "muito_seco";
  if (umidade < 45) return "seco";
  if (umidade < 70) return "ideal";
  if (umidade < 90) return "umido";
  return "encharcado";
}

// ============================================================
// Publicar leitura no MQTT
// ============================================================
void publicarLeitura(int umidade, const String& tipo) {
  String status = statusSolo(umidade);

  StaticJsonDocument<128> doc;
  doc["umidade"] = umidade;
  doc["status"]  = status;
  doc["bomba"]   = bombaLigada ? "ON" : "OFF";
  doc["tipo"]    = tipo;

  char payload[128];
  serializeJson(doc, payload);

  if (mqttClient.publish(TOPICO_SENSOR, payload)) {
    Serial.println("Publicado [" + tipo + "]: " + String(payload));
  } else {
    Serial.println("Falha ao publicar!");
  }
}

// ============================================================
// Setup
// ============================================================
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

// ============================================================
// Loop principal
// ============================================================
void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    digitalWrite(LED_STATUS, LOW);
    mqttClient.publish(TOPICO_STATUS, "offline", true);
    conectarWiFi();
  }

  if (!mqttClient.connected()) {
    digitalWrite(LED_STATUS, LOW);
    conectarMQTT();
  }

  mqttClient.loop();

  unsigned long agora = millis();

  // ── Watchdog da bomba ─────────────────────────────────────
  if (bombaLigada && (agora - bombaLigadaDesde >= WATCHDOG_BOMBA_MS)) {
    Serial.println(">> WATCHDOG: tempo máximo da bomba excedido, desligando!");
    desligarBomba();
  }

  // ── Leituras automáticas (sistema ativo) ──────────────────
  if (sistemaAtivo && (agora - ultimaLeituraMs >= intervaloLeituraMs)) {
    int umidade = lerUmidade();
    publicarLeitura(umidade, "auto");
  }

  delay(100);
}
