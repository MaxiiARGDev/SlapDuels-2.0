# Economy Balance V1.0 + Slap Crates V1.3

Implementación sincronizada con Studio **Edit**. Validación funcional real **PENDING** hasta recibir resultados del desarrollador. No se ejecutó Play, Run, Team Test, Start Server ni se controlaron personajes. Sin commits, push, publicación o escrituras cloud.

## Auditoría y fuente de verdad

| Ruta | Antes | Ahora / función |
|---|---|---|
| src/shared/Config.luau — Match.PointReward | 50 | **150**, fuente única de recompensa por gol |
| src/shared/Config.luau — Economy.KillRewardCoins | 50 | **30**, fuente única de recompensa por Kill |
| ScoreService._commitPoint | Config con fallback literal 50 | Lee Config directamente; conserva Goal:PointId y todos los bloqueos |
| PlayerService.AwardConfirmedKill | Config.Economy.KillRewardCoins | Mismo contrato de atribución, pertenencia, conexión y deduplicación Kill:EliminationId |
| EliminationService | Recibo con importe efectivamente acreditado | Sin cambios; tercera palmada, StrongSlap y caída atribuida comparten AwardConfirmedKill |
| Caída sin atacante | 0 | Sin cambios, ni Kill ni recompensa |
| Muerte Súbita, gol colectivo | ScoringPlayer=nil, recompensa 0 | Sin cambios, no inventa destinatario personal |
| PointFeedbackService | Presentación de gol, no otorga Coins | Sin cambios; no determina economía |
| DeathEffectService / DeathFeedbackController | Recibo privado para atacante acreditado | Sin cambios; no otorgan Coins |
| KillRewardController | Presenta RewardCoins, sin constante económica | Mantiene +30 de recibo Kill; reutiliza la misma animación para recibo de gol +150 |
| PlayerHUDController | Anima saldo desde DataUpdated | Sin cambios, refleja el saldo real |
| EndCinematic / estadísticas | Goals/Kills/Deaths/MatchPoints | Sin cambios; los contadores no se convierten en Coins ni otorgan otra recompensa |

No se reemplazaron indiscriminadamente valores 50. No cambiaron precios de habilidades, Death Effects o Point Effects. No se modificaron definición/atribución de Kill, física, cooldowns, ragdoll, contador de tres golpes, Muerte Súbita, RoundService ni EndCinematic.

## Recibo de gol e integración visual

PlayerService.AddCoins conserva la deduplicación y el commit sin yields. Solo tras un crédito positivo MatchPoint con transacción Goal: emite un segundo argumento opcional en el RemoteEvent existente Player.DataUpdated: Kind=CreditedGoal, RecipientUserId, SessionId, EventId y RewardCoins=importe acreditado. El primer argumento sigue siendo el perfil habitual; no cambia el contrato de sus consumidores existentes ni persiste el recibo dentro del perfil. Un reintento duplicado retorna antes de emitirlo.

KillRewardController escucha ese recibo, valida destinatario/sesión/tipo, deduplica por sesión/evento y usa la animación existente de KillRewardHUD. La etiqueta muestra el importe del recibo; el contador global sigue actualizado únicamente por saldo autoritativo. No hay Remote de solicitud de dinero ni cantidades económicas elegidas por el cliente. La animación comparte CoinTarget, template, sonido y trayectorias existentes; la cantidad de partículas sigue siendo estética, no representa un Coin por sprite.

Las Kills conservan su canal DeathFeedback y su recibo basado en el resultado real de AwardConfirmedKill. Gol y Kill son operaciones económicas independientes.

## Precios oficiales

| CrateId | Coins | SortOrder | PriceApproved | OddsApproved | Enabled |
|---|---:|---:|---|---|---|
| Basic | 500 | 10 | true | false | false |
| Common | 1000 | 20 | true | false | false |
| Uncommon | 1750 | 30 | true | false | false |
| Rare | 3000 | 40 | true | false | false |
| Gold | 4500 | 50 | true | false | false |
| Arcoiris | 7000 | 60 | true | false | false |
| Emote | 10000 | 70 | true | false | false |
| Wings | 13500 | 80 | true | false | false |
| Epic | 19000 | 90 | true | false | false |
| Legendary | 27500 | 100 | true | false | false |
| Blood | 37500 | 110 | true | false | false |
| Galaxy | 50000 | 120 | true | false | false |

ApprovalStatus=OddsPending y descripción actualizada. Weights={}, stock y políticas conservados. Shop recibe estos precios del catálogo existente: precio real + «Probabilidades pendientes», compra bloqueada. No duplica una lista de precios dentro del cliente. SortOrder y flujo compra/apertura/ruleta/premio permanecen intactos.

**StudioTest sigue a 1 Coin**, SortOrder=1000, pesos ilustrativos Basic=3/Common=1, AllowDuplicates y solo Studio/InMemory con flag de Edit habilitado. Sus compras/aperturas idempotentes pasaron la regresión aislada; no se afirma una compra real nueva en Studio. PolicyService continúa obligatorio y falla cerrado. Producción sigue bloqueada.

## Alcance e integridad

Únicamente cinco fuentes runtime modificadas:

- src/shared/Config.luau
- src/shared/SlapCrates/CrateDefinitions.luau
- src/server/Services/ScoreService.luau
- src/server/Services/PlayerService.luau
- src/client/Controllers/KillRewardController.luau

Se añadieron tests/specs/validadores e informes EconomyBalanceV1 y SlapCratesV13; el runner aislado incorpora aliases de ScoreService, KillRewardController, EliminationService y CompetitiveTransit. Los specs históricos conservan sus expectativas originales; el generador produce suites con la economía actual. No se deben ejecutar suites históricas de balance 50/50 como criterio económico actual.

Respaldo previo de las cinco fuentes y manifiesto SHA-256 en tests/assets/backups/EconomyBalanceV1. **139 archivos originales src ajenos a la tarea conservan sus hashes**, incluidos habilidades, Death Effects, stock, inventarios, variaciones, ruleta, combate, persistencia, RoundService y EndCinematic.

Se sincronizaron los cinco módulos con guardas Before/After sobre Source y buffer de ScriptEditorService. Ambos hashes coinciden con los archivos finales. Evidencia: EconomyBalanceV1.studio-edit.json. No hubo escrituras en propiedades físicas, geometría ni layouts. Se inspeccionaron StarterGui.KillRewardHUD.CoinTarget y RewardAmountTemplate existentes.

## Validaciones

| Suite / verificación | Resultado |
|---|---|
| Economía: ScoreService, PlayerService, EliminationService, HUD reales con mocks | PASS: 30 aserciones |
| Slap Crates V1.3: precios exactos, presentación, bloqueos, compra/apertura StudioTest y reintentos | PASS: 199 |
| Combate/protección víctima/StrongSlap/tres golpes | PASS: 150 |
| Habilidades multijugador aislado | PASS: 164 |
| AbilityRegistry | PASS: 89 |
| Shop de habilidades / economía actual | PASS: 86 |
| Slap Variations Appearance | PASS: 19 |
| Total | **737 aserciones aisladas** |
| Compilación Luau | PASS: 116 scripts runtime + specs de economía/cajas |
| Rojo default.project.json | PASS |
| Rojo studio-safe.project.json | PASS |
| git diff --check | PASS; advertencias LF/CRLF del Working Tree, sin errores |
| Sincronización Edit | PASS: 5 fuentes Source/editor verificadas |
| Partida, presentación visual, audio y animación real | NOT RUN; desarrollador |

La suite económica ejecuta entradas reales HandleSlapThreshold/HandleAbilityHit y procesamiento de caída con perfiles simulados; verifica 30, Kills +1, recibos y rechazo de duplicados. Ejecuta ScoreService para gol 150 y duplicado, transacción repetida, caída posterior a gol protegida y gol colectivo sin receptor. El HUD real muestra +150/+30 con scope/tiempo simulados, destinatario y deduplicación. No equivale a observar combate o animación reales.

La selección Studio/InMemory/WritesToCloud=false se inspeccionó estáticamente en el módulo físico de persistencia sin requerirlo/inicializarlo. No se inició servidor, por lo que el diagnóstico runtime de esa nueva sesión lo debe confirmar el desarrollador antes de probar. No se modificó PRODUCTION_UNIVERSE_ID ni se accedió a DataStores reales.

Reproducir offline: ejecutar tests/tools/validate_economy_balance_v1.py con Python y el runtime local documentado. Evidencias en EconomyBalanceV1.checks.json, .integrity.json y logs por suite. Para prueba real seguir EconomyBalanceV1.manual.md. Detenerse hasta validación humana.
