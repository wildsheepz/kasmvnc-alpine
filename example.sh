INDEX=10
docker build -t kuanyong/kasmvnc-alpine:latest . && docker run \
    -e TZ=Asia/Singapore \
    -e LC_ALL=en-SG.UTF-8 \
    -e NO_DECOR=1 \
    -e PUID=1000 \
    -e PGID=1000 \
    -e WEBSOCKET_PORT=70${INDEX} \
    -e DISPLAY=:${INDEX} \
    -e CUSTOM_PORT=90${INDEX} \
    -e CUSTOM_HTTPS_PORT=80${INDEX} \
    -e CUSTOM_USER=user \
    --network host \
    --rm -it kuanyong/kasmvnc-alpine:latest