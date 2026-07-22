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

# Copiar package.json y package-lock.json
COPY package*.json ./

# Instalar solo dependencias de producción
RUN npm ci --only=production

# Copiar el código de la aplicación (incluida la carpeta public/)
COPY server.js db.js ./
COPY public/ ./public/
COPY data/ ./data/

# Exponer el puerto por defecto de Express
EXPOSE 3000

CMD ["node", "server.js"]