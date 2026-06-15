README – Диагностика и проверка системы
В этом разделе собраны команды для быстрой проверки состояния базы данных, задач и общего осмотра компонентов системы. Используйте их при отладке или демонстрации.

1. Проверка PostgreSQL
Подключение к БД через контейнер API (рекомендуется)
API-контейнер (или любой другой с psql/Python) уже имеет доступ к переменным окружения:

bash
# Если API развёрнут в Kubernetes, выполните внутри пода
kubectl exec -it deployment/hybrid-api-api -- python3 -c "
import psycopg2, os
conn = psycopg2.connect(os.getenv('DB_DSN'))
cur = conn.cursor()
cur.execute('SELECT 1')
print('DB connection OK')
conn.close()
"
Просмотр таблицы tasks (через Python в поде)

bash
kubectl exec -it deployment/hybrid-api-api -- python3 -c "
import psycopg2, os, json
conn = psycopg2.connect(os.getenv('DB_DSN'))
cur = conn.cursor()
cur.execute('SELECT id, status, result_url, error_msg, created_at FROM tasks ORDER BY id')
print('ID | STATUS | RESULT_URL | ERROR_MSG | CREATED_AT')
print('-' * 60)
for row in cur.fetchall():
    print(f'{row[0]:<4} | {row[1]:<10} | {row[2] or \"\"} | {row[3] or \"\"} | {row[4]}')
conn.close()
"
Если используется локальный Docker-контейнер с worker'ом:

bash
docker exec -it gpu-worker python3 -c "
import psycopg2, os
conn = psycopg2.connect(os.getenv('DB_DSN'))
cur = conn.cursor()
cur.execute('SELECT id, status, result_url FROM tasks ORDER BY id')
for row in cur.fetchall():
    print(row)
conn.close()
"
2. Проверка статуса воркера
Локальный worker (Docker Compose)

bash
docker compose logs worker --tail 20
В логах должны быть сообщения Worker started, Processing task X, Task X completed.

Проверка, что контейнер запущен

bash
docker compose ps worker
Статус должен быть Up.

3. Проверка API и Kubernetes
Проверка подов

bash
kubectl get pods -l app=hybrid-api
Все поды должны быть Running.

Логи API

bash
kubectl logs deployment/hybrid-api-api --tail 10
Проверка Ingress

bash
kubectl get ingress hybrid-api-ingress
В колонке HOSTS должен быть указан домен api.<IP>.nip.io.

Проверка работоспособности API

bash
curl -s http://api.158.160.230.148.nip.io/health
4. Полный цикл проверки (создание задачи)
bash
# Создаём тестовую задачу
curl -X POST http://api.158.160.230.148.nip.io/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt": "test cat", "steps": 5}'

# Через некоторое время проверяем статус (подставьте ID задачи)
curl http://api.158.160.230.148.nip.io/status/1
Если worker работает, статус станет completed, а в поле result_url появится ссылка на изображение в S3.

5. Общий осмотр всех компонентов
bash
# Инфраструктура
cd terraform && terraform output

# Контейнеры
docker compose ps

# Kubernetes
kubectl get all -n default
kubectl get ingress -n default
Примечания
Все команды подразумевают, что вы находитесь в корне проекта (~/Diplom_TMS).

При работе с Kubernetes необходимо предварительно выполнить yc managed-kubernetes cluster get-credentials <cluster-id> --external --force.

Для локального worker'а используйте docker compose (файл docker-compose.yml).

Этот набор команд позволяет быстро оценить состояние системы и найти проблемы. В следующем разделе будет добавлен мониторинг (Grafana), который автоматизирует большую часть этих проверок.
