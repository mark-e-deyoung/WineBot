# Container build

Build the image with:

`docker build -f docker/Dockerfile -t winebot .`

Use the compose profiles for normal workflows:

`docker compose --profile headless up --build`

