# Gameplay V2 — implementación, auditoría y validación pendiente

Fecha: 2026-10-17. Repositorio: H:\repos-github\SlapDuels-2.0.
Implementado en archivos y Roblox Studio **Edit**. No Play/Run/Start Server, control
de personajes, partidas ni pruebas funcionales del agente. Aceptación humana PENDIENTE.
Audio de tensión: BLOCKED por falta de SoundId autorizado; infraestructura instalada.

## 1. Auditoría temporal anterior

RoundService:_runSession leía Config.Round.RoundDuration=300, mantenía elapsed local,
esperaba1s y sumaba elapsed+=1. Sólo pausaba en PointRestartCountdown; la espera de
feedback/delay de punto mientras seguía Playing podía consumir tiempo del reloj global.
No había un RoundId propio por salida ni deadline independiente tras un gol.
La victoria por5 y el timeout ya compartían BeginSessionResults/EndCinematic.
Score acumulaba marcador, premiaba y disparaba feedback/reinicio.
La protección Score/KillPart V1 ya coordinaba tránsito de gol por Character/generación.

Dependencias del reloj auditadas: Config.Round.RoundDuration, _runSession, duración
del payload Playing inicial/reinicio, Countdown PLAYING, session.RemainingTime,
MatchController/MatchHUD.MatchTimerFrame.Timer y MatchSession en Types.
No quedan300, elapsed+=1 ni el while del reloj global en RoundService.
Los3000 de Void son precios, no dependencias de temporizador; no se modificaron.
Se preserva StartTime como metadato inicial, sin usarlo para finalizar a los5min.

También se revisaron Combat/Slap/Ragdoll, Elimination/DeathEffect, Spawn/MatchInstance,
PointFeedback, cliente Match/Music/Slap, bootstrap de controladores, resultados y
estadísticas individuales. Antes: Slap hacía una única consulta espacial, mismo
SlapCooldown0.6 para acierto/fallo, ragdoll fijo1.5 y sin contador de3 impactos.
El Tool Classic observado tiene Power20 y SlapCooldown0.6; esos recursos no se editaron.

## 2. Arquitectura nueva de rondas

Services/Gameplay/RoundClock es un contrato puro de deadline:
Id=SessionId:Round:N, Index, Deadline monotónico, NetworkDeadline sincronizable,
Resolved/ResolvedAt y SuddenDeath. MatchSession.GameplayRound apunta a la ronda vigente.

RoundService mantiene UN loop de sesión, que consulta la ronda actual cada0.05s y
publica segundos cuando cambian. No se crea otro hilo de timer por gol.
Un nuevo deadline sustituye al anterior después de colocar/desbloquear participantes;
el marcador no se reinicia. Ningún callback captura un timer viejo para resolver otra ronda.
La frecuencia de sondeo no determina la duración: manda os.clock() contra Deadline.
workspace:GetServerTimeNow() sólo proyecta el deadline para la presentación del cliente.

## 3. Configuración y rutas

src/shared/Config.luau:
- Config.Round.RoundDuration=180.
- Config.Round.SuddenDeath.Enabled=true.
- Config.Round.SuddenDeath.StartAtRemainingSeconds=30.
- Config.Round.SuddenDeath.FallAwardsGoal=true.
- Config.Combat.SlapCombo.Enabled=true.
- Config.Combat.SlapCombo.SuccessfulHitRecovery=0.15.
- Config.Combat.SlapCombo.MissRecovery=0.45.
- Config.Combat.SlapCombo.SwingWindow=0.10.
- Config.Combat.SlapCombo.SampleInterval=0.025.
- Config.Combat.DefaultSlapKnockdownDuration=3.0.
- Config.Combat.SlapElimination.HitsToEliminate=3.
- Config.SuddenDeathPresentation: TransitionDuration0.8,
  TintColor(255,170,170), Contrast0.12, Saturation−0.12, Brightness−0.08,
  MusicSoundName="SuddenDeath".

Config.Match.WinningScore5, PointReward50 y Economy.KillRewardCoins50 se conservan.
No se cambian KillPartDelayMs500, fuerza Power20, blast del punto, modalidades,
_maxConcurrentSessions1 ni persistencia. Config.Ragdoll.DefaultDuration5 sigue siendo
el default de otras acciones como la explosión del punto; no es el derribo del Slap.

## 4. Goles, timeout y política de simultaneidad

ScoreService conserva zona/equipo/vida/contacto actual/debounce y exige ronda abierta.
La reserva de protección Score/KillPart y TryResolveGameplayRound("Goal") preceden al
commit del gol, Coins y feedback. Resolved detiene inmediatamente ese reloj.
El flujo existente reposiciona, cuenta salida y llama BeginGameplayRound con180s.

En timeout se resuelve una sola vez "Timeout", se publica0 y se usa GetWinner por
marcador: Red mayor→Red; Blue mayor→Blue; igualdad→Draw. No Kills como desempate ni
gol artificial. WinningScore5 mantiene victoria inmediata.

Política: se usa el tiempo del servidor AL VALIDAR el evento, no una hora enviada
por el cliente ni el momento físico supuesto de un Touched encolado.
Si now>=Deadline, gana timeout, incluso si el loop todavía no publicó0.
Antes de Deadline, gana la primera reserva terminal válida entre gol y caída especial.
La activación de SuddenDeath consulta el tiempo actual antes de validar la acción.
Un golpe/eliminación ordinaria no termina por sí solo la ronda.
Una acción validada después del deadline se rechaza; no se deshacen pagos ni goles.

No corre un reloj abierto durante reinicio/feedback, countdown, MapLoading,
Ending, cinemática o retorno. Se conserva un registro resuelto hasta la siguiente salida.
Los contactos de countdown no generan recibos competitivos: pueden reutilizar
ResetCharacterInArena para recuperación de colocación, después de comprobar protección.
No hay kills/cuentas de golpes por competir durante la pausa de salida.

## 5. Muerte Súbita y gol colectivo

Es una subfase lógica dentro de Playing, sin reemplazar la máquina de estados.
Al quedar<=30s, SuddenDeath=true una sola vez para el RoundId y se notifica por
Countdown exclusivamente a participantes de esa sesión.

KillPart, VoidBoundary y sondeo de vacío válidos:
1. Respetan primero protección de gol normal y deduplicación por vida.
2. Reservan SuddenDeathFall en la ronda antes de callbacks.
3. Resuelven atribución/Kill/Death/recompensa personal mediante el pipeline existente.
4. ScoreService:AwardSuddenDeathGoal suma1 al equipo contrario al de la víctima.
5. Sin anotador personal: PointScorer=nil, sin estadística individual de gol, sin +50
   de gol para nadie. No se inventa un atacante cuando la caída fue propia.
6. Reinicio por punto o victoria al5 mediante el flujo actual.

Una Kill acreditada de esa caída sigue pagando50 al atacante, independientemente del
gol colectivo. Caída propia:0 Coins personales por Kill y0 por gol colectivo.
El reinicio de punto es el dueño del reposicionamiento tras esa caída terminal;
no se programa además el respawn individual de500ms que luego competiría con él.

El mismo recibo de eliminación se entrega sincrónicamente a DeathEffectService antes
de cerrar por un quinto gol especial; luego se emite el Bindable habitual. Su dedup
existente por EliminationId impide otra presentación cuando el listener diferido se
ejecute. Esto conserva el feedback personal aunque Ending se adelante a señales diferidas.
No se modificó DeathEffectService ni se creó otro sistema de Kill/Coins.

## 6. Ambiente rojo local

Nuevo SuddenDeathController modular, descubierto por ClientBootstrap existente.
Clona una plantilla ColorCorrectionEffect física a Lighting **sólo en ese cliente**.
Transición de0.8s a la configuración roja/oscura moderada; al salir interpola identidad
y destruye SU clon. No cambia Sky, Atmosphere, Ambient ni otros efectos base.
La corrección también tiñe la imagen del cielo como equivalente visual local; no se
sustituye el skybox. La intensidad/visibilidad real requiere validación humana.

Filtra SessionId, participante local, MatchId, StateVersion y RoundIndex.
Descarta rondas anteriores, sale con resolución/reinicio/cierre/cambio de MatchId y
protege tweens con epoch para no destruir una nueva activación.
No instancia efectos en Lighting desde servidor ni afecta al lobby/otra sesión.
Parámetros de ejecución: Config.SuddenDeathPresentation; plantilla física editable.

## 7. Música

MusicController incorpora SuddenDeath dentro de su mezclador actual, no otro reproductor.
Prioridad sobre arena; TODAS sus suspensiones existentes, incluida EndCinematic y
EndCinematicPreview, tienen prioridad. Se preserva restore tras preview.
MusicEnabled y volumen de usuario siguen gobernando _getTargetVolume/crossfade.
Nueva ronda restaura arena; cierre respeta el silencio cinematográfico y el retorno.

Se auditaron Music.Lobby, Music.Matchmaking, Music.Arenas.Factory/Inferno y los SFX
existentes. No se identificó una pista de tensión autorizada apropiada.
SoundService.Music.SuddenDeath existe físicamente con SoundId="" configurable,
Volume0.35, Looped=true, PlayOnRemove=false. Estado **BLOCKED_AUDIO_ASSET**.
Mientras falte ID, se conserva música de arena y se avisa una vez; no se inventa audio
ni se declara música tensa audible. Asignar un ID autorizado en ese Sound y reexportar
SuddenDeathMusic.rbxm es el pendiente de audio.

## 8. Cadencia de palmadas y fallos

SlapService conserva Tool administrada/equipada, Player/Character vivo, sesión rival,
alcance9 studs, cono frontal, selección determinista y potencia existente.
Añade ronda abierta y rechazo del atacante derribado/respawneando.

Cada activación válida reserva un swing, consulta rivales durante0.10s con muestras
cada0.025s y termina al PRIMER impacto válido. RegisterHit se llama una sola vez:
un swing no puede sumar varias palmadas sobre la misma víctima ni varios rivales.
Mientras está en vuelo, otro Remote no abre otro swing. Se revalidan Character,
generación, herramienta, sesión, RoundId y deadline tras cada espera.
Precios, potencia o decisiones de impacto no vienen del cliente.

Acierto: siguiente ataque desde aceptación+0.15s.
Fallo: desde FIN de la ventana+0.45s (aprox0.55s total sin latencia si no hubo objetivo).
Con SlapCombo.Enabled=false queda el cooldown del Tool; con true manda Config.
OnCooldown y validaciones servidor permanecen; errores liberan el bloqueo.

Nuevo RemoteEvent privado Combat.SlapFeedback lleva resultado, secuencia, Character,
generación, SessionId/RoundId y ReadyAt del servidor. SlapController espera respuesta
y usa ese deadline, sin adivinar si acertó. Filtra respuestas obsoletas y hace debounce
mientras espera; un timeout local2s sólo permite reintentar, no concede un impacto.
La latencia puede alargar el intervalo práctico; no se promete0.15s visual exactos.

## 9. Ragdoll de3s

Cada Slap aceptado que no elimina usa Config.Combat.DefaultSlapKnockdownDuration3.
RagdollService registra RagdollRecoveryDeadline=os.clock()+duración y programa la
recuperación desde ese deadline. Otra palmada renueva3s DESDE EL ÚLTIMO golpe válido;
cancela el hilo anterior y mantiene una única recuperación activa por Character.
Conserva velocidades/knockback y la reutilización del rig R6 ya validada.

El callback conserva guardas de timer, Character, generación, Player, MatchId,
StateVersion y cierre. CancelRecovery invalida recuperaciones al resolver ronda/cerrar;
teleport/Zero-Death restablecen por sus mecanismos actuales y limpian el deadline.
El tercer golpe y la finalización de ronda pueden terminar el derribo antes de3s
porque pasan al ciclo de eliminación/reposicionamiento. No se toca el temporizador
de respawn ni se transfieren plazos al Character nuevo/lobby.

## 10. Contador de tres impactos

CombatService guarda _lifeHits por Player con SessionId, RoundId, Character,
ArenaPhysicsGeneration y Count. Sólo RegisterHit validado incrementa.
Nuevo Character/generación/RoundId empieza en0 antes de contar su primer golpe.
ClearCombatTag al eliminar y ClearMatch al iniciar/cerrar ronda limpian contadores;
PlayerRemoving también limpia. No se usa una cantidad enviada por cliente.

1/3 y2/3 aplican derribo normal;3/3 llama HandleSlapThreshold con atacante validado.
No se agregó una barra de vida ni inventario. El feedback existente se reutiliza.
Las estadísticas individuales continúan perteneciendo al cierre/eliminación autoritativos.

## 11. Pipeline reutilizado de eliminación

SlapThreshold valida atacante contrario y el CombatTag actual y entra a
_processEliminationEvent. ImpactCFrame es la posición real de la víctima, sin simular
un contacto con KillPart. Usa la misma atribución, RecordMatchPerformance, AddKill,
AwardConfirmedKill50, snapshot congelado, recibo, DeathEffect equipado de la víctima,
feed privado y BeginKillPartRespawn/Zero-Death de500ms.
No se necesita esperar una caída para ejecutar el tercer golpe.

El retiro pendiente y CompetitiveTransit bloquean contactos tardíos mientras dura la
eliminación. Después del teleport se validan proximidad de sensor y generación nueva;
los golpes anteriores no se transfieren. SlapThreshold NO es una fuente de caída:
aunque SuddenDeath esté activa no concede gol colectivo.
Dos golpes+KillPart siguen la atribución actual y generan una sola eliminación.

## 12. Coordinación con KillPart/zonas

La protección Score/KillPart V1 se conserva. Gol normal confirmado resuelve la ronda;
su posterior caída no crea recibo, Kill, gol rival, Coins o segundo respawn.
En Muerte Súbita rige exactamente igual; el gol normal no se convierte en otra caída.
La reserva terminal de ronda impide que dos contactos/sensores sumen dos goles.

Si la eliminación o caída se confirma primero, se conserva esa decisión y no se
otorga un gol normal retroactivo. Si timeout llega al deadline primero, no se cuenta
ninguno de esos goles posteriores. No se cambian geometría/CanTouch/tamaños de sensores.
Recuperaciones de countdown no son eventos competitivos y respetan primero la
protección del anotador. No se desactiva KillPart globalmente.

## 13. HUD

El MatchHUD físico existente se conserva:76 descendientes antes/después.
Comparación MCP: mismas clases, Position, Size y AnchorPoint de objetos originales.
Único TextLabel cambiado: MatchTimerFrame.Timer de5:00 a3:00.
Se exportó íntegro desde el estado actual de Studio; no se reconstruyó por código.

MatchController muestra el deadline de la ronda vigente con reloj de red local;
filtra RoundIndex/SessionId/StateVersion. Cierra interpolación en pausas/resultados.
Los paquetes PLAYING resueltos no disparan por error la animación de salida.
Al nuevo Playing inicializa3:00; al expirar/resolverse muestra0:00.

Nuevo SuddenDeathHUD físico con Notice “MUERTE SÚBITA”, Visible=false inicialmente,
editable, y UICorner. Se muestra sólo al participante durante la subfase.
No se movieron interfaces previas. El posicionamiento del NUEVO aviso y su legibilidad
en móvil/relación con LastPoint requieren revisión visual del desarrollador.

## 14. Archivos

MODIFICADOS:
- src/shared/Config.luau
- src/shared/Types.luau
- src/server/Services/RoundService.luau
- src/server/Services/ScoreService.luau
- src/server/Services/EliminationService.luau
- src/server/Services/CombatService.luau
- src/server/Services/SlapService.luau
- src/server/Services/RagdollService.luau
- src/client/Controllers/MatchController.luau
- src/client/Controllers/MusicController.luau
- src/client/Controllers/SlapController.luau
- default.project.json

NUEVOS:
- src/server/Services/Gameplay/RoundClock.luau
- src/client/Controllers/SuddenDeathController.luau
- src/ui/MatchHUD.rbxm (export del HUD existente)
- src/ui/SuddenDeathHUD.rbxm
- src/assets/SuddenDeathAssets.rbxm
- src/assets/SuddenDeathMusic.rbxm
- tests/GameplayV2.spec.luau (PREPARED_NOT_RUN)
- tests/GameplayV2.edit-evidence.json
- tests/GameplayV2.validation.md
- tests/GameplayV2.integrity.json
- tests/assets/backups/GameplayV2.sources.before.json
- tests/assets/backups/MatchHUD.before-GameplayV2.rbxm

Las11 fuentes previas coincidieron con Studio antes de editar; se exigió Source
anterior exacto al instalar las13 fuentes finales, incluidas las2 nuevas.
El diff contra HEAD incluye mucho trabajo de fases anteriores, no sólo Gameplay V2.
Se conservaron respaldos previos y el Working Tree. No hay commits/push.

## 15. Objetos físicos y recuperación

Instancia Studio ab01cdbb-f911-49b1-87b1-c311e6160909, modo Edit.

Creados:
- StarterGui.SuddenDeathHUD.Notice.UICorner.
- ReplicatedStorage.UIAssets.SuddenDeathAssets.RedCorrection (Disabled en plantilla).
- SoundService.Music.SuddenDeath (SoundId vacío).
- ReplicatedStorage.Remotes.Combat.SlapFeedback.
- ServerScriptService.Services.Gameplay.RoundClock.
- StarterPlayer.StarterPlayerScripts.Controllers.SuddenDeathController.
- ServerStorage._GameplayV2Backups.MatchHUD_before_GameplayV2.

Modificado físicamente: texto3:00 de StarterGui.MatchHUD.MatchTimerFrame.Timer.
Los demás cambios de Studio son Sources de los módulos auditados.
No hay cambios de Lighting base del servidor, cámaras, modelos de mapa, KillPart,
EndCinematic, ShopHUD o Frost/Void.

Exports nativos SerializationService, con deserialización temporal y conteo verificado:
- MatchHUD:18826 bytes,76 descendientes.
- Backup MatchHUD:18844 bytes,76 descendientes (nombre de backup diferente).
- SuddenDeathHUD:4536 bytes,2 descendientes.
- SuddenDeathAssets:1177 bytes,1 descendiente.
- SuddenDeathMusic:1241 bytes,0 descendientes.
Las copias temporales de verificación se destruyeron sin ejecutar contenido.
El manifiesto de integridad contiene SHA256 de fuentes/recursos relevantes.

default.project.json mapea estos mismos recursos, sin otro HUD paralelo. SoundService
y Music conservan objetos desconocidos. El backup no está mapeado a StarterGui.
Para cambios artísticos posteriores, exportar Studio hacia los assets antes de
sincronizar desde archivos antiguos. El lugar abierto NO se guardó/cerró/reemplazó.

## 16–17. Verificación técnica

rojo build default.project.json --output <TEMP>/SlapDuels-GameplayV2.rbxlx: PASS.
git -c core.safecrlf=false diff --check: PASS.
Inspección MCP final: IsStudio=true, IsRunning=false; instancias persistentes presentes.
No se requirió Bootstrap ni se ejecutaron los servicios, perfiles o remotes en Edit.
Build valida ensamblado de archivos/assets, no tipado ni jugabilidad.

Hashes conservados de PlayerService, ShopService, SpawnService, DeathEffectService,
Frost.rbxm, Void.rbxm y ShopHUD.rbxm. Persistencia, economía implementada, modelos
cosméticos y física de lobby no se modificaron. Concurrencia1 y2v2/3v3 deshabilitados.
No se cambia PRODUCTION_UNIVERSE_ID ni se llama a DataStoreService.

## 18. Matriz de pruebas

La suite nueva está PREPARADA y NO EJECUTADA: reloj con tiempos inyectados, rechazo
en deadline, identidad nueva y temporizador obsoleto, owner de timeout, impactos por
vida/ronda, friendly fire, gol colectivo sin pago, duplicados y quinto gol.
No se ejecutaron suites antiguas. Fixtures previos que simulaban RoundService sin
IsGameplayRoundOpen deben adaptarse al contrato V2 antes de usarlos como regresión.

| Área / caso | Evidencia actual | Funcional |
|---|---|---|
|180s y reinicio tras gol, marcador conservado|Deadline/fixtures preparados|NOT RUN|
|Timeout Red/Blue/Draw por goles|GetWinner y flujo de resultados|NOT RUN|
|Victoria inmediata5|Commit normal/colectivo usa DeclareSessionWinner|NOT RUN|
|Un timer y rechazo de timer viejo|Un loop, objeto/Id por ronda, fixtures|NOT RUN|
|Activación<=30 una vez|Flag por RoundId y tiempo consultado antes de acciones|NOT RUN|
|Cielo rojo local y restauración|Plantilla física/controlador privado|NOT RUN|
|Música tensa|Sound vacío; mixer integrado|BLOCKED: asset autorizado|
|Música/preferences/cinemática|Mixer/suspensiones existentes, restore añadido|NOT RUN|
|Lobby/otra sesión intactos|Filtros y envíos privados|NOT RUN|
|Caída concede gol rival sin scorer|Método colectivo/fixture sin AddCoins|NOT RUN|
|Gol/fall/timeout simultáneos|Reserva terminal y deadline|NOT RUN|
|Gol→KillPart no duplica|Protección V1 más barrera de ronda|NOT RUN|
|Swing único/acierto/fallo|Ventana servidor/ack y cooldown|NOT RUN|
|Ragdoll3 renovado|Deadline/cancelación por Character|NOT RUN|
|Tres impactos eliminan|Counter validado+pipeline compartido|NOT RUN|
|Contador reinicia|Identidad de vida/ronda y ClearCombatTag|NOT RUN|
|Tercer golpe+KillPart tardío|Retiro/transit/contacto actual|NOT RUN|
|Kill/Death/50/efecto víctima|Ruta compartida sin otra economía|NOT RUN|
|Shop/DefaultFall/Frost/Void|Fuentes/recursos previos conservados|NOT RUN|
|Zero-Death/lobby/segunda partida|Spawn y recuperación existentes|NOT RUN|
|EndCinematic por5/timeout/Draw|Mismo terminal owner, sin cambios visuales|NOT RUN|
|HUD físico/recursos/Sources|MCP Edit y export nativo inspeccionados|Verificación estática realizada|
|Build / diff|Comandos ejecutados|PASS / PASS|

Ninguna inspección de código se declara PASS de jugabilidad. No hay tolerancia visual
al milisegundo garantizada ni pruebas de rendimiento/red ejecutadas.

## 19. Instrucciones manuales — sólo desarrollador

Antes: iniciá VOS un servidor de prueba nuevo para cargar las fuentes. Confirmá en
Output PersistenceEnvironment=Studio, PersistenceProvider=InMemory, WritesToCloud=false.
Si difiere, detener. Usar dos participantes y opcionalmente un tercer cliente en lobby,
sin habilitar2v2/3v3 ni aumentar concurrencia. No cambiar relojes ni perfiles para fabricar PASS.

1. Jugá1v1 sin goles durante180s jugables desde GO/desbloqueo. Cronometrá y grabá3:00
   hasta0:00. No debe correr durante carga/countdown ni iniciar otra ronda al expirar.
2. En otra partida, anotá para dejar marcador desigual; la NUEVA ronda debe comenzar
   completa en3:00. Sin más goles, al180 debe ganar el líder por marcador, sin gol extra.
3. Repetí con0–0 o marcador igual: timeout→Draw y resultados/cinemática según contrato.
   Kills distintas no deben romper el empate.
4. Anotá varios goles antes del timeout: cada uno50 Coins sólo al anotador, PointFeedback,
   reset/salida y180 nuevos; marcador acumulado, sin “se cayó” ni segundo gol por KillPart.
5. En una ronda sin goles esperá hasta0:30. Activación única de MUERTE SÚBITA, no avisos
   repetidos cada segundo. El reloj continúa hasta0:00 si no hay resolución.
6. Verificá tono rojo del cielo/escena, visibilidad y transición; al reiniciar restaura.
   Audio de tensión actualmente BLOCKED por SoundId vacío: se conserva arena. Cuando
   se asigne/reexporte un ID autorizado, probar transición musical, MusicEnabled=false,
   volumen de usuario y silencio exclusivo de EndCinematic. No reportar audio PASS ahora.
7. En Muerte Súbita, hacé caer voluntariamente a Red por KillPart sin atacante reciente:
   efecto DefaultFall/feed según caída; gol+1 para Blue y ningún pago personal.
8. Repetí caída empujada por rival: gol colectivo para rival+Kill personal y50 Coins
   para atacante una vez; sin otro50 de “gol” ni scorer inventado. Al llegar5, cierre
   y celebración existentes. Probar también Blue cayendo→gol Red.
9. Tercer cliente permanece en lobby: sin corrección roja, aviso, música tensa,
   Death Effect ni animación de Coins de otra sesión. No habilitar otra sesión real.
10. Fuera de Muerte Súbita, encadená aciertos sobre rival: recuperación corta; mismo
    swing no cuenta dos impactos. Intentá golpear compañero/ajeno: servidor lo rechaza.
11. Fallá un swing sin rival en alcance. Medí ventana0.10 + recuperación0.45 antes de
    aceptar otro; clicks rápidos no saltan el bloqueo ni bloquean el Slap permanentemente.
    Latencia de ida/vuelta puede aumentar el intervalo, no se deben otorgar golpes por UI.
12. Con un único golpe y sin caer, medí derribo de3s desde impacto. Segundo golpe antes
    de recuperar renueva3s desde el segundo; no debe ejecutar la recuperación vieja.
13. Tres golpes válidos sobre la MISMA vida: tercer golpe elimina inmediatamente
    sin esperar KillPart. Repetí durante Muerte Súbita y confirmá que eso NO suma gol.
14. Comprobá +1 Kill/+1 Death competitiva/+50 atacante, efecto equipado de víctima,
    killfeed y Zero-Death500ms en spawn del equipo, sin salto/impulso residual.
    Tras reaparecer, el primer golpe cuenta1/3, no elimina por daño anterior.
15. Dos golpes+caída y tercer golpe+contacto tardío: una sola eliminación, efecto,
    Kill y pago. Gol normal durante Muerte Súbita+caída propia posterior: un solo gol
    normal,50 anotador, ningún gol rival. Repetir contactos/sensores no duplica.
16. Completá5 goles; comprobá EndCinematic, silencio musical, ranking y retorno estable.
    Repetí por timeout/Draw y una segunda partida. Shop/equipamiento/BasicKill/Frost/Void,
    DefaultFall, música normal, lobby sólido y preferencias deben conservarse.

Registrar por caso PASS/FAIL/BLOCKED/NOT RUN, tiempo real, RoundId/StateVersion si aparece,
marcador, Coins/Kills/Deaths antes/después, Output de servidor/clientes y clip.
La asignación de SoundId requiere recurso autorizado; no cambiar producción para probar.

## 20. Riesgos e incompatibilidades conocidas

- Música de tensión pendiente de asset autorizado. El sonido físico y prioridad existen;
  no hay pista audible nueva ni validación de permisos/rendimiento de audio.
- ColorCorrection tiñe el cielo existente; no es un skybox nuevo. Intensidad roja,
  banner en móvil, superposición con UI y accesibilidad esperan prueba visual humana.
- Latencia de red limita la velocidad práctica de combo; el cliente prioriza confirmación
  real y deadline del servidor frente a predecir impactos. Ventana0.10 configurable.
- Un timeout decide por hora de validación servidor; no se reconstruye un contacto
  histórico encolado ni se otorga gol retroactivo tras cierre.
- Una caída terminal de Muerte Súbita usa el reset de punto, no además500ms individual;
  la eliminación por tercer golpe sí usa500ms y no concede gol colectivo.
- El pipeline síncrono de feedback para quinta caída especial depende del mismo
  DeathEffectService y su dedup; debe verificarse con SignalBehavior/red del proyecto.
- Fixtures/consumidores personalizados anteriores sin GameplayRound/IsGameplayRoundOpen
  necesitan el contrato actualizado. No se declara tipado Luau aprobado por rojo build.
- InMemory sólo conserva el estado del servidor de prueba; no se promete durabilidad
  entre ejecuciones ni se habilitó persistencia productiva.
- Física de mapas, fuerza y spawns permanecen como estaban. Interacciones de3 golpes
  con knockback, bordes y lobby requieren las pruebas manuales indicadas.

Implementación detenida a la espera de validación del desarrollador. Sin publicación,
commits, push, escrituras cloud, pruebas del agente ni otras fases.
