# Combat System V1.3.1 — implementación y validación pendiente

Fecha: 2026-10-18 (America/Buenos_Aires). Repositorio: H:/repos-github/SlapDuels-2.0.

## Estado y diagnóstico

**V1.3 no está aprobada.** Resultados humanos recibidos: FAIL spam de fallos; FAIL latencia visual; PASS eliminación por tres golpes; PENDING aciertos, reequipamiento, respawn/nueva ronda y dos clientes. Estos resultados no se sustituyen por tests aislados.

Latencia confirmada en el código V1.3: SlapController reproducía Swing solo al recibir Started del servidor. El viaje de red formaba parte del inicio visual. V1.3.1 reproduce la animación al input elegible y reconcilia su presentación después.

**El origen concreto del spam manual sigue sin demostrar.** No se aportaron las trazas del intento real. Antes de modificar, V1.3 volvió a aprobar 79 aserciones aisladas y sus dos scripts coincidían por hash con Source/GetEditorSource de Studio Edit. Esto muestra el límite de aquellas fixtures, no invalida el FAIL del desarrollador.

| Clasificación solicitada | Evidencia disponible / conclusión |
| --- | --- |
| A: varias solicitudes cliente | V1.3 bloquea input mientras espera o conoce deadline. Un rechazo sin deadline liberaba pending/awaiting sin otro bloqueo provisional; podría permitir nuevas solicitudes si el estado competitivo local seguía atrasado. Ruta fuente comprobable, no causa demostrada del caso manual. V1.3.1 mantiene un piso local tras rechazo y lo prueba. |
| B: varias aceptaciones antes del deadline | No reproducido. El guard Window/Recovery del servidor y los tests deterministas rechazan los intentos prematuros. No se presenta esto como prueba universal de ausencia del fallo real. |
| C: varias animaciones sin ataques válidos | No observado por el agente. V1.3 animaba en Started, una vez por petición. Classic no contiene otro script embebido. Se necesitan Output y video del fallo para atribuirlo a otro origen o versión. |
| D: recuperación local desincronizada | No confirmada en el intento real. Se ejercitaron red desordenada, demoras, timeout, rechazo, Tool y ámbito de vida/ronda. La nueva predicción se reconcilia con identidad propia y sin liberar el input prematuramente. |
| E: otro problema | Classic tiene Power=20 y SlapCooldown=0.6. Con SlapCombo.Enabled=true ese 0.6 es fallback, no la recuperación activa. No demuestra un bypass ni justifica modificar balance. |

## Classic inspeccionado por pedido del desarrollador

MCP, exclusivamente Edit, leyó ServerStorage.Slaps.Classic.Configuration:

- Power: NumberValue, 20.
- SlapCooldown: NumberValue, 0.6.
- Sin atributos en Configuration/Tool y sin scripts embebidos en Classic.
- El clon competitivo sigue siendo sellado por GiveSlap; la plantilla sin IsSlapWeapon no es una inconsistencia.
- ReplicatedStorage.Shared.Config.Combat.SlapCombo: Enabled=true, SwingWindow=0.10, SuccessfulHitRecovery=0.15, MissRecovery=0.45, SampleInterval=0.025.

SlapService valida Tool.Configuration y usa los valores de SlapCombo cuando está activo; si está desactivado, usa el SlapCooldown del Tool. La predicción consulta exactamente ese mismo criterio. No se cambió ninguna de estas propiedades ni Config.

## Cambios funcionales

Solo se modificaron:

1. src/client/Controllers/SlapController.luau.
2. src/server/Services/SlapService.luau.

Cliente:

- Reserva una predicción con AttackId local/PredictionId antes de enviar.
- Reproduce Swing inmediatamente, una sola vez por input admitido.
- Bloquea solicitudes/animaciones redundantes con pending y un deadline provisional separado.
- Reconciliación Started vincula el AttackId del servidor sin repetir la animación.
- Hit/Miss confirmados sustituyen el plazo provisional por el deadline autoritativo; no se mantiene un Miss provisional que retrase un Hit.
- Rechazo cancela la presentación y conserva el bloqueo provisional y cualquier deadline autoritativo posterior.
- Identidad y ámbito descartan acuses tardíos antes de tocar el track, secuencia o cooldown.
- Diagnóstico tolera datos no tabulares sin fallar al intentar registrarlos.

Servidor:

- Conserva la decisión de aceptación y el gate Window/Recovery de V1.3.
- Valida PredictionId acotado y lo devuelve solo como correlación; genera su propio AttackId.
- Añade RequestReceived, tiempos y ventana explícita; AttackStarted muestra también el ataque/deadline anterior para contrastar el siguiente inicio.
- Cambia el marcador/contrato a CombatSystemV131 Protocol=3 para evitar mezclar versiones.

No se cambió el recorrido posterior al impacto: knockback, ragdoll, combo de tres, StrongSlap, Kills, efectos, Coins, habilidades/Registry, Shop, marcador, 180 s, Muerte Súbita y EndCinematic permanecen intactos. No se añadieron remotes, hitboxes físicas, loops, tareas por frame ni acceso a persistencia.

## Flujo de predicción y reconciliación

1. Scope local vigente: Character, ArenaPhysicsGeneration, MatchId y RoundId; estado Playing y movimiento permitido.
2. Si hay recuperación/predicción/petición pendiente vigente, el input retorna sin animación ni red.
3. Se genera PredictionId único en la sesión por UserId original y contador de petición. pending.AttackId identifica esa predicción local; no es un permiso de combate.
4. Se reserva PredictionUntil=instanteInput+SwingWindow+MissRecovery (0.55 s con combo activo) y una espera de transporte de 2 s. No son cooldowns del servidor.
5. Se reproduce Swing y se envía PerformSlap(tool, {RequestId, PredictionId, Character, Generation, SessionId, RoundId}).
6. El servidor comprueba identidad, estado y gate; su AttackId autoritativo solo nace al aceptar. PredictionId no puede autorizar impactos ni indicar relojes, Hit, ragdoll o recompensas.
7. Started aceptado enlaza pending.ServerAttackId. No vuelve a reproducir Swing.
8. Result Hit/Miss válido libera solamente el plazo provisional de ESA predicción e incorpora RecoveryUntil mediante max con la recuperación autoritativa local vigente. Esto permite Hit=0.15 sin esperar artificialmente 0.55.
9. Rejected/Cancelled detiene el track correspondiente, importa un deadline conocido y NO elimina el piso provisional. WindowPending no se traduce en listo dentro de 0.05 s.
10. Solo cambia vida/ronda/sesión legítima o vence el gate. Reequipar/reemplazar Tool no reinicia recuperación. Los callbacks del Character anterior siguen desconectados.

El rechazo puede corregir una animación que ya empezó: es la consecuencia normal de la predicción solicitada. Esa presentación jamás ejecuta RegisterHit, elimina, da Coins ni aplica física.

## Contrato y protección de estados

Protocol=3 en los mismos PerformSlap/SlapFeedback. RequestId y PredictionId identifican la solicitud; AttackId de respuesta sigue siendo exclusivo del servidor. Las respuestas incluyen Phase, Accepted, Character/Generation, SessionId/RoundId, Sequence, Hit/Outcome, Reason, WindowPending, AttackStartTime, WindowUntil, AttackWindowClosed y RecoveryUntil (alias ReadyAt).

La aceptación de feedback exige pending vigente, RequestId y PredictionId coincidentes, ámbito de vida/ronda y Sequence creciente. Si Started ya vinculó ServerAttackId, las respuestas posteriores deben corresponder a él. Result adelantado por reordenamiento no hace que Started tardío vuelva a animar.

Una respuesta rechazada sin deadline no vuelve a habilitar de inmediato el input: el plazo conservador local permanece. Un rechazo nunca borra una recuperación posterior. Al terminar la espera de transporte puede predecirse un reintento si todos los gates vencieron; si el servidor aún bloquea, lo rechaza y se corrige esa nueva predicción. Los acuses de la anterior no la afectan.

El servidor no depende de estos gates visuales y sigue rechazando solicitudes prematuras incluso si el cliente se los salta. Cada registro finaliza una vez y las excepciones de registros antiguos no modifican reemplazos.

Una nueva vida real asignada por el servidor o una nueva ronda conserva la semántica anterior de primer ataque válido sin bloqueo obsoleto. Alterar Character/generación en el payload no crea una nueva vida autorizada y se rechaza. No se trata un simple reequipamiento como respawn.

## Recuperaciones sin cambio de balance

- Ventana máxima normal: 0.10 s de búsqueda autoritativa, con muestras hasta cada 0.025 s.
- Hit: 0.15 s desde RegisterHit aceptado/cierre temprano.
- Miss: 0.45 s desde el cierre efectivo de la ventana sin impacto válido.
- Fallo normal: aproximadamente 0.55 s entre inicios aceptados, sujeto al planificador.
- Deadline de servidor en os.clock de su propio proceso; mensajes usan GetServerTimeNow comparable con el cliente. No se confía en tiempos suministrados por este.
- El siguiente AttackStarted de la misma vida/ronda registra PreviousAttackId y PreviousRecoveryMonotonic; StartMonotonic debe ser mayor o igual a ese deadline.
- HitConfirmed=false antes de Outcome final no prueba que ya terminó un Miss.

## Verificaciones automatizadas

| Verificación | Resultado / evidencia |
| --- | --- |
| Baseline anterior a modificar | 79 aserciones V1.3 PASS aislado: CombatSystemV131.before-test-results.txt. No aprueba V1.3 funcionalmente. |
| Nueva suite combate/predicción | 97 aserciones PASS: CombatSystemV131.spec.luau y test-results.txt. |
| Regresión de habilidades | 164 PASS: CombatSystemV131.ability-results.txt. |
| AbilityRegistry | 89 PASS: CombatSystemV131.registry-results.txt. |
| Total vigente | 350 aserciones aisladas aprobadas. |
| Compilación Luau | 99 archivos PASS: 98 fuentes y la suite nueva; compile.log. |
| Rojo default | PASS: CombatSystemV131.build.log / build.rbxlx. |
| Rojo SAFE | PASS: CombatSystemV131.safe-build.log / safe-build.rbxlx. |
| git diff --check | PASS: código 0; git-diff-check.log. Advertencias LF/CRLF preexistentes, sin cambiar configuración. |
| Integridad | PASS: 114 fuentes/recursos ajenos sin diferencias y dos respaldos íntegros; integrity.json. Sin problemas de espacios finales en los archivos comprobados. |
| Studio Edit | Source y GetEditorSource de los dos módulos igualan sus hashes locales; no se inició simulación. |

Los casos nuevos cubren diez solicitudes repartidas durante los 0.45 s de un Miss sin nueva aceptación, límite justo antes/en deadline, Hit consecutivo, tercer impacto con diez rechazos posteriores, predicción inmediata antes de entregar red, cancelación del track, rechazo con y sin deadline, bloqueo conocido, reordenamiento, Tool nueva/reequipamiento, respawn/ronda y mensajes obsoletos.

La fixture de transporte ejecuta cliente y servidor reales con 200 ms de demora de subida y 150 ms adicionales de entrega de acuses; entrega Result antes de Started y comprueba que no reanima. También retrasa una petición más de 2 s, permite un reintento local y demuestra que el servidor rechaza ese reintento durante MissRecovery sin otra ventana; su rechazo corrige la predicción nueva y el resultado antiguo no borra su deadline.

CombatService y hooks de StrongSlap se ejecutan en fixtures; red, geometría, ragdoll y sinks de eliminación son simulados. La comprobación de tercer umbral/cooldown no reemplaza la validación integrada de recibos, Coins y contactos reales de KillPart. El PASS humano previo de tercer golpe es de V1.3; repetirlo en V1.3.1.

## Trazas y diagnóstico pendiente

Se conserva SlapDiagnosticsEnabled, Studio-only y OFF por defecto, limitado a 12 filas/jugador/segundo por lado. No hay trazas por muestra/frame.

Eventos distinguen ClientRequest/PredictionPlayed de RequestReceived, AttackStarted y ServerRejected. Se añaden PredictionId, CharacterGeneration, RequestTime, WindowUntil y los deadlines anterior/actual. La hora de recepción del servidor es propia; no acepta timestamps arbitrarios del cliente.

Si continúa el FAIL, se necesitan Output de servidor y ambos clientes, un intento limpio y diez clics, video del reinicio real de Swing, todas las identidades de correlación y el siguiente AttackStarted. El límite de logs puede omitir filas bajo spam extremo; no inferir ausencia de ataques por silencio.

Guía con comandos y pasos exactos: CombatSystemV131.manual.md.

## Evidencia de Edit, seguridad y archivos

IsStudio=true e IsRunning=false al inspeccionar y sincronizar. UpdateSourceAsync prevalidó ambos Source y EditorSource contra respaldo/fuente nueva antes de escribir, con guardia adicional ante edición concurrente. No se guardó/cerró ni sobrescribió el place. No se modificaron Configuration, atributos, mapas ni objetos físicos.

Config y PersistenceEnvironment conservan los hashes anteriores. La rama Studio sigue seleccionando InMemory y WritesToCloud=false. Esto es inspección de configuración/fuente: no se inició un servidor para afirmar diagnóstico runtime; la guía exige comprobarlo antes de jugar. No hubo acceso cloud ni requerimientos de módulos autoritativos desde MCP.

Archivos funcionales: los dos indicados arriba. Soporte añadido: tests/CombatSystemV131.spec.luau, tests/tools/combat_v131_files.py, este informe, manual.md, edit-evidence.json, integrity.json, logs y builds. La suite/herramienta V1.3 permanece como evidencia histórica; no se sobrescriben sus resultados.

Respaldo previo: tests/assets/backups/CombatSystemV131 con las dos fuentes, manifest.json y protected.json. Respaldos anteriores preservados.

## Matriz de aceptación humana

| Caso | Estado de V1.3.1 |
| --- | --- |
| Spam de fallos / aceptación real versus animación | PENDING: no declarado corregido en multijugador |
| Respuesta visual inmediata con latencia real | PENDING |
| Hit rápido a 0.15 | PENDING |
| Reequipamiento / sustitución de Tool | PENDING |
| Respawn y nueva ronda | PENDING |
| Dos clientes y segunda partida | PENDING |
| Tres impactos y eliminación única | PENDING: repetir PASS previo de V1.3 |
| StrongSlap, Kill/Coins, efectos, Dash y demás integraciones | PENDING de regresión manual |

No se declara PASS funcional. No se ejecutaron Play, Run, Team Test, Start Server, control de personajes, commits, push, publicaciones ni escrituras cloud. Detenerse y esperar validación del desarrollador.

