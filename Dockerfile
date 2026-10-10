# syntax=docker/dockerfile:1

FROM node:22-slim AS deps
WORKDIR /app
COPY app/package.json app/package-lock.json ./
RUN npm ci --omit=dev

FROM node:22-slim
ENV NODE_ENV=production
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY app/package.json ./
COPY app/src ./src
USER node
EXPOSE 8080
CMD ["node", "src/serve.ts"]
