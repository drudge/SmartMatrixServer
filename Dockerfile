FROM node:current-alpine

RUN apk add --no-cache git go libwebp libwebp-dev alpine-sdk tzdata && \
    git clone https://github.com/acvigue/pixlet && \
    cd pixlet && \
    make build && \
    cp pixlet /bin/pixlet && \
    chmod +x /bin/pixlet && \
    cd / && rm -rf /pixlet /root/go /root/.cache/go-build && \
    apk del alpine-sdk go

WORKDIR /app
COPY . .
RUN npm install
USER 1000:1000

CMD [ "node", "index.js" ]