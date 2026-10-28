# Death Feedback V1.1 — recompensa autoritativa por Kill

Implementado por autorización expresa: **Kill válida +50 Coins**, gol válido +50 Coins sin cambios,
caída/muerte sin atacante acreditado 0 Coins por Kill.
La restricción económica de V1 (0 por Kill) queda sustituida. Los informes V1 son históricos.
Pruebas de jugabilidad y suites aisladas: **NO EJECUTADAS**; corresponden al desarrollador.

## Auditoría e implementación

- Config.Economy.KillRewardCoins=50 es la única constante de producción para este premio.
  Config.Match.PointReward=50 permanece separado y no se modificó ScoreService.
- PlayerService:AddKill sigue registrando estadísticas; por sí solo no crea dinero.
  Sus consumidores existentes conservan el resultado de total de Kills.
- EliminationService mantiene la atribución final existente, las estadísticas de Kills/Deaths,
  protección del anotador, debounce Touched de 0.5 s y EliminationId.
  Después de confirmar la Kill, llama una vez a PlayerService:AwardConfirmedKill.
- AwardConfirmedKill exige atacante/víctima distintos y conectados, misma sesión vigente,
  equipos opuestos, registro autoritativo, MatchId coincidente y estado Playing o
  PointRestartCountdown. Rechaza sesión congelada/cerrada y EliminationId de otra víctima/sesión.
- La operación económica usa PlayerService:AddCoins con clave "Kill:"..EliminationId.
  AddCoins incorpora un segundo retorno: monto NUEVO acreditado por esa llamada.
  El primer retorno sigue siendo el saldo, compatible con gol/tienda y consumidores anteriores.
- Las transacciones con clave exigen un perfil ya cargado: nunca registran ni cargan nuevamente
  al jugador si falta el perfil. La reserva de clave y actualización del saldo son sin yields.
  Una repetición devuelve 0 Coins nuevos y el saldo actual, sin duplicar crédito ni notificación.
  El registro de claves vive en memoria por jugador hasta su desregistro; no añade escrituras cloud.
- La sincronización de datos/leaderstats sucede después del crédito. Si falla esa notificación,
  el crédito sigue confirmado y el ID no queda disponible para cobrar de nuevo.
  La notificación de estadísticas de AddKill también queda protegida para no impedir el premio
  cuando ya se registró la Kill. No se cambian sus incrementos.
- EliminationRecord.RewardCoins proviene del resultado confirmado de la operación,
  no de un valor fijado en un controller ni de una comparación de saldos.
- DeathEffectService NO acredita Coins. Mantiene el envío privado por sesión;
  solo el atacante recibe RewardCoins positivo. Víctima y otros participantes reciben 0.
  Se mantienen dedupe por SessionId/EliminationId, versión, estado y caducidad.
- KillRewardController consume ese recibo, muestra "+50 Coins", reproduce el Sound local
  ya instalado y anima las monedas al CoinTarget físico leyendo su posición absoluta.
  No cambia CoinTarget.Position ni modifica el contador autoritativo de PlayerHUD.
- Las Kills competitivas confirmadas por VoidBoundary también pueden recibir el premio.
  Su recibo usa RewardOnly y solo se envía al atacante, sin fabricar un impacto KillPart
  ni generar un VFX/notificación nuevo fuera del contrato físico de V1.
- El efecto equipado de la víctima y las notificaciones KillPart de V1 se conservan.
  La caída sin atacante no llama AwardConfirmedKill.

## Archivos de esta entrega

- src/shared/Config.luau
- src/server/Services/PlayerService.luau
- src/server/Services/EliminationService.luau
- src/server/Services/DeathEffectService.luau
- src/client/Controllers/DeathFeedbackController.luau
- src/client/Controllers/KillRewardController.luau
- tests/DeathFeedbackV11.spec.luau (suite con perfiles falsos, preparada sin ejecutar)
- tests/DeathFeedbackV11.edit-evidence.json
- tests/DeathFeedbackV11.validation.md
- tests/DeathFeedbackV1.validation.md (aviso de regla sustituida)

No se cambió EndCinematic, ningún diseño de HUD, KillPart, mapas, preferencias,
modos, concurrencia, persistencia ni reglas de puntuación.
El Working Tree conserva los cambios de las fases anteriores.

## Studio Edit y comprobaciones

Se confirmó Edit antes de inspeccionar. Rojo sincronizó el código autorizado:
se consultó Source para confirmar configuración, autoridad, transacción, integración,
recibo y texto de monedas, sin requerir/ejecutar servicios ni acreditar perfiles en Edit.

CoinTarget conserva Position y Size del inicio de esta tarea.
Los 137 descendientes de ScenarioFinal conservan rutas/clases y CFrames de sus Parts,
incluidos los ajustes artísticos actuales de los billboards.
Evidencia: tests/DeathFeedbackV11.edit-evidence.json.
No se guardó, cerró ni sobrescribió el lugar abierto.

- rojo build default.project.json --output "$env:TEMP/SlapDuels-DeathFeedbackV11.rbxlx":
  **PASS estático**, exit 0.
- git -c core.safecrlf=false diff --check: **PASS estático**, exit 0.

Rojo build verifica empaquetado/rutas; no demuestra ejecución Luau ni comportamiento jugable.
La suite preparada usa perfiles y remotes falsos, sin DataStores ni jugadores reales.
Contempla crédito, repetición, caída, desconexión, perfil ausente, rivalidad, cierre,
independencia del gol, fallo de notificación y distribución privada del recibo.
No se ejecutó esa suite ni se ejecutaron pruebas en Studio.

## Validación manual del desarrollador

1. Guardar localmente una copia del lugar con tus cambios de Edit.
   Confirmar en Explorer StarterGui > KillRewardHUD > CoinTarget y RewardSound.
   Sus posiciones y sonido siguen siendo los recursos físicos instalados en V1.
2. Iniciar manualmente servidor local con tres clientes: dos participantes 1v1 y uno en lobby.
   Verificar Output servidor: PersistenceEnvironment=Studio, PersistenceProvider=InMemory,
   WritesToCloud=false. Si no coincide, detener la prueba.
3. Entrar a plataformas Red/Blue, votar mapa y esperar Playing.
   Anotar Coins y Kills del atacante y Coins de la víctima ANTES del golpe.
4. Kill válida: golpear al rival y conseguir que toque el KillPart clonado de esa arena
   dentro de LastHitLifetime (actualmente 10 s). Sin anotar un gol en ese intervalo:
   atacante suma exactamente 1 Kill y 50 Coins; víctima no recibe premio.
   Revisar una única línea de crédito "[PlayerService] +50 Coins ... Razón: SlapElimination".
   Solo el atacante ve "+50 Coins", monedas viajando hasta CoinTarget y escucha recompensa local.
   Ambos participantes mantienen el efecto de muerte de la víctima y notificación de V1.
5. Contactos múltiples: observar la misma caída con contactos de varias extremidades.
   Registrar un solo EliminationId aceptado y una sola diferencia de +50, no +100.
   La suite aislada preparada cubre además reenvío explícito de la misma clave;
   no fabricar créditos ni enviar remotes manuales para declarar PASS jugable.
6. Caída sin atacante: esperar más de 10 s sin golpes y caer.
   Debe verse DefaultFall y notificación de caída, sin incremento de Kill,
   sin Coins por Kill y sin animación/sonido de premio.
7. Gol válido: anotar sin Kill simultánea. Confirmar +50 Coins al anotador,
   marcador +1 y flujo de punto sin cambios. Una Kill y un gol distintos del mismo
   jugador suman +100 en total, cada uno por su propia causa.
8. Destino: en una segunda prueba, mover CoinTarget en Edit, guardar y repetir.
   Probar dos tamaños de ventana: las monedas deben llegar al centro real del destino.
   El script no debe cambiar la Position del recurso.
9. Aislamiento: el tercer cliente del lobby no debe recibir partículas, sonidos,
   notificaciones ni animación de monedas ajenas. La víctima no recibe la animación de premio.
10. Desconectar un participante durante una caída; no debe concederse dinero a un atacante
    ya desconectado ni recrearse su perfil. Si se desconecta DESPUÉS de acreditarse,
    el crédito ya ganado se conserva por el flujo de guardado existente, sin segundo premio.
11. Finalizar a cinco puntos, regresar al lobby y jugar otra partida.
    Comprobar ausencia de eventos/monedas pendientes, preferencias, Slap, reset,
    HUD existente y EndCinematic intactos. No habilitar otras modalidades.
12. Si falla: entregar Output completo servidor/atacante/víctima/lobby, SessionId,
    EliminationId, StateVersion, saldos/Kills antes y después, captura de CoinTarget y
    secuencia de acciones. Separar premios por gol de los de Kill.

| Verificación | Resultado actual |
|---|---|
| Kill válida: +50 y animación atacante | PENDIENTE manual |
| Caída sin atacante: 0 premio | PENDIENTE manual |
| Contactos/retransmisiones sin doble crédito | PENDIENTE manual; suite preparada |
| Gol conserva +50 | PENDIENTE manual; fuente sin cambios |
| Monedas llegan a CoinTarget y sonido local | PENDIENTE manual |
| Lobby y víctima sin animación de premio ajena | PENDIENTE manual |
| Desconexión/cierre/nueva sesión | PENDIENTE manual |
| Preferencias y sistemas existentes | PENDIENTE de regresión manual |
| CoinTarget y ScenarioFinal preservados | PASS de inspección Edit |
| Rojo build / git diff --check | PASS estático |

Sin Play, Run, Start Server, control de jugadores, partidas, commits, push,
publicaciones ni escrituras cloud. Implementación detenida hasta validación del desarrollador.
