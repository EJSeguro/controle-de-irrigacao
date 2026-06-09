# 🌿 Controle de Irrigação

App Flutter + ESP32 para automatizar irrigação via MQTT. Monitora umidade do solo, controla bomba e calcula consumo de água.

## Stack

| Camada | Tecnologia |
|--------|-----------|
| App | Flutter 3.44 • Dart 3.12 • Material Design 3 |
| Firmware | ESP32 (Arduino framework) |
| Comunicação | MQTT via HiveMQ Cloud (TLS 8883) |
| Estado | Provider (ChangeNotifier) |
| Auth | Local com SharedPreferences |
| Persistência | SQLite (sqflite) |

## Funcionalidades

- ✅ Autenticação local (email/senha)
- ✅ Ligar/desligar sistema e bomba
- ✅ Leitura de umidade do solo (manual ou automática)
- ✅ Sessão de irrigação controlada pelo ESP32 (2 min, finaliza quando solo fica úmido)
- ✅ Cooldown mínimo de 10s entre leituras
- ✅ Histórico de leituras (manual e automática)
- ✅ Configuração de intervalo, potência da bomba e diâmetro da tubulação
- ✅ Cálculo de consumo de água (hoje, mês, ano)
- ✅ Dados reais via MQTT com fallback mockado offline
- ✅ Status de conexão MQTT e ESP32 em tempo real

## Setup

### 1. App Flutter

```bash
git clone https://github.com/EJSeguro/controle-de-irrigacao.git
cd app
flutter pub get
flutter run
```

### 2. Firmware ESP32

Abra `iot_code/iot_code.ino` no Arduino IDE e ajuste:

```cpp
const char* WIFI_SSID = "SuaRedeWiFi";
const char* WIFI_PASS = "SuaSenhaWiFi";
```

Instale as bibliotecas:
- **PubSubClient** (knolleary)
- **ArduinoJson** (bblanchon)

Placa: **ESP32 Dev Module** — compile e faça upload.

### 3. HiveMQ Cloud

1. Crie um cluster gratuito em [console.hivemq.cloud](https://console.hivemq.cloud)
2. Crie um usuário MQTT (ex: `sensor_umidade`)
3. No **IP Whitelist**, adicione `0.0.0.0/0` (desenvolvimento) ou o IP fixo da rede
4. Atualize as credenciais em `app/lib/services/mqtt_service.dart` e `iot_code/iot_code.ino`

## Tópicos MQTT

| Tópico | Direção | Payload | Descrição |
|--------|---------|---------|-----------|
| `sensor_umidade` | ESP → App | `{"umidade": N, "status": "...", "bomba": "ON/OFF", "tipo": "auto/manual"}` | Leitura do sensor |
| `Bomba` | App ↔ ESP | `"ON"` / `"OFF"` | Estado da bomba (retain) |
| `sensor/comando` | App → ESP | `"LIGAR"` / `"DESLIGAR"` / `"LER"` | Comandos |
| `esp32/status` | ESP → App | `"online"` / `"offline"` | Status ESP32 (LWT) |
| `sensor/resultado` | ESP → App | `{"antes": N, "depois": N, "tempo_bomba": N}` | Resultado da sessão |
| `sensor/config` | App → ESP | `{"intervalo_s": N}` | Configura intervalo |

## Como usar

1. Faça login ou crie uma conta
2. Vá em **Config** e ajuste os parâmetros (intervalo, potência, diâmetro)
3. Na tela **Métricas**, ligue o sistema — o ESP32 inicia a sessão de irrigação
4. Use o botão 🔄 para uma leitura rápida manual
5. Acompanhe as leituras em **Sensor** e o histórico em **Leituras**
6. Na tela **Bomba**, é possível desligar manualmente — isso bloqueia o religamento automático até reativação manual

## Estrutura do projeto

```
app/
├── lib/
│   ├── main.dart                     # Entry point + providers
│   ├── models/leitura.dart           # Modelo de leitura
│   ├── providers/system_provider.dart # Estado central do sistema
│   ├── screens/
│   │   ├── auth_screen.dart          # Login/cadastro
│   │   ├── home_screen.dart          # Navegação (5 abas)
│   │   ├── metrics_screen.dart       # Métricas + consumo
│   │   ├── sensor_screen.dart        # Dados do sensor
│   │   ├── pump_screen.dart          # Controle da bomba
│   │   ├── config_screen.dart        # Configurações
│   │   └── readings_screen.dart      # Histórico de leituras
│   └── services/
│       ├── auth_service.dart         # Auth local
│       ├── mqtt_service.dart         # Conexão MQTT
│       └── database_service.dart     # SQLite
└── pubspec.yaml

iot_code/
└── iot_code.ino                      # Firmware ESP32
```

## Branches

- `main` — produção estável
- `homolog` — integração (pronto para produção)
- `feature/*` — funcionalidades em desenvolvimento

## Licença

Projeto acadêmico — uso livre.
