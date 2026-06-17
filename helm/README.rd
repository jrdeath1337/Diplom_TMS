markdown
## Быстрый старт

### 1. Развернуть инфраструктуру Terraform
```bash
cd terraform
terraform init -upgrade
terraform apply
После успешного выполнения в корне terraform/ появятся:

cpu-worker.env — переменные для Docker-воркера (генерируется автоматически).

kubeconfig_command в outputs — команда для подключения к кластеру.

2. Подключиться к Managed Kubernetes
bash
terraform output kubeconfig_command
# Выполнить полученную команду с флагом --force, например:
# yc managed-kubernetes cluster get-credentials cat27vm0p2c3sjj8i22g --external --force
kubectl get nodes   # должно показать две ноды
3. Собрать и запушить образ API в Container Registry
Важно: Если вы уже работали с реестром, и при пуше возникает ошибка Registry X not found, полностью очистите Docker-кэш перед пересборкой:

bash
docker rmi -f $(docker images -q --filter "reference=*/hybrid-api") 2>/dev/null; true
docker builder prune -af
docker system prune -a --volumes --all --force
Затем выполните сборку и пуш:

bash
cd ~/Diplom_TMS/Docker/api

# Логин в реестр
yc iam create-token | docker login --username iam --password-stdin cr.yandex

# Получить ID реестра (или задать явно)
REGISTRY_ID=$(yc container registry list --format json | jq -r '.[0].id')

# Собрать и запушить
docker build --no-cache -t cr.yandex/$REGISTRY_ID/hybrid-api:v0.1 .
docker push cr.yandex/$REGISTRY_ID/hybrid-api:v0.1
4. Создать Kubernetes Secret с чувствительными переменными
bash
cd ~/Diplom_TMS/terraform
DB_DSN=$(terraform output -raw db_connection_string)
S3_BUCKET=$(terraform output -raw s3_bucket_name)
ACCESS_KEY=$(terraform output -raw worker_sa_access_key)
SECRET_KEY=$(terraform output -raw worker_sa_secret_key)
S3_ENDPOINT=$(terraform output -raw s3_endpoint)

kubectl create secret generic hybrid-api-secrets \
  --from-literal=DB_DSN="$DB_DSN" \
  --from-literal=S3_BUCKET="$S3_BUCKET" \
  --from-literal=AWS_ACCESS_KEY_ID="$ACCESS_KEY" \
  --from-literal=AWS_SECRET_ACCESS_KEY="$SECRET_KEY" \
  --from-literal=S3_ENDPOINT="$S3_ENDPOINT"
5. Установить Ingress-контроллер (однократно)
bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace nginx --create-namespace
Дождитесь внешнего IP:

bash
kubectl get svc -n nginx nginx-ingress-ingress-nginx-controller
Запишите EXTERNAL-IP (например, 158.160.230.148).

6. Обновить values.yaml и задеплоить API
bash
cd ~/Diplom_TMS
# Подставить актуальный IP в хост
INGRESS_IP=$(kubectl get svc -n nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
sed -i "s|host: .*|host: api.$INGRESS_IP.nip.io|" helm/hybrid-api/values.yaml

# Убедиться, что repository указывает на правильный реестр
sed -i "s|repository: .*|repository: cr.yandex/$REGISTRY_ID/hybrid-api|" helm/hybrid-api/values.yaml

# Деплой
helm upgrade --install hybrid-api ./helm/hybrid-api
Проверьте:

bash
kubectl get pods
curl http://api.$INGRESS_IP.nip.io/health
7. Запустить локальный воркер
bash
docker compose up -d worker
Теперь всё готово: API в Kubernetes, воркер локально, чувствительные данные в Secret, а результаты генерируются через веб-интерфейс.

Примечания:

Если возникает ошибка «Registry not found», обязательно чистите кэш Docker перед сборкой.

Флаг --force в команде получения kubeconfig перезаписывает существующий контекст (нужен при повторных подключениях).

text

Этот README теперь включает борьбу с закэшированными слоями и уточнение по `--force`. Дальше можем заняться мониторингом или ArgoCD, как решишь.
