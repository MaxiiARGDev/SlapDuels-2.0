# Auditoría Shop → Kill Effects

Fecha: 2026-10-16. Repositorio: `H:\repos-github\SlapDuels-2.0`.

Auditoría de código y jerarquía física en Studio **Edit**, instancia
`ab01cdbb-f911-49b1-87b1-c311e6160909`, place 107328891970677.
No se ejecutaron módulos, remotes, compras, perfiles, Play/Run/Start Server ni
guardados/publicaciones. Única escritura autorizada: este informe. No se implementó
la integración ni se corrigieron los hallazgos. Death Feedback funciona según la
validación manual comunicada por el desarrollador; esta auditoría no lo vuelve a probar.

**Estados:** IMPLEMENTADO = existe evidencia en código/objetos, no significa prueba
funcional aprobada; PARCIAL = contrato presente con límites; PLACEHOLDER = elemento
preparado sin flujo completo; NO IMPLEMENTADO = falta la integración; NO VERIFICABLE
= no se puede confirmar sin ejecución o evidencia adicional. No hay PASS de compras.

## 1. Arquitectura actual — IMPLEMENTADO / PARCIAL

```text
ShopHUD físico → ShopController → Remotes.Shop (RemoteFunctions)
→ ShopRemotes → ShopService → ShopRegistry → ProductProvider
→ PlayerService (Coins + Inventory) → Player.DataUpdated → Shop/HUD
                         ↘ PlayerDataService → proveedor inyectado
```

ShopRegistry es agnóstico a categorías; ShopService sólo registra por defecto
PointEffectProvider. Compra Coins, propiedad y equipamiento sí están implementados:
el comentario inicial de ShopService sobre fases futuras está desactualizado frente
a `_processCoinsPurchase`. Robux está expresamente pendiente. El inventario ya es
genérico; no hace falta un segundo inventario/economía para Kill Effects.

## 2. Rutas de scripts y recursos — IMPLEMENTADO

Las rutas enlazadas son archivos reales; la columna Studio identifica sus instancias.

| Archivo / función relevante | Ruta Studio |
|---|---|
| [ShopService:PurchaseProduct, _processCoinsPurchase, EquipProduct](H:/repos-github/SlapDuels-2.0/src/server/Services/ShopService.luau:233) | `ServerScriptService.Services.ShopService` |
| [ShopRegistry:Register, GetProduct, GetCatalog](H:/repos-github/SlapDuels-2.0/src/server/Shop/ShopRegistry.luau:23) | `ServerScriptService.Shop.ShopRegistry` |
| [ShopRemotes:Init, safeCall, consumeRequest](H:/repos-github/SlapDuels-2.0/src/server/Shop/ShopRemotes.luau:110) | `ServerScriptService.Shop.ShopRemotes` |
| [PointEffectProvider:CanPurchase/CanEquip/OnPurchased/OnEquipped](H:/repos-github/SlapDuels-2.0/src/server/Shop/Providers/PointEffectProvider.luau:111) | `ServerScriptService.Shop.Providers.PointEffectProvider` |
| [ShopController:_bindHUD y acciones](H:/repos-github/SlapDuels-2.0/src/client/Controllers/ShopController.luau:122) | `StarterPlayer.StarterPlayerScripts.Controllers.ShopController` |
| [PlayerService:DeductCoins, AddItem, SetEquippedItem](H:/repos-github/SlapDuels-2.0/src/server/Services/PlayerService.luau:323) | `ServerScriptService.Services.PlayerService` |
| [PlayerDataService:ValidatePlayerData/LoadPlayer/SavePlayer](H:/repos-github/SlapDuels-2.0/src/server/Services/PlayerDataService.luau:108) | `ServerScriptService.Services.PlayerDataService` |
| [PersistenceEnvironment:Resolve](H:/repos-github/SlapDuels-2.0/src/server/Services/Persistence/PersistenceEnvironment.luau:39) | `ServerScriptService.Services.Persistence.PersistenceEnvironment` |
| [InMemoryDataStore](H:/repos-github/SlapDuels-2.0/src/server/Services/Persistence/InMemoryDataStore.luau:43) | `ServerScriptService.Services.Persistence.InMemoryDataStore` |
| [RobloxDataStoreAdapter](H:/repos-github/SlapDuels-2.0/src/server/Services/Persistence/RobloxDataStoreAdapter.luau:16) | `ServerScriptService.Services.Persistence.RobloxDataStoreAdapter` |
| [PlayerHUDController:_connectRemotes](H:/repos-github/SlapDuels-2.0/src/client/Controllers/PlayerHUDController.luau:116) | `StarterPlayer.StarterPlayerScripts.Controllers.PlayerHUDController` |
| [PointEffectDefinitions](H:/repos-github/SlapDuels-2.0/src/shared/PointEffectDefinitions.luau:19) | `ReplicatedStorage.Shared.PointEffectDefinitions` |
| [Types:PlayerInventory/ProductDefinition/ProductProvider](H:/repos-github/SlapDuels-2.0/src/shared/Types.luau:193) | `ReplicatedStorage.Shared.Types` |
| [Config:Economy/DataStore](H:/repos-github/SlapDuels-2.0/src/shared/Config.luau:202) | `ReplicatedStorage.Shared.Config` |
| [Bootstrap:proveedor inyectado y orden de servicios](H:/repos-github/SlapDuels-2.0/src/server/Bootstrap.server.luau:11) | `ServerScriptService.Bootstrap` |
| [ClientBootstrap:registro de controladores](H:/repos-github/SlapDuels-2.0/src/client/ClientBootstrap.client.luau:9) | `StarterPlayer.StarterPlayerScripts.ClientBootstrap` |
| [ScoreService:premio por punto](H:/repos-github/SlapDuels-2.0/src/server/Services/ScoreService.luau:446) | `ServerScriptService.Services.ScoreService` |
| [PointFeedbackService:efecto equipado y recurso](H:/repos-github/SlapDuels-2.0/src/server/Services/PointFeedbackService.luau:142) | `ServerScriptService.Services.PointFeedbackService` |
| [PointEffectRegistry:controllers](H:/repos-github/SlapDuels-2.0/src/server/PointEffectControllers/PointEffectRegistry.luau:36) | `ServerScriptService.PointEffectControllers.PointEffectRegistry` |
| [EliminationService:snapshot del efecto](H:/repos-github/SlapDuels-2.0/src/server/Services/EliminationService.luau:414) | `ServerScriptService.Services.EliminationService` |
| [DeathEffectService:HandleConfirmed](H:/repos-github/SlapDuels-2.0/src/server/Services/DeathEffectService.luau:38) | `ServerScriptService.Services.DeathEffectService` |
| [DeathFeedbackContract:ResolveEffect](H:/repos-github/SlapDuels-2.0/src/shared/DeathFeedbackContract.luau:19) | `ReplicatedStorage.Shared.DeathFeedbackContract` |
| [DeathEffectDefinitions](H:/repos-github/SlapDuels-2.0/src/shared/DeathEffectDefinitions.luau:3) | `ReplicatedStorage.Shared.DeathEffectDefinitions` |
| [DeathFeedbackConfig](H:/repos-github/SlapDuels-2.0/src/shared/DeathFeedbackConfig.luau:3) | `ReplicatedStorage.Shared.DeathFeedbackConfig` |
| [DeathFeedbackController](H:/repos-github/SlapDuels-2.0/src/client/Controllers/DeathFeedbackController.luau:21) | `StarterPlayer.StarterPlayerScripts.Controllers.DeathFeedbackController` |
| [DeathEffectPlayer](H:/repos-github/SlapDuels-2.0/src/client/DeathFeedback/DeathEffectPlayer.luau:11) | `StarterPlayer.StarterPlayerScripts.DeathFeedback.DeathEffectPlayer` |
| [KillRewardController](H:/repos-github/SlapDuels-2.0/src/client/Controllers/KillRewardController.luau) | `StarterPlayer.StarterPlayerScripts.Controllers.KillRewardController` |
| [Recursos DeathEffects](H:/repos-github/SlapDuels-2.0/src/assets/DeathEffects.project.json) | `ServerStorage.DeathEffects` |
| [Mapeo Rojo](H:/repos-github/SlapDuels-2.0/default.project.json:115) | preserva objetos desconocidos de `StarterGui` |

Se buscaron también `PurchaseProduct`, `Inventory`, `Owned`, `Equipped`, `DeductCoins`,
guardados y catálogos fuera de scripts denominados Shop. No se encontró otra economía
o inventario paralelo en las fuentes inspeccionadas. Las referencias auxiliares
`_ownedPointEffects/_equippedPointEffects` son compatibilidad sobre el inventario genérico.

## 3. Interfaz física — IMPLEMENTADO; navegación PARCIAL

Jerarquía observada, conservada sin cambios:

```text
StarterGui.ShopHUD (ScreenGui, Enabled=true, ResetOnSpawn=false)
├─ ShopButton (TextButton: TIENDA)
└─ MainFrame (Frame, Visible=false)
   ├─ UISizeConstraint / OpenScale (UIScale)
   ├─ Header
   │  ├─ Title (ImageLabel)
   │  ├─ CloseButton (ImageButton)
   │  └─ CoinsContainer → CoinIcon / CoinsLabel
   ├─ Tabs
   │  ├─ UIListLayout / UIPadding
   │  ├─ PointEffectsTab → SoonBadge / TextLabel
   │  ├─ SlapsTab → SoonBadge / Slabs
   │  └─ TrailsTab → SoonBadge / Trails
   ├─ Body
   │  ├─ Catalog (ScrollingFrame)
   │  │  ├─ UIGridLayout / UIPadding
   │  │  └─ ProductCardTemplate (TextButton, Visible=false)
   │  │     ├─ Preview → PreviewLabel / PreviewIcon
   │  │     ├─ NameLabel / RarityLabel / CoinIcon / PriceLabel
   │  │     └─ StateBadge
   │  ├─ DetailPanel
   │  │  ├─ UIListLayout / UIPadding
   │  │  ├─ Preview → PreviewLabel / PreviewIcon
   │  │  ├─ NameLabel / RarityLabel / DescriptionLabel
   │  │  ├─ PriceRow → CoinIcon / PriceLabel
   │  │  ├─ StatusLabel
   │  │  ├─ ActionButton (TextButton: COMPRAR)
   │  │  └─ SecondaryButton (TextButton: DESEQUIPAR)
   │  ├─ EmptyState
   │  └─ LoadingLabel
   └─ MessageLabel
```

Tarjetas generadas: `PlayerGui.ShopHUD.MainFrame.Body.Catalog.Card_<product.Id>`.
Son clones de una plantilla física editable, no UI construida de cero. Cambiar
categoría sí destruye/recrea las tarjetas (`_renderCatalog`); actualizar saldo/propiedad
reutiliza las tarjetas existentes (`_refreshStates`). El panel y la ventana no se reconstruyen.

**Hallazgo confirmado:** los tres botones de Tabs tienen `GetAttribute("Category")==nil`.
`_bindHUD` líneas175–185 sólo conecta botones con atributo Category string. Por tanto
esas pestañas no se conectan con el estado Edit actual. PointEffects sigue siendo
la categoría inicial por `DEFAULT_CATEGORY`, aunque los tabs no estén enlazados.
No existe un tab Kill Effects ni un provider para esa categoría.

PC/móvil: **NO VERIFICABLE funcionalmente**. Usa `Activated` (no sólo mouse), tamaños
relativos y scroll vertical con AutomaticCanvasSize.Y. MainFrame mínimo420×300,
máximo940×620; tarjetas de 146 px de alto y columna31% del catálogo. Ese mínimo puede
desbordar pantallas estrechas; no hay breakpoint móvil ni preview adaptativa demostrada.
DetailPanel AnchorPoint=(1,0), por lo que su X≈0.986 no indica por sí solo desborde.
No se redimensionó la ventana ni se tocó el diseño para comprobarlo.

ShopHUD **no está exportado** en default.project.json: StarterGui usa
`$ignoreUnknownInstances=true`, pero sólo mapea otros tres HUDs. La Shop física queda
en el lugar abierto; un build nuevo desde sólo las fuentes no reproduce ShopHUD.
Es un riesgo de recuperación/versionado, no ausencia de UI en el Studio actual.

## 4. Apertura/cierre — IMPLEMENTADO por código, NO VERIFICABLE en ejecución

`ShopController:_bindHUD` conecta ShopButton.Activated→Toggle y
Header.CloseButton.Activated→Close. Open muestra MainFrame, anima OpenScale 0.92→1,
conecta DataUpdated y solicita GetCatalog. Close oculta MainFrame, elimina tarjetas
y no cancela operaciones servidor ya enviadas (líneas642–668).

No se encontró ProximityPrompt de Shop ni apertura por NPC/tecla. El prompt observado
`Workspace.PointEffectTest.TestPart.TestPrompt` pertenece a pruebas de Point Effects,
no se identificó como mecanismo de tienda. No se pulsaron botones.

## 5. Compra — IMPLEMENTADO en memoria; transacción durable PARCIAL

1. Card seleccionada cambia `_selectedId`; ActionButton llama `_onActionPressed`.
2. Si no es poseída y Currency=Coins, `_request("PurchaseProduct",product.Id,...)`.
   Cliente envía **sólo ID**, no precio/saldo/propiedad. `_busy` evita doble clic local.
3. `ReplicatedStorage.Remotes.Shop.PurchaseProduct` es RemoteFunction.
   ShopRemotes exige string no vacío de hasta64 caracteres y limita mutaciones a
   un intervalo mínimo0.3 s por jugador; `safeCall` convierte excepciones a InternalError.
4. ShopService comprueba ID, transacción activa, registro, producto existente,
   IsAvailable, provider y CanPurchase. PointEffectProvider rechaza AlreadyOwned.
5. `_processCoinsPurchase` consulta GetCoins y compara contra precio **del catálogo servidor**.
   Adquiere lock por jugador; DeductCoins vuelve a comprobar saldo y descuenta.
6. OnPurchased→PlayerService:AddItem marca Owned[Category][Id]=true y envía DataUpdated.
7. Si OnPurchased devuelve false, devuelve Coins mediante AddCoins y libera lock.
   Si sale normalmente, libera lock y responde `(true,nil)`; rechazos `(false,código)`.
8. ShopController muestra resultado y deriva COMPRAR/EQUIPAR/EQUIPADO de los snapshots
   DataUpdated; compra no equipa automáticamente. Descuento y entrega envían snapshots
   separados, por lo que puede existir un estado visual intermedio.

**No se llama SavePlayer como parte de la compra.** Éxito significa commit en memoria,
no confirmación de DataStore. El comentario «atómico» no convierte descuento+entrega+
persistencia en una sola transacción. Ver hallazgos en sección12.

Los cuatro remotes de Shop **no existen en Edit** en esta inspección: su carpeta está
vacía. Es consistente con ShopRemotes:Init L113 (`if not RunService:IsRunning() then return end`)
y default.project.json (sólo declara Folder). Se crearían al inicializar en ejecución;
no se forzó esa inicialización ni se marca como fallo de instalación.

## 6. Equipar/desequipar — IMPLEMENTADO para PointEffects

Owned→ActionButton invoca `EquipProduct(product.Id)`. ShopService resuelve catálogo,
ProductType=Cosmetic y provider.CanEquip; éste valida propiedad y AlreadyEquipped.
OnEquipped→PlayerService:SetEquippedItem valida propiedad otra vez y reemplaza
Inventory.Equipped[Category] con un ID; un único equipado por categoría.

SecondaryButton envía `UnequipProduct(product.Category)`; sólo se muestra para el
producto equipado con Price>0. PointEffectProvider:OnUnequipped devuelve Basic, no
nil. La API genérica UnequipItem sí borra categorías no PointEffects. Los cambios
envían DataUpdated. No instancian herramientas por ser efectos cosméticos.

No se comprueba Shop abierta, ubicación, MatchId, Closing ni LoadState=Loaded en
estos endpoints. Cambiar equipamiento durante Playing/Ending no está prohibido por
el código actual; decidir la política futura es necesario, no asumir «sólo lobby».

## 7. Inventario — IMPLEMENTADO y extensible; defaults DeathEffects NO IMPLEMENTADOS

Contrato real, equivalente a OwnedCosmetics/EquippedCosmetics, sin esos nombres:

```text
PlayerData.Inventory.Owned[category][productId] = true
PlayerData.Inventory.Equipped[category] = productId
```

Types L193, PlayerService:GetInventory/HasItem/AddItem/GetEquippedItem/SetEquippedItem/
UnequipItem L459–629. Cualquier categoría string cabe en las tablas; el provider y
el registro deben ser la allowlist de productos. Estas APIs de servidor no deben
exponerse como un Remote genérico de «otorgar ID».

Defaults actuales: Owned.PointEffects.Basic=true y Equipped.PointEffects=Basic,
incluida regla universal HasItem para Basic. No hay default de propiedad/equipado
DeathEffects.BasicKill. El fallback audiovisual BasicKill existe independientemente.

No depende de Character: respawn, regreso al lobby y nueva MatchSession conservan
el inventario runtime del Player; no se requiere reequipar un modelo en Character.
Al reconectar se reconstruye desde PlayerDataService si el proveedor conserva datos.

## 8. Persistencia — IMPLEMENTADO el contrato; producción BLOQUEADA; durabilidad PARCIAL

Registro: Version=2, Coins, Wins, Losses, Kills, Inventory{Owned,Equipped}, LastSaved.
Store configurado `SlapDuels_PlayerData_v1`, clave `Player_<UserId>`.

PlayerDataService valida números finitos/no negativos, migra versiones anteriores,
rechaza futuras y sanitiza tablas de inventario conservando categorías genéricas.
Equipados no poseídos se descartan. Sólo asegura el default PointEffects.Basic.
No valida todos los IDs genéricos contra catálogos en la migración; el consumidor
debe seguir usando allowlist y propiedad.

Bootstrap inyecta un único proveedor. En Studio, PersistenceEnvironment selecciona
InMemory y WritesToCloud=false, sin fallback. En producción,
APPROVED_PRODUCTION_UNIVERSE_ID=nil bloquea el proveedor. No se modificó ni resolvió
con ejecución esa configuración. RobloxDataStoreAdapter contiene GetDataStore,
GetAsync y UpdateAsync, pero su constructor no se llamó en esta auditoría.

Load/GetAsync y Save/UpdateAsync tienen hasta3 intentos con backoff inicial1s×2.
Save sólo permite LoadState=Loaded, protege versiones futuras y serializa guardados
por jugador. Guarda al salir mediante PlayerService:_unregister y en BindToClose
con SaveAllPlayers y espera acotada25s. No se encontró autosave periódico ni guardado
por compra/equipamiento. `_unregister` no recupera durablemente un Save fallido antes
de limpiar runtime; el fallo queda en logs. UpdateAsync sobrescribe los campos
propios con el snapshot actual, no constituye bloqueo de perfil entre servidores.

Compra exitosa seguida de fallo/crash antes del save puede perder adquisición y
saldo/equipado recientes. No hay receipt/journal durable de compras. En InMemory
los datos viven sólo en ese servidor: se pueden recargar del mismo adaptador durante
su vida si se guardaron, pero una nueva ejecución de Studio empieza vacía.

## 9. Coins — IMPLEMENTADO; método reutilizable con límites

PlayerService es la autoridad única: AddCoins/GetCoins/DeductCoins y DataUpdated.
Kill: EliminationService→AwardConfirmedKill→AddCoins con clave `Kill:<EliminationId>`,
validación de rivales/sesión/perfil y premio Config.Economy.KillRewardCoins=50.
Punto: ScoreService L446–449 usa Config.Match.PointReward=50 y AddCoins("MatchPoint")
con las protecciones de puntuación existentes. No se cambió ninguna recompensa.

Gasto: DeductCoins devuelve `(éxito,nuevoSaldo)`, comprueba saldo y descuenta del mismo
runtime. Es el punto a reutilizar, no crear otra wallet. Actualmente rechaza amount<=0:
un producto gratuito no poseído no puede pasar por esta compra genérica; Basic actual
ya es universal y CanPurchase devuelve AlreadyOwned. BasicKill futuro debe otorgarse
como default legítimo, no comprarse por0 para simular propiedad.

DeductCoins no valida explícitamente tipo/NaN/infinito/entero ni LoadState y puede
_register si falta data. El catálogo actual tiene precios numéricos finitos fijos,
por lo que no se encontró un precio arbitrario enviado por cliente que explote esto.
Endurecer la API interna antes de ampliar providers es recomendable.

Sync: PlayerService:_sendDataUpdate sincroniza leaderstats y FireClient snapshot;
ShopController usa `ShopHUD.MainFrame.Header.CoinsContainer.CoinsLabel` y el HUD
principal `StarterGui.PlayerHUD.ProfileCard.CoinsContainer.CoinsLabel`. El destino
de animación de premios es `StarterGui.KillRewardHUD.CoinTarget`; comprar no otorga
un premio ni debe reutilizar el recibo de Kill para mostrar un descuento.

## 10. Catálogo — IMPLEMENTADO PointEffects; DeathEffects comercial NO IMPLEMENTADO

ProductDefinition: Id, Category, ProductType(Cosmetic/Consumable), DisplayName, Price,
Currency(Coins/Robux), IsAvailable; opcionales Description/Rarity/AssetId/Icon/Metadata,
y RobloxProductId para Robux. El estado Owned/Equipped viene del perfil, no del catálogo.

PointEffectProvider transforma PointEffectDefinitions a Category=PointEffects,
ProductType=Cosmetic, Currency=Coins e IsAvailable=true para **todos** los definidos.
No rellena Icon ni AssetId; UI muestra PreviewLabel «✦» si falta icono. No hay campo
Image separado: Icon alimenta los ImageLabels. La referencia física de puntos es
ServerStorage.PointEffects[Id], resuelta por PointFeedbackService.

| ID / nombre | Rareza | Precio Coins | Modelo observado Edit | Estado |
|---|---|---:|---|---|
| Basic / Básico | Common | 0 | `ServerStorage.PointEffects.Basic` | IMPLEMENTADO, default poseído |
| Inferno | Rare | 500 | `ServerStorage.PointEffects.Inferno` | IMPLEMENTADO en catálogo/recurso |
| Frost | Rare | 750 | No encontrado | PARCIAL: se vende, falta recurso propio |
| Thunder | Epic | 1500 | `ServerStorage.PointEffects.Thunder` | IMPLEMENTADO en catálogo/recurso |
| Void | Legendary | 3000 | No encontrado | PARCIAL: se vende, falta recurso propio |

PointFeedbackService:_getEffectTemplate L169–173 usa Basic si no hay modelo del ID.
PointEffectRegistry sólo declara controllers exclusivos Inferno/Thunder, además
del default. Vender Frost/Void así puede entregar propiedad sin su visual distintivo;
es un desajuste confirmado de catálogo/recursos, no una compra ejecutada en esta auditoría.

Los IDs de ShopRegistry son **globalmente únicos**, no sólo por categoría. Mantener
BasicKill distinto de Basic y validar colisiones de IDs al incorporar productos.

## 11. Categorías — PARCIAL

| Categoría | Provider | Inventario/API | Interfaz observada | Estado |
|---|---|---|---|---|
| PointEffects | PointEffectProvider registrado por defecto | Propiedad/equipado/default completos | PointEffectsTab sin Category | IMPLEMENTADO servidor / PARCIAL navegación |
| Slaps | Ninguno en Shop | API genérica posible; Tool Classic es otro sistema | SlapsTab sin Category | PLACEHOLDER de Shop |
| Trails | Ninguno | Sin productos actuales | TrailsTab sin Category | PLACEHOLDER |
| DeathEffects | Ninguno | Categoría ya consultada por DeathFeedbackContract | No hay tab | PARCIAL consumidor / NO IMPLEMENTADO comercio |

ShopRegistry acepta múltiples categorías y ProductType=Consumable, pero sólo hay
un provider Cosmético real. No inferir soporte completo de consumibles o Robux por
existir tipos. `_processRobuxPurchase` devuelve MarketplaceIntegrationPendingPhase6;
no hay ProcessReceipt/prompt de Marketplace conectado.

## 12. Seguridad — controles IMPLEMENTADOS; garantías transaccionales PARCIALES

| Caso | Evidencia / resultado estático | Clasificación |
|---|---|---|
| ID inexistente/arbitrario | Remote valida string≤64, registry lookup y provider; equip exige producto registrado | IMPLEMENTADO |
| Precio manipulado | Sólo ID viaja; precio y divisa del catálogo servidor | IMPLEMENTADO |
| Saldo insuficiente | Comparación en ShopService y nuevamente DeductCoins | IMPLEMENTADO |
| Equipar sin propiedad | Provider.CanEquip y SetEquippedItem comprueban HasItem | IMPLEMENTADO |
| Solicitudes repetidas normales | _busy cliente, rate0.3s servidor, lock de compra y AlreadyOwned | IMPLEMENTADO para flujo ordinario; no receipt idempotente de compra |
| Excepción durante descuento/entrega | ShopService L295–315 no usa finally/pcall que garantice liberar lock/compensar; safeCall exterior sólo responde InternalError | Defecto de manejo de excepciones CONFIRMADO; ocurrencia funcional NO VERIFICABLE |
| Estado cargado/cierre | Purchase/Equip no exigen Loaded, Player.Parent ni barrera Closing; getters/mutadores pueden _register | Falta de guardas CONFIRMADA; mutación/perdida efectiva requiere ese escenario |
| Compra guardada durablemente | No Save dentro de compra; éxito en memoria | Límite CONFIRMADO, no prometer durabilidad |
| Concurrentes con providers que ceden | CanPurchase está antes del lock y no se revalida bajo lock; equip no comparte lock | Riesgo CONDICIONAL futuro; provider actual no cede normalmente, no se demostró doble cobro actual |
| Spam GetCatalog | No consumeRequest; cada petición puede deferir snapshot DataUpdated | Falta de rate limit CONFIRMADA; impacto de carga NO VERIFICABLE |
| Equipar producto no disponible | EquipProduct/PointEffectProvider.CanEquip no revisan IsAvailable; UI sí bloquea | Inconsistencia CONFIRMADA; definir si disponibilidad afecta venta o uso antes de llamarlo exploit |
| Defaults/precios gratis | DeductCoins rechaza0 | Límite CONFIRMADO; no implementa adquisición gratuita genérica |
| Precios no finitos/futuros | Registry comprueba number y >=0, no finitud/entero; Deduct no rechaza NaN explícitamente | Riesgo interno de catálogo/provider, no precio remoto controlado por cliente en catálogo actual |

**Detalle del fallo de excepciones:** DeductCoins cambia Coins antes de _sendDataUpdate;
AddItem cambia Owned antes de notificar. Si una notificación u OnPurchased lanza
una excepción, el pcall de ShopRemotes devuelve InternalError, pero no entra en el
rollback condicionado a `deliveryOk=false` ni libera necesariamente el lock. Puede
quedar compra aplicada parcialmente o cliente viendo error tras commit en memoria.
No equivale a una vulnerabilidad remota reproducida; es una ruta de error comprobable.

**Compra sin descuento:** no se encontró una ruta ordinaria de producto de pago del
provider actual que entregue sin DeductCoins exitoso. Un provider futuro que entregue
y devuelva false podría provocar refund con propiedad retenida: riesgo de contrato,
no comportamiento demostrado del actual. Tampoco hay rollback de propiedad genérico.

**Cierre/guardado:** SavePlayer L390–397 copia Coins por valor pero mantiene Inventory
por referencia. Una mutación de Shop durante un save que cede puede mezclar saldo
previo con inventario posterior. La ausencia de barrera Closing y snapshot profundo
es un riesgo concreto de consistencia; no se ejecutó ni se escribió ningún DataStore.
_unregister ignora resultado de Save antes de limpiar datos. Debe resolverse antes
de ventas que se presenten como persistentes en producción.

Las restricciones de UI son presentación, no autorización: no exigir ventana abierta
no permite saltarse catálogo/propiedad. Sí hace falta decidir explícitamente el
contexto permitido de compra/equipado y bloquear mutaciones sobre perfiles inválidos.

## 13. DeathEffectService — IMPLEMENTADO y validado manualmente según desarrollador

Recursos físicos observados: `ServerStorage.DeathEffects.DefaultFall` (Model,
Duration1.5, 16 descendientes) y `.BasicKill` (Model, Duration2.2, 16 descendientes).
El catálogo DeathEffectDefinitions referencia ModelName, duración/emisión y
RequiredOwnership/IsDefault, **no** precio/rareza/venta.

Selección actual: Contract.ResolveEffect pregunta
`PlayerService:GetEquippedItem(victim,"DeathEffects")`. Si no hay atacante, retorna
DefaultFall siempre. Si hay Kill, permite selección allowlisted distinta de
DefaultFall y comprueba HasItem cuando RequiredOwnership=true; si no hay selección
válida retorna BasicKill. Ambas definiciones actuales tienen RequiredOwnership=false.
GetEquippedItem genérico también comprueba propiedad para una selección no nula.

Por tanto hay referencia a perfil para futuros equipados, pero BasicKill actual es
un **fallback universal**, no una compra ni propiedad DeathEffects creada por Shop.
DefaultFall no debe convertirse en producto; BasicKill será el default gratuito.

EliminationService resuelve el efecto de la **víctima** antes de la retirada y congela
FeedbackSnapshot. DeathEffectService consume esa decisión final, valida sesión,
participantes/versión/edad y deduplica por EliminationId. Envía a miembros autorizados
por `ReplicatedStorage.Remotes.Match.DeathFeedback`; sólo atacante recibe RewardCoins>0.
Replica plantillas a `ReplicatedStorage.DeathEffectAssets` en runtime y el cliente
crea clones locales en el impacto. No se necesita un modelo pegado al Character ni
que siga existiendo para reproducir el snapshot. No se tocó este flujo.

## 14. Integración recomendada — NO IMPLEMENTADO, diseño propuesto

Crear **un provider DeathEffectProvider** en el framework actual, cuyo GetCategory
sea exactamente **DeathEffects**. El texto del tab puede ser «Kill Effects», pero
usar KillEffects como clave de inventario rompería el contrato del consumidor actual.

Provider: CanPurchase valida catálogo/disponibilidad/propiedad; OnPurchased usa
AddItem; CanEquip y OnEquipped usan HasItem/SetEquippedItem; OnUnequipped restaura
BasicKill. Usar PurchaseProduct/EquipProduct/UnequipProduct existentes. No crear
remotes de compra ni inventarios nuevos. DeathFeedbackContract ya es el punto de
lectura correcto: no conectar Shop directamente a VFX, Coins de Kill o Character.

## 15. Componentes reutilizables — IMPLEMENTADO

ShopRegistry/ProductProvider, ShopService, ShopRemotes, PlayerService, Inventory,
DataUpdated, PlayerDataService y proveedor InMemory; ShopHUD, ProductCardTemplate,
DetailPanel, estados visuales, catálogo por categoría; DeathEffectDefinitions,
ResolveEffect, snapshot de eliminación, DeathEffectService y reproducción local.
No se necesita modificar RoundService, respawn, Slap, HUD de Kill, EndCinematic,
premio de Kill/gol ni crear sistema económico para esta integración.

## 16. Componentes faltantes — NO IMPLEMENTADO / PARCIAL

- DeathEffectProvider y su registro explícito en ShopService.
- Metadatos comerciales para efectos vendibles: precio, rareza, descripción e icono.
  Recomendación: extender la definición existente y adaptarla al ProductDefinition,
  no mantener dos catálogos manuales divergentes.
- Default gratuito BasicKill en inicialización, normalización de perfiles existentes
  y snapshot sin datos; consistencia entre HasItem, GetEquippedItem y lo que muestra UI.
- Tab físico Kill Effects con Category=DeathEffects; corregir atributos ausentes de
  tabs actuales sólo en fase autorizada. No se propone reemplazar su diseño.
- Exportación del ShopHUD físico para recuperación/versionado, pendiente de aprobación.
- Preview audiovisual real de Shop: NO IMPLEMENTADO. Preview actual sólo ImageLabel/
  texto; no hay ViewportFrame/controlador de partículas ni botón de reproducción.
- Endurecimiento de transacciones y política de estado/cierre antes de venta durable.

## 17. Riesgos de compatibilidad — PARCIAL

Preservar Basic (PointEffects) distinto de BasicKill (DeathEffects), IDs globales,
categoría DeathEffects, cosmético de víctima, DefaultFall fuera del catálogo de venta,
uso de monedas confirmado y aislamiento de MatchSession. Compras no deben cambiar
una eliminación ya capturada: el nuevo equipado afecta a eliminaciones posteriores.

Sanitización genérica ya conserva categorías nuevas; no requiere cambiar estructura
para DeathEffects. Añadir defaults de forma idempotente preservando compras/equipados
existentes. Definir/documentar si se registra esto como migración aditiva del esquema2
o versión nueva; no forzar incremento ni cambiar nombres de DataStore por necesidad
inexistente. No habilitar producción para probar esta integración.

La futura preview debe usar clones locales de recursos allowlisted, cancelados al
cerrar/cambiar producto y sin invocar una Kill, afectar Character o enviar recibos
económicos. No reutilizar la escena/cámara EndCinematic para una preview de tienda.

## 18. Arquitectura futura de Kill Effects — NO IMPLEMENTADO

```text
Tab físico Category=DeathEffects → catálogo existente + DeathEffectProvider
→ PurchaseProduct(ID) → precio servidor → DeductCoins + AddItem bajo transacción
→ DataUpdated → «TUYO» → EquipProduct(ID) → Equipped.DeathEffects=ID
→ guardado mediante PlayerDataService cuando corresponda, sin activar cloud
→ siguiente eliminación: ResolveEffect(víctima) → snapshot → feedback de sesión
```

BasicKill: propiedad/equipado inicial gratuito para perfiles nuevos y antiguos;
mostrar EQUIPADO sin pasar por descuento0. Futuros efectos de pago requieren
RequiredOwnership=true y producto/recurso válido. DefaultFall se excluye de
GetProducts y CanEquip; una caída sin atacante ignora la selección equipada.
No se agregan productos de pago sin precio aprobado y recurso físico disponible.

## 19. Cambios mínimos futuros — NO IMPLEMENTADO, requieren autorización

| Componente | Cambio propuesto |
|---|---|
| Nuevo `src/server/Shop/Providers/DeathEffectProvider.luau` | Adaptar catálogo/propiedad/equipado al framework |
| ShopService | Registrar provider; corregir límites de transacción antes de nuevas ventas |
| DeathEffectDefinitions | Metadatos comerciales aprobados y ownership para efectos de pago, sin vender DefaultFall |
| PlayerService y PlayerDataService | Default BasicKill coherente en todos los caminos; guardas Loaded/Closing y consistencia de compra/save |
| ShopHUD físico | Tab DeathEffects con Category; atributos de tabs existentes; exportar modelo si se autoriza |
| ShopController | Reutilizar tarjetas/estados; soporte de preview sólo si se incluye en alcance posterior |
| Pruebas aisladas | Compra/equip/defaults/replay/error/guardado; después pruebas manuales del desarrollador |

No son necesarios nuevos servicios de Coins, campos OwnedCosmetics/EquippedCosmetics,
remotes de recompensa ni cambios de cámaras/partidas. El punto de integración
DeathFeedbackContract ya existe; preservar su regla, no reescribirlo preventivamente.

## 20. Plan por fases — NO IMPLEMENTADO

1. **Contrato y endurecimiento.** Acordar categoría/IDs/metadatos y política de
   compra/equipado en partida. Guardas Loaded/Closing, lock liberado incluso con
   excepción, commit/compensación coherentes, notificación separada del commit,
   snapshot consistente con save. No prometer durabilidad cloud aún bloqueada.
2. **Defaults y provider.** BasicKill gratuito, normalización idempotente de perfiles,
   DeathEffectProvider registrado; DefaultFall excluido; pruebas aisladas con
   InMemory de ownership/equip/desquipado/default sin cambiar economía.
3. **Interfaz física.** Tab con atributo correcto, plantillas actuales, estados y
   saldo autoritativos; exportar HUD. Verificación manual PC/móvil por desarrollador.
   Preview audiovisual es subfase opcional con alcance explícito.
4. **Productos futuros aprobados.** Definiciones con precio/icono/rareza, recursos
   allowlisted disponibles y RequiredOwnership=true; compra y equipamiento usan
   inventario/proveedor existentes. No inventar catálogo/precios ahora.
5. **Regresión del desarrollador.** Comprar una vez, repetir solicitud, saldo
   insuficiente, equip sin propiedad, fallo de entrega/notificación, cierre con
   compra pendiente, reconexión en el mismo adaptador y nueva ejecución Studio.
   Kill sobre víctima equipada→su efecto; caída→DefaultFall; +50 Kill/+50 gol
   intactos, lobby ajeno sin feedback y EndCinematic sin cambios. PC/móvil pendientes.
6. **Persistencia productiva separada.** Sólo tras autorización expresa futura y
   aprobación humana del Universe ID, estrategia durable/fallos y aislamiento
   comprobados. Fuera del alcance de esta auditoría y de pruebas iniciales de Shop.

**Resultado:** la arquitectura base es reutilizable; el comercio DeathEffects todavía
no está conectado. Prioridades previas: transacciones/cierre, defaults gratuitos y
contrato físico de tabs/recursos. Se entrega este informe y se espera autorización
antes de implementar cualquiera de las fases.
