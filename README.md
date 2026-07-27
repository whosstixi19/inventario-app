# inventario-app

Catálogo de inventario con interfaz web y base de datos local (JSON). Repositorio para la práctica de CI/CD del examen final.

**Persona A:** Jose Tixi — jtixit@est.ups.edu.ec
**Persona B:** Angel Cardenas — acardenasl2@est.ups.edu.ec

---

## Estructura del repositorio

```
inventario-app/
├── .github/workflows/ci-cd.yml    # Pipeline CI/CD (build-test + build-push)
├── data/                           # Datos persistentes (products.json)
├── k8s/
│   ├── deployment.yaml             # Deployment con RollingUpdate + probes + secretKeyRef
│   ├── service.yaml                # Service tipo NodePort
│   ├── secret.yaml                # Secret con API_KEY (no versionado en Git)
│   └── blue-green/                 # Estrategia de despliegue (Persona B)
├── public/                         # Frontend estático
├── docs/                           # Evidencias
├── .dockerignore                   # Archivos excluidos del build Docker
├── Dockerfile                      # Multi-stage builder + runner
├── db.js                           # Módulo de base de datos JSON
├── package.json                    # Dependencias y scripts
├── server.js                       # Entry point Express
├── server.test.js                  # Tests con node:test
└── README.md                       # Este archivo
```

---

## Requisitos previos

- Node.js 20+
- Docker
- Minikube + kubectl
- Cuenta en GitHub con GitHub Container Registry habilitado

---

## 1. Ejecutar en local

```bash
npm install
npm start
# Abrir http://localhost:3000
```

## 2. Pruebas

```bash
npm test
```

---

## 3. Docker

### 3.1 Dockerfile multi-stage

El `Dockerfile` tiene dos etapas:

1. **builder** — instala dependencias con `npm ci` y ejecuta `npm test`. Si las pruebas fallan, el build se detiene.
2. **runner** — imagen mínima con `node:20-alpine`, solo copia `server.js`, `db.js`, `public/`, `data/` y las dependencias de producción.

### 3.2 Construir imagen local

```bash
docker build -t inventario-app:latest .
```

### 3.3 Ejecutar contenedor local

```bash
docker run -d -p 3000:3000 --name inventario-app inventario-app:latest
```

### 3.4 Verificar con curl

```bash
curl http://localhost:3000/
curl http://localhost:3000/health
curl http://localhost:3000/version
curl http://localhost:3000/api/products
```

### 3.5 Detener y limpiar

```bash
docker stop inventario-app
docker rm inventario-app
```

---

## 4. CI/CD con GitHub Actions

### 4.1 Workflow

Archivo: `.github/workflows/ci-cd.yml`

**Jobs:**

| Job | Depende de | Descripción |
|-----|-----------|-------------|
| `build-test` | — | `npm ci` + `npm test` |
| `trivy-scan` | `build-test` | Escanea la imagen con Trivy (severidad CRITICAL) |
| `build-push` | `build-test`, `trivy-scan` | Construye imagen Docker y la publica en ghcr.io |

**Tags de imagen:**
- `ghcr.io/<usuario>/inventario-app:<sha del commit>`
- `ghcr.io/<usuario>/inventario-app:latest`

### 4.2 Push a GitHub

```bash
git remote add origin https://github.com/<tu-usuario>/inventario-app.git
git branch -M main
git push -u origin main
```

### 4.3 Verificar pipeline

Ir a la pestaña **Actions** del repositorio en GitHub y confirmar que:
1. El job `build-test` pasa (tests en verde).
2. El job `build-push` se ejecuta después y publica la imagen en ghcr.io.

---

## 5. Despliegue en Kubernetes (Minikube)

### 5.1 Iniciar Minikube

```bash
minikube start --driver=docker
```

### 5.2 Aplicar manifiestos

```bash
kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

### 5.3 Verificar rollout

```bash
kubectl rollout status deployment/cicd-inventario-app
```

### 5.4 Ver pods y servicio

```bash
kubectl get pods
kubectl get svc
```

### 5.5 Probar desde curl

```bash
minikube ip
kubectl get svc cicd-inventario-app
# Ejemplo: curl http://192.168.49.2:30272/health
curl http://$(minikube ip):$(kubectl get svc cicd-inventario-app -o jsonpath='{.spec.ports[0].nodePort}')/health
curl http://$(minikube ip):$(kubectl get svc cicd-inventario-app -o jsonpath='{.spec.ports[0].nodePort}')/version
curl http://$(minikube ip):$(kubectl get svc cicd-inventario-app -o jsonpath='{.spec.ports[0].nodePort}')/api/products
```

---

### Paso 5: Observación de Persistencia de Datos

Al recrear o eliminar un pod (`kubectl delete pod`), la aplicación pierde todos los productos creados dinámicamente desde la interfaz. Esto ocurre porque `data/products.json` se almacena dentro del sistema de archivos efímero del contenedor del pod. Al destruirse el pod, el nuevo contenedor inicia desde la imagen base en GHCR, recreando la base de datos únicamente con los datos semilla iniciales. Para solucionar esto en un entorno de producción real, se requeriría un `PersistentVolumeClaim` (PVC) o un servicio de base de datos externo.

---

## 6. Componentes adicionales (Persona A)

### 6.1 Manejo de Secretos

**Archivo:** `k8s/secret.yaml`

Se creó un Secret de Kubernetes con una credencial ficticia `API_KEY`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: inventario-secret
type: Opaque
stringData:
  API_KEY: "secret-key-practica-cicd-2026"
```

El Deployment consume la variable vía `secretKeyRef`:

```yaml
env:
  - name: API_KEY
    valueFrom:
      secretKeyRef:
        name: inventario-secret
        key: API_KEY
```

> **Nota:** `k8s/secret.yaml` está en `.gitignore` para no versionar credenciales reales en Git. En el repositorio solo se incluye un archivo de ejemplo (`k8s/secret.yaml.example`).

---

## 7. Estrategia de despliegue (Blue-Green)

Implementada por Persona B. Manifiestos en `k8s/blue-green/`.

### 7.1 Desplegar blue y green

```bash
kubectl apply -f k8s/blue-green/deployment-blue.yaml
kubectl apply -f k8s/blue-green/deployment-green.yaml
kubectl apply -f k8s/blue-green/service-blue-green.yaml
```

### 7.2 Verificar pods

```bash
kubectl get pods -l version=blue
kubectl get pods -l version=green
```

### 7.3 Probar tráfico inicial (blue)

```bash
kubectl port-forward service/inventario-app-bluegreen 3001:80
# En otra terminal:
curl http://localhost:3001/version
# Debe mostrar "color":"blue"
```

### 7.4 Cortar tráfico a green

```bash
kubectl edit service inventario-app-bluegreen
# Cambiar "version: blue" → "version: green" en el selector
```

### 7.5 Verificar corte

```bash
curl http://localhost:3001/version
# Debe mostrar "color":"green" y hostname del pod green
```

Para volver a blue: `kubectl apply -f k8s/blue-green/service-blue-green.yaml`

---

## 8. Componente adicional: Readiness con arranque lento

Implementado por Persona B.

### 8.1 Código

`server.js` incluye la variable `STARTUP_DELAY_SECONDS`:

```javascript
const STARTUP_DELAY = parseInt(process.env.STARTUP_DELAY_SECONDS || '0', 10);
```

Si el pod tiene menos de N segundos de vida, `/health` responde:

```json
{"status":"not ready","reason":"arrancando..."}
```

### 8.2 Configuración en deployment

```yaml
env:
  - name: STARTUP_DELAY_SECONDS
    value: "15"
readinessProbe:
  httpGet: { path: /health, port: 3000 }
  initialDelaySeconds: 2
  periodSeconds: 3
  failureThreshold: 3
```

### 8.3 ¿Qué pasaría si solo se aumentan las réplicas?

Aumentar réplicas **no soluciona** el problema. Si la app tarda 15s en estar lista pero el readinessProbe no está ajustado, Kubernetes mata el pod antes de que termine de arrancar, entra en un ciclo de reinicio infinito (CrashLoopBackOff) y nunca se estabiliza. La solución correcta es ajustar el probe con `initialDelaySeconds` y `failureThreshold` para tolerar el tiempo de arranque.

### 8.4 Probar

```bash
# Ver el delay: eliminar un pod y observar
kubectl delete pod -l version=blue
kubectl logs -l version=blue --tail=5 -f
```

---

## 9. Componente adicional: Escaneo de seguridad con Trivy

Implementado por Persona B.

El workflow `.github/workflows/ci-cd.yml` incluye el job `trivy-scan` que:

- Escanea la imagen Docker con **Trivy**
- Falla si encuentra vulnerabilidades de severidad **CRITICAL** (`exit-code: 1`)
- Bloquea `build-push` si el escaneo falla (`needs: [build-test, trivy-scan]`)

Jobs encadenados:

```
build-test → trivy-scan → build-push (solo si ambos pasan)
```

---

## Endpoints de la API

| Método y ruta | Qué hace |
|---|---|
| `GET /health` | Health check (200 si ok, 500 si falla, 503 si arrancando) |
| `GET /version` | Versión, color y hostname |
| `GET /api/products` | Lista productos |
| `GET /api/products/:id` | Producto por ID |
| `POST /api/products` | Crear producto |
| `PATCH /api/products/:id` | Actualizar producto |
| `DELETE /api/products/:id` | Eliminar producto |
| `GET /` | Interfaz web |

## Variables de entorno

| Variable | Default | Descripción |
|----------|---------|-------------|
| `PORT` | `3000` | Puerto del servidor |
| `APP_VERSION` | `v1` | Versión visible en /version |
| `APP_COLOR` | `blue` | Color del banner (usado en Blue-Green) |
| `SIMULATE_FAILURE` | `false` | Simular fallo en /health |
| `DB_PATH` | `./data/products.json` | Ruta de la BD local |
| `API_KEY` | — | Desde Secret de Kubernetes |
| `STARTUP_DELAY_SECONDS` | `0` | Segundos que /health responde "not ready" al arrancar |
