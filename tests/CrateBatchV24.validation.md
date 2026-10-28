# Slap Crates V2.4 — auditoría, implementación y verificación

Fecha: 2026-10-19. Repositorio `H:\repos-github\SlapDuels-2.0`. Implementación instalada mediante MCP en **Studio Edit**, PlaceId 107328891970677. IsStudio=true e IsRunning=false observados. No se ejecutaron Play, Run, Start Server, Team Test ni aperturas reales. Aceptación funcional y visual: **PENDING del desarrollador**.

## 1. Arquitectura encontrada

El catálogo no requiere otro Registry: `SlapCrates.Catalog` compone Registry, definiciones de cajas/Slaps/variaciones y la matriz InitialOdds. Precios, aprobaciones y pesos viven allí. `Odds.Resolve` filtra recursos, propiedad y stock; divide pesos entre Slaps elegibles y normaliza. No se modificó ese algoritmo ni sus definiciones.

`CrateService` valida Player, lobby, perfil cargado, PolicyService y Quote. Usa el lock por jugador existente de ShopService. `CrateEngine` prepara el perfil; `PlayerService:CommitCrateState` realiza el único commit sin yield; `InMemoryStock`/StockLedger reservan y confirman unidades. `Inventory` conserva Crates, SlapUnits y CrateOperations durante normalización. No se duplicó el proveedor de inventario ni el servicio de compras.

`StandOpeningLedger` ya permitía leases privados por jugador; el bloqueo global y la espera se activaban mediante configuración. `StandOpeningService` adjudicaba el público y enviaba la presentación después del commit. El cliente instancia escenas locales y CameraLease preserva la cámara. CharacterVisibility y StandPromptVisibility son leases locales ligados a la secuencia.

V2.3 estaba realmente instalada: shutters, whooshes, entrada elevada/rebote, shake, overlay del stand desactivado y restauración. También estaba corregida la orientación de las cajas idle. Se conservaron esas implementaciones. El stand actual tenía 154 descendientes y difería de snapshots anteriores; se usó **la versión actual de Edit** como fuente.

## 2. Configuración final

En `OpeningConfig`:

```lua
AllowedOpenQuantities = {1, 5, 10}
BatchRevealDurations = {[5] = 4, [10] = 5}
Stand.ExclusiveOpening = false
Stand.ReopenCooldown = 0
```

Los demás parámetros del stand se preservaron. x1 continúa usando Cinematic.RewardRevealDuration, sin duplicar esa duración. Duraciones finales:

| Cantidad | Revelación | Secuencia total |
|---|---:|---:|
| x1 | 3 s | 10,5 s |
| x5 | 4 s | 11,5 s |
| x10 | 5 s | 12,5 s |

Todas quedan bajo MaxSequenceDuration=25. La misma cantidad y timeline se usan en el lease y en el cliente. No se conserva un deadline de cooldown con valor cero; el cliente limpia/oculta el contador antiguo. Permanecen rate limits y bloqueo de operaciones incompatibles de un mismo comprador.

## 3. Operación batch y garantías

Se extendió la acción **Open** del RemoteFunction existente con Quantity. Purchase sigue comprando **una sola caja**: seleccionar x5/x10 no hace compras masivas ni cobra más Coins. Cantidades ausentes equivalen a x1 por compatibilidad; números diferentes de 1/5/10, strings, NaN, infinitos y otros tipos se rechazan. Multi-open requiere StandCinematic; Spin continúa en x1.

Para x5/x10, CrateBatchEngine:

1. Copia el inventario y valida que tenga toda la cantidad solicitada.
2. Ejecuta una extracción independiente del catálogo por unidad.
3. Recalcula Odds.Resolve tras cada selección, considerando propiedad nueva y las reservas anteriores.
4. Reserva cada UnitId (UserId original + OperationId + índice), sin transformar IDs negativos de Studio.
5. Si alguna extracción/reserva falla, libera todas las reservas preparadas. No cambia el perfil original ni consume cajas.
6. Solo con el lote completo, resta la cantidad exacta, agrega todas las SlapUnits/Owned y crea **un recibo de lote**.
7. CrateService realiza un único CommitCrateState y después confirma el stock de todas las unidades.

El recibo incluye BatchId, Quantity y Rewards, además de los campos de la primera recompensa para compatibilidad. x1 conserva el contrato original de una unidad.

**Antes del commit:** un error/fallo de perfil libera las reservas, sin consumo ni concesión parcial. Si CommitCrateState lanza una excepción después de escribir, se comprueba la identidad del perfil autoritativo antes de decidir que falló; nunca se libera stock de un premio ya adjudicado.

**Después del commit:** todas las recompensas ya están juntas en el perfil. Un fallo de confirmación deja el recibo GrantCommitted y retiene las reservas; devuelve StockCommitPending. El cliente conserva Quantity y OperationId para reintentar. Reconcile confirma esas mismas unidades, sin sortear ni consumir otra vez. Mientras hay un recibo pendiente se rechazan otras transacciones de cajas incompatibles. La consulta de inventario también permite reconciliar.

Se corrigió un defecto descubierto por las pruebas: el replay devolvía un recibo de la copia de staging. Ahora devuelve la entrada real de CrateOperations, por lo que State y PresentationSent se actualizan en el perfil autoritativo. Cambiar cantidad, caja o tipo de acción reutilizando un ID produce OperationConflict. Un recibo ya presentado no reinicia la presentación.

Una operación explícitamente abortada antes del commit conserva tombstones Released del stock. Un nuevo intento tras un rechazo definitivo utiliza un nuevo OperationId. Los reintentos de una operación **ya concedida o sin confirmación** mantienen el mismo ID. No se promete volver a sortear una reserva abortada bajo la misma identidad.

## 4. Stock, duplicados y Quotes

Se reutilizan StockLedger y DuplicatePolicy existentes. UniquePerPlayer excluye también los premios escogidos antes en el mismo lote. AllowDuplicates puede producir unidades distintas del mismo RewardId si esa política lo permite. Se confirman identidades de unidad distintas; no se clona diez veces una decisión aleatoria.

El Quote conserva la distribución inicial y su firma de stock/elegibilidad. Se revalida antes de preparar el lote; después las extracciones se ejecutan sin yield sobre el mismo servidor. La UI muestra el aviso: las extracciones posteriores recalculan elegibilidad/stock y pueden tener probabilidades efectivas diferentes. No se inventan porcentajes x5/x10 ni se garantiza la misma distribución marginal para todos los índices.

Si hay stock para tres premios y se solicitan cinco, la preparación falla y libera los tres; no entrega parcialmente. Pruebas con dos compradores y un stock compartido simulado de 15 comprobaron que x10 reservado impide otro x10, pero deja exactamente cinco para un lote posterior.

## 5. Privacidad, concurrencia y cancelación

Sin exclusividad, Ledger.Stands no adquiere una reserva global. Cada comprador conserva su propio lease, OpeningId, plan, escena, cámara y resultados. Los paquetes Opening/Cancel privados se envían solo al comprador; los espectadores no reciben escenas ni ocultamiento. El estado global del stand sigue Idle. Los previews idle se ocultan solo para el comprador de ese stand durante su propia secuencia; la corrección de su orientación permanece.

Se agregó CancelOpening al RemoteFunction existente para liberar limpiamente la presentación al terminar/cancelar el cliente. Verifica Player y OpeningId contra Active del propio UserId, con limitación de frecuencia independiente. Una cancelación tardía no puede cerrar una apertura nueva ni la de otro jugador. Cancela **solo el lease visual**, no revierte premios ni devuelve cajas ya consumidas. Si el aviso se pierde por red, el deadline del servidor sigue siendo el fallback de limpieza.

La muerte/cambio de Character, alejamiento/contexto o desconexión mantienen la limpieza existente del servidor. CharacterVisibility, CameraLease y StandPromptVisibility no se refactorizaron. El cliente libera cámara, controles, música, personajes, prompt, shutters y objetos locales mediante el ciclo existente.

## 6. UI y galería

`ShopHUD.CratePanel.OpenQuantities.X1/X5/X10` son botones **permanentes de Edit**, clonados del estilo Open existente. x1 es inicial. La cantidad seleccionada tiene fondo opaco y atributo Selected; las demás, fondo atenuado. Incluyen AutoButtonColor para interacción/press, feedback de hover, texto escalado y estados deshabilitados. Cuando faltan cajas muestran la cantidad faltante; ABRIR xN no puede ejecutarse. Reintentos muestran REINTENTAR xN y conservan la cantidad original.

Solo se extendió el panel de cajas. Para dejar espacio se redujo la altura de OddsList/Outcomes. CrateActionsTemplate conserva su ruta de acceso al panel y no requiere otro selector por tarjeta. No se cambió CardTemplate compartido ni ShopController ni categorías de habilidades/efectos.

x1 conserva el premio 3D/billboard original. x5/x10 usan una caja y una secuencia, seguidas de modelos locales adjudicados por el servidor:

- x5: fila centrada de cinco en landscape.
- x10: dos filas de cinco en landscape.
- Pantalla portrait: hasta tres columnas y más filas para mantener el encuadre.
- Cada premio tiene modelo, nombre, variación y color autorizados; Appearance reutiliza los recursos actuales.
- Entrada escalonada cada 0,08 s con escala/elevación de 0,24 s. Los diez terminan de aparecer en menos de un segundo.
- Tratamiento discreto de rarezas y presupuesto de revelación de hasta 40 partículas por galería; sin emisiones repetidas por frame.
- La cámara calcula espacio según FOV, aspecto y margen; se aleja durante Flash si hace falta y mantiene la colección en Reward. No se cambia otra modalidad de cámara.

No se reactivó RewardOverlay del stand. El billboard original se deshabilita en el lote para que no duplique el título de las tarjetas 3D. El overlay compartido permanece instalado para sus usos futuros/existentes.

## 7. Objetos y preservación de Edit

Objetos nuevos:

- `StarterGui.ShopHUD.CratePanel.OpenQuantities` y sus botones X1/X5/X10.
- `ReplicatedStorage.UIAssets.CrateBatchRewardSlot`, Model editable con Anchor invisible y BillboardGui (Slap, Variation y componentes del estilo original).
- Cuatro ModuleScripts nuevos, listados abajo.

El Anchor usa Anchored=true, Transparency=1, CanCollide/CanTouch/CanQuery=false. El template no se coloca globalmente en el stand: se clona solo en la VM cliente. Sus textos son editables en Edit.

Antes de editar se guardaron snapshots binarios nativos del stand, ShopHUD y CrateOpeningHUD, fuentes previas, estado Git y hashes en `tests/assets/backups/CrateBatchV24/`. No se borraron respaldos anteriores ni se cerró/guardó/sobrescribió el lugar.

Comprobación posterior:

- Stand **byte idéntico** al respaldo: 154 descendientes, SHA-256 `308e97088596283e1ed8a742f019b6b2e13df16c3dd14bda26eaf34676963ab7`.
- CrateOpeningHUD byte idéntico al snapshot vigente V2.3.
- Comparación de 358 instancias originales y 1.749 propiedades seleccionadas: solo las dos alturas autorizadas de OddsList y Outcomes cambiaron.
- ShopHUD final: 191 descendientes; template de galería: 18.
- No hay recursos/módulos nuevos duplicados. Los clones de verificación se destruyeron sin Parent en el DataModel.

Snapshots finales están en `src/assets/CrateBatchV24/`; default.project referencia el stand actual, ShopHUD actual y template nuevo. Las fuentes V2.1/V2.3 antiguas no se importaron sobre el arte actual. SAFE sigue siendo scripts-only; futuras modificaciones de arte en Edit requieren reexportar antes del full sync.

## 8. Archivos de implementación

Modificados (fuentes runtime):

- `src/client/Controllers/CrateController.luau`
- `src/client/Controllers/CrateStandCinematicController.luau`
- `src/client/CrateOpening/CinematicConfig.luau`
- `src/server/Services/CrateService.luau`
- `src/server/Services/Crates/CrateEngine.luau`
- `src/server/Services/Crates/StandOpeningLedger.luau`
- `src/server/Services/Crates/StandOpeningService.luau`
- `src/shared/SlapCrates/CrateShopView.luau`
- `src/shared/SlapCrates/OpeningConfig.luau`
- `src/shared/SlapCrates/OpeningTimeline.luau`

Módulos nuevos:

- `src/shared/SlapCrates/BatchOpening.luau` — contrato de cantidad/recibos, sin autoridad cliente.
- `src/server/Services/Crates/CrateBatchEngine.luau` — staging/reservas del lote, exclusivamente servidor.
- `src/client/CrateOpening/RewardGalleryLayout.luau` — distribución/frustum.
- `src/client/CrateOpening/RewardGallery.luau` — presentación local de premios confirmados.

Recursos/mapas:

- `src/assets/CrateBatchV24/MainCrateStand.rbxm`
- `src/assets/CrateBatchV24/ShopHUD.rbxm`
- `src/assets/CrateBatchV24/CrateBatchRewardSlot.rbxm`
- `src/assets/CrateBatchV24/manifest.json`
- `default.project.json`
- `studio-safe.project.json` (regenerado).

Pruebas nuevas: `tests/CrateBatchV24.extension.luau`, `.spec.luau`, `.gallery.spec.luau`, `tests/tools/crate_batch_v24_spec.py`, `tests/tools/validate_crate_batch_v24.py`.

Fixtures actualizados: `tests/SlapCratesV1.spec.luau`, `tests/SlapCratesV2.extension.luau`, `tests/CrateOddsV13.extension.luau`, `tests/CrateVisibilityV22.spec.luau`, `tests/tools/run_ability_unit_tests.py`. Los casos históricos de exclusividad/cooldown usan una copia explícita de configuración; los nuevos tests verifican los valores reales de V2.4. Se regeneraron specs compuestos V1.3/V2/Odds/V2.1/V2.3. El inventario exacto de artefactos está en `tests/CrateBatchV24.files.json`.

La comparación SHA de todo src previo confirmó diez fuentes modificadas previstas y **159 archivos originales restantes sin cambios**. Incluye reglas económicas, definiciones, SlapService, RoundService, EndCinematic, persistencia y otros recursos.

## 9. Pruebas y límites

| Suite | Resultado aislado |
|---|---|
| Batch + regresión previa de cajas | PASS: 1.353 aserciones |
| Constructor/update reales de galería con modelos simulados | PASS: 88 |
| Cinemática V2.3 + ciclo de visibilidad V2.2 | PASS: 1.931 |
| Economía / combate / habilidades / registry / Shop | PASS: 30 / 150 / 164 / 89 / 86 |
| Compilación Luau | PASS: 135 scripts runtime y specs batch/galería |
| Build completo y SAFE | PASS, jerarquías y snapshots verificados |
| `git diff --check` | PASS; advertencias LF/CRLF existentes |
| MCP Edit | PASS: Source y editor coinciden por SHA en los 14 módulos afectados |

Total: 3.891 ejecuciones de aserciones, con fixtures compartidas y muestreos matemáticos; no son 3.891 pruebas de jugabilidad independientes. El simulador mantiene además las comprobaciones estadísticas históricas del catálogo. No se ejecutó una transacción real en Studio.

Matriz de los 38 puntos pedidos. **PASS aislado no equivale a aceptación funcional**:

| Puntos | Evidencia | Estado real en Play |
|---|---|---|
| 1–2. Cooldown cero y reapertura | Config real, Ledger.Release/Acquire, ausencia de deadline | NOT RUN |
| 3–5. Simultáneos, IDs, sin lock global | Dos x10 activos, solo audiencias compradoras, Stands vacío | NOT RUN |
| 6–8. x1/x5/x10 | Validación de contrato, estado GetView y botones físicos inspeccionados | NOT RUN táctil/hover |
| 9–10. Cantidades falsas/inventario | Request real con args falsos y rechazo íntegro | NOT RUN |
| 11–16. Consumo/entrega exactos | Perfil y SlapUnits de 1/5/10 | NOT RUN |
| 17–18. Idempotencia/incompatibles | Replay, IDs con cantidad distinta y lease activo | NOT RUN red real |
| 19–21. Stock/duplicados/último | Limited3, shared15, Unique10, último elegible | NOT RUN; no habilitar comerciales |
| 22–24. Fallos/recuperación | Reserve que falla después de reservar, commit rechazado, excepción tras escribir perfil, confirmación de stock fallida y retry | NOT RUN con proveedor real |
| 25. Cinemática x1 | Regresión de secuencia/lease, ruta original | NOT RUN visual |
| 26–27. Cinco/diez premios | Create/Update real con modelos mock: exactamente 5/10, escalonado y cleanup | NOT RUN render |
| 28. Resoluciones | Límites de frustum portrait/landscape/ultrawide, adaptación del constructor | NOT RUN legibilidad |
| 29. Overlay no duplicado | Controlador real no llama a Presenter.Show del stand | NOT RUN visual |
| 30–32. Personajes/prompt/cámara | Regresión V2.2/V2.3 con señales y leases simulados | NOT RUN multicliente |
| 33–34. Cancelación/desconexión | Release/Cancel con identidad, propietario, cancelación tardía y limpieza | NOT RUN red/cliente real |
| 35. Dos x10 simultáneos | Dos operaciones/leases autoritativos sobre fixtures | NOT RUN con clientes reales |
| 36. Spin | Regresión anterior y rechazo de multi-open fuera del stand | NOT RUN visual |
| 37. Economía | Suites y hashes, StudioTest=1, aprobación comercial bloqueada | Sin compras reales |
| 38. Arte preservado | Hash binario del stand y comparación de originales en Edit | PASS de inspección Edit |

## 10. Producción y pendientes

Se mantienen las guardas **Studio / InMemory / WritesToCloud=false** y ProductionBackendBlocked. La selección de proveedor se verificó por código/pruebas aisladas; no se inició un servidor para observar diagnósticos runtime. Gol=150, Kill=30, precios, pesos, aprobaciones y PRODUCTION_UNIVERSE_ID permanecen sin cambios. No hubo commits, push, publicación ni escrituras cloud.

Las garantías de reservas/staging/commit son para el proveedor InMemory de **un servidor** y su ruta sin yield. No hay atomicidad global ni recuperación durable tras cerrar/crashear ese servidor. Producción requiere proveedor durable, coordinación de stock entre servidores, estrategia de journal/outbox y pruebas de fallos reales antes de habilitarse. Los límites existentes de journal (256 recibos de perfil y 1024 operaciones de stock) siguen siendo finitos; los lotes usan varias unidades de stock. No se implementó compacción ni se alteró ese contrato.

Quedan pendientes tu validación visual/multicliente, legibilidad móvil, audio existente y comportamiento bajo latencia real. Si una restricción de PolicyService impide StudioTest, marcar BLOCKED, sin bypass. No se cambiaron SoundIds en esta tarea.

Guardar normalmente el lugar conserva los cambios Edit en disco. Ver `tests/CrateBatchV24.manual.md`. Implementación detenida hasta tu validación.
