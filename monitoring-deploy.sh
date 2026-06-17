#!/bin/bash
set -e

cd ~/Diplom_TMS

# Добавляем Helm-репозитории (если ещё не)
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
helm repo update

# --- БЛОК ОЧИСТКИ (ТОЛЬКО ДЛЯ ТЕСТОВ!!!) ---
echo "🧹 Cleaning up old resources for a fresh install..."
# Удаляем PVC (хранилища Grafana и Prometheus), чтобы сбросить старые данные
kubectl delete pvc --all -n monitoring --ignore-not-found=true

# Удаляем секреты и конфигурации, которые могли остаться от старой Grafana
kubectl delete configmap -n monitoring -l app.kubernetes.io/name=grafana --ignore-not-found=true
kubectl delete secret -n monitoring -l app.kubernetes.io/name=grafana --ignore-not-found=true

# 1. Устанавливаем Ingress-контроллер ПЕРВЫМ
echo "Installing NGINX Ingress controller..."
helm upgrade --install nginx-ingress ingress-nginx/ingress-nginx \
    --namespace nginx --create-namespace

# 2. Ждём, пока ему назначат внешний IP
echo "⏳ Waiting for Ingress external IP..."
INGRESS_IP=""
while [ -z "$INGRESS_IP" ]; do
    sleep 5
    INGRESS_IP=$(kubectl get svc -n nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
done
echo "Ingress IP: $INGRESS_IP"

# 3. Установка Loki (с блокировкой конфликтующих датасорсов)
echo "Installing Loki..."
helm upgrade --install loki grafana/loki-stack \
    --namespace monitoring --create-namespace \
    --set loki.persistence.enabled=false \
    --set promtail.tolerations[0].operator=Exists \
    --set grafana.enabled=false \
    --set grafana.sidecar.datasources.enabled=false \
    --set loki.monitoring.selfMonitoring.grafanaDatasource.enabled=false

echo "Cleaning old Grafana PVC..."
kubectl delete pvc -n monitoring -l app.kubernetes.io/name=grafana --ignore-not-found=true
sleep 5

# 4. Установка Prometheus + Grafana
GRAFANA_PASSWORD="${GRAFANA_PASSWORD:-admin123}"
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.ingress.enabled=true \
  --set grafana.ingress.hosts[0]="grafana.$INGRESS_IP.nip.io" \
  --set grafana.ingress.ingressClassName=nginx \
  --set grafana.adminPassword="${GRAFANA_PASSWORD}" \
  --set grafana.additionalDataSources[0].name="Loki" \
  --set grafana.additionalDataSources[0].type="loki" \
  --set grafana.additionalDataSources[0].url="http://loki:3100" \
  --set grafana.additionalDataSources[0].access="proxy" \
  --set grafana.additionalDataSources[0].isDefault=false \

# 5. Установка API из локального чарта
REGISTRY_ID=$(yc container registry list --format json | jq -r '.[0].id')
API_TAG="${API_TAG:-v0.1}"
helm upgrade --install hybrid-api ./helm/hybrid-api \
    --set image.repository="cr.yandex/$REGISTRY_ID/hybrid-api" \
    --set image.tag="$API_TAG" \
    --set ingress.host="api.$INGRESS_IP.nip.io"

# 6. Автоматическая настройка Grafana (дашборд FastAPI) – опционально
echo "⏳ Waiting for Grafana to be ready..."
# Проверяем /api/health (не требует авторизации)
until [ "$(curl -s -o /dev/null -w '%{http_code}' "http://grafana.$INGRESS_IP.nip.io/api/health")" -eq 200 ]; do
    sleep 3
done
echo "✅ Grafana is ready."

DASHBOARD_JSON="monitoring-dashboards/fastapi-metrics.json"
if [ -f "$DASHBOARD_JSON" ]; then
    echo "Importing dashboard..."
    # Импорт дашборда с проверкой ответа
    RESPONSE=$(curl -s -u "admin:${GRAFANA_PASSWORD}" -X POST "http://grafana.$INGRESS_IP.nip.io/api/dashboards/db" \
        -H "Content-Type: application/json" \
        -d "{\"dashboard\":$(cat $DASHBOARD_JSON),\"overwrite\":true}" \
        -w '%{http_code}')
    # Успешный импорт — коды 200 (обновление) или 201 (создание)
    if [[ "$RESPONSE" == "200" || "$RESPONSE" == "201" ]]; then
        echo "✅ Dashboard imported successfully."
    else
        echo "❌ Failed to import dashboard. HTTP status: $RESPONSE"
        # Дополнительно можно вывести тело ответа для диагностики
        # curl -s -u "admin:${GRAFANA_PASSWORD}" -X POST ... (без -w)
    fi
else
    echo "⚠️ Dashboard file not found: $DASHBOARD_JSON"
fi

echo ""
echo "✅ Deployment complete!"
echo "API: http://api.$INGRESS_IP.nip.io/health"
echo "Grafana: http://grafana.$INGRESS_IP.nip.io (admin / ${GRAFANA_PASSWORD})"
