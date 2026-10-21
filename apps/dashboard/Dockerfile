# Stage 1: build
FROM public.ecr.aws/docker/library/node:22-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --no-audit --no-fund
COPY . .
RUN npm run build

# Stage 2: run
FROM node:22-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000

# Copy production node_modules
COPY package*.json ./
RUN npm ci --no-audit --no-fund --omit=dev && npm cache clean --force

# Copy built output
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/next.config.ts ./next.config.ts
COPY --from=builder /app/next-env.d.ts ./next-env.d.ts
COPY --from=builder /app/postcss.config.* ./
COPY --from=builder /app/tailwind.config.* ./
COPY --from=builder /app/tsconfig.json ./

EXPOSE 3000
CMD ["node", "server.js"]
