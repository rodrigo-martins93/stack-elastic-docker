# 🚀 Elasticsearch + Kibana + APM + Prometheus + Grafana (Stack de Monitoramento Local)

> **Ambiente Docker completo para desenvolvimento local** com Elastic Stack (Elasticsearch, Kibana, APM Server) e observabilidade (Prometheus + Grafana + Elasticsearch Exporter).  
> Ideal para testes de APM, métricas e logs em ambientes locais ou de staging.

---

## ✅ Recursos Incluídos

| Serviço | Versão | Função |
|--------|--------|--------|
| **Elasticsearch** | `8.18.8` | Armazenamento e busca de dados |
| **Kibana** | `8.17.8` | Interface de visualização e gestão |
| **APM Server** | `8.18.8` | Coleta de traces e métricas de aplicações |
| **Elasticsearch Exporter** | `v1.8.0` | Exporta métricas do ES para Prometheus |
| **Prometheus** | `v2.53.0` | Coleta e armazenamento de métricas |
| **Grafana** | `11.5.1` | Dashboard visual de métricas e traces |

---

## 📦 Pré-requisitos

- [Docker](https://docs.docker.com/get-docker/) instalado
- [Docker Compose](https://docs.docker.com/compose/install/) (v2+ recomendado)
- Sistema operacional: **Ubuntu** (ou qualquer Linux/WSL2)

---

## 🛠️ Como Iniciar

### 1. Clone este repositório

```bash
git clone https://github.com/rodrigo-martins93/stack-elastic-docker.git
cd elastic-monitoring-stack
```


### 2. Gere as senhas e inicie o ambiente
```bash
chmod +x start_monitoring.sh
./start_monitoring.sh
```

 O script setup.sh: 

- Gera senhas seguras se não estiverem definidas no .env
- Regenera a senha do usuário kibana_system (obrigatório no Elasticsearch 8+)
- Corrige permissões do volume do Elasticsearch
- Inicia todos os serviços em modo detached (-d)

 ## 🚪 3. Acesse os Serviços

| Serviço              | URL                     | Credenciais                                     |
|----------------------|-------------------------|-------------------------------------------------|
| **Elasticsearch**    | `http://localhost:9200` | `elastic` / senha do `.env` (`ELASTIC_PASSWORD`) |
| **Kibana**           | `http://localhost:5601` | `elastic` / senha gerada (`ELASTIC_PASSWORD`) |
| **Grafana**          | `http://localhost:3000` | `admin` / senha do `.env` (`GF_SECURITY_ADMIN_PASSWORD`) |
| **APM Server**       | `http://localhost:8200` | Autenticação por token (veja abaixo)            |
| **Prometheus**       | `http://localhost:9090` | Sem autenticação (local)                        |
| **Elasticsearch Exporter** | `http://localhost:9114/metrics` |

> ✅ **As credenciais são salvas automaticamente no arquivo `.env` após a primeira execução.**

## 📁 Arquivos Importantes

### `.env` (Variáveis de Ambiente)

Após a primeira execução, o arquivo `.env` será criado com:

```env
ELASTIC_PASSWORD=SenhaGeradaAutomaticamente
KIBANA_SYSTEM_PASS=SenhaGeradaAutomaticamente
APM_SECRET_TOKEN=TokenGeradoParaAPM
GF_SECURITY_ADMIN_PASSWORD=SenhaDoGrafana
```

# Configuração do Docker Compose e Prometheus

## `docker-compose.yml`

Configuração completa dos serviços com:

- Redes isoladas (`monitoring`)
- Volumes persistentes
- Configuração de memória e segurança (ex: `bootstrap.memory_lock=true`)
- Dependências corretas entre serviços

## `prometheus.yml`

Configuração do Prometheus para coletar métricas de:

- Elasticsearch Exporter (`es-exporter:9114`)
- Prometheus itself (auto-monitoramento)

  # Script Python de exemplo para enviar traces ao APM Server usando `elasticapm`

```python
import os
import time
from elasticapm import client

token = "TOKEN-GERADO"
if not token:
    raise EnvironmentError("❌ APM_SECRET_TOKEN não definido!")

client = client.Client(
    service_name="lambda-apm-local",
    server_url="http://localhost:8200",
    environment="local",
    secret_token=token,
    capture_exceptions=True,
    debug=True,
)

def simulate_lambda():
    client.begin_transaction("request")
    client.capture_message("🚀 Lambda local começou o processamento")

    with client.capture_span("processamento_lento", "custom"):
        time.sleep(1.5)

    client.end_transaction("lambda_test", "success")

if __name__ == "__main__":
    print("🚨 Enviando trace para o APM Server...")
    simulate_lambda()
    client.close()  # ⚠️ OBRIGATÓRIO!
    print("✅ Trace enviado com sucesso!")
```

### 📤 Saída esperada:
```bash
📤 Enviando trace para o APM Server...
✅ Trace enviado com sucesso!
```

## `start_monitoring.sh`

Script robusto que:

- Verifica e cria senhas
- Corrige permissões de volume (crítico no Elasticsearch)
- Aguarda serviços estarem prontos
- Garante que o ambiente está totalmente funcional

  # Como Visualizar Dados

## 1. Kibana (`http://localhost:5601`)

- Faça login com `elastic` + senha do `.env`
- Vá em **Observability > APM** para ver os traces enviados pelo script Python
- Use **Discover** para visualizar logs (se estiver coletando)

---

## 2. Grafana (`http://localhost:3000`)

- Faça login com `admin` + senha do `.env`
- Adicione o datasource **Prometheus** (URL: `http://prometheus:9090`)
- Importe dashboards do Elasticsearch ou crie os seus próprios com métricas como:
  - `elasticsearch_cluster_health_status`
  - `elasticsearch_indices_docs_count`
  - `process_cpu_seconds_total` (do Prometheus)

## 3. Prometheus (`http://localhost:9090`)


## 🧩 Extensões Sugeridas

- ✅ Adicione **Filebeat** para coletar logs de aplicações
- ✅ Use **Alertmanager** para notificações via email/Slack


---

> 🇧🇷 *Desenvolvido por Rodrigo*  
> ✨ *"Monitorar é cuidar. O que não é medido, não é gerenciado."*




