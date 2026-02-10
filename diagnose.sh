#!/usr/bin/env bash
# Диагностика: проверка доступа backend → otel-collector
# Использование:
#   ./diagnose.sh [container_id_or_name]
#   ./diagnose.sh              # автопоиск контейнера referal/old_back/rukki

set -e

CONTAINER="$1"

if [ -z "$CONTAINER" ]; then
  CONTAINER=$(docker ps -q --filter "name=referal" --filter "name=old_back" --filter "name=rukki" 2>/dev/null | head -1)
  if [ -z "$CONTAINER" ]; then
    echo "Контейнер не найден. Укажите вручную: $0 <container_id>"
    echo "Пример: $0 rukki-prod-apitest-edaltr.1.xxxxx"
    exit 1
  fi
  echo "Найден контейнер: $CONTAINER"
fi

echo "Проверка доступа к otel-collector:4318 из контейнера $CONTAINER..."
echo ""

if docker exec "$CONTAINER" sh -c "command -v nc >/dev/null 2>&1 && nc -zv otel-collector 4318 2>&1" 2>/dev/null; then
  echo ""
  echo "OK: Сеть доступна, backend видит otel-collector."
  exit 0
fi

if docker exec "$CONTAINER" sh -c "command -v wget >/dev/null 2>&1 && wget -q -O- --timeout=3 http://otel-collector:4318/v1/metrics 2>&1 | head -1" 2>/dev/null; then
  echo ""
  echo "OK: HTTP доступен, backend видит otel-collector."
  exit 0
fi

if docker exec "$CONTAINER" sh -c "command -v curl >/dev/null 2>&1 && curl -s -o /dev/null -w '%{http_code}' --connect-timeout 3 http://otel-collector:4318/v1/metrics 2>/dev/null" 2>/dev/null; then
  echo ""
  echo "OK: HTTP доступен, backend видит otel-collector."
  exit 0
fi

echo ""
echo "FAIL: backend не может достучаться до otel-collector:4318"
echo "Проверьте:"
echo "  - referal-backend и observability в dokploy-network"
echo "  - Isolated Deployments отключено для обоих проектов"
exit 1
