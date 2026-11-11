# CLAUDE.md — Instrucciones permanentes del proyecto CÍCLIC

Estas instrucciones se aplican cada vez que Claude Code trabaja en este repositorio.
Complementan las reglas existentes en `.github/copilot-instructions.md`.
Si hay conflicto, prevalecen las restricciones de seguridad más estrictas.

## Contexto

CÍCLIC es una PWA de economía circular para intercambios, talleres y monedero de Cicliks.
La aplicación actual usa `index.html` (HTML/CSS/JS), `service-worker.js`, `manifest.webmanifest` y Supabase.
No presumas que hay build, tests o CI si no están presentes; inspecciona antes de actuar.
La base de datos de producción tiene usuarios y movimientos reales. Nunca uses sus datos para pruebas.

## Protocolo obligatorio en 6 pasos

1. **Diagnosticar antes de tocar.** Leer estructura, reglas del repositorio y los controles ya implantados. Revisar cambios recientes, dependencias, flujo de autenticación, RLS, RPC y posibles regresiones. No rehacer lo que ya funciona.
2. **Proteger los accesos.** Aplicar principio de mínimo privilegio, validar datos, separar secretos del navegador, verificar permisos de cada usuario y protección contra XSS, CSRF, inyección y abuso. Nunca introducir `service_role` en frontend. Las funciones `SECURITY DEFINER` requieren autorización explícita y pruebas específicas.
3. **Controlar estabilidad y coste.** Proponer solo herramientas justificadas y gratuitas si es posible. Gestionar límites de llamadas externas, presupuestos, alertas de fallos, copias restaurables y reversión. Fijar versiones de dependencias y mantener el bloqueo de versiones si se introducen paquetes.
4. **Preparar cumplimiento legal.** Revisar privacidad desde el diseño, minimización de datos, RGPD/LOPDGDD, LSSI/cookies, condiciones de uso y normativa europea de IA cuando aplique. Redactar borradores con campos pendientes; no inventar datos del titular ni afirmar validación jurídica. Tratar datos sanitarios como de protección reforzada si aparecieran en otros proyectos.
5. **Verificar antes de publicar.** Probar login, registro, permisos, bonificación de bienvenida única, monedero, aportación/canje, transferencias (incluidos dobles clics y saldo insuficiente), administración, móviles/PWA y accesibilidad. No dar por superada una prueba que no has ejecutado. Usar staging y datos ficticios.
6. **Cerrar con evidencia breve.** Informar únicamente: qué revisaste, qué modificaste, qué pruebas ejecutaste y resultado, qué quedó pendiente, siguiente paso. Mantener la documentación mínima necesaria para reutilizar controles en Hazlo Yaya y CRM R.Egara sin compartir bases de datos ni datos personales.

## Límites absolutos

- **Nunca** ejecutar SQL, API mutadoras, migraciones ni scripts contra Supabase de producción.
- **Nunca** modificar saldos, transacciones ni datos reales.
- **Nunca** desplegar cambios ni fusionar ramas que puedan desplegar, salvo autorización explícita para ese despliegue.
- **Nunca** contratar servicios, activar APIs de pago o generar gastos sin autorización.
- No solicitar ni copiar contraseñas/tokens privados, ni guardar secretos en Git.
- Realizar cambios mínimos en ramas de trabajo; utilizar PRs y comprobar diffs.
- Cuando algo requiera pruebas de staging, preparar y documentar los pasos, pero no simular haberlos completado.

## Referencias del repositorio

- `.github/copilot-instructions.md`: reglas globales del proyecto.
- `supabase-ciclik-audit.sql`: auditoría SQL de solo lectura.
- `supabase-ciclik-hardening.sql` y `supabase-ciclik-function-hardening.sql`: endurecimientos existentes; revisar primero.
- `security/REVISION-2026-11-11.md`: hallazgos, pendientes y comprobaciones.
- `security/ciclik-hardening-candidato-2026-11-11.sql`: propuesta para staging, no ejecutarla en producción.

**Objetivo:** aplicaciones seguras, útiles, estables, asequibles y fáciles de mantener desde el primer día.
