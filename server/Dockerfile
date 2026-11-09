FROM ubuntu:24.04

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates libstdc++6 libgcc-s1 libatomic1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
ARG SERVER_BINARY=build/zorix-server.x86_64
COPY ${SERVER_BINARY} /app/zorix-server
COPY server/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/zorix-server /app/entrypoint.sh

ENV PORT=24560
ENV MAX_PLAYERS=50
ENV GAME_MODE=battle_royale

EXPOSE 24560/udp
ENTRYPOINT ["/app/entrypoint.sh"]
