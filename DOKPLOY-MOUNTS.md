# Dokploy: настройка File Mounts для Observability Stack

**Важно:** используем монтирование **директорий**, а не отдельных файлов — это обходит ошибку Docker "Are you trying to mount a directory onto a file (or vice-versa)".

Dokploy создаёт файлы в `../files/`. При File Path `otel/config.yaml` создаётся `../files/otel/config.yaml` (и папка `otel`). Compose монтирует директории целиком.

---

## Таблица: File Path → источник контента

| File Path | Источник контента | Монтируется в |
|-----------|-------------------|---------------|
| otel/config.yaml | `observability/otel-collector-config.yaml` | `../files/otel` → `/etc/otelcol` |
| tempo/config.yaml | `observability/tempo-config.yaml` | `../files/tempo` → `/etc/tempo` |
| loki/config.yaml | `observability/loki-config.yaml` | `../files/loki` → `/etc/loki` |
| prometheus/prometheus.yml | `observability/prometheus.yml` | `../files/prometheus` → `/etc/prometheus` |
| grafana-provisioning/datasources/datasources.yml | `observability/grafana/datasources.yml` | `../files/grafana-provisioning` → `/etc/grafana/provisioning` |
| grafana-provisioning/dashboards/dashboards.yml | `observability/grafana/provisioning/dashboards/dashboards.yml` | ↑ |
| grafana-dashboards/metrics.json | `observability/grafana/dashboards/metrics.json` | `../files/grafana-dashboards` → `/var/lib/grafana/dashboards` |
| grafana-dashboards/traces.json | `observability/grafana/dashboards/traces.json` | ↑ |
| grafana-dashboards/logs.json | `observability/grafana/dashboards/logs.json` | ↑ |

---

## Порядок действий

1. **Удалить старые** File Mount в Dokploy (если есть).
2. **Удалить** папку `files` на сервере (иначе останутся старые файлы/каталоги):
   ```bash
   rm -rf /etc/dokploy/compose/rukki-prod-adsadad-wipqbc/files/*
   ```
3. **Добавить** 9 новых File Mount (Advanced → Volumes):
   - **Content** — из соответствующего файла в репо
   - **File Path** — из таблицы (например `otel/config.yaml`)
4. **Redeploy**

---

## Почему директории

При монтировании файла Docker иногда создаёт каталог вместо файла, из‑за чего возникает ошибка "not a directory". Монтирование директорий такой проблемы не даёт.
