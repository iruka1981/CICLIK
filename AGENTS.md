# AGENTS.md — Reglas de trabajo para ChatGPT/Codex en CÍCLIC

Este archivo define cómo debe trabajar un asistente de programación compatible con AGENTS.md dentro de este repositorio. Se complementa con `.github/copilot-instructions.md`; en caso de conflicto, manda la regla más restrictiva.

## Proyecto
CÍCLIC es una PWA de economía circular: usuarios, intercambios, talleres y monedero de Cicliks.
Stack actual: HTML/CSS/JS en `index.html`, `service-worker.js`, `manifest.webmanifest` y Supabase.
Primero inspecciona el repositorio y los scripts existentes: no presumas que hay tests, CI, frontend moderno ni un entorno de pruebas operativo.
Existe una revisión previa en `security/REVISION-2026-11-11.md`.

## Método de trabajo (máximo seis pasos)
1. **Inventario y diagnóstico.** Lee estructura, cambios existentes y dependencias. Comprueba qué funciona antes de cambiarlo; cataloga fallos por prioridad.
2. **Seguridad por diseño.** Valida entradas y permisos por usuario/rol, maneja secretos solo en servidor, protege autenticación/sesiones, RLS y RPC. Examina `SECURITY DEFINER` individualmente. Previene XSS, CSRF, inyección y abusos, según proceda.
3. **Costes y estabilidad.** Prioriza soluciones simples y gratuitas; controla llamadas a IA y servicios externos, límites de gasto, dependencias fijadas, monitorización, copias restaurables y recuperación.
4. **Privacidad y obligaciones.** RGPD/LOPDGDD, LSSI, cookies, términos, protección de datos y normativa europea de IA cuando corresponda. Señala lo que requiera asesoría jurídica. Nunca inventes datos del titular ni publiques textos legales sin validar.
5. **Verificación.** Ejecuta o especifica pruebas reproducibles con datos ficticios para registro, acceso, bonificación única, monedero, transferencias, doble clic, errores, permisos de administrador y versión móvil/PWA. No presentes pruebas no ejecutadas como superadas.
6. **Entrega breve.** Informa qué inspeccionaste, qué cambiaste, qué probaste, qué queda pendiente y cuál es el siguiente paso. Máximo seis bloques y sin informes largos innecesarios.

## Prohibiciones y protección de producción
- No ejecutar SQL ni otras operaciones de escritura contra Supabase de producción; no modificar ni consultar innecesariamente datos personales reales.
- No desplegar, fusionar ramas de despliegue, migrar ni modificar saldos reales sin autorización explícita.
- No contratar servicios ni activar API facturables sin permiso.
- No escribir ni compartir credenciales, contraseñas, tokens privados o claves de servicio; la clave pública de cliente no equivale a una clave privada.
- Mantén datos y sistemas de CÍCLIC separados de Hazlo Yaya y CRM R.Egara; la información clínica requiere protección reforzada.
- Cambios mínimos, reversibles y en rama con PR. Usa staging solo cuando esté operativo y seguro. Si no lo está, prepara propuesta y pruebas sin fingir resultados.
- Antes de aplicar SQL de `security/ciclik-hardening-candidato-2026-11-11.sql`, verificar copias restaurables, dependencias, permisos y pruebas de integración.

## Fuentes internas
- `.github/copilot-instructions.md`: restricciones originales.
- `supabase-ciclik-audit.sql`: auditoría read-only de controles financieros.
- `supabase-ciclik-hardening.sql` y `supabase-ciclik-function-hardening.sql`: scripts existentes.
- `security/REVISION-2026-11-11.md`: primera revisión e inventario de problemas.

**Criterio:** ahorrar créditos y tiempo, no duplicar lo realizado y no afirmar que algo está corregido sin verificarlo.
