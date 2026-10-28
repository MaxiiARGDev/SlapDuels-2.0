# Combat System V1.3 — prueba manual con dos clientes

La implementación está en Edit. El agente NO ejecutó Play/Run/Team Test/Start Server. Esta guía corresponde al desarrollador. No publicar ni activar cloud para probarla.

## Preparación

1. Confirmá que Rojo usa este repositorio y el perfil SAFE. Los dos scripts deben contener el marcador CombatSystemV13 Protocol=2 en su log de inicio. No aceptes sincronizaciones que borren objetos desconocidos.
2. Antes de iniciar la prueba, en Command Bar de **Edit**, habilitá opcionalmente las trazas:

~~~lua
local run = game:GetService("RunService")
assert(run:IsStudio() and not run:IsRunning(), "Ejecutar en Edit")
game:GetService("ReplicatedStorage"):SetAttribute("SlapDiagnosticsEnabled", true)
~~~

El atributo viene apagado/ausente. Solo funciona en Studio y limita las trazas a 12 filas por jugador y segundo en cada lado. No cambies Config ni valores económicos.

3. Iniciá vos un servidor local con **dos clientes** mediante las herramientas de prueba de Studio. No hace falta habilitar 2v2 ni concurrencia.
4. Revisá el Output del servidor: debe mostrar PersistenceEnvironment=Studio PersistenceProvider=InMemory WritesToCloud=false. Si no coincide, detené la prueba.
5. En la Command Bar del **servidor de prueba**, podés comprobar el proveedor real con esta consulta de solo lectura:

~~~lua
local run = game:GetService("RunService")
assert(run:IsStudio() and run:IsRunning() and run:IsServer(), "Usar el servidor local de prueba")
local data = require(game:GetService("ServerScriptService").Services.PlayerDataService)
local info = data:GetPersistenceDiagnostics()
assert(info.Environment == "Studio" and info.ProviderName == "InMemory"
    and info.WritesToCloud == false, "ABORTAR: persistencia no aislada")
print("CombatV13 persistence:", info.Environment, info.ProviderName, info.WritesToCloud)
~~~

6. Confirmá el marcador CombatSystemV13 Protocol=2 tanto en el servidor (SlapService) como en ambos clientes (SlapController). Si falta, no mezcles versiones antiguas de cliente y servidor. Para Team Test también debe coincidir el código compartido; esta tarea no publicó ni hizo commits de Drafts.

## Secuencia reproducible

| Paso | Acción humana | Resultado esperado |
| --- | --- | --- |
| 1 | Con ambos clientes, entrar a Red/Blue, votar y esperar el countdown y desbloqueo completos. | Partida 1v1, Slap equipado, ronda Playing de 180 s. Antes de Playing no hay animaciones de ataque. |
| 2 | Separar los jugadores más de 9 studs, en suelo seguro. Hacer un clic con A y enseguida muchos clics. | Una sola aceptación/animación; ventana de 0.10 s sin Hit; recuperación de 0.45 s DESDE el cierre. Los clics bloqueados no generan nuevas solicitudes ni efectos. |
| 3 | Repetir el fallo con B mientras A recupera, y luego alternar ambos. | Recuperaciones independientes; no se transfieren cooldowns ni feedback entre jugadores. |
| 4 | Durante recuperación, intentar desequipar/reequipar con el mecanismo normal del juego. | El bloqueo de equipamiento sigue funcionando; aunque haya rebote de Tool no se adelanta otro ataque. Si el juego impide la maniobra, marcar esa parte manual NOT RUN; no desactivar scripts para fabricarla. |
| 5 | Enfrentarse a corta distancia y acertar con A. Volver a atacar tras la recuperación, cuando la geometría permita otro contacto válido. | Hit confirmado; recuperación rápida de 0.15 s desde RegisterHit aceptado, sin añadir una espera fija extra. La animación empieza al recibir Started aceptado, por lo que su percepción depende de la latencia real. |
| 6 | Repetir tres impactos válidos sobre la misma vida, sin cruzar KillPart ni reiniciar ronda entre ellos. | El tercer impacto elimina una vez; los rechazos/fallos no cuentan. Ragdoll de los primeros impactos conserva 3 s desde el último derribo. |
| 7 | Mirar las Coins y el feedback del atacante/víctima. Después provocar contacto tardío de la misma eliminación si sucede naturalmente. | Kill/Death y recompensa de +50 por Kill acreditada una vez, efecto de víctima y feedback del atacante intactos. Los fallos no premian. No usar comandos para modificar saldos. |
| 8 | Si StrongSlap ya está disponible en el inventario aislado, seleccionarlo por el flujo normal, armarlo, fallar y después acertar antes de expirar. | Fallar conserva el armado; acertar lo consume una vez y elimina sin sumar un impacto de combo normal. Si no está disponible, registrar BLOCKED por inventario, sin alterar perfiles reales. |
| 9 | Probar Dash y las demás habilidades disponibles por su flujo normal. | Sin cambios de física, balance, selección, preferencias ni Shop. No asumir PASS de las habilidades que no se probaron. |
| 10 | Hacer una caída en KillPart, reaparecer e intentar el primer ataque válido de la nueva vida. | No hereda la recuperación anterior; no recibe animaciones ni impactos de una solicitud antigua. |
| 11 | Hacer un gol mientras hay actividad de combate y esperar el reinicio. | Gol válido sigue dando +50; ningún golpe tardío durante countdown; nueva ronda habilita el primer ataque válido. |
| 12 | Llegar a Muerte Súbita y finalizar la partida. | Reglas actuales, resultado y EndCinematic intactos; sin ataques en final/cinemática. |
| 13 | Volver al lobby y jugar otra partida. | Sin Tool/animaciones/cooldowns residuales; Workspace.ActiveMatches se limpia tras finalizar. |

No provoques artificialmente errores de código, manipules remotes ni desconectes servicios para completar esta guía. Excepciones antiguas, desorden de paquetes y spam remoto hostil se verificaron en fixtures aislados; un caso no reproducido en gameplay permanece NOT RUN.

## Cómo interpretar la traza

Filtrá el Output por [SlapTrace]. Vinculá servidor y cliente usando UserId, RequestId, AttackId, SessionId, RoundId y Generation.

- ClientRequest: solicitud enviada, todavía sin animación.
- AttackStarted: servidor aceptó y reservó esa ventana. Su acuse tiene Phase=Started y Accepted=true.
- FeedbackReceived de Started: el cliente puede reproducir Swing una sola vez.
- RecoverySet con RecoveryType=Miss: HitConfirmed=false; RecoveryUntil - AttackWindowClosed debe ser 0.45. La ventana normal sin rival dura aproximadamente 0.10 s desde AttackStartTime, con variación del planificador.
- RecoverySet con RecoveryType=Hit: HitConfirmed=true; RecoveryUntil - AttackWindowClosed debe ser 0.15. En Hit, AttackWindowClosed es el instante de confirmación y cierre temprano, no el plazo máximo teórico.
- ServerRejected: por ejemplo OnCooldown, RequestScopeMismatch o MatchNotPlaying; no crea nuevo AttackId ni nueva ventana. Un rechazo durante una ventana conserva WindowPending=true y no inventa un deadline de 0.05 s.
- ClientBlocked: input detenido localmente; no se envió otra solicitud.
- FeedbackIgnored: acuse de otra petición/vida/ronda o ya superado. No cambia recuperación.
- AttackCancelled: registro invalidado/desacoplado.
- [SlapService] AttackError: excepción, como máximo una advertencia por jugador cada 5 s; conserva protección finita si el ataque seguía vigente.

Los tiempos de recuperación enviados vienen de GetServerTimeNow del servidor; el cliente compara con su estimación del mismo reloj. No compares os.clock de dos procesos.

La traza no imprime cada muestra de hitbox. Con spam extremo el límite puede omitir filas, especialmente ClientBlocked; obtené primero un intento limpio con un solo clic para comparar los plazos.

## Evidencia para devolver

- Output del servidor y de ambos clientes desde el arranque y durante al menos un Miss, un Hit y una nueva vida.
- Confirmación de Studio/InMemory/false y del marcador Protocol=2 en los tres procesos.
- UserId/RequestId/AttackId de cualquier discrepancia, RecoveryUntil y AttackWindowClosed, motivo de rechazo y errores con stack.
- Video breve si aparece una animación sin acuse Started aceptado, si se nota bloqueo extra tras Hit o si el reequipamiento adelanta un ataque.
- Resultado por fila de la tabla: PASS / FAIL / BLOCKED / NOT RUN y número de partidas completadas. No declarar PASS por mirar solamente el código.
- Estado de ActiveMatches después de volver al lobby y tras cerrar la segunda partida.

## Apagar trazas

Después de detener vos la prueba y volver a **Edit**:

~~~lua
local run = game:GetService("RunService")
assert(run:IsStudio() and not run:IsRunning(), "Ejecutar en Edit")
game:GetService("ReplicatedStorage"):SetAttribute("SlapDiagnosticsEnabled", nil)
~~~

No guardar/publicar el lugar solo para apagar este atributo. El agente dejó los diagnósticos deshabilitados y no cerró ni sobrescribió el place.

