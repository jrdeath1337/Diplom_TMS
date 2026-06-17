#!/bin/bash
set -e

# ============================================================
#  Full Deploy: инфраструктура + приложения + мониторинг
# ============================================================
cd ~/Diplom_TMS

echo "========================================"
echo " 1/6  Terraform: создаём облачную инфру"
echo "========================================"
cd terraform
terraform init -upgrade
terraform apply -auto-approve
cd ..

echo "========================================"
echo " 2/6  Подключаемся к кластеру Kubernetes"
echo "========================================"
# Получаем команду из outputs и выполняем
KUBECONFIG_CMD=$(terraform -chdir=terraform output -raw kubeconfig_command)
echo "Выполняем: $KUBECONFIG_CMD"
eval "$KUBECONFIG_CMD --force"

echo "========================================"
echo " 3/6  Собираем и пушим образ API в реестр"
echo "========================================"
REGISTRY_ID=$(yc container registry list --format json | jq -r '.[0].id')

# Очистка Docker-кэша (чтобы избежать «Registry not found»)
docker rmi -f $(docker images -q --filter "reference=*/hybrid-api") 2>/dev/null || true
docker builder prune -af
docker system prune -a --volumes --all --force 2>/dev/null || true

# Логин в Container Registry
yc iam create-token | docker login --username iam --password-stdin cr.yandex

# Сборка и пуш
cd Docker/api
docker build --no-cache -t cr.yandex/$REGISTRY_ID/hybrid-api:v0.1 .
docker push cr.yandex/$REGISTRY_ID/hybrid-api:v0.1
cd ../..

echo "========================================"
echo " 4/6  Устанавливаем Ingress и Мониторинг"
echo "========================================"
# Этот скрипт ждёт Ingress IP, ставит NGINX, Loki, Prometheus, Grafana и API
./monitoring-deploy.sh

echo "========================================"
echo " 5/6  Создаём Kubernetes Secret (если не создан)"
echo "========================================"
# В Terraform уже есть создание секрета (k8s-secrets.tf), но на всякий случай проверим
if ! kubectl get secret hybrid-api-secrets -n default > /dev/null 2>&1; then
    DB_DSN=$(terraform -chdir=terraform output -raw db_connection_string)
    S3_BUCKET=$(terraform -chdir=terraform output -raw s3_bucket_name)
    ACCESS_KEY=$(terraform -chdir=terraform output -raw worker_sa_access_key)
    SECRET_KEY=$(terraform -chdir=terraform output -raw worker_sa_secret_key)
    S3_ENDPOINT=$(terraform -chdir=terraform output -raw s3_endpoint)

    kubectl create secret generic hybrid-api-secrets \
      --from-literal=DB_DSN="$DB_DSN" \
      --from-literal=S3_BUCKET="$S3_BUCKET" \
      --from-literal=AWS_ACCESS_KEY_ID="$ACCESS_KEY" \
      --from-literal=AWS_SECRET_ACCESS_KEY="$SECRET_KEY" \
      --from-literal=S3_ENDPOINT="$S3_ENDPOINT"
    echo "Secret hybrid-api-secrets created."
else
    echo "Secret already exists, skipping."
fi

echo "========================================"
echo " 6/6  Запускаем локальный worker (GPU)"
echo "========================================"
# Предполагается, что docker-compose.yml настроен и лежит в корне
docker compose up -d worker

echo ""
echo "✅ Полное развёртывание завершено!"
echo "API: http://api.$(kubectl get svc -n nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}').nip.io/health"
echo "Grafana: http://grafana.$(kubectl get svc -n nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}').nip.io (admin / admin123 или ваш пароль)"
