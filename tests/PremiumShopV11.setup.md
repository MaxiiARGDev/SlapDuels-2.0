# Premium Shop V1.1 — configuración y activación pendiente

Estado: **ventas desactivadas**. Studio usa InMemory y no escribe cloud. Cambiar ProductIds no completa la migración de perfiles ni habilita ventas.

## Configurar cada Developer Product

1. Abrir Roblox Creator Hub.
2. Seleccionar la experiencia SlapDuels 2.0 y comprobar su identidad/Universe con el propietario. El nombre solo no demuestra identidad; no cambiar el Universe aprobado automáticamente.
3. Entrar en **Monetization > Developer Products**.
4. Crear cada producto y asignarle su precio Robux real. Los precios de la tabla son sugerencias, no precios cobrados por el código.
5. Copiar el **ProductId**, no el ID de un pase, asset o place.
6. Abrir el ModuleScript de la tabla. En Coins, cada fila del generador representa un paquete; para IDs reales conviene asignarlos explícitamente por PackageId, preservando la identidad de los productos existentes.
7. Reemplazar DeveloperProductId por el ID real correspondiente. No reutilizar ninguno de los once números reservados de ejemplo.
8. Cambiar IsPlaceholder=false **solo en ese producto**. El verificador además enumera los Developer Products de la experiencia; un número positivo no acredita pertenencia.
9. Revisar Rewards, ContractVersion, DuplicatePolicy y ContentsApproved; aprobar PurchaseApproved individualmente. Para cajas/combo con cajas, aprobar primero sus odds reales y apertura. Los combos vacíos siguen sin aprobación.
10. **Antes de activar ventas**, completar y verificar el puente durable descrito abajo, revisar migración/servidores antiguos, verificar IDs y precios reales y obtener autorización para una transacción controlada. Solo después revisar DurableCommerceValidated, PurchasesEnabled y flags por categoría de PremiumShopConfig. Mantenerlos false hasta entonces. Esto no autoriza publicar ni cambiar el entorno/Universe.

| Producto | Placeholder | Robux sugeridos | ModuleScript relativo a src/shared/PremiumShop/Catalog |
|---|---:|---:|---|
| Coins_1000 | 123456001 | 19 | CoinPackages.luau |
| Coins_2500 | 123456002 | 39 | CoinPackages.luau |
| Coins_6000 | 123456003 | 79 | CoinPackages.luau |
| Coins_15000 | 123456004 | 149 | CoinPackages.luau |
| Coins_40000 | 123456005 | 299 | CoinPackages.luau |
| PremiumCombo_01 | 123456101 | 99 | Combos/PremiumCombo_01.luau |
| PremiumCombo_02 | 123456102 | 249 | Combos/PremiumCombo_02.luau |
| PremiumCombo_03 | 123456103 | 499 | Combos/PremiumCombo_03.luau |
| PremiumI | 123456201 | 49 | PremiumCrates.luau |
| PremiumII | 123456202 | 99 | PremiumCrates.luau |
| PremiumIII | 123456203 | 199 | PremiumCrates.luau |

Ubicación en Studio: ReplicatedStorage.Shared.PremiumShop.Catalog. PremiumCombos requiere explícitamente los tres módulos autorizados.

## Precios y presentación

El cliente consulta GetProductInfoAsync(ProductId, Enum.InfoType.Product) para obtener el precio efectivo de ese usuario. SuggestedRobux se presenta únicamente como referencia de configuración; nunca habilita ni fija el botón de compra. La consulta fallida bloquea la compra. Un cambio entre catálogo, autorización y prompt exige renovar la acción; el prompt oficial es la confirmación final del precio cobrado por Roblox. El servidor verifica pertenencia y estado comercial, sin usar su precio compartido como precio personalizado.

Referencias oficiales: [Developer products](https://create.roblox.com/docs/production/monetization/developer-products), [MarketplaceService](https://create.roblox.com/docs/reference/engine/classes/MarketplaceService), [Perfiles y compras](https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing).

## Agregar y mantener productos

- **Coins:** agregar un registro con PackageId/Id únicos, Coins y Rewards.Coins iguales, ProductId real independiente y demás campos del contrato. El HUD consume el catálogo; no necesita otra lista. No reordenar los IDs generados existentes ni reasignar productos vendidos a premios distintos.
- **Combos:** crear otro módulo copiando uno de Combos y añadir su require explícito a PremiumCombos.luau. Usar Id/ComboId y ProductId únicos. Nunca cargar módulos arbitrarios por descendencia.
- **Cajas:** Rewards.Crates={{CrateId="ID_EXISTENTE",Quantity=3}} concede cajas cerradas. No abre sorteos. El catálogo valida identidad, cantidades y aprobaciones. Las odds efectivas por RewardId deben consultarse antes de adquirir y abrir. El servidor valida token, vencimiento y firma de cada tipo de caja. El stock productivo todavía requiere backend durable; mientras falte, las cajas siguen bloqueadas.
- **Slaps exclusivos:** primero registrar y preparar el recurso aprobado en el catálogo SlapCrates; luego Rewards.Slaps={{SlapId="ID",VariationId="ID"}}. No inventar identidades fuera del catálogo. Una variante con stock limitado continúa bloqueada sin garantías durables de stock.
- **Kill Effects:** registrar el efecto autorizado existente como producto equipable; usar Rewards.KillEffects={"ID"}. No crear efectos definitivos de ejemplo.
- **Duplicados:** aprobar OncePerPlayer, RestrictOwned o RepeatableNoCompensation según el contrato. No hay compensación implícita. El futuro puente debe validar compras antes del prompt bajo su lock; aun así una carrera posterior puede dejar un recibo pendiente y requiere resolución aprobada, nunca descarte silencioso.
- **Modificar:** no cambiar ProductId, identidad ni contrato de recompensa de un producto con recibos pendientes. Conservar la definición histórica o crear un producto nuevo. Registrar el cambio y revisar cómo se resolverán pendientes.
- **Desactivar:** Enabled=false impide nuevas autorizaciones. Conservar el registro, ID y aprobaciones de cumplimiento para poder procesar recibos ya cobrados; no borrar productos vendidos. No retirar PurchaseApproved/ContentsApproved de recibos pendientes sin un plan de recuperación.

## Bloqueante real: integración del ciclo de perfiles

ProfileReceiptStore implementa UpdateAsync sobre la **misma clave Player_<UserId> del adaptador existente**: premio y journal atómicos, lease por servidor, revisión, rechazo de saves antiguos y reintento idempotente. No crea otro saldo ni otro DataStore. Está probado con un adaptador aislado; no se ejecutó contra cloud.

El ciclo actual PlayerDataService/PlayerService no serializa todas las mutaciones con ese motor. Por ello **GetPremiumProfileBridge no está implementado**, DurableReceiptBackend devuelve ProfileLifecycleIntegrationPending en un entorno productivo autorizado y no entrega premios reales. En Studio se bloquea antes por TestingOrUnapprovedEnvironment.

Para completar el puente es necesario:

1. Adquirir/renovar/liberar una sesión sobre el perfil; usar tokens únicos por ingreso, nunca tokens compartidos entre servidores.
2. Serializar absolutamente todas las mutaciones de Coins/inventario/estadísticas y saves automáticos, PlayerRemoving y BindToClose. Ningún snapshot anterior puede sobrescribir el commit.
3. Publicar el snapshot confirmado a PlayerService/PlayerHUD antes de liberar el lock. No perder ganancias de gameplay ocurridas mientras UpdateAsync espera.
4. Implementar CanPurchase(UserId, product), RunReceiptTransaction(UserId, callback) y ReadReceipts(UserId), además de FullyFenced=true, SupportsOfflineReceipts=true y ProfileVersion. Las banderas solo deben declararse después de verificarlo.
5. Resolver recibos offline conservando/adquiriendo ownership; devolver pendiente mientras otro servidor posea el perfil. Verificar reconexión, cierre, errores ambiguos y transferencia de ownership.
6. Revisar tamaño máximo del perfil/journal y retención; no eliminar PurchaseIds procesados sin un diseño durable alternativo que conserve idempotencia. No activar ventas sin esta capacidad.
7. Coordinar salida de servidores antiguos antes de migrar: esta versión rechaza perfiles con _PremiumProfile desde el camino legacy; versiones desplegadas anteriores no conocen esa protección. Probar migración y recuperación sin tocar datos reales durante desarrollo.

No basta con añadir una función que devuelva FullyFenced=true ni con activar un flag. La infraestructura queda deliberadamente sin este puente para evitar una garantía falsa de durabilidad.

## Recibos pendientes y recuperación

- ProcessReceipt devuelve NotProcessedYet ante almacenamiento fallido, producto desconocido, configuración incompleta o backend no disponible. PurchaseGranted exige confirmación durable coincidente de PlayerId, ProductId y PurchaseId.
- El futuro endpoint Status publica únicamente recibos propios Applied. La UI no concede inventario ni interpreta PromptProductPurchaseFinished como entrega.
- Tras interrupción, recuperar la configuración histórica y dejar que Roblox reintente el mismo PurchaseId. Nunca cambiarlo, conceder Coins manualmente ni eliminar el journal como forma de reintento.
- En una futura herramienta administrativa autorizada, inspeccionar Inventory.PremiumReceipts[PurchaseId] en el perfil correspondiente y sus campos ProductId, ProductKey, PlayerId, ContractVersion, Rewards, State y AppliedAt. En este trabajo no se creó una herramienta cloud ni se autoriza leer/escribir perfiles reales.
- Si existe Applied, verificar saldo/inventario/revisión antes de resolver; si no existe, mantener pendiente hasta disponer del perfil y backend. Un timeout después de escribir se resuelve consultando/reintentando la misma transacción.
- El cierre/reingreso conserva durabilidad solo cuando el puente futuro esté completo; no declarar esta garantía para el runtime actual.

## Validación manual del desarrollador

Sin cambiar IDs/flags: iniciar vos la prueba, confirmar Studio / InMemory / WritesToCloud=false en Output, abrir las tres categorías, revisar 5 paquetes, 3 combos y 3 cajas; todos deben permanecer sin compra y sin prompt. Revisar diseño, entrada desde PlayerHUD/CoinShop y cierre. Verificar tienda normal y apertura de cajas únicamente según sus aprobaciones actuales. Capturar Output y pantalla si faltan tarjetas o aparecen errores.

No probar compras reales hasta resolver el puente y autorizar expresamente un entorno/transacción de validación. Este trabajo no inició Play ni efectuó compras.
