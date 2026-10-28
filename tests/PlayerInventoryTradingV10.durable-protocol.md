# Trading durable — diseño requerido, implementación bloqueada

Este documento es una especificación de la integración futura, **no un protocolo durable implementado o validado**. TradeTransactionService.Commit siempre devuelve TradeCommitDisabled; TradeRecoveryService declara explícitamente que no dispone de reconciliación durable. No hay DataStore nuevo ni escrituras de transacción en V1.0.

## Bloqueo actual

El ciclo legacy GetAsync/copia runtime/SavePlayer puede sobrescribir una revisión nueva de otro servidor. El leasing de ProfileReceiptStore solo protege sus propios métodos; no gobierna todavía todas las recompensas, compras, guardados, cargas, aperturas y equipamientos del juego. No es seguro conectar trading a ese motor por separado. DurableReceiptBackend también permanece bloqueado hasta disponer del puente de perfiles. No se altera el Universe ID ni el nombre del DataStore.

## Contrato necesario antes de habilitar un backend

Un único dueño serializado por perfil debe cercar **todas** las mutaciones y SavePlayer/BindToClose, renovar lease con fencing token monótono, rechazar snapshots viejos y reconciliar pendientes antes de publicar inventario utilizable. No basta un mutex dentro del servidor ni dos UpdateAsync sucesivos. Debe existir recuperación offline entre servidores y un índice durable descubrible de operaciones pendientes, sin depender de que vuelvan ambos jugadores.

## Protocolo propuesto

1. Crear journal durable por TradeId con intención inmutable: participantes, UnitIds exactos, RewardIds, procedencia, revisiones y fencing esperados. Reintentar el mismo TradeId solo si la intención coincide exactamente. No usar nombres visuales como identidad.
2. Preparar los dos perfiles con reservas **persistidas** de unidades, por orden determinista de UserId, conservando UnitId original, origen e historial. Validar políticas, copias, locks, catálogo, capacidad de destino y ownership contra el estado durable vigente. Si un perfil está ocupado por otro servidor, no robar su lease.
3. Las unidades preparadas permanecen bloqueadas para equipamiento/consumo/comercio y los guardados normales no pueden borrar ese bloqueo. Antes de decidir, se puede abortar mediante journal durable; solo la reconciliación libera reservas con una decisión de aborto confirmada.
4. Registrar una única decisión durable Commit/Abort en el journal mediante compare-and-update. Una decisión Commit es irreversible; ya no depende de GUI, conexión ni estado de partida. Nunca reportar Completed por aceptar una animación o un ack del cliente.
5. Aplicar idempotentemente a cada perfil el mismo TradeId/versión: retirar las unidades salientes y anexar las entrantes con nuevo OwnerUserId, manteniendo la identidad UnitId. Recalcular Owned.Slaps desde unidades/entitlements y sustituir el equipado por Classic:Basic si ya no queda copia. La operación por perfil registra qué revisión aplicó y queda bloqueada hasta la finalización global.
6. Después de leer y confirmar durablemente ambos Applied, registrar resolución final. Solo entonces el puente puede publicar inventarios utilizables, levantar las reservas y notificar éxito. Una aplicación parcial nunca entrega unidades utilizables mientras el otro dueño puede usarlas. El receptor y donante siguen bloqueando esas unidades ante cualquier estado incierto.
7. La recuperación lee la decisión, reejecuta pasos idempotentes pendientes con fencing actualizado y verifica las dos aplicaciones antes de liberar. Cada carga desde otro servidor debe consultar pendientes y mantener las unidades afectadas en cuarentena. Los eventos retrasados no pueden revertir ownership ni repetir premios.

## Casos que deben demostrarse con el backend integrado

Fallo antes/después de cada escritura del journal o de A/B, timeout de respuesta con escritura sí confirmada, cierre de servidor, desconexión, expiración de lease, dos recuperadores, otro servidor cargando A/B, replay de intención, reservas duplicadas, guardado obsoleto y catálogo/stock restringido. Verificar conservación exacta de UnitIds y ausencia de unidades utilizables por ambos perfiles. El estado incierto debe ser recuperable sin borrado definitivo.

También faltan migración y drenaje de servidores legacy, límites/compactación auditada de journals, capacidad de inventario y política de duplicados al recibir, actualización del ownership del stock limitado y aprobación explícita de fuentes Premium. Ninguna se sustituye por un flag. Primero deben pasar pruebas de fallos deterministas y pruebas reales autorizadas en un universo separado; Studio/InMemory mantiene el commit apagado.
