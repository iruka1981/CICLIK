# Contexto compartido del proyecto CICLIK

Este archivo lo cargan automáticamente todos los agentes (y el chat normal) de VS Code.

## Qué es CICLIK
PWA estática de economía circular ("Tot pot tornar a circular"): mercado de objetos, intercambio, talleres y saldo/transferencias entre miembros. Interfaz en catalán/castellano.

## Estructura
- `index.html`: aplicación completa (HTML + CSS + JS en un solo archivo, ~4300 líneas). `index-ciclik-corregido.html` es una variante anterior.
- `service-worker.js`, `manifest.webmanifest`, `icons/`: PWA.
- `supabase-*.sql`: scripts de esquema, perfiles, avatares, transferencias, auditoría y endurecimiento (RLS/funciones). Son scripts **de referencia**; no se ejecutan desde aquí.
- Imágenes de marca y slides en la raíz; `fotos web/` es una copia guardada de la web (no editar).
- Backend: Supabase (cliente `supabase-js@2` desde el navegador, con clave pública anon).
- No hay `package.json`, build ni tests automatizados.

## Reglas de seguridad obligatorias (todos los agentes)
1. **Prohibido** ejecutar nada contra el Supabase de producción (SQL, migraciones, CLI, MCP, REST con claves de servicio).
2. **Prohibido** desplegar la web (sin `git push` a ramas de despliegue, sin hosting CLI) salvo que el usuario lo pida explícitamente en ese turno.
3. **Prohibido** modificar saldos, transferencias o datos reales de miembros. Usar solo datos ficticios y entornos locales.
4. **Prohibido** contratar servicios, crear cuentas o activar APIs de pago/facturables.
5. No escribir secretos en el código ni en commits. Solo la clave `anon` pública puede estar en el cliente; nunca `service_role`.
6. Los cambios SQL se entregan como archivos/propuestas para revisión humana, nunca ejecutados.
7. Cambios mínimos y quirúrgicos; no reescribir `index.html` entero ni tocar archivos ajenos a la tarea.

## Colaboración
- El **Coordinador** divide el trabajo y delega en los especialistas; los demás pueden pedir revisión entre sí mediante handoffs.
- Todo agente termina con un resumen breve: qué cambió, qué verificó y qué queda pendiente.
