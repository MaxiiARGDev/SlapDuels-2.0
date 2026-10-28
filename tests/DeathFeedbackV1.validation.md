# Death Feedback V1 — implementación y validación pendiente

Actualización V1.1: el usuario autorizó +50 Coins por Kill válida.
Ver DeathFeedbackV11.validation.md. Las referencias a premio 0 y bloqueo económico
en este informe describen exclusivamente la versión histórica V1.

Implementación de código y objetos físicos completada. Inspección estructural MCP en Edit realizada.
Pruebas de jugabilidad y suite aislada: **NO EJECUTADAS**. El desarrollador las ejecuta.
No hubo Play, Run, Start Server, control de personajes ni partidas por parte del agente.

## 1. KillPart y atribución

Se inspeccionó Workspace.Levels.Geometry.KillPart en Edit: Part, CanTouch=true,
Position=(161.5,-25,805), Size=(334,5,248), sin scripts descendientes.
No se movió ni modificó. El código actual de EliminationService no conecta ese Part global:
BindMatch conecta InstanceInfo.KillParts, descendientes del mapa clonado de cada arena.
MatchInstanceService descubre esos sensores al clonar el mapa.
La víctima se obtiene recorriendo ancestros del BasePart que tocó el sensor y verificando
Players:GetPlayerFromCharacter; un rig cinematográfico no es el Character de un Player.
La sesión y la pertenencia se validan con RoundService y con el contenedor de la arena.

SlapService valida Playing, alcance, orientación y cooldown; CombatService conserva el último
atacante válido con MatchId y ventana LastHitLifetime. EliminationService toma la decisión final,
exige rival de la misma sesión y aplica el debounce existente de 0.5 s, contador y EliminationId.
DeathEffectService NO consulta golpes recientes para inferir otra Kill.
No se añadieron conexiones Touched ni se sustituyó el sistema de eliminación.

## 2. Fuente real de recompensa

**La Kill actualmente concede +1 Kill y 0 Coins.** PlayerService:AddKill no llama AddCoins.
Los +50 Coins existentes son por gol: ScoreService usa Config.Match.PointReward=50
y PlayerService:AddCoins(...,"MatchPoint"). Se mantuvo esta separación.

AddKill conserva su primer resultado (total de Kills) y añade un segundo resultado explícito:
Coins realmente acreditadas por esa operación, actualmente 0.
EliminationService incorpora ese recibo en el evento confirmado. No se infiere un premio
comparando saldos que podrían haber cambiado por otra razón.
Los consumidores anteriores que solo usan el primer retorno siguen siendo compatibles.
Ni DeathEffectService ni los controllers conceden Coins/Kills/Deaths/Score.

Propuesta para una regla futura de +50 por Kill: aprobar primero la modificación económica;
acreditar una sola vez en la autoridad existente con EliminationId y devolver el recibo real.
La animación ya puede consumir ese recibo. **No se implementó esa nueva regla en V1.**

## 3. Arquitectura

EliminationService captura ImpactCFrame desde el miembro que activó Touched ANTES de
ResetCharacterInArena. Amplía el EliminationRecord con posición, recibo, StateVersion y ConfirmedAt.
Su BindableEvent PlayerEliminated existente sigue siendo la única fuente.
DeathEffectService se suscribe una vez, valida vigencia/participantes/estado/versión, deduplica
EliminationId por sesión y emite Remotes.Match.DeathFeedback exclusivamente con FireClient.
El cliente valida MatchId, SessionId, StateVersion y antigüedad antes de reproducir.

DeathFeedbackController coordina DeathEffectPlayer, DeathNotifications y KillRewardController.
Scope posee modelos, clones de GUI, tareas, tweens y conexiones temporales cancelables.
No se tocó RoundService, matchmaking, spawns, combate, scoring ni persistencia en esta entrega.
Bootstrap añade únicamente DeathEffectService al orden existente; ClientBootstrap ya descubre
automáticamente los nuevos controllers.

## 4–5. Models físicos y contenido

Instalados y consultados por MCP en **Edit**:

- ServerStorage.DeathEffects.DefaultFall
- ServerStorage.DeathEffects.BasicKill

Cada Model tiene:

- Origin (Part invisible).
- VFX/VerticalJet/Jet, VFX/WideBurst/Burst, VFX/Shockwave/Disc,
  VFX/Sparks/Sparks y VFX/Flash/Glow (Parts con ParticleEmitters).
- VFX/Flash/ImpactLight (PointLight).
- SFX/Impact/DeathImpact (Sound 3D).

Son siete Parts seguros, cinco emisores y un Sound por Model.
BasicKill: paleta naranja/dorada/roja, jet 32–52 studs/s, apertura radial,
flash, disco horizontal y chispas; total de 77 partículas, Duration=2.2.
DefaultFall: paleta fría azul/gris, impulso menor, 37 partículas, Duration=1.5.
Todos los emisores están Enabled=false y Rate=0; se disparan con EmitCount/EmitDelay.
No hay Explosion con daño ni fuerzas aplicadas a personajes.
Los sonidos reutilizan IDs presentes en PointEffects.Basic; su carga, permisos y mezcla
quedan pendientes de validación auditiva manual.

Los recursos tienen fuente persistente en src/assets/DeathEffects.project.json, mapeada por Rojo.
Los HUDs también tienen proyectos de recursos propios.
Se usa el formato de propiedades/atributos documentado por
[Rojo](https://rojo.space/docs/v7/properties/), sin generadores visuales durante Play.

## 6–7. Cosméticos y víctima

DeathEffectDefinitions declara DeathEffectId, DisplayName, ModelName, Duration, EmitCount,
EmitDelay, PlayDelay, RequiredOwnership e IsDefault.
El proveedor usa PlayerService:GetEquippedItem(victim,"DeathEffects") y HasItem cuando corresponda.
Solo acepta IDs incluidos en el catálogo. Nunca consulta el equipamiento del atacante.

Existe API genérica de inventario reutilizable, pero no existe una categoría comercial
de DeathEffects provisionada en esta fase. Si no hay equipamiento válido se usa BasicKill
explícitamente como default, sin fingir compra, propiedad o persistencia.
Una caída sin atacante elige DefaultFall directamente, sin consultar cosméticos.
No se añadieron compras, ítems al inventario ni escrituras DataStore.

## 8–9. Distribución y ubicación

El servidor replica plantillas inertes desde ServerStorage.DeathEffects a
ReplicatedStorage.DeathEffectAssets al inicializar el servicio.
NO replica efectos activos en Workspace. Cada destinatario autorizado crea una copia LOCAL
y la sitúa mediante Origin y el ImpactCFrame confirmado por el servidor.
Ver los assets en ReplicatedStorage no permite que otro cliente autorice eventos competitivos:
no hay handler de solicitudes del cliente en DeathFeedback.

ImpactCFrame se obtiene proyectando la posición del miembro que tocó el sensor a la superficie
de su caja orientada (incluye contacto interior). No usa el spawn ni el atacante.
Los VFX tienen orientación vertical mundial, sin fuerzas.
Los eventos de VoidBoundary/diagnóstico no fabrican un contacto con KillPart: no disparan este
feedback de impacto. El reset de seguridad previo continúa funcionando.
En StartCountdown/Ending se conserva el comportamiento previo de reset, pero no se emite este feedback.

## 10–12. HUDs, animaciones y sonidos

StarterGui.DeathFeedbackHUD:

NotificationContainer > UIListLayout y NotificationTemplate (CanvasGroup).
La plantilla contiene Background/UICorner/UIStroke, Icon, MessageLabel, UIScale y NotificationSound.
El controller clona esa plantilla, usa texto plano RichText=false, anima escala/opacidad,
apila y limita notificaciones, reproduce Sound local y limpia al vencer su duración.
Muestra "{atacante} tiró a {víctima}" o "{víctima} se cayó".
KillColor y FallColor son atributos Color3 editables de NotificationTemplate.
NotificationContainer.Position no se escribe durante la reproducción.

StarterGui.KillRewardHUD:

CoinTarget (Label y ArrivalTemplate), CoinTemplate, EffectsContainer,
RewardAmountTemplate y RewardSound.
El controller clona monedas 2D, usa trayectorias Bézier con suavizado, stagger y escala variable,
lee la posición absoluta real de CoinTarget para cada frame y añade pulso de llegada.
CoinTarget.Position no se modifica; las capas no capturan input.
El monto mostrado es el recibo confirmado; no se altera el contador existente de PlayerHUD.
Con el premio actual de 0 por Kill NO se muestra la animación ni se reproduce su sonido.

## 13. Duplicación y ciclo de vida

Se conserva el antidupe competitivo existente; no hay un segundo registrador de eliminaciones.
Además hay dedupe por SessionId/EliminationId en servidor, feedback cliente y recibos de monedas.
Solo el atacante recibe RewardCoins positivo, si existiera; los demás reciben 0.
Cambiar de sesión limpia los registros locales y no permite reutilizar eventos de partidas anteriores.
Se rechazan callbacks tardíos por versión/estado, eventos vencidos y eventos previos a un cleanup.
Se cancelan efectos/tareas al terminar, retornar, cambiar Character, desconectar jugadores o cambiar
a estados no permitidos. Cada efecto/notificación/animación tiene duración y límites.
Las conexiones persistentes son por servicio/controller; no se agregan listeners permanentes por muerte.
No se genera feedback de preview ni sobre rigs cinematográficos.

Se conserva Zero-Death: ResetCharacterInArena reposiciona el Character existente.
MatchStats.Deaths continúa contando eliminaciones competitivas acreditadas; la caída normal no
se convierte en un nuevo incremento de Deaths, de acuerdo con la regla preexistente.

## 14. Archivos de esta entrega

Modificados:

- default.project.json
- src/server/Bootstrap.server.luau
- src/server/Services/EliminationService.luau (captura y datos del evento existente)
- src/server/Services/PlayerService.luau (segundo retorno de AddKill, actualmente 0)
- src/shared/Types.luau (campos opcionales del registro)

Nuevos:

- src/server/Services/DeathEffectService.luau
- src/shared/DeathFeedbackConfig.luau
- src/shared/DeathEffectDefinitions.luau
- src/shared/DeathFeedbackContract.luau
- src/client/Controllers/DeathFeedbackController.luau
- src/client/Controllers/KillRewardController.luau
- src/client/DeathFeedback/Scope.luau
- src/client/DeathFeedback/DeathEffectPlayer.luau
- src/client/DeathFeedback/DeathNotifications.luau
- src/assets/DeathEffects.project.json
- src/ui/DeathFeedbackHUD.project.json
- src/ui/KillRewardHUD.project.json
- tests/DeathFeedbackV1.spec.luau
- tests/DeathFeedbackV1.edit-evidence.json
- tests/DeathFeedbackV1.validation.md

El diff Git acumulado contiene muchas fases anteriores; no atribuir todo ese diff a esta entrega.

## 15. Studio Edit y preservación

Se añadieron exclusivamente DeathEffects, ambos HUDs y Remotes.Match.DeathFeedback.
La conexión Rojo existente reflejó los módulos de código y los cambios de integración en Edit.
La inspección confirmó su presencia sin requerir ni ejecutar Bootstrap/servicios.
Se añadieron atributos artísticos de color únicamente a la nueva plantilla de notificaciones.

Evidencia: tests/DeathFeedbackV1.edit-evidence.json.
Comparación antes/después de 137 descendientes de ScenarioFinal: mismas rutas, clases
y, para Parts, CFrame/Size. Incluye las posiciones artísticas actuales del usuario en los billboards.
KillPart conserva CFrame y Size. No hay efectos temporales DeathFeedback_* en Workspace.
Se revisaron nombres únicos y ausencia de scripts/Explosions en los nuevos recursos.

No se guardó, cerró ni sobrescribió el lugar abierto. Guardar localmente los cambios de Edit.
Para conservar futuros ajustes artísticos al resincronizar, actualizar también el recurso Rojo
correspondiente; un recurso administrado por Rojo debe mantenerse alineado con su fuente.

## 16–17. Comprobaciones estáticas

- rojo build default.project.json --output "$env:TEMP/SlapDuels-DeathFeedbackV1.rbxlx":
  **PASS estático**, exit 0.
- git -c core.safecrlf=false diff --check: **PASS estático**, exit 0.

Build verifica empaquetado y rutas/recursos, no ejecución Luau ni resultados visuales.
Diff check no incluye los archivos no rastreados; estos se revisaron directamente.
No se ejecutó la suite preparada ni se declaró PASS funcional.

## 18. Guía manual exacta

1. En Edit: Explorer > ServerStorage > DeathEffects > DefaultFall o BasicKill.
   Para editar intensidad: VFX > Part correspondiente > ParticleEmitter.
   Ajustar Speed, SpreadAngle, Size, Color, Lifetime y atributos EmitCount/EmitDelay.
2. Sonido 3D: SFX > Impact > DeathImpact. Ajustar SoundId, Volume, PlaybackSpeed,
   RollOffMinDistance, RollOffMaxDistance y PlayDelay. No usar sonidos de EndCinematic.
3. Notificaciones: StarterGui > DeathFeedbackHUD > NotificationContainer:
   mover/ajustar Position/Size en Edit. Diseño dentro de NotificationTemplate.
   Sonido dentro de NotificationTemplate > NotificationSound.
4. Destino de monedas: StarterGui > KillRewardHUD > CoinTarget: mover en Edit.
   CoinTemplate/RewardAmountTemplate definen la emisión inicial; ArrivalTemplate, la llegada.
   Guardar una copia local del lugar que incluya tus cambios no guardados.
5. El desarrollador inicia manualmente servidor local con al menos dos clientes.
   Antes de jugar, comprobar Output del servidor: PersistenceEnvironment=Studio,
   PersistenceProvider=InMemory, WritesToCloud=false. Si no coincide, detener.
6. Dos jugadores entran en las plataformas Red/Blue de la zona 1v1, votan y esperan Playing.
   Para caída sin atacante: no recibir golpes durante más de Config.Combat.LastHitLifetime
   (si falta configuración, 10 s) y caer hasta tocar el KillPart DE LA ARENA.
   Esperado: DefaultFall, "{víctima} se cayó", reset existente y ningún premio/Kill.
7. Para Kill válida: el rival golpea con el Slap y la víctima cae al KillPart de la misma arena
   dentro de la ventana vigente. Esperado: BasicKill por fallback, notificación de ambos nombres,
   +1 Kill del atacante y una sola reproducción pese a múltiples contactos de extremidades.
   Caer solo por el VoidBoundary no demuestra el impacto KillPart de esta fase.
8. Equipamiento de víctima: V1 resuelve BasicKill si no existe un ítem DeathEffects válido.
   No hay tienda ni otro cosmético equipable instalado para comparar dos estilos.
   La suite aislada preparada usa proveedores falsos distintos para víctima/atacante.
   Un cosmético distinto en una partida real requiere catálogo/modelo/propiedad autorizados en otra fase.
9. Coins: anotar saldo antes/después de la Kill. Con la regla actual el saldo no cambia
   y NO aparece animación de premio. Anotar un punto sigue dando los 50 Coins existentes.
   La animación positiva por Kill queda BLOCKED por ausencia de una regla económica positiva;
   no forzar saldo, inventar recibos en una partida ni cambiar la economía para marcar PASS.
10. Para aislamiento, dejar al menos un tercer cliente en lobby.
    No debe recibir notificaciones, modelos locales ni sonidos de la pelea.
    En Explorer de CADA CLIENTE, los DeathFeedback_<EliminationId> activos solo aparecen
    en los dos participantes. Las plantillas de ReplicatedStorage pueden existir en todos, inertes.
11. Repetir caídas, alternar dos víctimas, finalizar a cinco puntos y volver al lobby.
    Verificar limpieza, segunda partida sin eventos viejos y EndCinematic intacto.
    Repetir moviendo NotificationContainer/CoinTarget en Edit y cambiando tamaño de ventana.
12. Configuración central: ReplicatedStorage.Shared.DeathFeedbackConfig (fuente en src/shared).
    Ajustar Enabled, límites, duración máxima, sonidos, tiempos, cantidad de monedas,
    stagger, FlightDuration, ArcHeight y ArrivalPulse. ID vacío usa el Sound físico del HUD.
    Duration por efecto y EmitCount/EmitDelay/PlayDelay se editan en sus recursos, sin duplicar catálogo comercial.
13. Si falla: copiar Output COMPLETO de servidor y cliente, mensajes [DeathEffectService],
    [DeathFeedback], [KillReward], [EliminationService], [CombatService] y [SpawnService].
    Adjuntar SessionId, StateVersion, EliminationId, tipo, saldos/Kills antes/después,
    captura del sensor clonado, efecto/HUD y cliente donde ocurrió. No incluir secretos.
14. Suite opcional preparada: tests/DeathFeedbackV1.spec.luau devuelve una función con mocks.
    Para ejecución manual, el desarrollador puede copiarla a un ModuleScript aislado y requerirla
    en su contexto de pruebas servidor. No envía remotes reales ni modifica perfiles;
    el recibo sintético +50 usado por el spy NO demuestra una recompensa real.

## Matriz A1–A20

| ID | Verificación | Estado actual |
|---|---|---|
| A1 | Efecto seleccionado por víctima | PENDIENTE manual; fixture de proveedor preparada |
| A2 | No usar cosmético atacante | PENDIENTE manual; fixture preparada |
| A3 | DefaultFall sin atacante | PENDIENTE manual |
| A4 | Caída sin Kill/Coins | PENDIENTE manual |
| A5 | Multicontacto sin doble efecto | PENDIENTE manual; dedupe de ID preparado |
| A6 | Sin doble notificación | PENDIENTE manual |
| A7 | Sin doble premio | PENDIENTE manual; regla vigente 0 por Kill |
| A8 | Posición de contacto | PENDIENTE manual; caso geométrico preparado |
| A9 | Participantes reciben | PENDIENTE manual; spy preparado |
| A10 | Ajeno no recibe | PENDIENTE manual; spy preparado |
| A11 | Animación positiva solo atacante | BLOCKED en partida real: Kill no acredita Coins |
| A12 | Monto igual al crédito real | PENDIENTE para 0; positivo BLOCKED por regla vigente |
| A13 | Posición NotificationContainer | PENDIENTE manual; propiedad instalada en Edit |
| A14 | Posición CoinTarget | PENDIENTE manual; propiedad instalada en Edit |
| A15 | EndCinematic intacto | PASS estructural Edit; funcional PENDIENTE |
| A16 | Limpieza de sesión | PENDIENTE manual; rechazo tardío preparado |
| A17 | Reset y puntos conservados | PENDIENTE manual |
| A18 | Reglas competitivas conservadas | Revisión estática realizada; regresión PENDIENTE |
| A19 | Rojo build | PASS estático |
| A20 | Git diff --check | PASS estático |

## 19–20. Limitaciones y cierre

El aspecto, permisos de audio, tiempos, comportamiento con latencia y sesiones multicliente
requieren validación del desarrollador. No se habilitaron modos ni concurrencia.
Las caídas normales conservan la semántica Zero-Death existente.
La animación positiva está implementada como presentación de recibos, pero no se activará con
la economía actual; no se concede una recompensa nueva sin autorización.
El guardado local del lugar y cualquier ajuste artístico quedan pendientes.

Sin Play/Run/Start Server, partidas, commits, push, publicaciones ni escrituras cloud.
Sin compras, cambios a persistencia, KillPart o EndCinematic.
La implementación se detiene aquí a la espera de validación del desarrollador.
