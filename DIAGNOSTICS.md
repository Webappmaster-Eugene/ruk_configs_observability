# Диагностика пустых дашбордов Grafana

Если дашборды Metrics, Traces, Logs пустые — пошагово проверьте цепочку доставки данных.

## Цепочка доставки

```
referal-backend → otel-collector → Prometheus / Tempo / Loki → Grafana
     (OTLP)           (:4318)         (remote write / OTLP)
```

## Шаг 1. Сеть: доходит ли backend до коллектора

**Где:** контейнер referal-backend (Dokploy → контейнеры backend-приложения)

**Быстрая проверка (скрипт):**
```bash
./observability/diagnose.sh [container_id]
# Без аргумента — поиск контейнера по имени referal/old_back/rukki
```

**Ручная проверка:**
```bash
# Узнать ID контейнера backend
docker ps | grep -E "referal|old_back|rukki"

# Войти в контейнер
docker exec -it <backend_container_id> sh

# Проверка DNS и порта (внутри контейнера)
nc -zv otel-collector 4318
# или
wget -q -O- http://otel-collector:4318/v1/metrics 2>&1 || curl -v http://otel-collector:4318/v1/metrics
```

**Ожидаемо:** подключение успешно.  
**Если ошибка (connection refused, timeout):** backend и otel-collector в разных сетях.

**Исправление:**
- referal-backend должен быть в `dokploy-network` (docker-compose настроен)
- observability тоже в `dokploy-network`
- В Dokploy для обоих проектов отключите **Isolated Deployments**

---

## Шаг 2. Данные от backend

**Где:** логи backend (Dokploy → логи приложения)

Проверьте:
- `[Telemetry] OpenTelemetry initialized with exporter: otlp`
- `[MetricsService] Metrics collection initialized (OTLP export)`
- Отсутствие ошибок `ECONNREFUSED`, `ETIMEDOUT`, `ENOTFOUND`

**Важно:** метрики отправляются раз в 60 секунд. Первая отправка — через ~1 минуту после старта.

---

## Шаг 3. Приём данных коллектором

**Где:** логи otel-collector (Dokploy → observability → otel-collector)

В docker-compose включён debug (`--set=service.telemetry.logs.level=debug`). В логах collector должны появляться сообщения о приёме/экспорте.

**Монтирование конфига:** compose ожидает `../files/otel` → `/etc/otelcol`. В Dokploy настройте File Mount по [DOKPLOY-MOUNTS.md](DOKPLOY-MOUNTS.md).

---

## Шаг 4. Prometheus: есть ли метрики

**Где:** Grafana → Explore → источник Prometheus

Запросы:

```promql
# Любые метрики с job
{job=~".+"}

# Метрики backend
{job=~"rukki-backend|referal-backend"}
{service_name=~"rukki-backend|referal-backend"}

# Все HTTP-метрики
{__name__=~"http_.*"}
```

- **Нет данных:** обрыв до коллектора или до Prometheus
- **Есть данные, другие labels:** поправить запросы в дашбордах

---

## Шаг 5. Tempo: есть ли traces

**Где:** Grafana → Explore → источник Tempo

```text
{ resource.service.name=~"rukki-backend|referal-backend" }
```

---

## Шаг 6. Loki: есть ли логи

**Где:** Grafana → Explore → источник Loki

```logql
{job=~"rukki-backend|referal-backend"}
{service_name=~"rukki-backend|referal-backend"}
{job=~".+"}
```

Логи по OTLP приходят только если backend шлёт их через OtelLoggerService. Labels могут отличаться.

---

## Шаг 7. Datasources Grafana

**Где:** Grafana → Connections → Data sources

Проверьте Save & Test:
- Prometheus: `http://prometheus:9090`
- Tempo: `http://tempo:3200`
- Loki: `http://loki:3100`

---

## Матрица локализации

| Проверка          | Результат                     | Вывод                                           |
|-------------------|-------------------------------|-------------------------------------------------|
| Шаг 1 (nc/curl)   | fail                          | **Сеть** — backend не видит otel-collector      |
| Шаг 1             | ok                            | Переходим к шагу 4                              |
| Шаг 4 Prometheus  | нет данных                    | **Collector** — не получает или не шлёт в Prom  |
| Шаг 4 Prometheus  | есть данные, другие labels    | **Дашборды** — поправить запросы                |
| Шаг 4 Prometheus  | есть данные, labels совпадают | Проверить время/refresh                         |
| Шаг 7 Datasources | fail                          | **Grafana** — нет доступа к Prom/Tempo/Loki     |

---

## Вероятные причины

1. **Сеть** — referal-backend и observability в разных Dokploy-проектах с Isolated Deployments
2. **File Mount** — конфиг коллектора не примонтирован в Dokploy
3. **Таймаут** — метрики выходят раз в 60 секунд, подождать минуту после старта
4. **Labels** — в Prometheus приходит `service_name` вместо `job`, обновить дашборды
