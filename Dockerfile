FROM node:24-alpine
ENV NODE_ENV=production
WORKDIR /app
COPY --chown=node:node app/ ./app/
USER node
EXPOSE 8080
CMD ["node", "app/server.mjs"]
