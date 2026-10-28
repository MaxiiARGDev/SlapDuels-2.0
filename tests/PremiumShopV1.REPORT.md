# Premium Shop V1.0 — Implementación para revisión, pagos deshabilitados

No se ejecutó Play, Run, Start Server, Team Test ni compras reales. No se publicaron cambios ni se hicieron commits/push. No se escribieron datos cloud ni se cambió el Universe ID aprobado. La prueba visual realizada fue una preview estática en Edit, sin ejecutar controladores ni servicios; sus clones temporales fueron retirados.

## Arquitectura y auditoría

No existe EconomyService en este proyecto: PlayerService es la fuente actual de Coins/inventario y PlayerDataService gestiona la persistencia. No se encontró ningún ProcessReceipt previo en src ni en las fuentes legibles del DataModel. ShopService conserva compras/equipamiento con Coins; CrateService conserva resolución, stock, consumo, inventario y presentaciones. No se creó otro motor económico ni de apertura.

Se reutilizan el catálogo de slaps/variaciones, Inventory, Owned.DeathEffects y CrateService. Los slaps garantizados usan RewardId SlapId:VariationId y SlapUnits, y los Kill Effects usan las definiciones actuales. No se inventaron exclusivos ni se modificó combate, Kills, recompensas o equipamiento.

**Tienda Coins:** `Workspace.Shops.CoinShop.InteractionPart.ProximityPrompt` → CoinShopAccessService → `ReplicatedStorage.Remotes.Shop.CoinShopAccess` → ShopController → `StarterGui.ShopHUD`. El servidor comprueba identidad del punto/prompt, conexión, personaje vivo, lobby y distancia máxima min(12, MaxActivationDistance). El cliente no decide la autorización del prompt.

El botón anterior ShopHUD.ShopButton permanece físicamente, oculto. Sus objetos, estilo y UIEffects se preservaron. Se conserva el acceso legítimo a Crates desde el stand y el acceso a cajas Premium ya poseídas mediante el inventario existente. Las ofertas Premium no poseídas se filtran de la tienda Coins; no se elimina su acceso al inventario.

**Tienda Premium:** `StarterGui.PlayerHUD.PremiumShopButton` → PremiumShopController → `StarterGui.PremiumShopHUD` → `ReplicatedStorage.Remotes.PremiumShop.Request`. Solicitudes: Catalog, Odds y Purchase. Purchase rechaza siempre con PurchasesDisabled en V1.0. Los remotes se crean/enlazan al iniciar sus servicios, conforme al patrón existente; sus callbacks no se ejecutaron en Edit.

ShopController y PremiumShopController cierran la otra interfaz. Premium cierra el panel de cajas al abrirse; ir a inventario desde Premium cierra Premium. Las restricciones de partida/resultados/cinemática y el cierre al iniciar opening privado evitan superposición. La interfaz Premium no toma la cámara ni bloquea controles. PlayerHUD, ShopHUD y PremiumShopHUD tienen ResetOnSpawn=false.

## Registro y configuración

Registro autoritativo: `ServerScriptService.PremiumShop.PremiumProductRegistry`. Requiere explícitamente CoinPackages, PremiumCombos y PremiumCrates; nunca descubre/requiere hijos arbitrarios. Rechaza IDs internos/ProductIds duplicados, ProductIds inválidos, cantidades inválidas, IDs inexistentes y tipos de recompensa desconocidos. El cliente recibe una proyección pública para renderizar; sus datos no se usan para decidir contenidos o entregas.

Configuración: `ReplicatedStorage.Shared.PremiumShop.PremiumShopConfig`:

| Campo | Inicial |
|---|---|
| PremiumShopEnabled | true |
| PurchasesEnabled | false |
| CoinPackagesEnabled / CombosEnabled / PremiumCratesEnabled | true |
| DefaultCategory | Coins |
| VisualTheme | NightArcade |
| DurableCommerceValidated | false |
| CoinShopDistance | 12 |

Además de flags, el endpoint de compra permanece bloqueado expresamente y el coordinador no tiene backend durable. Cambiar una configuración cliente o un flag no habilita pagos.

Catálogos editables:

- `src/shared/PremiumShop/Catalog/CoinPackages.luau`: un borrador Coins_Draft, Rewards.Coins=0 significa **cantidad pendiente**, no oferta gratuita. No se aprobó el ejemplo conceptual de 1.000 Coins.
- `src/shared/PremiumShop/Catalog/PremiumCombos.luau`: Combo_Draft vacío, sin exclusivos inventados. Rewards admite Coins, Crates cerradas, Slaps garantizados y KillEffects registrados.
- `src/shared/PremiumShop/Catalog/PremiumCrates.luau`: tres productos que referencian las definiciones de cajas existentes en el motor común.

Para agregar un paquete: copiar una definición del grupo, usar Id único, metadatos, Rewards.Coins y DeveloperProductId real cuando exista. Para un combo: incluir únicamente IDs registrados en Rewards.Crates ({CrateId,Quantity}), Rewards.Slaps ({SlapId,VariationId}) y Rewards.KillEffects (IDs). Los módulos de grupo forman la lista autorizada explícita; si se divide un producto en otro ModuleScript, agregar su require explícito dentro del grupo. No habilitar ventas por completar esos datos solamente.

Duplicados: se prepararon OncePerPlayer, RestrictOwned y RepeatableNoCompensation. El combo inicial sigue Unspecified y bloqueado. No se inventaron compensaciones. Los garantizados con stock limitado permanecen bloqueados por falta de transacción durable conjunta de stock/perfil. Antes de vender, revisar además compras repetidas externas a la experiencia: un Developer Product repetible no debe listarse como compra única sin una resolución aprobada para esos recibos.

## Tres cajas Premium

Definiciones: `src/shared/SlapCrates/PremiumCrateDefinitions.luau`, agregadas explícitamente por CrateDefinitions al Catalog común.

| CrateId | Nombre provisional | Modelo editable |
|---|---|---|
| PremiumI | Premium I | ReplicatedStorage.CrateEffects.PremiumI |
| PremiumII | Premium II | ReplicatedStorage.CrateEffects.PremiumII |
| PremiumIII | Premium III | ReplicatedStorage.CrateEffects.PremiumIII |

Colores provisionales violeta, azul y magenta con detalles dorados/cian. Modelos nativos sin AssetIds nuevos, scripts ni física activa. Cada modelo tiene PremiumFX/PremiumSparkles de su color, reutilizando una textura existente: Rate=0, desactivado, bursts acotados en Appear/Growth/Flash. El perfil visual existente emite esos bursts únicamente en cajas Premium; las cajas anteriores conservan su camino. Los previews quedan desactivados. Stock real se configura en StockDefinitions por recompensa/variación; StockRules de cada caja es un placeholder, no un segundo contador de stock. Los pesos están **vacíos y pendientes**; no representan probabilidades comerciales. No hay garantía de premios excepcionales. Stock y contenidos deben aprobarse antes de habilitar.

Las tres tienen PremiumOnly=true, Enabled=false, OddsApproved=false, OpeningApproved=false y ningún precio Coins. El motor rechaza comprarlas por Coins. Para cajas Premium previamente poseídas, el mismo motor puede abrir sin cargo de Coins cuando exista aprobación de apertura; la prueba aislada con configuración ficticia verificó x1/x5/x10. No se habilitaron esas configuraciones en Studio ni en las definiciones reales.

La presentación se enruta por el sistema actual: StandCinematic y su spin 3D/galería. El acceso a apertura requiere interactuar con el stand, mantener la distancia y obtener Quote actual. No se duplicaron OpeningTimeline, RNG ni controladores de revelación.

## Recibos, persistencia y bloqueos productivos

`PremiumShopService.Start` contiene la única asignación de MarketplaceService.ProcessReceipt. `ReceiptCoordinator` valida PlayerId, ProductId, PurchaseId, registro autorizado y aprobación. No utiliza PromptProductPurchaseFinished para otorgar. El cliente solo tiene preparada la llamada oficial PromptProductPurchase, condicionada a autorización del servidor; V1.0 nunca la emite. Esto sigue el contrato de [Developer Products](https://create.roblox.com/docs/production/monetization/developer-products).

Sin backend durable devuelve NotProcessedYet, incluso con InMemory. Con un futuro backend validado, solo puede devolver PurchaseGranted después de una confirmación durable con los mismos tres identificadores. Los duplicados concurrentes locales se difieren. El backend deberá resolver también deduplicación entre servidores y reintentos. [Contrato oficial de ProcessReceipt](https://create.roblox.com/docs/reference/engine/classes/MarketplaceService#ProcessReceipt).

`PremiumGrantPlan.Stage` es una preparación pura, sin efectos externos: produce una copia del perfil con Coins, cajas, slaps, DeathEffects y PurchaseId juntos. Conserva estadísticas/equipamiento. Repetir el mismo recibo retorna el estado previo, sin otro premio. Inventory.Preserve conserva los journals PremiumReceipts/PremiumPurchases para una futura integración. **Este plan no se conecta a una entrega real ni constituye persistencia durable.**

El backend ApplyReceiptAtomic todavía **no está implementado ni instalado**. Deberá integrar propiedad de sesión del perfil, serialización con guardados/jugabilidad, grant+journal atómicos, confirmación durable, recuperación tras desconexión y conciliación del estado runtime de PlayerService. No sirve llamar AddCoins y luego guardar el recibo en otra escritura. La [guía de datos y compras de Roblox](https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing) distingue cambios en memoria de confirmación persistida.

Antes de ventas reales faltan: backend durable validado; catálogo/contratos versionados e IDs históricos; resolución de compras repetidas/propiedad; stock durable donde corresponda; ProductIds reales; contenidos/cantidades; precios consultables; revisión de políticas y Odds; pruebas de fallos/reconexión entre servidores; autorización humana para habilitar el endpoint de prompt. No basta cambiar PurchasesEnabled=true.

## PolicyService y probabilidades

Coins son fungibles y podrían financiar cajas indirectamente. Se conserva la protección conservadora existente de CrateService: **todas** las compras/aperturas aleatorias de cajas pasan por ArePaidRandomItemsRestricted, incluidas cajas normales, de combos o Premium. Un error o dato ausente bloquea el acceso aleatorio; no se acepta una declaración del cliente ni un bypass Studio. Los progresos/cosméticos no aleatorios existentes permanecen disponibles. [Política oficial de artículos aleatorios pagados](https://create.roblox.com/docs/production/monetization/paid-random-items).

PremiumEligibility aplica política a combos/cajas aleatorios y considera IsPaidItemTradingAllowed; falla conservadoramente si el servicio no responde. No hay sistema de intercambio actual: el flag no habilita ninguno. Un futuro trading requerirá su propia validación autoritativa.

Odds en detalles delega al Quote de CrateService: resultados numéricos por RewardId, exclusiones por propiedad/stock y aviso de recálculo por extracción. La compra/apertura común sigue invalidando Quotes vencidos o modificados. Las cajas Premium sin aprobación muestran pendiente; no se calculan números ficticios. Los pagos siguen bloqueados hasta validar todas las rutas, incluida la compra indirecta con Coins.

Los precios solo se consultan mediante GetProductInfoAsync con InfoType.Product cuando existe un ProductId configurado; una respuesta inválida/no disponible no crea un precio. No se usó ningún precio Robux hardcodeado. No se consultaron productos reales durante esta entrega.

## Recursos y sincronización

Recursos persistentes inspeccionados en Edit:

| Ruta | Descendientes |
|---|---:|
| StarterGui.PremiumShopHUD | 58 |
| StarterGui.PlayerHUD.PremiumShopButton | 3 |
| Workspace.Shops.CoinShop | 7 |
| ReplicatedStorage.PremiumShopPreviews | 38: cinco modelos |
| ReplicatedStorage.CrateEffects.PremiumI / PremiumII / PremiumIII | 7 cada uno |

PremiumShopHUD tiene dim, panel azul noche con gradiente y bordes violetas, tres pestañas, catálogo con scroll y plantilla ProductCardTemplate. Cada tarjeta tiene ViewportFrame/WorldModel/Camera, nombre, descripción, contenido, precio, disponibilidad y botón COMPRAR. El panel Details tiene scroll de contenidos/Odds, compra bloqueada y acceso al inventario de cajas. El grid usa dos columnas en PC y una en ancho menor a 620 px. Se anima la apertura y se limpian tarjetas, conexiones y previews al cerrar; no se modifican cámaras globales. Apariencia móvil real pendiente de prueba humana.

Snapshots actuales y SHA-256: `src/assets/PremiumShopV1/manifest.json`. `default.project.json` usa estos recursos completos, evitando superponer snapshots antiguos. SAFE conserva su configuración scripts-only con ignoreUnknownInstances=true. No sincronizar recursos desde un proyecto viejo sobre el diseño actual.

Respaldo previo: `tests/assets/backups/PremiumShopV1/` contiene ShopHUD 348, PlayerHUD 54, MainCrateStand 154, fuentes previas, manifiesto de hashes y estado Git. El snapshot nuevo de ShopHUD conserva las mejoras recientes que no estaban en el snapshot V2.5 de 200 objetos. La comparación de todas sus propiedades/hijos contra el respaldo permitió solo ShopButton.Visible=false. En PlayerHUD no cambió ninguna propiedad previa: únicamente se añadió el botón con sus tres decoraciones. Los nombres duplicados preexistentes del ShopHUD se preservaron; no se eliminaron como parte de esta tarea.

MainCrateStand coincide byte por byte con su respaldo. No se modificó su diseño físico, VisualDecor ni cámaras. Las plantillas nuevas no contienen scripts ni recursos temporales. No se cerró ni se guardó/sobrescribió el lugar del desarrollador.

20 fuentes sincronizadas y verificadas contra Source/editor por SHA-256. Evidencia: `tests/PremiumShopV1.studio-edit.json`. La resolución del proveedor en Edit confirmó **Studio / InMemory / WritesToCloud=false**; no se inicializaron perfiles de juego. La comprobación runtime deberá realizarla el desarrollador al probar.

## Archivos

Doce scripts nuevos:

- `src/shared/PremiumShop/PremiumShopConfig.luau`
- `src/shared/PremiumShop/Catalog/CoinPackages.luau`
- `src/shared/PremiumShop/Catalog/PremiumCombos.luau`
- `src/shared/PremiumShop/Catalog/PremiumCrates.luau`
- `src/shared/SlapCrates/PremiumCrateDefinitions.luau`
- `src/server/PremiumShop/PremiumProductRegistry.luau`
- `src/server/PremiumShop/PremiumGrantPlan.luau`
- `src/server/PremiumShop/PremiumEligibility.luau`
- `src/server/PremiumShop/ReceiptCoordinator.luau`
- `src/server/Services/PremiumShopService.luau`
- `src/server/Services/CoinShopAccessService.luau`
- `src/client/Controllers/PremiumShopController.luau`

Ocho fuentes previas modificadas: Bootstrap.server, ShopController, CrateStandCinematicController (cierre de Premium y bursts propios de las cajas nuevas), CrateService, CrateEngine (gate Premium y apertura sin precio Coins), CrateDefinitions, CrateShopView e Inventory. Ver rutas completas en `tests/PremiumShopV1.checks.json`. Otros **178 archivos previos de src** conservan sus hashes. También se añadieron recursos/pruebas/informes y se actualizaron los mapas normal/SAFE; no se confunden estos cambios con los numerosos cambios locales anteriores.

## Verificaciones

Compilación de **153 scripts src y spec**, ambos builds Rojo, validación de recursos/propiedades, SAFE y git diff --check: **PASS**. **6.952 ejecuciones de aserciones aisladas**, no pruebas de jugabilidad: 83 nuevas de Premium, 1.375 de la base motor/servicio, 2.956 reveal, 88 galería, 1.931 cinemática/ciclo de vida, 30 economía, 150 combate, 164 habilidades, 89 registry, 86 Shop. Las suites comparten fixtures; no son 6.952 escenarios funcionales independientes.

Resultados: `tests/PremiumShopV1.checks.json`, `tests/PremiumShopV1.*-results.txt` y logs/builds del mismo prefijo. Reproducción offline: ejecutar `tests/tools/validate_premium_shop_v1.py` con el Python del entorno. No inicia Studio ni realiza compras.

| # | Prueba solicitada | Evidencia / límite |
|---:|---|---|
| 1 | Apertura física normal | Prompt PASS Edit; validador distancia/lobby PASS aislado; apertura real NOT RUN |
| 2 | Apertura Premium desde HUD | Botón/UI PASS Edit; wiring inspeccionado; input real NOT RUN |
| 3 | Independencia de interfaces | Jerarquías separadas PASS Edit; transiciones reales NOT RUN |
| 4 | Catálogo Coins | Servicio público y borrador PASS aislado |
| 5 | Registro de paquetes | Registro explícito/duplicados/IDs PASS aislado |
| 6 | Registro de combos | PASS aislado |
| 7 | Contenidos de combos | IDs, cantidades y premios desconocidos PASS aislado |
| 8 | Duplicados permanentes | RestrictOwned, OncePerPlayer y RepeatableNoCompensation PASS aislado |
| 9 | Tres cajas registradas | Exactamente tres PASS aislado + modelos PASS Edit |
| 10 | Precio sin configurar | nil/no solicitud real/no precio inventado PASS aislado |
| 11 | ProductIds inválidos | PASS aislado |
| 12 | Productos deshabilitados | PASS aislado |
| 13 | Pagos deshabilitados | Endpoint servidor rechaza contenidos/precio cliente PASS aislado |
| 14 | Recibos repetidos | Plan+coordinador con backend ficticio PASS aislado |
| 15 | Reintentos | Error/confirmación durable ficticia PASS aislado |
| 16 | Desconexión durante intento | Corutina, fallo y liberación in-flight PASS aislado |
| 17 | Confirmación sin entrega pendiente | Solo confirmación durable de identidad coincidente PASS aislado; backend real BLOCKED |
| 18 | Otorgamientos dobles | Replay y concurrencia mientras yield PASS aislado |
| 19 | Cambios de stock | Regresión Quote/reservas/rollback PASS aislado |
| 20 | Restricciones aleatorios | Restricción/error PolicyService PASS aislado |
| 21 | Probabilidades visibles | Contrato Quote por RewardId PASS aislado; UI real NOT RUN; Premium pendiente BLOCKED |
| 22 | Inventario | Staging conserva esquema/estadísticas/equipamiento PASS aislado; entrega real BLOCKED |
| 23 | x1/x5/x10 | Motor común con fixture Premium habilitada solo offline PASS aislado; cajas reales BLOCKED |
| 24 | Cinemática | Regresión aislada PASS; opening real Premium BLOCKED por aprobación pendiente |
| 25 | Móvil | Reglas de grid/scroll inspeccionadas; emulación real NOT RUN |
| 26 | Preservar ShopHUD | Comparación completa de propiedades/jerarquía PASS; solo botón oculto |
| 27 | Economía/recompensas | Regresión y hashes PASS aislado/estático; jugabilidad NOT RUN |

## ProductIds y precios pendientes

| Id interno | DeveloperProductId | Precio Robux | Otros pendientes |
|---|---|---|---|
| Coins_Draft | nil | No consultable | Cantidad, nombre/arte final y aprobación |
| Combo_Draft | nil | No consultable | Contenidos, duplicados y aprobación |
| PremiumI | nil | No consultable | Contenidos/Odds/stock y aprobación |
| PremiumII | nil | No consultable | Contenidos/Odds/stock y aprobación |
| PremiumIII | nil | No consultable | Contenidos/Odds/stock y aprobación |

No se crearon productos en Creator Dashboard. Los IDs/precios de los tests son fixtures locales ficticias y nunca se configuran como ofertas.

## Guía de validación manual

1. Guardá tu lugar con tu procedimiento habitual. Mantené Rojo **Scripts Only SAFE**; los recursos ya están en Edit. No ejecutes el instalador nuevamente ni importes snapshots viejos sobre ShopHUD.
2. Iniciá vos Play y, antes de probar acciones económicas, verificá en Command Bar Server:

```lua
assert(game:GetService("RunService"):IsStudio())
local d=require(game.ServerScriptService.Services.PlayerDataService):GetPersistenceDiagnostics()
assert(d.Environment=="Studio" and d.ProviderName=="InMemory" and d.WritesToCloud==false,"ABORTAR: persistencia no aislada")
print(d.Environment,d.ProviderName,d.WritesToCloud)
```

3. Acercate a Workspace.Shops.CoinShop y activá el prompt. Debe abrir el ShopHUD con su diseño reciente y categorías existentes. El botón normal anterior no debe verse. Desde fuera del radio no debe abrir mediante el prompt. No se exige estar cerca para todas las acciones de inventario ya existentes; la validación agregada corresponde al punto de apertura física.
4. Cerrá normal y pulsá TIENDA PREMIUM a la derecha del HUD. Revisá Coins, Combos y Cajas Premium, scroll, previews y panel de detalles. Las cinco ofertas deben mostrar contenidos/precios pendientes y COMPRAR bloqueado. **No debe aparecer un prompt Roblox de pago.**
5. Abrí alternativamente ambas tiendas y usá el acceso del stand a Crates. No deben superponerse. Desde el detalle de Premium probá VER INVENTARIO/APERTURA: utiliza el panel actual; las cajas Premium reales siguen bloqueadas, sin Odds inventadas ni venta Coins.
6. Repetí cerrar/abrir, respawn y transición normal a combate/resultados. Probá que la tienda no abra durante una cinemática. Verificá que no cambien cámara ni controles y que no se acumulen tarjetas/previews.
7. Emulá vertical/móvil y PC. Revisá una/dos columnas, lectura, botones y scroll de detalles. Capturá video y Output completo de Client/Server si aparece un error.
8. Regresión: verificá categorías/equipamiento normal y StudioTest x1/x5/x10 con los procedimientos ya existentes, únicamente InMemory. No habilites Premium ni cambies probabilidades para fabricar compras; no hay productos aprobados para probar pagos.

Registrar resultados observados por separado de lo inspeccionado. No declarar compras productivas, entrega durable ni aceptación funcional listas. Detener nuevas implementaciones hasta la validación del desarrollador.
