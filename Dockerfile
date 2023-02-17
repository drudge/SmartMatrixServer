FROM node:18-alpine

RUN apk add --no-cache openssl tzdata

WORKDIR /app
COPY . .
RUN npm install
RUN chmod -R a+x pixlet
RUN ls -lah pixlet/**/*
USER 1000:1000

CMD [ "node", "index.js" ]