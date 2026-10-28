# Contrato de persistencia y límites de producción

## Funcional en Studio InMemory

Un único perfil existente contiene Coins y:

```
Inventory.Owned.Slaps[RewardId] = true
Inventory.Equipped.Slaps = RewardId
Inventory.Crates[CrateId] = cantidad cerrada
Inventory.SlapUnits[UnitId] = {SlapId, VariationId, RewardId, OwnerUserId, OperationId, EditionId, VariationEditionId, Origin}
Inventory.CrateOperations[OperationId] = {Kind, CrateId, State, RewardId?, UnitId?, CreatedAt, ...}
```

`UnitId = UserId original + OperationId`. Se preservan IDs negativos de Studio. Las unidades permiten múltiples copias sin alterar Owned booleano ni equipamiento. No hay compensaciones económicas por duplicados.

Purchase debita Coins y agrega una caja en el MISMO commit de perfil, sin yield. Open determina premio, prepara todos los datos, reserva stock y hace un commit de perfil con consumo y premio juntos. Luego convierte la reserva en emisión. El resultado está registrado antes del primer evento visual. Spin/cierre/HUD no conceden nada.

El lock es el existente ShopService._withShopLock por jugador. Tras la consulta PolicyService se vuelven a validar conexión, lobby y perfil cargado. No se ejecutan consultas cloud en las pruebas automáticas.

## Stock

StockLedger modifica en una sola transición las restricciones `Reward:RewardId:EditionId` y, opcionalmente, `Variation:VariationId:EditionId`. Una unidad reserva un cupo en CADA restricción activa. Commit mueve cada cupo de Reserved a Issued; Release solo admite Reserved. Una emisión nunca vuelve a stock.

El remanente elegible es el mínimo de los límites activos. TotalSupply es el límite propio de la recompensa si lo tiene; Constraints expone el límite agregado por separado. IssuedCount cuenta emisiones de esa RewardId; no se confunde con unidades poseídas ni propietarios únicos. CurrentlyOwnedUnits y UniqueOwnerCount permanecen desconocidos mientras no haya un índice autoritativo correspondiente. Sin límites se muestra Ilimitado; también se cuentan emisiones dentro del ledger local.

Las cantidades y EditionId son inmutables una vez usada una edición. Cambiar Supply sobre un bucket existente falla. No hay stock limitado comercial configurado. No hay TTL que libere automáticamente reservas ambiguas.

InMemoryStock es **por proceso de servidor de Studio**, nunca stock global real. Reiniciar todo Studio descarta ese entorno de prueba, perfiles y stock; no constituye regeneración de una edición productiva.

## Estados y fallos

| Momento del fallo | Acción segura |
|---|---|
| Policy, precio, pesos, recursos o stock desconocidos | Rechazar antes de cobrar o consumir. |
| Cambian probabilidades/stock tras consulta | OddsChanged; mostrar nueva distribución antes de reintentar. |
| Compra ya registrada | Devolver recibo; no volver a debitar. |
| Reserva rechazada | No commit de perfil; ninguna caja consumida. |
| Perfil no se pudo confirmar ANTES de otorgar | Release de la reserva conocida no emitida; conservar caja y Coins. |
| Perfil ya tiene GrantCommitted y falla stock.Commit | Conservar reserva y unidad. Reconcile reintenta MISMO UnitId; no liberar, rerollear ni cobrar. |
| Se pierde respuesta de apertura / desconexión durante spin | Recibo en perfil; repetir OperationId devuelve el mismo resultado. Inventory reconcilia y permite consultar último premio. |
| Repetir evento de presentación | Cliente deduplica OpeningId. Ningún evento cliente otorga unidades. |
| Se alcanza capacidad de journal | Fallar cerrado; no borrar recibos automáticamente y reabrir posibilidad de duplicación. |

Límites V1 deliberados: 256 operaciones de perfil, 1024 en ledger; no existe retención automática que olvide IDs. Requiere diseño de archivo/retención antes de producción. Anuncios y eventos visuales son best-effort tras commit: una caída puede perder presentación, nunca el derecho ya registrado. En esta fase no se promete entrega durable exactamente una vez de notificaciones entre reinicios.

## Backend productivo preparado y BLOQUEADO

ProductionStockAdapter acepta un store inyectado y un key de ledger, usa UpdateAsync con StockLedger idempotente y no busca DataStoreService. Reserva conjunta evita una adjudicación independiente del último cupo de reward y variación. Una respuesta perdida tras UpdateAsync se trata como resultado desconocido: reintentar con MISMO OperationId. View devuelve AuthoritativeSnapshotRequired; no finge conocer stock mediante un GetAsync cacheado.

El adaptador NO está conectado al proveedor de producción. CrateService selecciona stock únicamente cuando IsStudio, InMemory y WritesToCloud=false coinciden. Fuera de ese entorno no hay proveedor y toda venta/apertura se bloquea, incluso si alguien aprueba precios en el catálogo. Catalog.ProductionCommerceEnabled=false es informativo; cambiarlo solo NO habilita producción.

Antes de habilitarla hace falta implementar y validar:

1. Lease/ownership exclusivo del perfil por sesión de servidor, versionado/CAS y escrituras durables del journal de Coins/cajas/unidades. SavePlayer actual no ofrece esto.
2. Intent durable con OperationId y quote/version aprobada antes de cualquier mutación; precio cobrado/caja adquirida atómicamente en perfil.
3. Resultado fijado en journal durable antes de reservar, sin reroll en reintentos; reserva del ledger con MISMA identidad.
4. Commit durable de consumo+unidad+GrantCommitted en perfil bajo lease; confirmar stock sin liberar ante resultado ambiguo.
5. Worker de reconciliación tras caída/reconexión que consulte ambos journals. Solo liberar con prueba durable de abort previo al otorgamiento y dueño de lease válido. Nunca usar timeout como prueba de que no hubo grant.
6. Snapshot autoritativo/versionado de elegibilidad y stock para disclosure, revisión ante carreras, límites de tamaño/budget/hot key, journal de outbox e índices de ownership si se necesitan.
7. Pruebas reales con varios servidores, fallos y cierres en CADA transición. Esas pruebas NO se realizaron ni están autorizadas en esta fase.

No hay transacción atómica entre DataStores, Coins e inventario por el mero uso de UpdateAsync. Las pruebas del adaptador usan un store falso compartido con callback repetido/respuesta perdida. No son prueba de stock global de producción.
