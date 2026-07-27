# Guion de Demostración — Los Diferentes Despliegues

**Integrantes:** Jose Tixi y Angel Cardenas
**Idea del guion:** mostrar cada despliegue como un camino completo y separado — de principio a fin, uno a la vez, bien demostrado. Trivy es la única excepción: no se repite en vivo, solo se muestra su historial en GitHub Actions.

**Dónde se corre todo:** en la computadora de Angel, porque ahí es donde está desplegado Blue-Green (Jose no lo aplicó en su propio Minikube). Para demostrar que ambos trabajaron en el proyecto, en vez de alternar de laptop a mitad de la demo (riesgoso: reconectar proyector, reabrir túneles, etc.), se muestra el historial de commits de GitHub — ahí queda clarísimo, con nombre y hora, quién hizo cada parte, sin ningún riesgo técnico.

---

## Preparación previa (la noche antes o justo antes de entrar a exponer)

Correr esto en la compu de Angel, **antes** de que empiece la presentación, para no perder tiempo en vivo:

### 1. Verificar que Minikube esté corriendo

```bash
minikube status
```

Si no está `Running`, arrancarlo:

```bash
minikube start
```

### 2. Verificar que el Secret siga existiendo

```bash
kubectl get secret inventario-secret
```

Si no existe (por ejemplo, si Minikube se reinició del todo), recrearlo:

```bash
kubectl apply -f k8s/secret.yaml
```

### 3. Verificar que todos los pods estén arriba y sanos

```bash
kubectl get pods -l app=cicd-inventario-app
kubectl get pods -l app=inventario-app
```

Deben verse 10 pods en `Running`: 4 base, 3 blue, 3 green. Si falta alguno o los manifiestos no están aplicados:

```bash
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/blue-green/deployment-blue.yaml
kubectl apply -f k8s/blue-green/deployment-green.yaml
kubectl apply -f k8s/blue-green/service-blue-green.yaml
kubectl rollout status deployment/cicd-inventario-app
```

### 4. Confirmar que el selector de Blue-Green esté en "blue" (estado inicial para la demo)

```bash
kubectl get service inventario-app-bluegreen -o yaml
```

Si dice `version: green` en el selector, regrésalo a blue para empezar la demo desde el estado inicial esperado:

```bash
kubectl patch service inventario-app-bluegreen -p "{\"spec\":{\"selector\":{\"app\":\"inventario-app\",\"version\":\"blue\"}}}"
```

### 5. Abrir los dos túneles de Minikube (dejar ambas terminales abiertas, sin cerrarlas)

**Terminal A:**
```bash
minikube service cicd-inventario-app --url
```

**Terminal B:**
```bash
minikube service inventario-app-bluegreen --url
```

Cada una te da una URL con un puerto — anótalos, los vas a usar en los `curl` del guion.

### 6. Abrir las pestañas del navegador

- [ ] Pestaña 1: la URL del Terminal A (Service base)
- [ ] Pestaña 2: la URL del Terminal B (Blue-Green) — confirmar que se ve **azul**
- [ ] Pestaña 3: `github.com/<tu-usuario>/inventario-app/commits/main` (historial de commits)
- [ ] Pestaña 4: `github.com/<tu-usuario>/inventario-app/actions` (para Trivy)
- [ ] Pestaña 5: `github.com/<tu-usuario>/inventario-app/pkgs/container/inventario-app` (Packages/ghcr.io)

### 7. Terminal C — libre, para los comandos `kubectl` en vivo durante la demo

---

## Introducción — 45 seg

> "Vamos a mostrar los distintos despliegues que armamos para `inventario-app`. Todo lo vamos a correr desde esta computadora, porque aquí es donde está desplegado el clúster completo con Blue-Green. Para que quede claro que los dos trabajamos en el proyecto, antes de empezar les mostramos el historial de commits."

**(Pestaña 3 — historial de commits en GitHub)**

> "Aquí ven, con nombre y hora real de cada uno: Jose Tixi hizo el Deployment base y corrigió un bug del selector; Angel Cardenas hizo el workflow de CI/CD, Blue-Green, y los componentes de Secrets y Readiness. Cada commit tiene su autor real, verificable, no hay forma de simularlo."

---

## Despliegue 1 — Base, con Rolling Update — 2 min

> "Este es el camino más simple: la app empaquetada en Docker, publicada automáticamente, y corriendo en Kubernetes con actualización continua."

**Paso 1 — la imagen ya está publicada (mostrar rápido)**

**(Pestaña de Packages / ghcr.io)**

> "La imagen se construye y publica sola cada vez que hacemos `push`, gracias al pipeline de GitHub Actions."

**Paso 2 — el manifiesto**

```bash
kubectl get pods
```

> "Estos 4 pods son el Deployment base. Usan `RollingUpdate` con `maxUnavailable: 1` y `maxSurge: 1` — o sea que al actualizar, nunca se cae más de una réplica a la vez."

```bash
kubectl rollout status deployment/cicd-inventario-app
```

> "Confirma que el despliegue está sano y completo."

**Paso 3 — probar que responde**

**(Pestaña del navegador con el Service base)**

> "Y aquí está corriendo en vivo, servido desde uno de esos pods del clúster."

```bash
curl http://127.0.0.1:PUERTO/health
curl http://127.0.0.1:PUERTO/version
```

> "`/health` confirma que está sano, y `/version` nos dice desde qué pod exacto respondió."

---

## Despliegue 2 — Blue-Green — 2.5 min

> "Esta es la segunda estrategia de despliegue: dos versiones completas corriendo al mismo tiempo, y un Service que decide con un solo cambio cuál de las dos recibe el tráfico."

**Paso 1 — mostrar que ambas versiones están arriba**

```bash
kubectl get pods -l app=inventario-app
```

> "Vean los pods de `blue` y `green` — 3 de cada uno, corriendo a la vez, cada una con su propia etiqueta de versión."

**Paso 2 — estado inicial (blue)**

**(Pestaña del navegador con Blue-Green)**

> "Ahora mismo el Service de Blue-Green apunta a `blue` — vean el banner azul."

**Paso 3 — el corte de tráfico, en vivo**

```bash
kubectl patch service inventario-app-bluegreen -p "{\"spec\":{\"selector\":{\"app\":\"inventario-app\",\"version\":\"green\"}}}"
```

**(Refrescar la misma pestaña)**

> "Con un solo comando cambiamos el selector del Service — no tocamos ningún pod — y el tráfico ya pasó a `green` de forma instantánea. Este mismo mecanismo, al revés, sería un rollback inmediato si algo saliera mal con la versión nueva."

**Paso 4 (opcional, si hay tiempo) — volver a blue**

```bash
kubectl patch service inventario-app-bluegreen -p "{\"spec\":{\"selector\":{\"app\":\"inventario-app\",\"version\":\"blue\"}}}"
```

> "Y así de fácil volvemos atrás."

---

## Despliegue 3 — Secrets — 1.5 min

> "Este componente resuelve cómo manejar credenciales sin exponerlas en el código."

**Paso 1 — el Secret existe en el clúster, no en un archivo**

```bash
kubectl get secret inventario-secret
kubectl describe secret inventario-secret
```

> "Este Secret lo aplicamos desde el archivo `k8s/secret.yaml` que está en el repositorio — con `.gitignore` para no trackearlo — y el valor real se inyecta directamente en el clúster. Vean que `describe` no muestra el contenido — solo confirma que existe y cuánto pesa."

**Paso 2 — la app lo está usando de verdad**

```bash
curl http://127.0.0.1:PUERTO/api/secret-check
```

> "Este endpoint responde `true` porque la aplicación, corriendo dentro del pod, sí recibió la clave — inyectada por Kubernetes vía `secretKeyRef` — sin que nosotros la hayamos puesto en ningún YAML."

---

## Despliegue 4 — Readiness con Arranque Lento — 2 min

> "Este componente evita que Kubernetes mande tráfico a un pod que técnicamente ya está corriendo, pero que internamente todavía no está listo."

**Paso 1 — forzar el arranque desde cero**

```bash
kubectl delete pod <nombre-de-un-pod-base>
```

> "Acabo de borrar un pod a propósito para que Kubernetes cree uno nuevo desde cero."

**Paso 2 — observar la transición en vivo**

```bash
kubectl get pods -l version=blue --watch
```

> "El pod nuevo va a aparecer primero como `0/1` — el contenedor ya arrancó, pero programamos que `/health` responda 'no listo' durante 15 segundos, simulando una conexión lenta a base de datos. Kubernetes espera pacientemente en vez de matarlo."

*(Esperar la transición a `1/1`, luego `Ctrl+C`. Si el tiempo no calza:)*

```bash
kubectl describe pod <nombre-del-pod-nuevo>
```

> "Y aquí queda registrado igual: el evento `Readiness probe failed... 503` durante el arranque, seguido del pod pasando a `Ready`."

---

## Despliegue / Componente 5 — Trivy — 1.5 min — SOLO historial en GitHub, sin demo en vivo

> "Este último componente no lo vamos a repetir en vivo, porque implicaría reintroducir una vulnerabilidad real a propósito. Lo mostramos directamente con el historial de ejecuciones en GitHub Actions."

**(Pestaña de Actions — abrir la ejecución que falló por Trivy)**

> "Aquí ven una ejecución en rojo: el job `build-push` falló porque Trivy, nuestro escáner de seguridad, detectó una vulnerabilidad crítica real en una librería llamada `tar`, empaquetada dentro de `npm`. El pipeline bloqueó la publicación — no llegó a subir esa imagen a producción."

**(Abrir la ejecución posterior, en verde)**

> "Y aquí, después de corregirlo —eliminando `npm` de la imagen final, porque en producción solo necesitamos `node`— la misma revisión pasó con cero vulnerabilidades críticas y la imagen sí se publicó."

---

## Cierre — 20 seg

> "Esos son los 5 caminos de despliegue: el base con rolling update, Blue-Green con corte de tráfico en vivo, y los tres componentes extra — Secrets y Readiness demostrados en el clúster, y Trivy con evidencia real del pipeline. Como vieron al inicio en los commits, ambos participamos en cada parte del proyecto. Todo el código y los comandos están en el repositorio. Gracias."

---

## Definiciones rápidas (por si preguntan)

- **Rolling update:** reemplazar pods viejos por nuevos de a poco, nunca todos de golpe.
- **Blue-Green:** dos versiones completas corriendo a la vez; se cambia el tráfico con un solo switch.
- **Secret (Kubernetes):** una caja donde se guardan contraseñas o claves separadas del código.
- **Readiness probe:** la pregunta repetida que hace Kubernetes a un pod para saber si ya puede recibir tráfico.
- **CVE:** el nombre oficial que se le da a una falla de seguridad ya conocida y documentada (*Common Vulnerabilities and Exposures*).
