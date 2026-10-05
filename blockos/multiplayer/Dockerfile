# BlockOS game server in a container, for hosting it on the internet.
#   docker build -t blockos-server . && docker run -p 8790:8790 blockos-server
FROM node:22-alpine
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY relay.js chatfilter.js ./
EXPOSE 8790
USER node
CMD ["node", "relay.js", "--port", "8790"]
