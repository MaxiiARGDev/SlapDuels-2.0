# Combat System V1.3 — auditoría de Fase A

Fecha: 2026-10-17. Repositorio: H:\repos-github\SlapDuels-2.0.

## Dictamen

**Existe cooldown por fallo, está configurado y el servidor lo utiliza. No se demostró que el camino normal permita ataques efectivos sin recuperación. La causa concreta de la prueba manual sigue sin confirmar.**

La configuración actual es SuccessfulHitRecovery=0.15, MissRecovery=0.45, SwingWindow=0.10 y SampleInterval=0.025, con SlapCombo.Enabled=true. Un fallo normal se penaliza desde el momento en que termina la búsqueda del rival, no desde el clic: aproximadamente 0.10+0.45=0.55 s entre inicios aceptados, sujeto al planificador. No se debe aumentar el balance para esconder otro problema.

Sí hay debilidades comprobables en el código: animación predictiva sin filtro competitivo local; reinicio de los bloqueos visuales al reequipar; feedback sin correlación a una activación aceptada; y limpieza indiscriminada del cooldown ante excepciones. Su presencia está confirmada por inspección; que hayan ocurrido en la prueba reportada NO está confirmado. Una animación repetida no demuestra un impacto aceptado.

**Fase B no implementada.** No se modificaron scripts, configuración, assets ni objetos de Studio. No se ejecutó Play/Run/Start Server ni pruebas con jugadores.

## Evidencia y límites

- MCP inspeccionó el DataModel Edit abierto: IsStudio=true, IsRunning=false, GameId=10769217377 y PlaceId=107328891970677. Es identificación, no aprobación del universo de producción.
- Los 20 scripts principales auditados coinciden por SHA-256 normalizado entre disco, Source y GetEditorSource. Se normalizaron CRLF y espacios finales solo para comparar; no se escribieron fuentes.
- Entre ellos están Config, SlapService, SlapController, CombatService, KnockbackService, RagdollService, EliminationService, RoundService, SpawnService, PlayerService, PlayerDataService, AbilityService, las cinco habilidades, PersistenceEnvironment y ambos Bootstraps.
- En ServerStorage.Slaps.Classic: Power=20, SlapCooldown=0.6 y Swing=rbxassetid://204062532. No contiene scripts embebidos. Solo se encontró Classic en esa carpeta.
- Remotes.Combat contiene un PerformSlap y un SlapFeedback, ambos RemoteEvent. La búsqueda de referencias al ataque en scripts del DataModel encontró SlapController y SlapService.
- Se detectó además un Config de un TestHarness preexistente en ServerStorage. No es ReplicatedStorage.Shared.Config ni la ruta requerida por los servicios auditados; se preservó sin ejecutar ni borrar.
- Los perfiles Rojo default y SAFE apuntan a las fuentes correctas. No se reinició Rojo ni se aceptaron sincronizaciones.
- No se conoce la versión que ejecutó la prueba manual anterior, sus tiempos, estado competitivo ni errores. La coincidencia actual no prueba la versión histórica del Team Test.
- IsStudio está observado. Studio/InMemory/WritesToCloud=false está verificado **por el resolver fuente**, no mediante un servidor de juego iniciado para esta auditoría. PersistenceEnvironment.ResolveWithOptions retorna InMemory y false en la rama Studio antes de considerar producción. No se requirió ni inicializó ningún módulo de persistencia, ni se accedió a DataStoreService.
- git status mostró muchos cambios previos, preservados. Los hashes de los 118 archivos bajo src y los dos perfiles de proyecto incluidos en ese total permanecen iguales al finalizar. git diff --check terminó con código 0 al ejecutarlo fuera de la restricción que inicialmente impedía diff; solo advertencias preexistentes LF/CRLF. No se cambió configuración Git.
- No se ejecutaron tests funcionales ni builds en esta fase de inspección. Los PASS de fases anteriores no se reutilizan como evidencia del cooldown.

Evidencia de hashes y modo: CombatSystemV13.audit-evidence.json.

## Archivos y funciones responsables

Las rutas de esta tabla son relativas al repositorio indicado arriba.

| Archivo | Funciones / líneas | Responsabilidad |
| --- | --- | --- |
| src/shared/Config.luau | Combat, 219–225 | Valores de recuperación, ventana, ragdoll y tres impactos. |
| src/client/Controllers/SlapController.luau | _onToolEquipped 59; _onToolUnequipped 87; _onToolActivated 104; Init 160; _bindCharacter 131 | Tool.Activated, animación, petición, bloqueo local y feedback. |
| src/server/Services/SlapService.luau | _ensureRemotes 113; _validateTool 532; _selectOpponent 579; ProcessSlap 673; Start 820 | Única entrada remota, validación, ventana, selección, cooldown, integración de impacto y respuesta privada. |
| src/server/Services/CombatService.luau | RegisterHit 94; ClearCombatTag 245; ClearMatch 253 | Equipos/sesión, CombatTag y contador de impactos por vida/ronda. No administra cooldown del Slap. |
| src/server/Services/KnockbackService.luau | Init/Start vacíos | Placeholder. La física real del Slap no pasa por este servicio. |
| src/server/Services/RagdollService.luau | ApplyRagdoll 42; CancelRecovery 211; RemoveRagdoll 217 | Impulso, derribo, actualización y limpieza de un timer de recuperación. |
| src/server/Services/AbilityService.luau | PrepareHit 210; ConsumeHit 224 | Capacidad de contacto StrongSlap: preparar antes del registro y consumir después del impacto aceptado. |
| src/server/Abilities/StrongSlapAbility.luau | Start; Hooks.BeforeHit/Consume | Arma Golpe Fuerte; no controla recuperación del Slap. |
| src/server/Services/EliminationService.luau | HandleSlapThreshold 353; HandleAbilityHit 369; _processEliminationEvent 386 | Umbral, Golpe Fuerte, KillPart/void, deduplicación, atribución y recibo de eliminación. |
| src/server/Services/PlayerService.luau | AwardConfirmedKill 302 | Coins por eliminación confirmada, transacción Kill:EliminationId. |
| src/server/Services/RoundService.luau | BeginGameplayRound 1101; IsGameplayRoundOpen 1143; CancelGameplayRecoveries 1159 | Ronda vigente, bloqueo por punto/final/cinemática, limpieza de combate y habilidades. |
| src/server/Services/SpawnService.luau | ResetCharacterInArena 427; generación, 463 | Cambio de vida física/respawn que invalida un swing en búsqueda. |
| src/server/Services/ScoreService.luau | _validateScorer 245 | Puntuación independiente; requiere ronda abierta y respawn no pendiente. |
| src/server/Bootstrap.server.luau; src/client/ClientBootstrap.client.luau | carga e Init/Start | Servicio Slap explícito en servidor; controladores por carpeta en cliente. |
| src/server/Abilities/DashAbility.luau, AirJumpsAbility.luau, DevilSpeedAbility.luau, InvisibilityAbility.luau | Start/Step/Cancel | Movimiento o presentación; no escriben el cooldown del Slap. |
| src/server/Services/Persistence/PersistenceEnvironment.luau | ResolveWithOptions 39–50 | Selección Studio aislada. |

## Recorrido real de una palmada

| Paso | Componente y comportamiento real |
| --- | --- |
| 1. Input | Tool.Activated llama _onToolActivated. No hay una hitbox de contacto Tool.Touched. |
| 2. Cliente | Compara GetServerTimeNow con _localNextSlapTime y _awaitingUntil. Si permite, espera respuesta hasta 2 s, reproduce Swing a velocidad 1.2 y envía PerformSlap(tool). No calcula Hit. |
| 3. Estado competitivo | ProcessSlap exige Character vigente en Workspace, vivo, sin ArenaRespawnPending ni PlatformStand; Tool sellada/equipada y configuración válida; sesión Playing y IsGameplayRoundOpen. |
| 4. Inicio autoritativo | Compara os.clock() con _cooldowns[player]. Si está bloqueado retorna OnCooldown. Si acepta, escribe math.huge antes del primer task.wait. |
| 5. Ventana | Captura Character, ArenaPhysicsGeneration y GameplayRound.Id. Busca de inmediato y luego cada hasta 0.025 s, hasta 0.10 s. No crea una Part hitbox; usa posiciones/cono. |
| 6. Rival | _selectOpponent recorre participantes autoritativos del equipo contrario, vivos/conectados y de la misma sesión; excluye respawn. Alcance máximo 9 studs y producto frontal >= -0.2. Prioriza distancia, Slot y UserId. No hace raycast de oclusión. |
| 7. Miss | Si acaba sin rival válido, guarda os.clock()+0.45 y retorna false con motivo. No registra tag, contador, eliminación ni recompensa. |
| 8. Hit | Si hay candidato, reserva recuperación de fallo mientras valida; PrepareHit prepara ticket opcional y RegisterHit valida y acepta. Solo al aceptar cambia el deadline a os.clock()+0.15. |
| 9. Efectos | Sonido Hit; consume StrongSlap si corresponde; si no, tercer impacto va a eliminación; si tampoco, aplica impulso y ragdoll de 3 s. Máximo un candidato/registro por invocación. |
| 10. Respuesta | Start genera Sequence por solicitud y envía SlapFeedback privado: Character, Generation, SessionId, RoundId, Hit, Reason y ReadyAt en tiempo de servidor. No es un AttackId dedicado. |
| 11. Cliente | Comprueba Character/Generation/MatchId, Sequence creciente y ReadyAt numérico. Libera espera y copia ReadyAt. No comprueba RoundId ni distingue rechazo de swing aceptado. |
| 12. Nuevo ataque | No hay timer que desbloquee el Slap. El siguiente ProcessSlap vuelve a comparar reloj y deadline. Rechazos OnCooldown normales no escriben el deadline. |

Ejemplo lógico, no medición de gameplay: inicio t=10.000; ninguna víctima; cierre aproximadamente t=10.100; RecoveryUntil aproximadamente 10.550. Solicitudes durante búsqueda o antes de 10.550 no deben alcanzar _selectOpponent. Un acierto inmediato puede habilitar aproximadamente 10.150.

Tool.Configuration.SlapCooldown=0.6 se valida siempre, pero solo es el fallback de recuperación cuando SlapCombo.Enabled=false. Config.Combat.SlapCooldown=0.6 no decide la cadencia en ProcessSlap. El log de “Slap exitoso” imprime el cooldown del Tool, por lo que puede mostrar 0.60 aunque se haya usado 0.15; no es evidencia del deadline aplicado.

## Hallazgos: confirmados frente a hipótesis

### Confirmado por inspección

1. **La recuperación de fallo no falta.** La rama de Miss escribe +0.45 después de cerrar la ventana. La de Hit solo escribe +0.15 después de RegisterHit exitoso. Un rechazo de CombatService conserva la recuperación de fallo reservada.
2. **No hay bypass normal por repetir PerformSlap.** Mientras la primera búsqueda cede el hilo mantiene math.huge; las peticiones siguientes retornan OnCooldown antes de buscar/registrar rival. Después del Miss conservan el deadline finito. No hay task.delay del Slap que lo acorte.
3. **El feedback visual puede representar ataques rechazados.** El cliente anima antes de aceptación y no consulta Playing/PointInProgress/ragdoll/respawn. Un rechazo previo a reservar recuperación —por ejemplo MatchNotPlaying sin cooldown anterior— responde ReadyAt≈ahora y permite volver a animar tras la respuesta. Eso no produce hitbox/impacto válido.
4. **Reequipar elimina los bloqueos locales.** _onToolUnequipped pone ambos deadlines locales en cero; _onToolEquipped lo llama al enlazar. No elimina _cooldowns del servidor, pero permite solicitudes/animaciones prematuras si el Tool rebota o se regenera.
5. **Acuse durante búsqueda demasiado corto.** Si llega una segunda petición durante math.huge, la respuesta transforma infinito en ahora+0.05. Como Sequence aumenta por petición, un rechazo más nuevo puede hacer que el cliente ignore la respuesta del primer swing más antiguo. Debilidad de presentación/correlación, no autorización de impacto en servidor.
6. **Errores fallan abriendo el gate.** El pcall del listener, ante cualquier excepción, borra _cooldowns[player] sin comprobar identidad de ataque. Si el error ocurre después de reservar recuperación o incluso después de registrar un impacto, se pierde ese bloqueo. La ruta existe; no hay evidencia aportada de que se ejecutara. No se demostró un payload remoto concreto que la fuerce.
7. **Estado insuficientemente modelado.** Solo hay deadline por Player, no registro AttackId/vida/ronda. La búsqueda sí captura Character/generación/RoundId, pero el cooldown completado no queda asociado a ellos. Se limpia en Init/PlayerRemoving, no explícitamente en nueva vida/ronda/cierre.
8. **Validación post-yield incompleta.** La búsqueda revisa identidad, generación, Tool y ronda, pero no repite Health/PlatformStand/Pending del atacante después de cada espera. Puede haber una transición de estado mientras busca. No se observó un impacto en esa transición.
9. **Feedback tardío de ronda.** El payload contiene RoundId pero el cliente no lo valida. El listener obtiene SessionId/RoundId al responder, no del inicio. La generación protege muchos respawns, pero no equivale a un contrato de ataque correlacionado.
10. Las conexiones ChildAdded/ChildRemoved antiguas del Character no se desconectan explícitamente en _bindCharacter. Es deuda de ciclo de vida del cliente; no prueba de solicitudes duplicadas en la prueba actual.

### Hipótesis que requieren evidencia

- La prueba percibió animaciones repetidas fuera de Playing, durante un bloqueo competitivo o tras reequipamiento.
- 0.45 s se percibe como ataque continuo sin una medida de intervalos.
- Hubo InternalError/SwingInvalidated durante las peticiones.
- La prueba anterior ejecutó otra versión o configuración. Las fuentes actuales coinciden; esa coincidencia no prueba ni descarta la versión histórica.
- Hubo acuses fuera de orden. Se necesita la secuencia temporal, no solo capturas visuales.

**No se identifica como causa confirmada** una carrera que permita saltarse la rama normal de Miss con clics consecutivos. Tampoco se atribuye el fallo a Dash, StrongSlap, red o Rojo sin una traza que lo demuestre.

## Compatibilidad y riesgos

- Ragdoll: Slap usa 3.0 s; el valor 5.0 de Config.Ragdoll.DefaultDuration es para otros usos, no contradice ese argumento explícito. ApplyRagdoll cancela el timer anterior, actualiza deadline, cancela movimiento de habilidad y usa identidad/generación/sesión para recuperar. No tocarlo para arreglar el cooldown.
- Tres palmadas: RegisterHit suma solo tras validaciones y reinicia el contador por SessionId/RoundId/Character/Generation. Miss/OnCooldown no llegan a ese incremento. El tercer Hit llama HandleSlapThreshold y comparte eliminación/deduplicación; un swing no registra tres veces.
- Golpe Fuerte: Start solo arma; PrepareHit produce ticket con SkipComboCount=true y ConsumeHit ocurre tras RegisterHit aceptado. Miss no consume ticket ni habilidad. Debe conservarse la recuperación de acierto y el consumo único. Riesgo existente: si se preparó ticket con SkipComboCount y luego ConsumeHit falla, se sigue la ruta normal sin haber sumado ese impacto; no se demostró en ejecución. No refactorizar esta regla incidentalmente.
- Dash/AirJumps/Speed: no controlan el cooldown del Slap; sus movimientos cambian geometría del impacto. Ragdoll/Elimination cancelan habilidades. No modificar su física/compra/duración para resolver esta auditoría.
- Invisible: presentación, sin cambio de colisión/hitbox autoritativa.
- Respawn/KillPart: Pending y generación protegen entrada/búsqueda; falta una limpieza explícita por AttackId y vida para el cooldown. Mantener quiet retirement de 500 ms y transacción de eliminación.
- Muerte Súbita: IsGameplayRoundOpen protege el plazo; caída puede resolver ronda, pero SlapThreshold/StrongSlap no se convierten en gol de caída. No cambiar puntuación.
- Reinicio/EndCinematic: ronda cerrada, PointInProgress, GameplayFrozen y sesión terminal bloquean impactos. CancelGameplayRecoveries limpia habilidades/ragdoll, no el estado de Slap explícitamente.
- Coins: solo la eliminación confirmada acreditada pasa por AwardConfirmedKill y transacción única. Miss o rechazo de Slap no tiene ruta directa a Coins. Mantener +50 por Kill y +50 por gol independientes.

Estas son comprobaciones de rutas fuente, no PASS de jugabilidad.

## Corrección mínima propuesta, todavía NO autorizada

No cambiar Config ni balance. No sustituir hitboxes, combate, ragdoll, economía o habilidades.

1. En SlapService, encapsular el deadline y búsqueda actuales en un registro por Player con AttackId único, Character, generación, SessionId y RoundId. Reservarlo antes de cualquier yield. Un rechazo no crea otro registro ni otra ventana.
2. Una sola finalización idempotente valida que sigue siendo el registro vigente y establece Hit=impacto aceptado o Miss=ventana cerrada sin impacto. MissRecovery empieza inequívocamente al cierre; HitRecovery al impacto aceptado. Mantener la política actual de fallo ante rechazo final de CombatService.
3. Sustituir el borrado global en excepciones por cierre protegido de ese registro. Si sigue vigente, conservar una recuperación segura; si es obsoleto, no tocar el nuevo. No convertir error en autorización inmediata ni fabricar Hit.
4. Revalidar estado del atacante después de cada yield y antes de RegisterHit. Cancelar el registro obsoleto al cambiar vida/ronda, cerrar/abandonar o desconectar. La limpieza debe invalidar el token antes de devolver control. Integrar una llamada pequeña al ciclo de vida existente solo si no basta observar las identidades desde SlapService.
5. En SlapController, separar petición pendiente, ataque aceptado y rechazo; correlacionar respuesta con RequestId/AttackId y ámbito de vida/ronda, rechazar feedback tardío y no reiniciar recuperación por un simple reequipamiento. El servidor genera/valida el AttackId; un identificador cliente sirve únicamente para correlación.
6. Preservar respuesta inmediata predictiva, pero filtrar estados competitivos locales conocidos y mantener bloqueo hasta respuesta coherente. Un rechazo no debe acortar una recuperación vigente. La autoridad sigue siendo del servidor.
7. Primero instrumentar de forma optativa el flujo real para confirmar el caso reportado y comprobar el arreglo. No habilitar trazas por defecto.

**Cliente y servidor requieren endurecimiento**, con SlapService y SlapController como alcance mínimo. Config ya es suficiente. Una integración de limpieza podría requerir una llamada puntual desde RoundService/SpawnService; se debe revisar y autorizar su alcance antes de implementarla. No hay motivo demostrado para modificar CombatService, KnockbackService, Shop, habilidades, EliminationService ni HUD.

## Diagnóstico necesario antes de atribuir la causa

No se añadió instrumentación funcional en Fase A. AbilityDiagnostics existente no registra el recorrido Slap; activarlo no reemplaza esta evidencia.

Proponer flag Studio-only apagado por defecto, por ataque/rechazo limitado, sin logs por frame. Registrar:
UserId original (incluidos negativos), SessionId, RoundId, Character/generación, RequestId, AttackId, AttackStartTime, HitConfirmed, AttackWindowClosed, RecoveryType, RecoveryUntil y RejectionReason. Agregar hora monotónica del servidor y tiempo replicable para comparar; no restar os.clock de cliente y servidor.

Eventos: ClientInput/ClientBlocked, ServerRejected, AttackStarted, HitConfirmed, WindowClosed, RecoverySet, FeedbackReceived y AttackCancelled. Una fila al cierre, no por muestreo. Para rechazos antes de aceptar, AttackId puede ser nil y se conserva RequestId; no inventar un ataque.

Evidencia humana necesaria: modo local/Team Test, versión, Output servidor y cliente completos del intervalo, errores [SlapService] Swing error, si estaba Playing con countdown acabado, clics con timestamps y video que permita separar swing visual de hit/sonido/ragdoll. No hace falta iniciar una partida desde el agente.

## Pruebas automatizadas propuestas (no implementadas ni ejecutadas)

Usar módulos reales SlapService/SlapController con reloj y planificador controlados; mockear jugadores/ronda/red/física/economía. Los tests existentes GameplayV2.spec.luau comprueban valores de config pero NO ejecutan ProcessSlap ni SlapController para demostrar cadencia.

- Miss: un swing, ventana completa, deadline cierre+0.45; justo antes rechaza y justo en deadline admite. Cero RegisterHit/ConsumeHit/Coins.
- Hit: primer contacto aceptado, deadline impacto+0.15; un solo RegisterHit aunque haya varios rivales/muestras.
- Spam: 100 solicitudes durante búsqueda/recuperación no abren ventanas ni cambian el deadline. Jugadores A/B independientes.
- Contacto al borde: última muestra válida y cierre se resuelven una vez. CombatService rechazado no concede recuperación corta.
- Excepciones antes/después del impacto: no borrar recuperación válida; callback antiguo nunca toca ataque de nueva generación.
- Muerte/ragdoll/respawn/generación/ronda/cierre/desconexión durante espera: ninguna aplicación tardía.
- Cliente: respuesta fuera de orden, RoundId distinto, reequipamiento, timeout de 2 s y rechazo mientras otro swing está pendiente no habilitan spam visual ni acortan deadline.
- StrongSlap: Miss preserva armado; Hit consume una vez, no aumenta combo y elimina una vez; los contactos tardíos no duplican Kill/+50.
- Combo: tres impactos aceptados por vida; Miss/rechazo no suman, nueva generación/ronda reinicia.

## Matriz de regresión preparada

Todos los casos de ejecución están NOT RUN en esta Fase A.

| Prueba | Resultado actual | Criterio para Fase B |
| --- | --- | --- |
| Valores 0.15/0.45/0.10 y rama de cooldown | VERIFICADO ESTÁTICAMENTE | No alterar balance; medir deadlines reales. |
| Mismas fuentes Edit/disco | VERIFICADO: 20/20 hashes | Repetir tras cualquier implementación. |
| Miss repetido en Playing | NOT RUN | Inicio siguiente >= cierre+0.45; sin Hits/Kills/Coins. |
| Hit y combo rápido | NOT RUN | >= impacto+0.15; una víctima por swing. |
| Solicitudes simultáneas/in-flight | NOT RUN | Una ventana; rechazos no cambian deadline. |
| Reequipar y feedback desordenado | NOT RUN | Sin animaciones prematuras ni acuses de otra ronda. |
| Error interno | NOT RUN | Cierre seguro; no puerta abierta a otro ataque inmediato. |
| Ragdoll | NOT RUN | 3 s desde último golpe, sin ataque tardío del derribado. |
| Tercera palmada | NOT RUN | Una eliminación, Kill/Death y +50 únicos. |
| StrongSlap con Miss/Hit | NOT RUN | Miss conserva; Hit consume/elimina una vez, sin combo extra. |
| Dash y otras cuatro habilidades | NOT RUN | Sin regresión de movimiento, input ni selección. |
| Respawn/KillPart y golpe tardío | NOT RUN | Ningún ataque viejo sobre nueva vida; sin duplicar recibos. |
| Gol y Muerte Súbita | NOT RUN | +50 por gol válido, caída SD y resolución únicas. |
| Reinicio, final y EndCinematic | NOT RUN | Sin ataques en cierre/countdown/cinemática. |
| Lobby y segunda partida | NOT RUN | Aislamiento de HUD/feedback y ausencia de estado residual. |
| Persistencia de servidor de prueba | NOT RUN | Antes del test humano: Studio/InMemory/WritesToCloud=false. |

## Entrega y siguiente decisión

Resultado: auditoría terminada, causa de la percepción reportada todavía no establecida; cooldown normal presente y debilidades concretas identificadas. Esperar autorización para instrumentación/corrección de Fase B. No se entrega un “fix aplicado” ni PASS multijugador.

Archivos añadidos en esta tarea: este informe y CombatSystemV13.audit-evidence.json. Las notas técnicas de Lexis se actualizan como memoria de auditoría. Se preservaron los cambios locales anteriores y no se modificó contenido de producción.

