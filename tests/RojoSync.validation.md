# Conexión segura de Rojo — 2026-10-17

## Seguimiento de la segunda captura

La revisión inicial de nombres repetidos no cubrió todas las subcarpetas. Se encontraron tres grupos adicionales: StarterPlayer.StarterPlayerScripts.DeathFeedback y EndCinematic.Modules.EndCinematicBillboards / EndCinematicRanking. Se compararon recursivamente nombres, clases, atributos, fuentes y propiedades Sandboxed/Capabilities disponibles; las copias resultaron equivalentes. Se conservaron copias Before y los originales adicionales en ServerStorage._RojoSyncRecovery_20261017_Followup, dejando una instancia activa por ruta. Esta segunda recuperación existe en el DataModel Edit y no está incluida en el archivo .rbxm anterior.

La revisión recursiva posterior de Shared, ServerScriptService y StarterPlayer no encontró duplicados. No se editaron fuentes. El servidor seguro sigue con 77/77 fuentes equivalentes y ninguna ruta duplicada; build y diff --check pasan. Cancelar la vista previa previa y volver a conectar a 34873 para obtener una comparación actualizada; la aceptación del plugin continúa pendiente.

## Diagnóstico

La papelera de la vista previa corresponde a instancias de Studio que Rojo propone eliminar; no indica que vaya a borrar archivos locales durante la sincronización normal del disco hacia Studio.

El servidor anterior, puerto 34872, sirve los 77 scripts actuales, pero conserva un árbol de proyecto anterior. Studio contenía nueve grupos con nombres repetidos: cinco módulos de Shared, DeathEffectService, Respawn y los controladores DeathFeedbackController y KillRewardController. Los módulos duplicados tenían fuentes equivalentes; la carpeta Respawn adicional era un subconjunto de la carpeta completa.

## Preparación realizada

- Se creó studio-safe.project.json, un perfil para sincronizar código y conservar objetos desconocidos en cada nodo. No sincroniza recursos físicos de mapas, HUD, efectos, cámaras o sonidos.
- Los 77 archivos están mapeados individualmente. No se combinan rutas de directorios con hijos explícitos del mismo nombre, ya que Rojo 7.7 puede generar hijos duplicados al hacerlo.
- Start-StudioSafeRojo.ps1 actualiza los mappings de archivos de código y sirve este perfil explícitamente en 127.0.0.1:34873. Los mappings de archivos eliminados requieren revisión manual antes de quitarlos.
- El servidor seguro está iniciado. El servidor anterior 34872 no fue detenido ni modificado.
- Se conservaron las instancias completas y se movieron los originales adicionales a ServerStorage._RojoSyncRecovery_20261017_063311. Cada grupo contiene Before (copias previas) y MovedOriginals (original adicional con atributos de procedencia).
- Se exportó ese archivo de recuperación a tests/assets/backups/RojoSyncRecovery.rbxm: 21.121 bytes, 61 descendientes, SHA-256 CD3847805F64216B1FE63A79F525BAA8BDC960C3EC15215F510D4C129B7CA66E. Se verificó su deserialización sin incorporarlo al escenario activo.
- No se editaron fuentes de producción ni default.project.json durante esta tarea. Sus modificaciones previas permanecen intactas. No se guardó, cerró ni publicó el lugar.

## Verificaciones

| Verificación | Resultado |
|---|---|
| Fuentes servidas frente al repositorio | 77/77 equivalentes, normalizando CRLF y whitespace final |
| Fuentes de Studio frente al repositorio | 77/77 equivalentes con la misma normalización; incluidas las copias previas |
| Árbol del servidor seguro | 117 instancias, ninguna ruta duplicada |
| Conservación de objetos desconocidos | Activada en los 117 nodos |
| Studio Edit | IsRunning=false; sin nombres repetidos en Shared, Services y Controllers |
| Recuperación física | Nueve grupos presentes; Respawn activo conserva sus tres módulos |
| rojo build studio-safe.project.json | PASS |
| git diff --check | PASS |
| Conexión del plugin y aceptación de vista previa | PENDIENTE del usuario; no se ha aceptado ninguna sincronización |
| Jugabilidad | NO EJECUTADA |

Evidencia: RojoSync.audit.json, RojoSync.safe-audit.json, RojoSync.studio-source-hashes.json y RojoSync.recovery.json. El cotejo normalizado no afirma igualdad binaria de Source: pueden aparecer actualizaciones por saltos de línea o whitespace final.

## Conectar ahora

1. Cancelar la vista previa anterior y desconectar el plugin de su servidor anterior.
2. Conectar a 127.0.0.1, puerto 34873.
3. Confirmar el nombre exacto: **SlapDuels-2.0 Scripts Only SAFE**.
4. Revisar la vista previa. Si propone eliminar recursos o scripts vigentes, cancelar y capturar esa lista para revisarla. No aceptar el proyecto anterior por error.
5. Aceptar solamente la vista previa revisada del perfil seguro.

El MCP disponible permite operar el DataModel de Studio, pero no aceptar la ventana del plugin Rojo. Este último paso queda pendiente.

En futuras sesiones iniciar desde PowerShell en el repositorio:

```powershell
.\Start-StudioSafeRojo.ps1
```

No iniciar otra copia mientras 34873 ya esté ocupado. Mantener esa terminal abierta; Ctrl+C detiene ese servidor.

Este perfil protege objetos no administrados, pero actualiza propiedades de los scripts que sí administra. No exporta al repositorio los cambios artísticos de Studio ni constituye un respaldo completo del lugar. El perfil default permanece disponible para build/export; evitar usarlo para sincronización en vivo hasta revisar sus recursos físicos.

## Recuperación

Los originales adicionales siguen dentro de MovedOriginals. Sus atributos RojoRecoveryOriginalParent y RojoRecoveryOriginalName registran la procedencia. Para deshacer la consolidación, revisar esos atributos y devolver únicamente los originales elegidos a sus padres; hacerlo recreará los duplicados originales. Before conserva las copias anteriores a los movimientos. Como alternativa, importar RojoSyncRecovery.rbxm en un contenedor de recuperación y comparar antes de restaurar. No reemplazar todo el lugar ni ejecutar restauraciones automáticas sobre el Working Tree.

El respaldo integral previo permanece intacto. No hubo Play, Run, partidas, commits, push, publicaciones ni acceso a DataStores.

Referencia del formato: https://rojo.space/docs/v7/project-format/ ($ignoreUnknownInstances).
