# Combat System V1.3 — Fase B implementada

Fecha: 2026-10-18 (America/Buenos_Aires). Estado: lógica aislada y sincronización Edit verificadas; **validación funcional con jugadores pendiente del desarrollador**.

## Resultado y alcance

Se corrigieron las debilidades demostradas en Fase A sin atribuirles retrospectivamente la causa exacta de la prueba manual. No se demostró que aquel servidor hubiera permitido impactos inválidos; esta implementación protege tanto la autoridad como la presentación y añade trazas optativas para esclarecer cualquier fallo residual.

Solo dos fuentes funcionales cambiaron:

- src/server/Services/SlapService.luau.
- src/client/Controllers/SlapController.luau.

También se añadieron tests/CombatSystemV13.spec.luau, tests/tools/combat_v13_files.py, este informe, la guía CombatSystemV13.manual.md, evidencia/logs/builds y un respaldo local de los dos scripts. tests/tools/run_ability_unit_tests.py incorpora tres entradas de fuentes para probar los módulos reales Slap, SlapController y Combat.

No se modificaron Config, CombatService, KnockbackService, RagdollService, AbilityService/Registry ni las cinco habilidades, Shop, EliminationService, SpawnService, RoundService, ScoreService, HUD, mapas, assets físicos o persistencia. Los 114 archivos restantes bajo src se verifican contra el manifiesto previo. No se activó XvX ni concurrencia.

## Debilidades corregidas

1. El input no reproduce una animación especulativa. Envía una sola solicitud y espera Started aceptado por el servidor. Un rechazo no anima ni reproduce efectos.
2. Los deadlines y la solicitud pendiente pertenecen a la vida/ronda competitiva del cliente. Quitar, reequipar o sustituir la Tool solo limpia enlaces/track, no la recuperación.
3. Servidor y cliente correlacionan RequestId, AttackId, Character, Generation, SessionId, RoundId y Sequence. Un acuse ajeno u obsoleto no puede liberar el gate ni contaminar la secuencia de una vida nueva.
4. Las excepciones usan el registro capturado por esa invocación, no el registro actual del jugador. Solo la finalización del registro vigente puede establecer recuperación. Se elimina el borrado indiscriminado de cooldowns.
5. La búsqueda verifica identidad/estado después de esperar y vuelve a comprobarlos tras PrepareHit antes de registrar un impacto.
6. Las conexiones del Character anterior se desconectan al enlazar el nuevo. La primera vida/ronda válida no hereda los deadlines anteriores.
7. Se elimina el acuse artificial de “listo en 0.05 s” mientras otro ataque sigue buscando rival.

## Contrato de sincronización (Protocol=2)

La misma pareja PerformSlap/SlapFeedback se conserva. No se crearon nuevos remotes.

Petición: PerformSlap(tool, {RequestId, Character, Generation, SessionId, RoundId}). RequestId es un entero creciente de correlación, no autoriza ataques. Peticiones repetidas o con ámbito distinto se rechazan. El servidor no utiliza timestamps, resultados ni duraciones arbitrarias del cliente.

El servidor genera un AttackId único por ataque aceptado, con sesión y contador del servicio. Su registro contiene Character/generación, objeto de sesión/RoundId, Stage, StartTime y recuperación. El contador se comparte dentro del servicio para evitar colisiones entre jugadores, incluidos UserId negativos de Studio; no se transforman UserIds.

Respuesta privada SlapFeedback:

| Campo | Significado |
| --- | --- |
| Protocol=2 | Versión de contrato; cliente/servidor deben actualizarse juntos. |
| Sequence | Secuencia creciente de emisiones del servidor por Player. |
| RequestId | Petición a la que responde; no se cambia por un intento posterior. |
| AttackId | Identidad autoritativa del ataque aceptado. Rechazo previo a aceptación puede no tenerlo; OnCooldown puede referenciar el ataque que bloquea. |
| Character, Generation, SessionId, RoundId | Ámbito original de la respuesta/registro, nunca sustituido por el ámbito nuevo al finalizar una operación vieja. |
| Phase=Started | Accepted=true, ventana reservada. Única fase que reproduce Swing, una vez por petición vigente. |
| Phase=Result | Accepted=true, resultado del ataque aceptado: Hit/Miss, Hit booleano y recuperación. |
| Phase=Rejected | Accepted=false; no se creó un nuevo ataque. Reason explica el rechazo. |
| Phase=Cancelled | Operación aceptada anteriormente pero obsoleta; no modifica el registro nuevo. |
| WindowPending | El bloqueo corresponde a una ventana todavía activa; no equivale a cooldown vencido. |
| AttackStartTime | Inicio aceptado, expresado en tiempo replicable de servidor. |
| AttackWindowClosed | Cierre real de búsqueda/confirmación del Hit, en el mismo reloj. |
| RecoveryUntil / ReadyAt | Deadline de recuperación confirmado; ReadyAt es alias. Ausente mientras la ventana sigue pendiente. |
| Outcome, Hit, Reason | Resultado Hit/Miss, confirmación y motivo de fallo/rechazo/error. |

Una respuesta tardía primero debe coincidir con la solicitud pendiente y su ámbito; después se compara Sequence. Así, un mensaje viejo con número alto no puede bloquear una nueva vida. Un Result adelantado por reordenamiento cierra la petición; su Started tardío no reproduce una animación pasada.

## Recuperación y tiempos

Los valores continúan en Config.Combat.SlapCombo: ventana 0.10 s; muestras hasta cada 0.025 s; Hit 0.15 s; Miss 0.45 s. Tool.SlapCooldown=0.6 sigue siendo el fallback cuando SlapCombo.Enabled=false.

- Hit: empieza inmediatamente después de que RegisterHit acepte el contacto. La ventana termina temprano al primer impacto válido. No se añade un timer artificial para la animación ni para el siguiente ataque.
- Miss: empieza cuando termina la ventana sin rival válido. En el caso normal el siguiente inicio se permite aproximadamente 0.10+0.45 s después del anterior; un task.wait puede reanudarse más tarde, nunca se acorta la penalización.
- Si falla la validación final del contacto o hay error antes de un Hit confirmado, se cierra con recuperación segura de Miss desde ese cierre.
- Si una excepción ocurre después de confirmar Hit y fijar su recuperación, la finalización idempotente conserva Hit y el deadline existente.
- El servidor compara os.clock solo dentro de su proceso. Envía deadlines calculados con GetServerTimeNow; el cliente usa su estimación de ese mismo reloj.
- El cliente nunca reduce un deadline vigente por recibir otro acuse. Started no le impone una recuperación provisional de Miss que retrasaría los Hits.
- La espera de red de 2 s es un límite de reintento de transporte; no crea un Hit ni reproduce una animación. Un acuse de una petición vencida se descarta.
- La animación espera un viaje de respuesta real del servidor. Esto evita representar peticiones rechazadas, pero la sensación de latencia requiere validación humana. No se afirma latencia cero.

## Vida, ronda, errores y limpieza

El registro autoritativo pasa de Window a Recovery una sola vez. _finishAttack comprueba referencia exacta y estado Window antes de escribir. Un error antiguo conserva su propio registro en un holder local, por lo que no finaliza ni borra el del nuevo Character o ronda.

Durante la búsqueda se revisan Character, generación, Player conectado, Tool equipada, Health, PlatformStand, MovementLocked, Pending y ronda abierta. PrepareHit puede ceder el hilo; se revalida antes del efecto competitivo.

Una nueva petición elimina el registro anterior si cambió sesión/Character/generación/RoundId, y así no hereda cooldown de la vida anterior. El cierre normal con RemoveMatchPlayers desacopla el registro solo si corresponde a esa sesión. PlayerRemoving limpia registro, IDs de petición, secuencia y presupuestos de diagnósticos. Una ventana pendiente que pierde estado válido se cierra en su siguiente reanudación.

No se añaden tareas por cooldown ni Heartbeats nuevos. Un registro de recuperación ya terminado puede conservarse hasta la próxima petición/limpieza del jugador; no contiene callbacks ni conexiones. No se modificaron los dueños de ciclo de vida de RoundService/SpawnService.

En cliente, los remotes existentes StateChanged y Countdown aportan el estado competitivo y el RoundId/RoundIndex. Se filtran StateVersion e índices antiguos; una ronda resuelta no se reabre por un snapshot sin resolver atrasado. El cambio de vida/ronda/sesión limpia pending y deadline, mientras un reequipamiento de la misma vida los conserva.

## Integración preservada

El cálculo de alcance/cono, selección de rival y knockback no cambió. El Slap sigue llamando RegisterHit una sola vez por ventana y aplicando ragdoll con el argumento existente de 3 s. StrongSlap se prepara antes de RegisterHit, se consume después de aceptarlo y continúa evitando el incremento del combo normal; Miss no consume el armado. Tres impactos normales siguen invocando HandleSlapThreshold.

No se alteran KillPart, deduplicación de eliminación, +50 por Kill, +50 por gol, Death Feedback, los 180 s, Muerte Súbita ni EndCinematic. La conservación por hash y el ejercicio de llamadas en fixtures no sustituyen su regresión funcional real.

## Verificaciones realizadas

| Verificación | Resultado | Evidencia / límite |
| --- | --- | --- |
| Combate cliente/servidor | PASS: 79 aserciones aisladas | CombatSystemV13.test-results.txt y spec.luau. Módulos reales con reloj, red, geometría y servicios externos simulados. |
| Regresión de habilidades | PASS: 164 aserciones aisladas | CombatSystemV13.ability-regression-results.txt. |
| AbilityRegistry | PASS: 89 aserciones aisladas | CombatSystemV13.registry-results.txt. |
| Total | 332 aserciones aprobadas | No hay jugadores ni compras/perfiles reales. |
| Compilación Luau | PASS: 99 archivos | 98 fuentes src y el nuevo spec; CombatSystemV13.compile.log. Compilación, no análisis de tipos Roblox completo. |
| Rojo default | PASS | CombatSystemV13.build.log / build.rbxlx. |
| Rojo SAFE | PASS | CombatSystemV13.safe-build.log / safe-build.rbxlx. |
| git diff --check | PASS: código 0 | CombatSystemV13.git-diff-check.log; advertencias LF/CRLF preexistentes sin cambiar configuración. |
| Integridad de fuentes protegidas/respaldo | PASS: 114 sin cambios y 2 copias íntegras | CombatSystemV13.integrity.json; sin diferencias ni problemas de espacios finales. |
| Studio Edit | PASS de sincronización, no de gameplay | Source y GetEditorSource de los dos módulos coinciden con disco. IsStudio=true, IsRunning=false; diagnósticos OFF. |
| Persistencia | Inspección estática; runtime NOT RUN | Config/resolver fuente iguales al inicio: Studio selecciona InMemory/false. No se inicializó un servidor ni se hizo acceso cloud. |
| Dos clientes reales | NOT RUN | Responsabilidad del desarrollador según guía manual. |

Los tests de combate ejercitan spam de 100 solicitudes en Hit/Miss, deadlines, replay/ámbito inválido, ventana en vuelo, dos UserIds negativos y tres ciclos de spam de ambos jugadores, errores antes/después del Hit y de una vida vieja, cambio de generación dentro de hook, cierre de ronda y ragdoll tras yield. El cliente real se prueba con inputs/enlaces, rechazos sin animación, reemplazo/reequipamiento de Tool, respuestas desordenadas, nueva vida, timeout y eliminación de callbacks antiguos.

CombatService y StrongSlap se ejecutan realmente en la fixture. Los sinks de eliminación, ragdoll y red están simulados: no se declara validación de física Roblox, transacciones de Coins reales ni deduplicación integrada de KillPart por esos tests.

Al ampliar los casos de dos jugadores apareció un fallo por redondeo en la conversión del reloj simulado del cliente. Se corrigió el fixture para situarlo 1 microsegundo después del deadline replicable. Las comprobaciones exactas antes/en el deadline del servidor permanecen; no se cambió balance ni código de producción para hacer pasar el test.

Las primeras ejecuciones de Rojo/diff bajo sandbox encontraron acceso denegado/resolución de working tree. Se repitieron con los mismos comandos fuera de esa restricción y se registran los resultados finales, sin modificar el proyecto ni los permisos/configuración del repositorio.

## Diagnósticos y evidencia de Studio

[SlapTrace] se habilita solo si IsStudio y ReplicatedStorage.SlapDiagnosticsEnabled=true. Viene OFF. Registra como máximo 12 filas por jugador/segundo por lado, sin trazas por muestra/frame. Los errores internos advierten como máximo una vez cada 5 s por jugador con AttackId y error truncado.

Se registran UserId original, RequestId/AttackId, ámbito, tiempos de inicio/cierre, HitConfirmed, RecoveryType/RecoveryUntil y motivo. Los marcadores Protocol=2 en ambos logs de inicio permiten detectar cliente/servidor de versiones distintas.

La sincronización Edit prevalidó Source y EditorSource contra respaldo o fuente nueva y usó UpdateSourceAsync con guardia contra cambios concurrentes. No se crearon objetos, no se cambió ningún atributo de configuración, no se guardó/cerró/sobrescribió el place ni se publicó. No se ejecutaron módulos autoritativos mediante MCP.

CombatSystemV13.edit-evidence.json registra los hashes anteriores, la instalación y la verificación final. PerformSlap y SlapFeedback siguen siendo únicos; Workspace.ActiveMatches tiene 0 hijos en Edit. Power=20, Tool.SlapCooldown=0.6 y Swing del Classic permanecen iguales.

## Matriz funcional pendiente

| Caso con jugadores reales | Estado |
| --- | --- |
| 1v1: matchmaking, voto, countdown y spawn | NOT RUN |
| Miss 0.45 desde cierre, spam y feedback visual | NOT RUN |
| Hit 0.15 y fluidez percibida con red real | NOT RUN |
| Reequipamiento / sustitución si reproducible | NOT RUN |
| Recuperaciones independientes en los dos clientes | NOT RUN |
| Tres golpes, ragdoll, Kill/Death/+50 únicos | NOT RUN |
| StrongSlap y otras habilidades | NOT RUN |
| Respawn/KillPart, primer ataque de nueva vida | NOT RUN |
| Gol, reinicio y Muerte Súbita | NOT RUN |
| EndCinematic, lobby y segunda partida | NOT RUN |
| Aislamiento de persistencia del servidor real de prueba | NOT RUN: comprobar antes de jugar |

Pasos y comandos exactos: CombatSystemV13.manual.md.

## Riesgos restantes y detención

La causa histórica de las palmadas percibidas como spam sigue sin demostrarse. Se corrigieron las debilidades auditadas y las trazas permitirán correlacionar percepción/aceptación/rechazo.

La animación ahora depende de la aceptación del servidor; evaluar RTT real y sincronización perceptiva con sonido/impacto. En pérdida/reordenamiento extremo se descartan acuses vencidos sin recrear animaciones pasadas; el reintento de transporte puede retrasar la respuesta, sin conceder ataques válidos prematuros. Una sesión mixta de Protocol=1/2 no es compatible y debe detenerse, no aplicar un fallback inseguro.

No se cambiaron las reglas de StrongSlap ni se corrigieron posibles problemas ajenos a este alcance. La recuperación tras errores evita ataques gratuitos/bloqueos permanentes del registro; no intenta revertir efectos competitivos que otro servicio ya confirmó.

Se preserva el respaldo en tests/assets/backups/CombatSystemV13, con dos fuentes y manifiestos SHA-256. También se preservaron los respaldos anteriores.

No hubo Play, Run, Team Test, Start Server, control de jugadores, commits, push, publicaciones ni escrituras cloud. **Detenerse hasta la validación manual del desarrollador.**

