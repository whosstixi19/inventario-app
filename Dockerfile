# --- Stage 1: Build y Pruebas ---
FROM node:20-alpine AS builder

WORKDIR /app

# Copiar archivos de dependencias
COPY package*.json ./

# Instalar todas las dependencias
RUN npm ci

# Copiar el código fuente completo
COPY . .

# Ejecutar las pruebas unitarias (si falla, detiene el build)
RUN npm test

# --- Stage 2: Runtime Mínimo ---
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production

# Hookear el stage builder para forzar la ejecución de npm test en BuildKit
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/package-lock.json ./package-lock.json

# Instalar solo dependencias de producción
RUN npm ci --only=production

# El runtime no necesita npm; retirarlo reduce la superficie de escaneo.
RUN npm cache clean --force && rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx /root/.npm

# Copiar el código de la aplicación desde el builder
COPY --from=builder /app/server.js ./server.js
COPY --from=builder /app/db.js ./db.js
COPY --from=builder /app/public ./public
COPY --from=builder /app/data ./data

# Exponer el puerto por defecto de Express
EXPOSE 3000

CMD ["node", "server.js"]