# Инфраструктура наблюдаемости

OTLP Collector + Tempo + Loki + Prometheus + Grafana.

## Архитектура для Dokploy

- **Только Grafana** доступна из интернета (через Traefik и домен)
- **Collector, Tempo, Loki, Prometheus** — только внутри dokploy-network
- Все Dokploy-приложения (referal-api и др.) общаются с otel-collector по имени `otel-collector:4318`

## Dokploy: пошаговая настройка

### 1. Создание проекта

1. Создайте новый проект в Dokploy
2. Добавьте сервис типа **Docker Compose**
3. Укажите Compose Path: `docker-compose.observability.yml`
4. Смонтируйте папку `observability/` с конфигами (через Git или volume mount)

### 2. Отключите Isolated Deployments

В настройках проекта **отключите** Isolated Deployments, чтобы observability оказалась в `dokploy-network` и была доступна referal-api и другим приложениям.

### 3. Добавьте домен для Grafana

1. Перейдите на вкладку **Domains** проекта observability
2. Добавьте домен для сервиса Grafana (например, `grafana.example.com`)
3. Dokploy настроит Traefik для маршрутизации на Grafana:3000

### 4. referal-backend: переменные окружения

В проекте referal-backend задайте:

```env
OTEL_ENABLED=true
OTEL_EXPORTER=otlp
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318
OTEL_SERVICE_NAME=rukki-backend
OTEL_SERVICE_VERSION=1.0.0
METRICS_ENABLED=true
```

### 5. referal-backend: сеть

referal-backend должен быть в `dokploy-network`, а не в `network_mode: host`. Уберите `network_mode: "host"` из docker-compose referal-backend и подключите сервис к `dokploy-network`.

## Конфиги (mount в Dokploy)

| Файл | Mount Path (Dokploy) |
|------|----------------------|
| otel-collector-config.yaml | ../files/otel-collector-config.yaml |
| tempo-config.yaml | ../files/tempo-config.yaml |
| loki-config.yaml | ../files/loki-config.yaml |
| prometheus.yml | ../files/prometheus.yml |
| datasources.yml | ../files/datasources.yml |
| dashboards.yml | ../files/dashboards.yml |
| metrics.json | ../files/metrics.json |
| traces.json | ../files/traces.json |
| logs.json | ../files/logs.json |

Пути в compose — `../files/<filename>`.

## Локальный запуск

```bash
cd /path/to/90.rukki
# Создайте папку files/ с конфигами (структура должна соответствовать volume mounts в compose)
mkdir -p files/otel files/tempo files/loki files/prometheus files/grafana-provisioning/datasources files/grafana-provisioning/dashboards files/grafana-dashboards
cp observability/otel-collector-config.yaml files/otel/config.yaml
cp observability/tempo-config.yaml files/tempo/config.yaml
cp observability/loki-config.yaml files/loki/config.yaml
cp observability/prometheus.yml files/prometheus/prometheus.yml
cp observability/grafana/datasources.yml files/grafana-provisioning/datasources/
cp observability/grafana/provisioning/dashboards/dashboards.yml files/grafana-provisioning/dashboards/
cp observability/grafana/dashboards/*.json files/grafana-dashboards/

docker compose -f observability/docker-compose.observability.yml up -d
```

Для локального запуска нужна сеть `dokploy-network`. Если её нет:
`docker network create dokploy-network`

## Grafana

- URL: домен, добавленный в Dokploy (например, https://grafana.example.com)
- Логин: admin / admin (вход только по логину/паролю, sign up отключён)
- Datasources: Prometheus, Tempo, Loki (уже настроены)
- Dashboards: папка **Observability** — Metrics, Traces, Logs (просмотр метрик, трейсов и логов referal-api без ручной настройки)