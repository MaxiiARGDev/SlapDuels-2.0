**Ability System Multiplayer Fix V1 — diagnóstico de Dash.** Fecha: 2026-10-17.

**Conclusión:** no se confirmó una causa única del fallo multijugador reportado. Se instaló instrumentación controlada para encontrar el primer corte real de la secuencia. No se declara Dash corregido ni PASS multijugador; no se cambiaron sus valores físicos ni se asumió que las otras cuatro habilidades estén rotas.

**Evidencia inicial y entorno.** Antes de editar, las 97 fuentes del repositorio coincidían con Rojo SAFE, GetEditorSource y Source de Studio Edit, sin diferencias. AbilityRegistry/manifiesto estaban presentes, se registraban cinco habilidades y el Output recuperado incluía Bootstrap con Studio/InMemory/WritesToCloud=false y AbilityController inicializado. Sin embargo, ese Output estaba truncado y mezclaba sesiones previas; no contenía E/solicitud/Start/Step/cancelación del intento fallido. No permite asignarle una versión exacta de Team Test ni identificar el primer punto que falló.

El lugar abierto permanece en Edit, IsRunning=false. Después de instalar el diagnóstico hay 98/98 fuentes iguales entre repositorio, Rojo, Source y GetEditorSource. AbilityRequest y AbilityState son un único RemoteEvent cada uno. Los recursos físicos y el registro conservan cinco habilidades; el helper diagnóstico no es una habilidad ni está en el manifiesto.

Bootstrap inicializa y sella AbilityRegistry antes de cargar/inicializar Shop y luego inicializa AbilityService. Éste reutiliza los Remotes, registra su handler y mantiene una única conexión de Heartbeat. La selección y los cooldowns se indexan por sesión y Player; no hay cooldown global compartido ni transformación de UserId. El derecho inicial a Dash sigue en el inventario existente y no requiere compra.

Test/Test Here separa simulaciones cliente y servidor; Server & Clients crea una sesión de servidor y varios clientes; Team Test es la prueba colaborativa. En Drafts, una prueba individual puede usar un borrador local que no sea todavía la versión compartida de la prueba colaborativa. Estas diferencias justifican comparar el Build ejecutado, pero no prueban que fueran la causa de este fallo. No se enviaron drafts, guardaron versiones cloud ni publicaron cambios automáticamente. Fuentes: [testing modes](https://create.roblox.com/docs/studio/testing-modes), [collaboration / drafts](https://create.roblox.com/docs/projects/collaboration#drafts-mode).

**Archivos inspeccionados.** Se trazaron AbilityController, AbilityCatalog, AbilitySelection, AbilityService, AbilityRegistry, AbilityManifest, AbilityCallbacks, AbilityInputAdapter, DashAbility y MovementGuard; se revisaron Bootstrap, llamadas de RoundService, referencias de MatchInstanceService, propiedad/lectura del inventario y persistencia ya auditadas en V1.3. Se contrastaron las copias de respaldo V1.2/V1.3, los proyectos Rojo y las fuentes reales en Edit. Se leyó el Output existente sin iniciar ni manipular una simulación.

**Flujo de Dash observado en código y diagnóstico disponible.** Todos los puntos siguientes tienen inspección/pruebas aisladas; ninguno tiene todavía PASS de jugabilidad multicliente de esta tarea.

| Paso | Implementación y evidencia prevista |
|---|---|
| 1. Input | Start de AbilityController conecta E y AbilityButton; InputDetected distingue processed/textbox |
| 2. Identificación | _activate consulta AbilityCatalog por el AbilityId seleccionado; CatalogEntryMissing identifica ausencia |
| 3. Transmisión | _send envía identidad de sesión/ronda/vida/generación, dirección y TraceId opcional; RequestSent |
| 4. Recepción | HandleRequest conserva rate limit/tipos; Received o Rejected RateLimited |
| 5. Sesión/jugador | _get resuelve la sesión del Player real; NoSession, AbilitySessionNotPrepared o SessionMismatch |
| 6. Selección | Payload AbilityId debe coincidir con la elección competitiva; SelectedAbilityMismatch |
| 7. Playing | _live y gates de estado conservados; razones de bloqueo/NotPlaying/PointInProgress |
| 8. Vida/generación | LifeChangedResync, LifeIdMismatch, GenerationMismatch y RoundMismatch |
| 9. Cooldown | AlreadyActive o Cooldown, con tiempo restante; no se reinicia al rechazar |
| 10. Registro/propiedad | RegistryEntryUnavailable, ProfileNotReady, NotOwned; Dash usa entitlement gratuito |
| 11. Start | StartBegin y Accepted o motivo de rechazo del callback/ownership |
| 12. Impulso | Dash prepara dirección/ownership en Start y aplica velocidad en Step/Heartbeat; FirstStep y Cancelled |
| 13. Comunicación | Snapshot autoritativo original más resultado diagnóstico privado sólo si está habilitado |
| 14. HUD | El estado sigue llegando por snapshot/revisión; ServerResult no sustituye _payload ni modifica cooldown |

Start no aplica por sí mismo AssemblyLinearVelocity; eso sucede en Step. El límite dt>0,1, barrido de cuerpo, límite de arena y sensores ya existían. Un frame largo o un bloqueo físico puede finalizar la ventana sin desplazamiento; faltan logs para saber si sucedió en la prueba reportada. Tampoco se puede afirmar que el cliente sobrescribiera la velocidad o que fallara ownership sin observar la activación real.

**Cambios, exclusivamente relacionados con diagnóstico.**

1. `src/shared/AbilityDiagnostics.luau` — nuevo helper Studio-only, Build AbilityMultiplayerFixV1, whitelist de datos y presupuesto de 30 líneas por usuario/segundo. Se activa sólo si ReplicatedStorage.AbilityDiagnosticsEnabled=true y RunService:IsStudio(). Entregado apagado; no se crea una vía de activación desde un Remote.
2. `src/client/Controllers/AbilityController.luau` — traza input, envío, cambios de snapshot y resultado privado; añade TraceId sólo cuando está habilitado. Ready identifica versión/lado. El resultado diagnóstico retorna sin cambiar snapshot, revisión, selección o cooldown.
3. `src/server/Services/AbilityService.luau` — razones de rechazo, Ready con registro/Remotes/persistencia, StartBegin/Accepted, primer Step y cancelación. _live devuelve también el motivo, preservando condiciones de aceptación. Los rechazos diagnósticos se limitan a uno cada 0,5 s por jugador; los paquetes extra sólo existen con diagnóstico habilitado. El primer Step se registra una vez por activación.
4. `src/server/Abilities/DashAbility.luau` — guarda StopReason, LastStepDt y MovementApplied para observar la ruta ya existente; no cambia fórmulas ni condiciones de movimiento. Start y Step siguen devolviendo su resultado original.
5. `src/server/Abilities/MovementGuard.luau` — añade razones como retorno secundario/terciario. Distancia segura y ownership conservan sus valores principales, márgenes y decisiones. AirJumps sigue consumiendo los mismos primeros retornos.

Se regeneró studio-safe.project.json para incluir el helper y se reinició únicamente el servidor Rojo SAFE propio en 127.0.0.1:34873 (PID 23104). No es un servidor de juego. En Studio se agregó sólo ReplicatedStorage.Shared.AbilityDiagnostics y se verificaron/actualizaron los cuatro Source existentes. No se modificaron HUD, mapas, personajes, cámaras, Shop, precios, inventario, otros módulos de habilidad ni configuración de persistencia.

La instrumentación registra los identificadores necesarios solicitados, códigos de resultado y observaciones escalares de física: dt, velocidad, distancia, estado de Humanoid y ownership. No vuelca perfiles, nombres, credenciales, payloads arbitrarios ni listas de jugadores. No imprime cada snapshot/per-frame: sólo cambios relevantes, primer Step y cierre. Las claves de presupuesto conservan el UserId original y se liberan al salir/destruir el controlador.

**Qué se preservó.** Dash: ID Dash, nombre Impulso, derecho gratuito, duración 0,2 s, distancia 24 studs, cooldown 11 s. Se mantiene Start(record,direction), selección 5/3, elección/preferencia/propiedad separadas, cancelación por ragdoll/respawn/cierre y cooldown de la misma ronda. No se reintrodujo una tabla fija de habilidades ni se duplicaron Remotes. No hay una corrección física presentada como causa confirmada.

Respaldo de tarea: `H:\repos-github\SlapDuels-2.0\tests\assets\backups\AbilityMultiplayerFixV1`: cuatro fuentes previas y perfil SAFE, con SHA-256. Los 111 archivos de src fuera del alcance se verifican contra su manifiesto. Los respaldos anteriores siguen presentes. No se descartó el Working Tree ni se hicieron operaciones Git destructivas, commits o push.

**Verificación ejecutada.**

| Comprobación | Resultado | Límite |
|---|---|---|
| Activación/regresión | PASS aislado: 164 | Funciones reales con tablas descartables; hereda escenarios V1.3 y comprueba trazas/identidades independientes, ausencia de paquetes con diagnóstico off, FirstStep único y LongFrame |
| Diagnóstico/input cliente | PASS aislado: 22 | Helper real: apagado por defecto, bloqueo fuera de Studio, whitelist/budget; bindings E/móvil y respuesta sin autoridad |
| Selector 5/3 | PASS aislado: 54 | Apertura explícita, confirmación, plazos, aislamiento y cierre |
| Compra/preferencia/selección | PASS aislado: 15 | Playing conserva elección/cooldown; propiedad nueva sólo seleccionable dentro del plazo |
| Shop/economía | PASS aislado: 86 | Precios, compra coherente, insuficiencia, duplicados/concurrencia, equipamiento y otras categorías |
| Remotes Shop | PASS aislado: 31 | Metadatos seguros, precio manipulado, rate limit y reintentos |
| UI Shop | PASS aislado: 23 | Estados, compra pendiente/cierre y snapshots repetidos |
| Registry | PASS aislado: 89 | Cinco contratos, aprobaciones, errores, sellado y proyección segura |
| Presentación/recursos | PASS aislado: 18 | Invisible/restauración y validación de recursos |
| Total | **502 aserciones aisladas** | No simulan físicamente dos clientes reales ni prueban latencia/ownership del motor |
| Compilación Luau | PASS | 98 fuentes src + cuatro archivos de pruebas de esta fase |
| Ambos builds Rojo | PASS | AbilityMultiplayerFixV1.build.rbxlx y .safe-build.rbxlx, con logs |
| git diff --check | PASS | Log correspondiente; se conserva la advertencia habitual LF/CRLF si aparece |
| Whitespace de nuevos/no rastreados | PASS adicional | Archivo file-integrity.json |
| Integridad de protegidos/respaldo | PASS | 111 protegidos sin diferencias, cinco respaldados íntegros |
| Editor y Source actuales | PASS: 98/98 | Comparación SHA-256 normalizada, incluyendo nuevo helper |
| Rojo SAFE | PASS: 98/98 | 143 nodos preservan desconocidos; sin rutas duplicadas |
| Remotes de habilidad | PASS estructural | Uno de AbilityRequest y uno de AbilityState, ambos RemoteEvent |
| Persistencia en Edit | Studio / InMemory / WritesToCloud=false | No establece el proveedor de un Team Test antiguo; comprobarlo al repetir |
| Diagnósticos al entregar | false | Bandera no activada por el agente |
| Workspace.ActiveMatches en Edit | 0 | No es prueba de cierre de una partida ejecutada por el agente |

Las suites nuevas están en tests/AbilityMultiplayerFixV1.*.spec.luau; resultados, evidencias y logs comparten el mismo prefijo. Se ampliaron las fuentes del runner de pruebas; las suites históricas no se reescribieron. Los fixtures adaptados suministran el diagnóstico sin efectos cuando prueban la lógica previa.

**Matriz funcional y pendientes.**

| Prueba real | Estado |
|---|---|
| Dash gratuito inicial con dos clientes | NOT RUN por el agente |
| Primer corte del intento reportado | NO IDENTIFICADO con el Output disponible |
| E/móvil, impulso y cooldown real | NOT RUN |
| Ownership y posible sobrescritura de velocidad | PENDIENTE de FirstStep/Cancelled y vídeo |
| Respawn, cambio de ronda e independencia real | NOT RUN |
| Shop/preferencia y otras cuatro habilidades reales | NOT RUN; no se consideran rotas por inferencia |
| Team Test con Build/entorno confirmados | NOT RUN |
| Sesión publicada/producción | NOT RUN; no publicar ni habilitar persistencia para esta prueba |

Los pasos exactos para dos clientes, activación/desactivación de la bandera y los logs que hay que devolver están en `H:\repos-github\SlapDuels-2.0\tests\AbilityMultiplayerFixV1.manual.md`. Registrar el primer Phase ausente o Reason, no sólo que «no se movió». Si aparece Accepted sin movimiento, comparar FirstStep con Cancelled; una distancia inicial 0 no es prueba suficiente de sobrescritura.

No se inició Play/Run/Team Test/Start Server, no se controlaron personajes ni se accedió a datos reales. No hubo commit, push, publicación, aprobación de Universe ID o activación de cloud. La tarea se detiene para obtener la validación y los logs reales del desarrollador antes de aplicar una corrección funcional no respaldada.
