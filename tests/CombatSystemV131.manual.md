# Combat System V1.3.1 — validación humana con dos clientes

V1.3 NO está aprobada: el desarrollador reportó FAIL de spam por fallo y de latencia; PASS de eliminación por tres golpes; aciertos, reequipamiento, respawn/ronda y dos clientes quedaron pendientes. Los tests aislados de V1.3.1 no reemplazan esta nueva validación.

El agente no inició Play/Run/Team Test/Start Server. Realizá vos los pasos siguientes.

## Preparación e aislamiento

En Command Bar de Edit, habilitá opcionalmente las trazas:

~~~lua
local run = game:GetService("RunService")
assert(run:IsStudio() and not run:IsRunning(), "Solo Edit")
game:GetService("ReplicatedStorage"):SetAttribute("SlapDiagnosticsEnabled", true)
~~~

Después iniciá tu servidor local con dos clientes. Revisá que servidor y ambos clientes muestren **CombatSystemV131 Protocol=3** en los logs SlapService/SlapController. No mezclar cliente V1.3 con servidor V1.3.1. Esta instalación no publicó ni compartió Drafts automáticamente.

Antes de jugar, el Output del servidor debe confirmar **PersistenceEnvironment=Studio PersistenceProvider=InMemory WritesToCloud=false**. Si no coincide, detené la prueba. Consulta de solo lectura opcional, ejecutada por vos en la Command Bar del servidor de prueba:

~~~lua
local run = game:GetService("RunService")
assert(run:IsStudio() and run:IsRunning() and run:IsServer(), "Solo servidor local de prueba")
local info = require(game:GetService("ServerScriptService").Services.PlayerDataService):GetPersistenceDiagnostics()
assert(info.Environment == "Studio" and info.ProviderName == "InMemory"
    and info.WritesToCloud == false, "ABORTAR: proveedor no aislado")
print("CombatV131 persistence:", info.Environment, info.ProviderName, info.WritesToCloud)
~~~

No tocar DataStores, Universe ID, Config ni balance. Classic.Configuration.Power=20 y SlapCooldown=0.6 se preservaron; con SlapCombo.Enabled=true se usan las recuperaciones de 0.15/0.45 de Config, no 0.6.

## Prueba reproducible

1. Entrar con A/B a Red/Blue, votar y terminar el countdown. Antes de Playing y mientras el movimiento está bloqueado no debe predecirse una palmada.
2. Alejar a los jugadores más de 9 studs sobre suelo seguro. Hacer **un clic** con A: la animación debe comenzar al input, antes del acuse. Obtener primero una traza limpia.
3. Repetir con **10 clics rápidos** tras el primero. Debe haber una predicción/solicitud inicial; no nuevas animaciones mientras el cliente sabe que está bloqueado. El servidor acepta una sola ventana de 0.10 s y aplica MissRecovery=0.45 DESDE el cierre.
4. Seguir intentando cerca del límite: el siguiente ataque aceptado de esa misma vida/ronda no puede empezar antes de RecoveryUntil. Comparar los timestamps; que el brazo se siga moviendo en una animación no demuestra otra aceptación.
5. Repetir con B y alternar ambos. No deben compartir bloqueos, AttackIds autoritativos ni feedback.
6. Durante la recuperación intentar desequipar/reequipar por los controles normales. El bloqueo de equipamiento puede impedirlo; si no es reproducible, registrar esa parte NOT RUN. No desactivar scripts para fabricar el escenario.
7. Acercarse y acertar frente al rival. La recuperación autoritativa debe seguir siendo 0.15 desde el contacto aceptado. Confirmar sensación de respuesta inmediata, sin otra animación al llegar Started. Repetir golpes válidos cuando la geometría lo permita.
8. Revalidar tres impactos sobre una misma vida sin gol/caída intermedia: una eliminación, una Kill/Death y +50 por Kill acreditada. Un fallo/rechazo no suma. Confirmar ragdoll de 3 s y ausencia de duplicados por contactos tardíos naturales.
9. Si StrongSlap está disponible normalmente en el inventario aislado, armar, fallar y luego acertar antes de expirar: Miss conserva, Hit consume una vez. Probar Dash y demás habilidades disponibles sin editar perfiles ni compras reales.
10. Caer en KillPart, reaparecer y probar una nueva vida válida. No recibir impactos/animaciones de peticiones anteriores ni heredar bloqueos obsoletos.
11. Hacer un gol, esperar el reinicio y jugar hasta final/Muerte Súbita. Conservar +50 por gol, marcador, EndCinematic y retorno al lobby.
12. Completar otra partida y revisar limpieza de Workspace.ActiveMatches. Registrar cuántas partidas se completaron.

No inyectar ataques falsos, errores o tráfico de red desde Command Bar para esta validación. Los casos hostiles, demoras y desorden se probaron en fixtures. Si algún escenario de gameplay no puede reproducirse, registrar BLOCKED o NOT RUN.

## Distinguir solicitudes de aceptaciones

Filtrar [SlapTrace], con Build=CombatSystemV131. Vincular UserId, PredictionId, RequestId, AttackId, SessionId, RoundId y CharacterGeneration.

| Evento | Qué demuestra |
| --- | --- |
| ClientRequest / PredictionPlayed | Input y animación predicha. El AttackId local es PredictionId; todavía no existe autorización del servidor. |
| RequestReceived | Recepción del mensaje en el servidor, NO aceptación ni impacto. |
| AttackStarted, Accepted=true | Servidor reservó una ventana y generó AttackId autoritativo. |
| ServerRejected, Accepted=false | Petición rechazada, sin nueva ventana ni nuevo impacto. |
| RecoverySet, RecoveryType=Miss | Fallo finalizado. RecoveryUntil - AttackWindowClosed=0.45. |
| RecoverySet, RecoveryType=Hit | Impacto aceptado. RecoveryUntil - AttackWindowClosed=0.15. |
| PredictionCancelled | Presentación corregida por rechazo/cancelación de esa predicción. |
| ClientBlocked | No se envió otra solicitud ni se reprodujo otra animación. |
| FeedbackIgnored | Respuesta obsoleta/ajena, sin modificar la predicción actual. |

AttackStarted incluye PreviousAttackId, PreviousRecoveryUntil y PreviousRecoveryMonotonic. Para ataques sucesivos de la MISMA vida/ronda, StartMonotonic debe ser >= PreviousRecoveryMonotonic. Un cambio de vida/ronda legítimo se analiza separadamente.

WindowUntil es el límite máximo de búsqueda; AttackWindowClosed es su cierre real (temprano en Hit). El planificador puede cerrar tarde, nunca justificar una recuperación menor a 0.45 desde el cierre efectivo. No interpretar HitConfirmed=false en RequestReceived/Started como un Miss final: todavía no hay Outcome.

Las trazas están limitadas a 12 filas/jugador/segundo por lado y apagadas por defecto. El spam extremo puede omitir filas por ese límite. Capturá primero el intento limpio; los silencios por límite no prueban ausencia de ataques.

## Qué enviar si continúa el FAIL

- Output del servidor y de ambos clientes, incluyendo los marcadores de versión y aislamiento.
- Un intento limpio y otro con los 10 clics; video corto que permita separar movimiento continuo de múltiples reinicios de Swing.
- PredictionId/AttackId involucrados, tiempos ClientRequest/RequestReceived/AttackStarted/AttackWindowClosed/RecoveryUntil y el siguiente AttackStarted.
- Motivos ServerRejected, PredictionCancelled, FeedbackIgnored y cualquier AttackError con stack.
- Si hubo reequipamiento, cambio de Character/CharacterGeneration o RoundId justo antes del fallo.
- Matriz PASS/FAIL/BLOCKED/NOT RUN por los doce pasos y partidas completadas.

Clasificación a resolver con esas evidencias: A varias solicitudes; B aceptaciones prematuras; C animaciones sin aceptación; D estado local desincronizado; E otro mecanismo demostrado. No hace falta compartir datos personales, credenciales o Output ajeno.

Al detener vos la prueba, volver a Edit y apagar trazas:

~~~lua
local run = game:GetService("RunService")
assert(run:IsStudio() and not run:IsRunning(), "Solo Edit")
game:GetService("ReplicatedStorage"):SetAttribute("SlapDiagnosticsEnabled", nil)
~~~

No publicar ni sobrescribir el place para probar esta versión.

