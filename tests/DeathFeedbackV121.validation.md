# Death Feedback V1.2.1 — implementación y validación pendiente

Fecha: 2026-10-16. No se ejecutaron Play, Run, Start Server, personajes ni partidas.
La estabilidad del respawn NO se declara corregida hasta la validación humana.

## Corrección posterior: arranque de RagdollStatesHandler sandboxed

El desarrollador aportó Output que confirma un error al requerir Config desde
RagdollStatesHandler: el LocalScript es Sandboxed=true y Config no lo es. Ese
require diagnóstico agregado por V1.2.1 detenía el script antes de conectar StateEvent.
Se quitó el require de ambos scripts de Character. ArenaRespawn copia la opción
Config.Respawn.Debug al atributo ArenaRespawnDebug del Character al iniciar la
retirada; los clientes sólo leen ese booleano. Ausencia del atributo significa false.
La activación sigue siendo Config.Respawn.Debug=true antes de iniciar la prueba;
el diagnóstico cliente estará disponible desde la primera retirada y replicación
del atributo. No se alteraron Sandboxed, Capabilities ni permisos de Config.

MCP Edit verificó una instancia por script, ausencia de require en ambos y el
emisor del atributo en servidor. RagdollStatesHandler conserva Sandboxed=true;
ArenaRespawnGuard conserva Sandboxed=false. Build y diff check PASS tras el arreglo.
No se ejecutó gameplay: hay que reiniciar manualmente la prueba para generar los
Characters con los LocalScripts actualizados y repetir B–D. El Output anterior
demuestra un fallo de arranque, no permite concluir sobre el salto residual.

## 1. Evidencia y causa

El desarrollador informa en V1.2: caída accidental, su respawn, efectos, premios,
eliminaciones consecutivas y temporizador PASS; respawn tras palmada FAIL.
Son resultados informados por el desarrollador, no pruebas ejecutadas por el agente.

La auditoría confirma un defecto R6: ApplyRagdoll volvía a crear colliders,
attachments y BallSocketConstraints en golpes repetidos, sobrescribiendo
_r6Instances[character]. El reset sólo podía destruir la última lista. Esto permite
recursos físicos residuales. No hay evidencia runtime suficiente para atribuirle
por sí solo el salto observado tras una sola palmada.

Otras hipótesis pendientes: pose de miembros aún articulada al reactivar motores,
estado Physics/velocidades en el cliente al recuperar ownership y paquetes antiguos
antes de observar los nuevos atributos. Se refuerzan estos puntos sin afirmar que
se haya demostrado una causa física única.

## 2. Diferencia de rutas auditadas

Caída: KillPart → EliminationService → Spawn/ArenaRespawn → mismo Character.
Palmada: SlapService → CombatService.RegisterHit → RagdollService → velocidad lineal
y angular en servidor y StateEvent en cliente → Physics, motores desactivados,
constraints y timer de recuperación → KillPart → el mismo lifecycle Zero-Death.

KnockbackService es un placeholder; no aplica fuerzas. El recorrido activo no usa
BodyVelocity, LinearVelocity, VectorForce ni ApplyImpulse. El RagdollModule legacy
contiene waits y recolocación, pero RagdollHandler mantiene ragdollModule=nil:
ese camino no está conectado y no se cambió. SlapController maneja herramientas,
animación/remotes; no aplica velocidad de respawn. CharacterRemoving/Added de
Spawn ya cancelan el registro pendiente del Character exacto.

## 3. Archivos de código modificados en esta tarea

- src/server/Services/RagdollService.luau: reutilizar rig R6 en golpes repetidos;
  recuperación con identidad de tarea, Character, generación, Player, sesión y
  StateVersion; recomposición R6 silenciosa durante retirada anclada.
- src/character/RagdollStatesHandler.client.luau: identidad del Character vigente,
  generación, sesión y paquete actual en el defer; desconexión al retirar Character;
  marca local de golpe aceptado para preservar un golpe NUEVO tras reaparecer.
- src/character/ArenaRespawnGuard.client.luau: en PreSimulation, una limpieza por
  revisión de respawn de velocidades y estado local Physics. Se hace incluso con
  salto antiguo retenido. No se repite al liberar la tecla y no anula un golpe
  nuevo ya aceptado para la generación actual. Restaura Jumping/AutoJump originales.
- src/server/Services/SlapService.luau: el equipamiento diferido conserva Character,
  generación, sesión/versión y bloqueo, revalidados también tras WaitForChild.
  Fórmulas, potencia, cooldown, selección de rival y reglas del golpe intactos.
- src/server/Services/Respawn/ArenaRespawn.luau: diagnóstico optativo por evento,
  EliminationId y tipo; conserva temporizador, retirada y ownership originales.
- src/server/Services/SpawnService.luau: transporta tipo diagnóstico opcional.
- src/server/Services/EliminationService.luau: entrega tipo Kill/NormalFall al
  lifecycle; no cambia atribución, estadísticas, debounce ni transacción de Coins.
- src/shared/Config.luau: sólo añade Config.Respawn.Debug=false. Delay sigue 500 ms.

También se agregan este informe, DeathFeedbackV121.spec.luau (NO EJECUTADO) y
DeathFeedbackV121.edit-evidence.json. El diff contra HEAD incluye trabajo anterior;
no debe interpretarse como diff exclusivo de V1.2.1.

## 4–8. Recuperación, callbacks, física y Zero-Death

Se conserva ArenaPhysicsGeneration: incrementa al retirar y reposicionar. No se
creó otra generación de vida. La identidad del paquete y del thread sólo cancelan
operaciones reemplazadas dentro de una misma generación.

ResetRagdollImmediate quiet destruye sus recursos rastreados, reactiva motores y,
si había rig R6 y root ya anclado por ArenaRespawn, recompone posiciones según
Part0.CFrame*C0*C1^-1, con Transform identidad, antes de restaurar colisiones.
No mueve geometría del mapa ni cambia C0/C1. No reconstruye poses R15 por esta vía.
Spawn sigue resolviendo equipo/slot, orientación, separación y solapamiento.
La limpieza de todas las velocidades existente permanece; se añade una limpieza
local una sola vez en el límite físico de retorno. No hay impulsos compensatorios.

El objetivo local es Running, PlatformStand=false, Jump=false al recuperar control.
Si llegó un golpe válido NUEVO para esa generación, se conserva su Physics/velocidad.
Saltar vuelve a habilitarse con los valores previos al soltar la entrada antigua;
no cambia JumpPower ni JumpHeight. No se añade espera ni anclaje permanente.
Ownership sigue siendo servidor durante retirada y se devuelve al modo previo.

Zero-Death reutiliza el Character; no crea uno nuevo ni escribe Health=0. Los
callbacks comprobados capturan el Character original y no buscan el reemplazo para
aplicar velocidad. Fin de sesión y punto conservan cancelación de respawns existente.
No se cambiaron HUD, cosméticos, CoinTarget, economía, EndCinematic, mapa, KillPart,
modalidades, concurrencia ni persistencia. No hubo escrituras cloud.

## 9–11. Matriz de verificación

| Comprobación | Estática | Funcional V1.2.1 |
|---|---|---|
| Kill invalida generación anterior | Inspeccionado: Begin/Reset incrementan token existente | NOT RUN |
| Caída sin atacante | Ruta conservada; PASS anterior informado por desarrollador | NOT RUN |
| Deferred launch antiguo | Character/Player/generación/sesión/paquete comprobados | NOT RUN |
| Recuperación ragdoll antigua | Thread/Character/Player/token/sesión/versión comprobados | NOT RUN |
| Velocidades de respawn | Cero servidor + limpieza cliente acotada | NOT RUN |
| Jump involuntario | Jump=false y barrera de entrada retenida | NOT RUN |
| Salto legítimo posterior | Restauración de flags originales | NOT RUN |
| Delay 500 ms | Valor conservado | NOT RUN |
| Doble contacto | Pending/contact guard/debounce conservados | NOT RUN |
| Kill y Coins una sola vez | Reglas y transacción existentes conservadas | NOT RUN |
| Notificaciones/efectos | Sin cambios en productores/consumidores visuales | NOT RUN |
| Reinicio por gol | CancelSessionRespawns existente conservado | NOT RUN |
| Cierre con respawn pendiente | Cancelación existente conservada | NOT RUN |
| Modelo Rojo | PASS: rojo build default.project.json | No prueba Luau ni física |
| Espacios/conflictos del diff | PASS: git -c core.safecrlf=false diff --check | No prueba funcional |
| Despliegue Edit | PASS: ocho Sources con marcadores y una instancia por ruta | No ejecución de módulos |

El build se genera en la carpeta temporal, fuera del repositorio.
Las primeras invocaciones sandbox fallaron por acceso al filesystem; reintentos
con permiso de lectura completaron ambos checks. No se corrió analizador Luau ni
la suite preparada. No hay Output de partidas nuevas para presentar como evidencia.

Studio MCP confirmó IsStudio=true, IsRunning=false, DataModel Edit. Inspección de
PersistenceEnvironment/Bootstrap confirma rama Studio→InMemory/WritesToCloud=false.
No se ejecutó Bootstrap ni se afirmó un proveedor de servidor activo en Edit.
No se guardó, cerró, reemplazó ni publicó el lugar con cambios del desarrollador.

## 12. Guía manual A–H

Antes de comenzar, verificá en el servidor de TU prueba local:
PersistenceEnvironment=Studio, PersistenceProvider=InMemory, WritesToCloud=false.
Si difieren, detené la prueba. Usá dos clientes, entrá por matchmaking y esperá Go.
Anotá Coins y estadísticas del atacante antes de cada caso. No uses comandos que
fabriquen Kills, Health=0, movimientos ni premios.

| Caso | Acciones del desarrollador | Resultado esperado / evidencia |
|---|---|---|
| A | Sin recibir golpes en los últimos 10 segundos, caminá fuera hasta KillPart. No pulses salto. | Retirada inmediata; retorno al spawn tras ~500 ms, sin salto; DefaultFall, 0 Coins por Kill. Grabación de víctima y Output servidor. |
| B | Con un Slap existente de potencia alta, golpeá al rival cerca del borde para que toque KillPart durante ragdoll. Víctima sin pulsar salto. | Regresa estable y orientado en su spawn, sin subida, rotación ni salto automático. Esperá también más que el timer normal de ragdoll (1.5 s) para detectar recuperación tardía. Grabá ambas vistas. |
| C | Repetí B cinco veces en la misma sesión. En una eliminación, encadená dos golpes válidos antes de que toque KillPart si la geometría y cooldown lo permiten. | Cinco recuperaciones estables; un premio por eliminación; ningún Collider/RagdollConstraint/TorsoWeld residual después del retorno. Si no puede darse doble golpe, marcá ese subcaso NOT RUN. |
| D | Tras reaparecer sin entrada retenida, caminá y pulsá salto una vez. Repetí una eliminación reteniendo salto desde antes de caer, soltalo al volver y presionalo de nuevo. | Primer retorno sin salto automático; nueva pulsación salta normalmente; no bloqueo de movimiento ni salto permanente. Probar teclado y controles usados en el proyecto. |
| E | Compará Coins antes/después de B; observá contactos múltiples de la misma eliminación y un tercer cliente en lobby si está disponible. | Exactamente +50 al atacante; FX de víctima y feed conservados; monedas llegan a CoinTarget; lobby sin feedback ajeno. |
| F | Desde Edit, cambiá manualmente KillPartDelayMs a 0, 250 y 1000, reiniciando tu prueba para cada valor. Luego restauralo a 500. | Retirada inmediata y demora correspondiente; sin impulsos ni doble retorno incluso a 0 ms. No cambiar Max, economía ni potencia. |
| G | Anotá un gol válido, incluido un caso con rival retirado si resulta reproducible naturalmente. Esperá countdown y Go. | +50 por gol; spawn/countdown normales, sin callback posterior que cambie posición/estado. |
| H | Para facilitar la observación, en Edit usá temporalmente 2000 ms y reiniciá TU prueba. Durante retirada, hacé abandonar al otro cliente para cerrar la sesión. Restaurá 500 al terminar. | Cancelled por cierre; regreso al flujo normal/lobby; tras el plazo anterior no vuelve a aparecer en la arena ni se modifica un Character reemplazado. |

Si H/G no se pueden reproducir naturalmente, marcar BLOCKED/NOT RUN con motivo,
sin modificar reglas ni simular desde código de producción. Registrar por caso:
PASS/FAIL/NOT RUN/BLOCKED, sesión, jugadores, clip, Output y diferencia observada.

### Diagnóstico si persiste

En Edit, en ReplicatedStorage.Shared.Config (fuente src/shared/Config.luau), poné
Config.Respawn.Debug=true ANTES de iniciar tu prueba para que lo lean ambos lados.
Repetí B y copiá Output de servidor y víctima desde el golpe hasta al menos 2 s
después del retorno. Buscá [RespawnDebug]: RetiredAfterRagdoll/RetiredWithoutRagdoll,
ServerRestored, ClientSettled, StaleStateEvent, StaleDeferredLaunch,
StaleRagdollRecovery y Cancelled. Incluí líneas de EliminationService y ArenaRespawn,
EliminationId, UserId, generación, tipo, estado, Jump y velocidades. Un callback
cancelado antes de ejecutarse no genera mensaje stale; su ausencia no es un fallo.
Velocidades cero registradas en un instante no demuestran estabilidad posterior.
Restaurá Debug=false y KillPartDelayMs=500 al terminar. No se registra por frame.

## 13. Riesgos y límite de aceptación

La física y el orden de replicación sólo se verifican con clientes reales. R15,
latencia alta, golpes nuevos justo al retornar, salto táctil/gamepad y cinco Kills
requieren validación humana. La limpieza no elimina constraints ajenas por nombre:
sólo las que este servicio rastrea; no destruye piezas cosméticas o de otros sistemas.
No se implementaron funciones nuevas fuera de este alcance. Detener trabajo aquí
y esperar la validación del desarrollador antes de cualquier fase siguiente.
