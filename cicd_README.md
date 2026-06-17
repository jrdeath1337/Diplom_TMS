1. Секреты, которые нужно добавить в GitHub Actions
Перейди в репозиторий → Settings → Secrets → Actions → New repository secret.
Добавь все перечисленные ниже секреты. Часть из них ты уже создавал ранее — просто убедись, что они есть.

Секрет	Как получить
YC_OAUTH_TOKEN	OAuth‑токен Яндекса. Можно взять здесь
YC_CLOUD_ID	ID облака. Можно посмотреть в terraform.tfvars или в выводе yc config list
YC_FOLDER_ID	ID каталога. Аналогично – из terraform.tfvars или yc config list
YC_REGISTRY_ID	ID Container Registry. После первого terraform apply выполни yc container registry list и скопируй ID
KUBECONFIG	Важно обновлять после каждого пересоздания кластера! Как получить – описано ниже
INGRESS_IP	Публичный IP Ingress‑контроллера. Как получить – описано ниже
2. Как перезапустить CI/CD после terraform destroy && terraform apply
После того как ты заново создал облачную инфраструктуру, нужно обновить два динамических секрета: KUBECONFIG и INGRESS_IP. Вот пошаговая инструкция.

Шаг 1. Получи новый kubeconfig
bash
cd ~/Diplom_TMS/terraform
terraform output kubeconfig_command   # покажет готовую команду
# Выполни эту команду, например:
yc managed-kubernetes cluster get-credentials cath757on6ns72iud8t7 --external --force
После этого твой локальный ~/.kube/config будет содержать актуальные данные для подключения к новому кластеру.

Шаг 2. Закодируй kubeconfig и обнови секрет KUBECONFIG
bash
cat ~/.kube/config | base64
Скопируй весь вывод (это длинная строка).
Перейди в GitHub → Settings → Secrets → Actions → KUBECONFIG → Update, вставь скопированную строку и сохрани.

Шаг 3. Получи новый IP Ingress-контроллера
Сначала установи Ingress‑контроллер и дождись внешнего IP (это можно сделать скриптом deploy.sh, но нам нужен только IP):

bash
helm upgrade --install nginx-ingress ingress-nginx/ingress-nginx --namespace nginx --create-namespace
# подожди 1–2 минуты и проверь:
kubectl get svc -n nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
Если IP показался, запиши его. Если нет — подожди ещё.

Шаг 4. Обнови секрет INGRESS_IP
Скопируй полученный IP и вставь в GitHub → Settings → Secrets → Actions → INGRESS_IP → Update.

Шаг 5. Запусти CI/CD
Теперь можно либо сделать любой пуш в ветку main (например, изменить пробел в README и закоммитить), либо запустить workflow вручную:

В репозитории перейди на вкладку Actions.

Выбери слева workflow «Build, Test and Deploy API».

Нажми кнопку «Run workflow» → выбери ветку main → Run workflow.

Workflow отработает все шаги: тесты, сборку, пуш образа и деплой в Kubernetes.

Шаг 6. Запусти остальные сервисы (мониторинг, Loki, API)
Выполни скрипт deploy.sh (он сам подставит новый IP):

bash
cd ~/Diplom_TMS
./deploy.sh
После этого всё будет работать: API, мониторинг, логирование.

3. Важные замечания
KUBECONFIG и INGRESS_IP нужно обновлять только после пересоздания кластера или Ingress‑контроллера. При обычных изменениях кода они остаются неизменными.

Если ты не делаешь destroy, а просто повторно применяешь Terraform (без удаления кластера), обновлять эти секреты не нужно.

В production-среде эти шаги автоматизируются через Terraform Cloud и External Secrets Operator, но для учебного проекта ручное обновление двух секретов – нормальная практика.

Теперь у тебя есть полная инструкция по перезапуску CI/CD после «чистого листа». Поздравляю – проект полностью завершён и готов к демонстрации!
