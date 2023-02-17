FROM node:16-alpine

RUN apk add --no-cache openssl tzdata strace 

WORKDIR /app
COPY . .
RUN npm install
RUN chmod -R a+x pixlet && chown -R 1000:1000 pixlet
USER 1000:1000

CMD [ "node", "index.js" ]