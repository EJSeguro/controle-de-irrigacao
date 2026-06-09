# Esquemas do Projeto — Controle de Irrigação

## 1. Diagrama de Casos de Uso

```mermaid
graph TD
    subgraph Autenticação
        UC01[Criar conta]
        UC02[Fazer login]
        UC03[Fazer logout]
    end

    subgraph Sistema
        UC04[Ligar sistema]
        UC05[Desligar sistema]
        UC06[Ver status do sistema]
    end

    subgraph Leitura
        UC07[Leitura automática<br/>(sessão ESP)]
        UC08[Leitura manual<br/>(rápida)]
        UC09[Ver histórico de leituras]
    end

    subgraph Bomba
        UC10[Ligar bomba manualmente]
        UC11[Desligar bomba manualmente]
        UC12[Bomba liga automática<br/>(solo seco)]
    end

    subgraph Configuração
        UC13[Configurar intervalo]
        UC14[Configurar potência]
        UC15[Configurar diâmetro]
    end

    subgraph Monitoramento
        UC16[Ver consumo de água]
        UC17[Ver status conexão<br/>MQTT / ESP32]
    end

    subgraph Sessão
        UC18[Sessão automática 2 min]
        UC19[Finalização antecipada<br/>solo úmido]
        UC20[Ver resultado da sessão]
    end
```

## 2. Descrição dos Casos de Uso

### Autenticação

| ID | Nome | Ator | Descrição | Pré-condição | Pós-condição |
|----|------|------|-----------|-------------|-------------|
| UC01 | Criar conta | Usuário | Cadastra email + senha via SharedPreferences | — | Conta criada, redirecionado para Home |
| UC02 | Fazer login | Usuário | Informa email + senha cadastrados | Conta existente | Sessão iniciada, redirecionado para Home |
| UC03 | Fazer logout | Usuário | Encerra sessão | Estar autenticado | Retorna para tela de login |

### Sistema

| ID | Nome | Ator | Descrição | Pré-condição | Pós-condição |
|----|------|------|-----------|-------------|-------------|
| UC04 | Ligar sistema | Usuário | Publica `LIGAR` no tópico `sensor/comando` | Config válida | ESP inicia sessão |
| UC05 | Desligar sistema | Usuário | Publica `DESLIGAR` no tópico `sensor/comando` | Sistema ligado | ESP encerra sessão |
| UC06 | Ver status | Usuário | Visualiza MQTT, ESP32 e bomba | — | — |

### Leitura do Solo

| ID | Nome | Ator | Descrição | Pré-condição | Pós-condição |
|----|------|------|-----------|-------------|-------------|
| UC07 | Leitura automática | ESP32 | Durante sessão, publica a cada `intervalo_s` | Sessão ativa | Leitura salva no BD e exibida |
| UC08 | Leitura manual | Usuário | Publica `LER` no `sensor/comando` | Cooldown respeitado | Leitura salva no BD e exibida |
| UC09 | Ver histórico | Usuário | Lista leituras ordenadas por data | — | — |

### Bomba

| ID | Nome | Ator | Descrição | Pré-condição | Pós-condição |
|----|------|------|-----------|-------------|-------------|
| UC10 | Ligar bomba | Usuário | Publica `ON` no tópico `Bomba` | — | Bomba ligada, `bombaDesligadaManual = false` |
| UC11 | Desligar bomba manual | Usuário | Publica `OFF` no tópico `Bomba` | — | Bomba + sistema desligados, `bombaDesligadaManual = true` |
| UC12 | Bomba automática | ESP32 | Liga se umidade < 45%, desliga se ≥ 45% | Sessão ativa | Bomba controlada pelo firmware |

### Configuração

| ID | Nome | Ator | Descrição |
|----|------|------|-----------|
| UC13 | Configurar intervalo | Usuário | Altera `intervaloLeitura`; se MQTT conectado, publica `{"intervalo_s": N}` |
| UC14 | Configurar potência | Usuário | Altera `potenciaBomba` |
| UC15 | Configurar diâmetro | Usuário | Altera `diametroTubulacao` |

### Monitoramento

| ID | Nome | Ator | Descrição |
|----|------|------|-----------|
| UC16 | Ver consumo | Usuário | Exibe consumo do último ciclo, hoje, mês e ano (calculado de `vazaoEstimada × tempoBomba`) |
| UC17 | Ver status conexão | Usuário | Indicadores verde/vermelho para MQTT e ESP32 |

### Sessão

| ID | Nome | Ator | Descrição |
|----|------|------|-----------|
| UC18 | Sessão automática | ESP32 | Duração máxima 2 min; cooldown 10s entre leituras |
| UC19 | Finalização antecipada | ESP32 | Se solo ficar úmido após ter estado seco, sessão encerra |
| UC20 | Ver resultado | Usuário | Exibe `antes`, `depois`, `tempo_bomba` recebido via `sensor/resultado` |

---

## 3. Schema do Banco de Dados (SQLite)

### Tabela: `leituras`

Armazena o histórico de leituras de umidade do solo.

```sql
CREATE TABLE leituras (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    data        TEXT    NOT NULL,  -- ISO 8601 (ex: "2026-06-08T21:30:00.000")
    umidade     INTEGER NOT NULL,  -- 0 a 100 (%)
    status_solo TEXT    NOT NULL,  -- "Muito seco" | "Seco" | "Ideal" | "Úmido" | "Encharcado"
    tipo        TEXT    NOT NULL   -- "manual" | "automática"
);
```

### Tabela: `consumo` (planejado / futura implementação)

Registra o consumo de água por ciclo de irrigação.

```sql
CREATE TABLE consumo (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    data            TEXT    NOT NULL,  -- ISO 8601
    litros          REAL    NOT NULL,  -- Ex: 12.5
    tempo_segundos  INTEGER NOT NULL   -- Tempo que a bomba ficou ligada
);
```

### Relacionamentos

```
leituras ──→ (independente, sem FK)
consumo   ──→ (independente, sem FK — registros avulsos por ciclo)
```

> Nota: Atualmente apenas `leituras` está implementada. A tabela `consumo` está documentada para implementação futura quando houver persistência dos registros de consumo.

---

## 4. Mapa de Telas × Casos de Uso

| Tela | Casos de Uso |
|------|-------------|
| **AuthScreen** | UC01, UC02 |
| **HomeScreen** | UC03 (logout na AppBar) |
| **MetricsScreen** | UC04, UC05, UC06, UC08, UC16, UC17 |
| **SensorScreen** | UC06, UC07, UC17, UC18, UC19, UC20 |
| **PumpScreen** | UC10, UC11, UC12, UC16 |
| **ConfigScreen** | UC13, UC14, UC15 |
| **ReadingsScreen** | UC09 |
