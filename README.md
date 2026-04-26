# Docker pattern web app

Минимальное веб-приложение для проверки связки:

- домен `www.timptr.ru`;
- уже запущенный Nginx на сервере;
- Docker-контейнер со статической HTML-страницей;
- reverse proxy из Nginx в контейнер.

Страница рисует абстрактный изменяющийся узор на `<canvas>`.

## Структура

```text
.
├── app/
│   └── index.html
├── nginx/
│   └── timptr.ru.conf.template
├── scripts/
│   └── install.sh
├── .dockerignore
├── docker-compose.yml
└── Dockerfile
```

## Быстрый запуск локально

```bash
docker compose up -d --build
```

После запуска приложение доступно на:

```text
http://127.0.0.1:8080
```

Остановить:

```bash
docker compose down
```

## Установка на сервер с Nginx

1. Склонируйте репозиторий на сервер.
2. Запустите установочный скрипт:

```bash
chmod +x scripts/install.sh
sudo DOMAIN=www.timptr.ru APP_PORT=8080 scripts/install.sh
```

Скрипт:

- проверит наличие Docker, Docker Compose plugin и Nginx;
- попробует запустить Docker daemon, если он установлен, но остановлен;
- соберет и запустит контейнер;
- создаст конфиг Nginx в `/etc/nginx/sites-available/www.timptr.ru.conf`;
- включит его через `/etc/nginx/sites-enabled/`;
- проверит конфигурацию Nginx;
- перезагрузит Nginx.

Если на сервере уже есть другой Nginx-конфиг с `server_name www.timptr.ru`, отключите или обновите его перед запуском, чтобы не было конфликтующих server block.

## Если Docker daemon не запущен

Ошибка вида:

```text
Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?
```

означает, что Docker установлен, но его сервис не работает. На Ubuntu обычно помогает:

```bash
sudo systemctl enable --now docker
sudo systemctl status docker --no-pager
```

После этого повторите установку:

```bash
sudo DOMAIN=www.timptr.ru APP_PORT=8080 scripts/install.sh
```

Если `systemctl` недоступен:

```bash
sudo service docker start
```

## Настройки

Переменные окружения для `scripts/install.sh`:

| Переменная | По умолчанию | Описание |
| --- | --- | --- |
| `DOMAIN` | `www.timptr.ru` | Домен для Nginx server block |
| `APP_PORT` | `8080` | Локальный порт, на который Docker публикует приложение |
| `COMPOSE_PROJECT_NAME` | `timptr-pattern` | Имя Docker Compose проекта |

## Проверка после установки

```bash
curl -I http://www.timptr.ru
docker compose ps
sudo nginx -t
```
