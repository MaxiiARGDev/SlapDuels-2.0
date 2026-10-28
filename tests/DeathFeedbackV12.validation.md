# Death Feedback V1.2 — física y respawn individual

El desarrollador confirmó manualmente que V1.1 funciona (efectos, atribución, feed, +50 Coins,
animación y aislamiento). Esta entrega no reimplementa esos sistemas.
V1.2: implementación terminada; **validación de jugabilidad PENDIENTE del desarrollador**.
El agente no inició Play/Run/Start Server ni ejecutó suites.

## 1. Auditoría de la caída prolongada

EliminationService validaba la eliminación y llamaba inmediatamente a ResetCharacterInArena.
Ese código NO contiene un retraso de respawn: tampoco tiene una etapa de retirada física,
reserva del Character ni invalidación del lanzamiento anterior. Se limita a borrar velocidades
y hacer PivotTo con el Character bajo su ciclo de simulación normal.
El cliente puede volver a aplicar el lanzamiento recibido mediante StateEvent y task.defer.
StateEvent es UnreliableRemoteEvent y sus paquetes antes solo estaban vinculados a MatchId,
que permanece igual después de una caída individual. Esto demuestra una vía estática para
que una orden de física anterior sobreviva al reset de la misma sesión.

Se corrigió esa carencia de ciclo de vida: retirada inmediata, generación física, un solo
temporizador y rechazo de mensajes de otra generación/Character.
**Sin reproducir la partida no se demuestra cuál de estas carreras produjo cada caída observada.**
Si persiste, los timestamps Retired/Restored y el primer contacto aceptado permitirán distinguir
contacto tardío de simulación/replicación posterior al contacto. No se afirma un PASS funcional.

La ruta histórica Workspace.Levels.Geometry.KillPart no existe en el Edit inspeccionado.
Se encontraron Workspace.MapaPlantilla.Geometry.KillPart y
ServerStorage.Maps.Levels.Geometry.KillPart. No se movieron ni modificaron.
EliminationService conecta exclusivamente InstanceInfo.KillParts de la arena clonada;
los Touched de otra geometría no se aceptan como eliminación de esa sesión.
Ambos sensores inspeccionados son Anchored=true, CanCollide=false, CanTouch=true.
Los spawns de ambas geometrías están anclados, colisionables y horizontales.
No se encontraron scripts de muerte adjuntos a esos sensores.

## 2. Auditoría del salto/impulso

Son riesgos distintos de la caída:

- ResetRagdollImmediate forzaba GettingUp y el cliente también lo forzaba al recibir recuperación.
- Humanoid.Jump no se limpiaba y no había control acotado de una entrada de salto mantenida.
- La recuperación forzaba HumanoidRootPart.CanCollide=true en servidor y cliente,
  sin restaurar el valor anterior. El Rig R6 de Edit tiene ese valor false y HipHeight=0.
- Los paquetes/defer de lanzamiento de una vida anterior podían asignar de nuevo velocidad
  lineal/rotacional después del teleport.

Se corrigieron esas rutas estáticas. La contribución exacta del motor GettingUp, entrada mantenida,
colisiones y latencia al salto observado sigue siendo una **hipótesis pendiente de comprobación manual**.
No se cambió globalmente JumpPower/JumpHeight ni se aplicó fuerza ascendente.

KnockbackService es un placeholder; SlapService aplica el lanzamiento por RagdollService.
RagdollService es el propietario activo de constraints/timers. El RagdollModule antiguo está
desconectado (RagdollHandler mantiene ragdollModule=nil); no se activó ni reemplazó.
Humanoid.Died del match es diagnóstico pasivo. CharacterAdded no vuelve a registrar una caída.
Players.CharacterAutoLoads=true y RespawnTime=3 permanecen intactos: el match sigue Zero-Death
y no llama LoadCharacter para estas eliminaciones. La recarga nativa de lobby continúa separada.

## 3. Archivos modificados

- src/shared/Config.luau
- src/server/Services/EliminationService.luau
- src/server/Services/SpawnService.luau
- src/server/Services/RagdollService.luau
- src/character/RagdollStatesHandler.client.luau
- src/server/Services/CombatService.luau (solo exclusión de participantes retirados)
- src/server/Services/SlapService.luau (solo exclusión de participantes retirados)
- src/server/Services/ScoreService.luau (solo rechazo de un Character retirado)
- src/server/Services/RoundService.luau (solo cancelar respawn individual al iniciar PointRestart)

Nuevos:

- src/shared/ArenaRespawnPolicy.luau
- src/server/Services/Respawn/ArenaRespawn.luau
- src/character/ArenaRespawnGuard.client.luau
- tests/DeathFeedbackV12.spec.luau
- tests/DeathFeedbackV12.edit-evidence.json
- tests/DeathFeedbackV12.validation.md

No se cambiaron los servicios de efectos/monedas, HUDs, partículas, preferencias,
EndCinematic ni sus cámaras. El hook de RoundService no modifica el código cinematográfico.

## 4. Configuración

Ruta Studio: ReplicatedStorage.Shared.Config > Respawn.KillPartDelayMs.
Fuente: src/shared/Config.luau.

Valor predeterminado: **500 milisegundos**.
Respawn.MaxKillPartDelayMs=10000 fija el máximo aceptado.
Se permiten 0, 250, 500 y 1000 ms. Negativos, valores no numéricos, NaN o infinitos
se normalizan explícitamente a 0 con warning. Fracciones se truncan; exceso se limita al máximo
y se avisa. Un máximo inválido también normaliza a 0 con warning.
La conversión /1000 se realiza al programar task.delay, descontando el trabajo ya transcurrido
desde la confirmación/retirada. 0 significa siguiente oportunidad del scheduler, no tiempo negativo.
La replicación y carga del motor pueden añadir latencia visible; no se promete precisión de reloj cliente.

El parámetro solo gobierna KillPart durante Playing. No cambia StartCountdown,
PointRestartCountdown, MapSelection, duración de match, EndCinematic ni retorno.
VoidBoundary y estados no jugables conservan su política de recuperación previa.

## 5–9. Flujo resultante y coordinación

1. EliminationService valida contacto/arena/víctima, captura impacto, atacante y EliminationId.
2. SpawnService retira inmediatamente el Character: toma propiedad de red cuando es posible,
   ancla la raíz, limpia velocidades, cancela ragdoll sin GettingUp, oculta cuerpo/accesorios,
   apaga colisiones/sensores y deja ArenaRespawnPending=true.
3. El mismo flujo de V1.1 registra Kill/Deaths, acredita Coins y publica el evento una vez.
   ImpactCFrame ya está capturado. Los modelos VFX son clones locales independientes del Character.
4. Un temporizador único conserva Session, StateVersion, Character y generación física.
   Al vencer exige jugador conectado, mismo participante/sesión/Character/generación, Playing,
   sin cierre, congelación ni punto en progreso.
5. SpawnService resuelve el spawn del participante en la arena clonada. Usa altura de rig
   R6/R15 y posición exacta de raíz, independientemente del pivot del Model.
   Valida solapamiento de las partes corporales con geometría sólida; no ignora paredes.
   Un spawn inválido produce diagnóstico y usa la cancelación de sesión existente, sin inventar coordenadas.
6. Borra velocidades, limpia Jump, restaura propiedades visuales/físicas y propiedad de red,
   recupera Running y devuelve control. No destruye ni reemplaza el Character ni su Player.
   El cuerpo permanece oculto durante la espera, no suspendido visiblemente sobre el sensor.

Mientras está retirado no puede recibir/dar golpes ni anotar por un evento residual.
Los Touched de KillPart/VoidBoundary comprueban además proximidad actual al sensor:
un callback que quedó en cola antes del teleport no vuelve a eliminar a quien ya está en su spawn.
Los incrementos de estadísticas y recompensas siguen en su autoridad original, fuera del temporizador.
No hay un segundo sistema que vuelva a confirmar o premiar la eliminación.

El temporizador obsoleto solo limpia su propia reserva; nunca teletransporta un Character nuevo.
PointRestart cancela la espera individual y entrega el personaje al flujo de reposicionamiento.
UnbindMatch cancela reservas antes de que el cierre capture los estados de los personajes.
TeleportCharacterToSpawn y ResetCharacterInArena consumen/cancelan la reserva como propietarios
explícitos; el temporizador ya no puede intervenir después.
CharacterRemoving/CharacterAdded/cambio de MatchId/desconexión cancelan operaciones de la instancia
anterior. Los listeners de jugador son únicos y se desconectan al retirarlo.

ArenaPhysicsGeneration cambia en retirada y teleport. Los paquetes de RagdollService incluyen
generación e identidad exacta del Character. El cliente y su callback diferido rechazan paquetes
viejos, de otro Character o recibidos mientras está retirado. Los timers de ragdoll se cancelan
y comprueban generación.

RagdollService restaura el valor original de colisión de la raíz en lugar de imponer true.
La recuperación individual usa modo quietRespawn, sin GettingUp.
ArenaRespawnGuard limpia Jump y desactiva temporalmente Jumping/AutoJump durante esta operación.
Es necesario hacerlo también en cliente: SetStateEnabled no replica sus cambios entre
servidor y cliente, según la [documentación de Humanoid](https://create.roblox.com/docs/reference/engine/classes/Humanoid).
La entrada residual de Space/ButtonA o del JumpButton táctil se descarta hasta su liberación.
Después se restablece la capacidad de salto en una frontera PreSimulation, sin temporizadores
arbitrarios adicionales. La revisión de respawn persistente cubre también 0 ms, cuando el booleano
Pending puede quedar coalescido por replicación.
No se crean botones ni se modifica el diseño de los HUDs.

No hay CharacterAdded durante este respawn normal: conservar el mismo Model evita cancelar
los efectos de DeathFeedback que ya fueron validados. Una sustitución externa sí invalida la reserva.
Los valores propios de saltos/preferencias se restauran; la regresión táctil/gamepad queda pendiente.

## 10–11. Inspección Edit y comprobaciones estáticas

MCP confirmó Edit y presencia del código de configuración, lifecycle, integración, cancelación
de punto, guard de entrada y rechazo por identidad. Los valores +50 por Kill y por gol siguen presentes.
No se ejecutaron los servicios ni se crearon personajes para comprobarlo.

Se detectó una copia idéntica del nuevo LocalScript ArenaRespawnGuard en StarterCharacterScripts.
Para evitar dos guards concurrentes se conservó una activa y se movió la copia, desactivada, a:
ServerStorage._DeathFeedbackV12_EditArchive.ArenaRespawnGuard_duplicate_2.
No se borró su fuente. Solo se conserva como respaldo de Edit, fuera de ejecución.
También se observaron dos ModuleScripts idénticos DeathEffectService ya existentes;
no se modificaron por pertenecer a V1.1 validado. Bootstrap selecciona un único módulo por nombre.

- rojo build default.project.json --output "$env:TEMP/SlapDuels-DeathFeedbackV12.rbxlx":
  **PASS estático**, exit 0.
- git -c core.safecrlf=false diff --check: **PASS estático**, exit 0.

Build comprueba empaquetado, no ejecución Luau ni física.
La suite aislada preparada comprueba normalización, identidad/estado/generación, reserva única,
cancelación y ausencia de transporte del Character sustituto. **No se ejecutó.**
No se guardó, cerró ni sobrescribió el lugar con sus cambios artísticos.

## 12–13. Pruebas manuales exactas

1. En Edit abrir ReplicatedStorage > Shared > Config y buscar Config.Respawn.
   En el repositorio cambiar el mismo campo en src/shared/Config.luau para mantener Rojo alineado.
   Establecer sucesivamente KillPartDelayMs=0, luego 250, 500 y 1000.
   Guardar localmente tus cambios. No modificar Players.RespawnTime para esta prueba.
2. El desarrollador inicia servidor local con dos clientes (tercero en lobby si es posible).
   Antes de jugar confirmar Studio/InMemory/WritesToCloud=false en Output servidor.
3. Entrar a plataformas Red/Blue de 1v1, votar mapa y esperar Playing.
   Usar el KillPart de la arena activa, no el modelo de edición MapaPlantilla.
4. Caída normal: esperar más de LastHitLifetime (10 s actuales) sin golpes y caer.
   Desde Retired debe desaparecer el cuerpo y detenerse la raíz, sin seguir cayendo.
   El VFX y la notificación deben continuar. Debe reaparecer una sola vez después del intervalo.
   No debe sumar Kill ni Coins por Kill.
5. Kill: golpear y tirar al rival dentro de la ventana de atribución.
   Confirmar una sola Kill, Deaths según regla previa y +50 Coins al atacante,
   su animación de monedas y el efecto de la víctima. El temporizador no concede otro premio.
6. Para 1000 ms observar la espera completa: cuerpo invisible, sin sombra/nombre colgante,
   sin control de Slap/puntuación y partículas vivas hasta su duración normal.
   Comparar ElapsedMs entre Retired y Restored, no contra el reloj visual del cliente.
7. Probar reaparecer sin tocar salto; después mantener Space/ButtonA/JumpButton durante la caída.
   Al reaparecer no debe saltar automáticamente. Soltar y volver a presionar:
   el salto legítimo posterior debe funcionar. Repetir con AutoJump móvil según tus preferencias.
8. En el servidor inspeccionar HumanoidRootPart en el primer frame disponible de retorno:
   sin velocidad angular y sin pico de velocidad Y positiva. La gravedad o un salto legítimo
   posterior no deben confundirse con un impulso residual de la vida anterior.
   Confirmar orientación del equipo, pies sobre suelo y sin intersección.
9. Buscar un único Retired y un único Restored para el mismo EliminationId.
   Contactos de varias extremidades no deben aumentar contadores ni repetir respawn/feed/premio.
10. Con demora 1000, hacer que el otro jugador anote durante la espera.
    Debe registrarse Cancelled PointRestart y el flujo de ambos equipos continuar con sus tiempos
    originales. No debe aparecer un Restored del timer antiguo después de reposicionarse.
11. Con una espera pendiente provocar fin de partida/abandono o desconexión.
    Debe cancelarse sin transportar avatares nuevos, afectar EndCinematic ni dejar reservas/cuerpos.
    Repetir una segunda partida para detectar eventos anteriores.
12. Anotar un gol sin Kill simultánea: +50 Coins por punto y marcador/reinicio habituales.
    Comprobar aislamiento con el cliente de lobby y preferencias/HUDs sin cambios.

Output a recopilar ante fallo: servidor y cliente completos, SessionId, EliminationId,
ArenaPhysicsGeneration, ArenaRespawnRevision, Pending y logs [ArenaRespawn] Retired/Restored/Cancelled,
[SpawnService], [EliminationService], [RagdollService], [DeathEffectService], crédito de PlayerService;
valor de DelayMs, tipo de rig, estado de Humanoid, Jump, raíz/velocidades, input mantenido y vídeo si es posible.
Un warning Unsafe spawn overlap debe incluir el spawn y la parte corporal indicados;
no cambiar el mapa a ciegas ni sustituir el Character para ocultarlo.

| ID | Comprobación | Estado |
|---|---|---|
| A1 | Caída normal, una eliminación | PENDIENTE manual |
| A2 | Kill válida, una eliminación | PENDIENTE manual |
| A3 | Ambas rutas usan 0/250/500/1000 ms | PENDIENTE manual; política preparada |
| A4 | Caída se interrumpe al confirmar | PENDIENTE manual |
| A5 | Sin velocidad vertical heredada | PENDIENTE manual |
| A6 | Sin velocidad angular heredada | PENDIENTE manual |
| A7 | Sin salto involuntario; salto nuevo válido | PENDIENTE manual |
| A8 | Spawn/orientación/solapamiento correctos | PENDIENTE manual |
| A9 | Multicontacto, una reserva/respawn | PENDIENTE manual; reserva preparada |
| A10 | Timer anterior no afecta vida nueva | PENDIENTE manual; guard preparado |
| A11 | Fin de sesión cancela espera | PENDIENTE manual; política preparada |
| A12 | Reinicio de punto cancela espera | PENDIENTE manual; política preparada |
| A13 | Desconexión limpia operaciones | PENDIENTE manual |
| A14 | Efectos/feed/sonido persisten | PENDIENTE de regresión manual |
| A15 | Kill conserva +50 una vez | PENDIENTE de regresión manual |
| A16 | Caída conserva 0 Coins por Kill | PENDIENTE de regresión manual |
| A17 | Gol conserva +50 | PENDIENTE de regresión manual |
| A18 | Arena clonada y SessionId correctos | PENDIENTE manual |
| A19 | rojo build | PASS estático |
| A20 | git diff --check | PASS estático |

## 14. Cierre

Sin Play/Run/Start Server, partidas, control de personajes, commits, push, publicaciones
ni escrituras cloud. No se habilitaron modos ni concurrencia y no se cambió persistencia.
Se detiene el desarrollo a la espera de validación del desarrollador.
