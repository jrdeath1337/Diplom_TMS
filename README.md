# Diplom_TMS
Дипломная работа для курса DevOps Engineer
CompfyUI_cloud
├── ansible #Настройка ОС и софта
│   ├── inventort.ini #IP инстанса (генерируется terraform)
│   ├── roles #Роли ansible
│   │   ├── common #База (Docker, пакеты)
│   │   ├── k3s #Установка кластера+GPU плагин
│   │   ├── nvidia #Драйвер GPU + nvidia-container-toolkit
│   │   └── storage #Монтирование S3 или создание папок под ИИ модели
│   └── site.yml #Главный playbook
├── docker #Сборка image
│   └── Dockerfile #CompfyUI на базе NVIDIA CUDA
├── k8s #k8s manifest
│   ├── deployment.yaml #Манифест CompfyUI
│   ├── pvc.yaml #persistentVolumeClaim - тут будут храниться ИИ модели для Compfy
│   └── service.yaml #Доступ к UI (NodePort или LoadBalancer)
├── README.md #Ветрина
├── .github #CI/CD pipeline
│   └── workflows
│       └── main.yml Linting -> Build -> Push -> Deploy
└── terraform #IaC: Поднятие инфраструктуры (железа в облаке)
    ├── main.tf #Основные ресурсы (VM, Network, Disk)
    ├── outputs.tf #IP сервера после создания 
    ├── provider.tf #Настройка провайдера (Пока хз что за облако будет)
    └── variables.tf #Переменные (тип GPU, регион)

