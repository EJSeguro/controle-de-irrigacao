# Documentação do App — Controle de Irrigação

## 1. Visão Geral

App Flutter para controle e monitoramento de um sistema de irrigação via ESP32.
A comunicação entre app e ESP32 é feita via **MQTT** (HiveMQ Cloud).

---

## 2. Arquitetura do Projeto

```
app/
├── lib/
│   ├── main.dart
│   ├── screens/
│   │   ├── metrics_screen.dart       # Tela inicial (Métricas)
│   │   ├── sensor_screen.dart        # Tela do Sensor
│   │   ├── pump_screen.dart          # Tela da Bomba
│   │   └── config_screen.dart        # Tela de Configurações Gerais
│   ├── services/
│   │   ├── mqtt_service.dart         # Conexão MQTT
│   │   └── storage_service.dart      # Armazenamento local (SharedPreferences / SQLite)
│   ├── models/
│   │   ├── sensor_reading.dart       # Modelo de leitura do sensor
│   │   ├── pump_log.dart             # Modelo de log da bomba
│   │   └── system_config.dart        # Modelo de configurações
│   └── providers/
│       └── irrigation_provider.dart  # Estado global do sistema
├── pubspec.yaml
└── DOCUMENTACAO.md
```

---

## 3. Telas do App

### 3.1 Tela de Métricas (Tela Inicial)

- **Switch geral do sistema** — Liga/desliga todo o sistema. Quando desligado, finaliza processos ativos e armazena métricas até o momento.
- **Consumo por dia, mês e ano** (água em litros, tempo de bomba ligada em minutos).
- **Última leitura do sensor** (umidade, status do solo, data/hora).
- **Status atual** (sensor ativo/inativo, bomba ligada/desligada).

### 3.2 Tela do Sensor

Apenas **métricas e status** (configs移idas para a Tela de Configurações):

- **Última leitura**: data, hora, resultado (umidade %, status do solo).
- **Médias da última leitura ativa**:
  - Umidade do solo antes de regar
  - Umidade do solo depois de regar
  - Tempo que a bomba ficou ligada
- **Switch liga/desliga sensor** — inicia uma sessão de leitura de 2 minutos.
- Durante os 2 minutos, se o solo estiver seco, liga a bomba automaticamente.
- Quando o solo deixa de estar seco, desliga a bomba e finaliza a leitura, entrando em espera.

### 3.3 Tela da Bomba

Apenas **métricas e status** (configs移idas para a Tela de Configurações):

- **Status atual**: ligada/desligada, tempo ligada, consumo atual (L/min).
- **Último ligamento**: data/hora, tempo ligado, consumo total daquele ciclo.
- **Consumo calculado** com base nos parâmetros:
  - Potência da bomba (V) — opcional para referência
  - Diâmetro interno da tubulação (mm) → usado para estimar vazão (L/min)

### 3.4 Tela de Configurações Gerais

Todas as configurações do sistema reunidas aqui:

- **Configurações do Sensor**:
  - Intervalo entre leituras (segundos/minutos) — temporizador
- **Configurações da Bomba**:
  - Potência da bomba (V)
  - Diâmetro interno da tubulação (mm) → para cálculo de vazão
- **Configurações de Rede (Wi-Fi)**:
  - SSID da rede
  - Senha da rede
  - Botão "Enviar para o ESP" — publica via MQTT para o tópico `wifi/config` (a criar no ESP)

---

## 4. Comunicação MQTT

### 4.1 Tópicos MQTT

| Tópico | Direção | Formato | Descrição |
|---|---|---|---|
| `sensor_umidade` | ESP → App | `{"umidade": 45, "status": "seco", "bomba": "OFF", "tipo": "auto"}` | Dados do sensor (`tipo`: `"auto"` ou `"manual"`) |
| `Bomba` | App → ESP | `"ON"` / `"OFF"` | Controle da bomba (com retain, override manual) |
| `sensor/comando` | App → ESP | `"LIGAR"` / `"DESLIGAR"` / `"LER"` | Ativar sessão de 2 min, desativar, ou leitura rápida |
| `esp32/status` | ESP → App | `"online"` / `"offline"` | Status do ESP (com LWT e retain) |
| `sensor/config` | App → ESP | `{"intervalo_s": 30}` | Configurar intervalo entre leituras na sessão (mín 10s) |
| `sensor/resultado` | ESP → App | `{"antes": 20, "depois": 65, "tempo_bomba": 45}` | Resultado da sessão de leitura |

### 4.2 Broker

- Host: `bcf945890f214ca89c3846609fd07a6b.s1.eu.hivemq.cloud`
- Porta: `8883` (TLS)
- Usuário: `sensor_umidade`
- Senha: `Senha1234567890`
- Client ID: `Flutter_App_XXX` (único por dispositivo)

---

## 5. Modelos de Dados

### 5.1 SensorReading

```dart
class SensorReading {
  final DateTime timestamp;
  final int umidade;          // 0–100
  final String status;        // "muito_seco", "seco", "ideal", "umido", "encharcado"
  final bool bombaLigada;
}
```

### 5.2 PumpLog

```dart
class PumpLog {
  final DateTime inicio;
  final DateTime? fim;
  final int duracaoSegundos;
  final double consumoLitros; // calculado
}
```

### 5.3 SystemConfig

```dart
class SystemConfig {
  int intervaloLeitura;        // segundos
  double potenciaBomba;        // volts
  double diametroTubulacao;    // mm
  String wifiSSID;
  String wifiPassword;
}
```

### 5.4 SensorSession

```dart
class SensorSession {
  final DateTime data;
  final int umidadeAntes;
  final int umidadeDepois;
  final int tempoBombaSegundos;
  final double consumoBombaLitros;
}
```

---

## 6. Funcionalidades Detalhadas

### 6.1 Ciclo do Sensor (Sessão Automática)

1. Usuário liga o sensor (switch na Tela do Sensor).
2. App publica `"LIGAR"` no tópico `sensor/comando`.
3. ESP32 registra umidade inicial (`antes`) e inicia leituras a cada `intervalo_s` por até 2 minutos.
4. Se em qualquer leitura o solo estiver seco (`umidade < 45`), ESP32 liga a bomba automaticamente.
5. Quando o solo deixar de estar seco, ESP32 desliga a bomba, encerra a sessão e publica `sensor/resultado`.
6. Se o solo nunca ficar seco, a sessão dura os 2 minutos completos.
7. Se o solo nunca ficar úmido, a bomba fica ligada até o fim dos 2 minutos.
8. ESP32 publica o resultado em `sensor/resultado` com `antes`, `depois`, `tempo_bomba`.
9. App armazena a `SensorSession` localmente.

### 6.2 Leitura Rápida (Manual)

1. Usuário toca em "Ler solo agora" na tela Métricas.
2. App publica `"LER"` no tópico `sensor/comando`.
3. ESP32 faz uma única leitura e publica em `sensor_umidade` com `tipo: "manual"`.
4. Cooldown mínimo de 10s entre leituras para não sobrecarregar o ESP.
5. App exibe o resultado e adiciona ao histórico de leituras.

### 6.2 Cálculo de Consumo de Água

```
Vazão (L/min) = (π × (diâmetro/2)² × velocidade) / 1000
```

Usar aproximação prática baseada no diâmetro interno da tubulação:

| Diâmetro (mm) | Vazão aprox. (L/min) |
|---|---|
| 10 | ~4 |
| 15 | ~9 |
| 20 | ~16 |
| 25 | ~25 |

Consumo total = Vazão × tempo (minutos) da bomba ligada.

### 6.3 Armazenamento Local

Usar **SQLite** (pacote `sqflite`) ou **SharedPreferences** para dados simples:

- `sensor_sessions` — tabela de sessões de leitura
- `pump_logs` — tabela de logs da bomba
- `system_config` — configurações do sistema
- `daily_metrics` — métricas consolidadas por dia

### 6.4 Sistema Liga/Desliga

- **Switch na Tela de Métricas** controla o estado geral do sistema.
- Quando **desligado**:
  - Publica `"DESLIGAR"` em `sensor/comando` se sensor estiver ativo.
  - Publica `"OFF"` em `Bomba` se bomba estiver ligada.
  - Armazena métricas parciais da sessão atual.
  - Bloqueia novas leituras.
- Quando **ligado**:
  - Restaura funcionamento normal.

---

## 7. Dependências (pubspec.yaml)

Adicionar ao `pubspec.yaml`:

```yaml
dependencies:
  mqtt_client: ^10.x.x
  sqflite: ^2.x.x
  path_provider: ^2.x.x
  provider: ^6.x.x
  intl: ^0.19.x
  fl_chart: ^0.70.x     # para gráficos de métricas
```

---

## 8. Fluxo de Navegação

```
Métricas (Home) ──→ Sensor
                ──→ Bomba
                ──→ Configurações
```

- App inicia na **Tela de Métricas**.
- Navegação via BottomNavigationBar ou Drawer.

---

## 9. Considerações Técnicas

- **Retain messages**: usar retain nos tópicos de status (`Bomba`, `esp32/status`) para que o app sempre receba o estado atual ao conectar.
- **LWT**: o ESP32 já usa LWT no tópico `esp32/status` para publicar `"offline"` se cair.
- **Reconexão**: o app deve tentar reconectar ao MQTT automaticamente em caso de queda.
- **TLS**: conexão com HiveMQ é via porta 8883 (TLS). Usar `SecurityContext.defaultContext`.
- **UUID do dispositivo**: gerar um identificador único para o client MQTT do app.

---

## 10. Código do ESP32 (Referência)

O firmware do ESP32 está em `iot_code/iot_code.ino`. Ele implementa:
- Leitura do sensor de umidade no pino 34 (média de 10 amostras)
- Controle da bomba no pino 26 (auto durante sessão + override manual)
- Conexão Wi-Fi e MQTT (HiveMQ Cloud, TLS 8883)
- Sessão automática de 2 minutos com leituras a cada `intervalo_s` configurável
- Controle automático da bomba: liga se solo seco (`umidade < 45`), desliga e encerra sessão se ficar úmido
- Leitura rápida manual via comando `"LER"` (cooldown mínimo 10s)
- Publicação de resultado da sessão em `sensor/resultado` (`antes`, `depois`, `tempo_bomba`)
- Publicação de leituras individuais em `sensor_umidade` com campo `tipo` (`"auto"` ou `"manual"`)
- Assinatura dos tópicos `Bomba`, `sensor/comando`, `sensor/config`
- LWT para status online/offline em `esp32/status`
