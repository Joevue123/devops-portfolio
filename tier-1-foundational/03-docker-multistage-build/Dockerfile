# syntax=docker/dockerfile:1.7

# ─── Stage 1: production dependencies only ────────────────────────────────────
FROM node:20-alpine AS deps
WORKDIR /app

# Copy manifests first for better layer caching
COPY package.json package-lock.json ./

RUN npm ci --omit=dev --ignore-scripts \
    && npm cache clean --force


# ─── Stage 2: build ───────────────────────────────────────────────────────────
FROM node:20-alpine AS builder
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --ignore-scripts

COPY tsconfig.json ./
COPY src/ ./src/

RUN npm run build


# ─── Stage 3: test (CI only — never shipped to production) ────────────────────
FROM builder AS test
COPY --from=builder /app/dist ./dist

RUN npm run test -- --coverage --ci \
    && npm run lint


# ─── Stage 4: production ──────────────────────────────────────────────────────
FROM gcr.io/distroless/nodejs20-debian12:nonroot AS production

WORKDIR /app

# Copy only what the app needs at runtime
COPY --from=deps    /app/node_modules ./node_modules
COPY --from=builder /app/dist         ./dist
COPY --from=builder /app/package.json ./

# Distroless runs as nonroot (uid 65532) by default
# USER nonroot is set in the base image

EXPOSE 3000

ENV NODE_ENV=production \
    PORT=3000

CMD ["dist/index.js"]
