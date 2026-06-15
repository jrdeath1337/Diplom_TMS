#!/bin/bash
set -e

cd ~/Diplom_TMS

echo "⏳ Waiting for Ingress external IP..."
INGRESS_IP=$(kubectl get svc -n nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
while [ -z "$INGRESS_IP" ]; do
    sleep 5
    INGRESS_IP=$(kubectl get svc -n nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
done
echo "Ingress IP: $INGRESS_IP"

# Добавляем Helm-репозитории
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update

# Установка Ingress-контроллера
helm upgrade --install nginx-ingress ingress-nginx/ingress-nginx \
    --namespace nginx --create-namespace

# Установка Prometheus + Grafana
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
    --namespace monitoring --create-namespace \
    --set grafana.ingress.enabled=true \
    --set grafana.ingress.hosts[0]="grafana.$INGRESS_IP.nip.io" \
    --set grafana.ingress.ingressClassName=nginx \
    --set grafana.adminPassword="${GRAFANA_PASSWORD:-admin123}"

# Установка API из локального чарта
REGISTRY_ID=$(yc container registry list --format json | jq -r '.[0].id')
helm upgrade --install hybrid-api ./helm/hybrid-api \
    --set image.repository="cr.yandex/$REGISTRY_ID/hybrid-api" \
    --set image.tag="${API_TAG:-v0.1}" \
    --set ingress.host="api.$INGRESS_IP.nip.io"

echo ""
echo "✅ Deployment complete!"
echo "API: http://api.$INGRESS_IP.nip.io/health"
echo "Grafana: http://grafana.$INGRESS_IP.nip.io (admin / ${GRAFANA_PASSWORD:-admin123})"
