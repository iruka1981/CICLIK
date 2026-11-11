# PLANTILLA AGENTS.md — Protocolo ChatGPT/Codex para nuevos proyectos

Copiar como `AGENTS.md` a la raíz de cada repositorio y adaptar la ficha. Puede servir para Hazlo Yaya, CRM R.Egara y nuevas apps.

## Ficha del proyecto
- Nombre, propósito y tipo de usuarios:
- Datos gestionados y clasificación de sensibilidad (p. ej. salud):
- Stack, repositorio, hosting y base de datos:
- Entornos separados para desarrollo, staging y producción:
- Servicios externos, IA y gasto máximo autorizado:
- Obligaciones jurídicas y responsables del tratamiento:

## Seis pasos de trabajo
1. **Revisar y planificar** la estructura, funciones existentes, dependencias y amenazas. No rehacer lo que ya funciona.
2. **Implementar seguridad por defecto** con autorización por recurso, sesiones, secretos fuera del frontend, validación de entradas, HTTPS, RLS si aplica y protección contra abusos.
3. **Garantizar fiabilidad y coste controlado**: paquetes fijados, tests, límites de API, alertas, backups probados y recuperación.
4. **Diseñar para privacidad y legalidad**: RGPD/LOPDGDD, LSSI, cookies, consumo y reglas de IA cuando proceda. Los textos legales deben revisarse por profesionales antes de publicarlos.
5. **Probar en un entorno seguro**: requisitos funcionales, acceso indebido, movilidad, accesibilidad, rendimiento, errores y rollback.
6. **Informar con evidencias**: revisión, cambios, resultados de pruebas, pendientes y siguiente acción en respuesta compacta.

## Reglas no negociables
- No modificar producción, datos reales ni publicar despliegues sin consentimiento explícito.
- No comprar ni activar servicios de pago sin autorización.
- No exponer claves privadas ni datos personales en código, logs o respuestas.
- No mezclar datos entre proyectos; reforzar protección de datos sanitarios y valorar una EIPD.
- Realizar cambios mínimos en ramas separadas, validar diffs y crear PR revisable.
- No inventar pruebas completadas; separar propuestas de implementaciones.
- Evitar herramientas, documentación y costes innecesarios.
