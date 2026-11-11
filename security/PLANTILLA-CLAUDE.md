# Plantilla CLAUDE.md — nuevas webs y aplicaciones

**Uso:** copiar este contenido como `CLAUDE.md` en la raíz de cada repositorio (por ejemplo, Hazlo Yaya o CRM R.Egara), y adaptar su sección «Contexto» antes de desarrollar. Claude Code debe leerlo automáticamente en ese proyecto.

## Contexto a completar
- Nombre y finalidad:
- Usuarios y datos tratados (identificar datos sensibles, especialmente salud):
- Framework, hosting, repositorio y base de datos:
- Coste máximo y proveedores autorizados:
- Entornos de desarrollo / staging / producción:
- Servicios y normas específicas:

## Protocolo de trabajo obligatorio — 6 fases
1. **Auditar y diseñar**: inventariar código, dependencias, arquitectura, amenazas y requisitos antes de instalar o modificar.
2. **Seguridad por defecto**: autenticación, autorización por recurso, sesiones, protección de secretos, validación, HTTPS, RLS donde corresponda, rate limiting y mínimos privilegios.
3. **Fiabilidad y gastos**: versiones fijadas, pruebas, registro de errores sin datos personales, backups verificables, control de consumo de IA, límites y alertas de presupuesto.
4. **Privacidad y legalidad**: RGPD, LOPDGDD, LSSI, cookies, condiciones, consumo y Reglamento de IA cuando aplique. Documentar pendientes; solicitar revisión profesional antes de publicar textos legales. Para datos de salud, controles reforzados y valorar EIPD.
5. **Pruebas y lanzamiento controlado**: pruebas funcionales y de seguridad, UX móvil, accesibilidad, staging, rollback; no desplegar sin permiso.
6. **Cierre resumido y reutilización**: informar (a) qué revisó, (b) qué implementó, (c) qué probó, (d) pendientes, (e) siguiente paso. Guardar patrones reutilizables sin compartir datos entre productos.

## Restricciones
- Nunca acceder o modificar datos de producción para experimentar; usar staging y datos ficticios o anonimizados.
- Nunca instalar dependencias innecesarias ni contratar/activar servicios facturables sin aprobación.
- Nunca almacenar secretos en repositorios o clientes; no exponer claves de servicio.
- Nunca prometer seguridad absoluta ni declarar una auditoría completada sin pruebas.
- No duplicar lo ya implementado, no reescribir sin necesidad y priorizar cambios mínimos reversibles.
- Evitar exceder seis etapas o generar documentos largos innecesarios.
