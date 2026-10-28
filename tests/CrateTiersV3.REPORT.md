# Cajas por variación y descubrimiento de Slaps V3

## Reglas aprobadas por el desarrollador

Cada caja normal favorece su variación: 60% propia, 20% inmediatamente inferior y 20% inmediatamente superior. Basic y Galaxy usan 80% propia y 20% vecina. Solo se incluyen esas variaciones. El modelo se distribuye equitativamente entre los modelos elegibles de cada variación. Duplicados individuales autorizados: tener un premio no modifica sus probabilidades.

| Caja | Inferior | Propia | Superior |
| --- | --- | --- | --- |
| Basic | — | Basic 80% | Common 20% |
| Common | Basic 20% | Common 60% | Uncommon 20% |
| Uncommon | Common 20% | Uncommon 60% | Rare 20% |
| Rare | Uncommon 20% | Rare 60% | Gold 20% |
| Gold | Rare 20% | Gold 60% | Arcoiris 20% |
| Arcoiris | Gold 20% | Arcoiris 60% | Emote 20% |
| Emote | Arcoiris 20% | Emote 60% | Wings 20% |
| Wings | Emote 20% | Wings 60% | Epic 20% |
| Epic | Wings 20% | Epic 60% | Legendary 20% |
| Legendary | Epic 20% | Legendary 60% | Blood 20% |
| Blood | Legendary 20% | Blood 60% | Galaxy 20% |
| Galaxy | Blood 20% | Galaxy 80% | — |

Con los tres modelos actuales, cada modelo Gold tiene 20% en caja Gold; cada modelo Rare/Arcoiris tiene aproximadamente 6,6667%. Si falta solo un modelo, el peso de su variación se reparte entre los restantes. Si una variación con peso positivo no tiene ningún candidato válido, la compra/apertura se bloquea con RequiredVariationUnavailable; no se venden porcentajes distintos mediante una renormalización silenciosa.

## Modelos y recursos físicos

Tres modelos: Classic, Chancla y PingPong. Bases originales: ServerStorage.Slaps.Classic, Slap_Chancla y Slap_PingPong. Doce Tools por modelo en ServerStorage.SlapVariations.<SlapId>.<VariationId>, 36 en total.

Se crearon únicamente las 24 variantes faltantes de Chancla y PingPong, conservando el Tool completo y cambiando Hand.Color y Highlight. El Hand de PingPong sigue siendo UnionOperation; los otros MeshPart. Los tres Tools base y las doce variantes Classic previas se verificaron byte a byte sin cambios:

- Slaps originales: SHA-256 serializado `72fc11c4ac280940b04dd4fa0d67deb51c4b33f30f9c5b8e5225fac93b28a019`.
- Árbol Classic previo: SHA-256 serializado `80bfcac7bd05722d182e9f88a01dd3d873c58c29ac4971beecb375b03b66db33`.

## Registro y futuras incorporaciones

SlapResourceRegistry inspecciona únicamente hijos físicos de ServerStorage.Slaps y las carpetas de ServerStorage.SlapVariations. Valida Tool, Hand BasePart, Configuration.Power positivo finito y SlapCooldown no negativo finito. Acepta MeshPart y UnionOperation; no requiere scripts contenidos en los recursos. Rechaza nombres/IDs ambiguos y duplicados; recursos desconocidos o inválidos generan diagnóstico y no se convierten en premios.

Un base llamado Slap_Chancla se identifica por defecto como Chancla; un atributo SlapId explícito permite fijar el ID. No renombrar IDs ya entregados sin migración. Las carpetas de variantes se vinculan por ese ID (también se conserva su nombre físico en metadata). Una carpeta válida de variantes puede aportar un modelo sin base separado, siempre que sus Tools sean completos. El base solo aporta Basic automáticamente; otras variaciones necesitan un Tool físico válido, no se inventan.

Bootstrap publica metadata y previews completas antes de cargar servicios/Shop. SlapDefinitions consume la misma metadata replicada; los clientes esperan SlapCatalogReady. En Edit y ambos proyectos se dejó el atributo false: únicamente el siguiente arranque del servidor lo activa tras publicar el catálogo. En ejecución real falta de metadata aborta, no cae a un catálogo silenciosamente distinto. El fallback Classic de SlapDefinitions queda solo para herramientas offline/Edit sin metadata.

Las previews de ReplicatedStorage.SlapVariationPreviews.<SlapId>.<VariationId> se regeneran desde los Tools físicos al arrancar. CrateRewardPreviews contiene un modelo completo por base. Configuración, geometría y componentes se conservan; las copias de presentación están ancladas y sin colisiones, y no contienen scripts. Las plantillas físicas de variación son autoritativas: no se superponen efectos cosméticos generados aunque el artista no haya marcado manualmente SlapVariationAuthored. Los componentes agregados a la plantilla se conservan al equipar.

### Agregar un modelo nuevo con una variación existente

1. Crear un Tool base válido en ServerStorage.Slaps (p. ej. Slap_Mazo), conservando Hand, Handle, Swing y Configuration.
2. Crear ServerStorage.SlapVariations.Mazo y colocar dentro Tools completos llamados Gold, Rare, etc. Solo se registran las variantes físicas existentes. Al clonar entre modelos, limpiar/corregir atributos de identificación heredados: el SlapId del base debe corresponder al nuevo modelo.
3. Guardar tus cambios de Edit. En la siguiente prueba, Bootstrap detecta el modelo, publica su metadata/previews y lo añade al catálogo compartido, cajas, inventario y panel admin. No hace falta añadir cada recompensa a cada caja.
4. Si se usa Rojo como fuente de assets, actualizar también sus archivos binarios antes de una sincronización que vuelva a aplicar snapshots antiguos; guardar un lugar de Studio no actualiza automáticamente los .rbxm del repositorio.

Una decimotercera rareza requiere definir sus metadatos, posición en InitialOdds.VariationOrder, caja/precio y revisar la validación de matriz (actualmente doce). No se incorporan nuevas rarezas comerciales arbitrariamente por el nombre de una carpeta. El trade conserva su whitelist y restricciones: descubrir un modelo no habilita automáticamente su transferencia.

## Entrega y estado comercial

Las doce cajas normales ahora tienen Enabled=true, OddsApproved=true, DuplicatePolicy=AllowDuplicates y matriz TierAdjacentV3. Precios originales sin cambios. Compra de una caja usa Coins; abrir consume la caja y registra Owned.Slaps, SlapUnits y CrateOperations. Cada duplicado tiene un UnitId distinto; un reintento de la misma operación conserva el premio y no consume otra caja. Se reutilizaron Engine, BatchEngine, CommitCrateState y el flujo del stand/cinemática existentes.

**Habilitadas para Studio aislado. Las ventas de producción NO quedaron habilitadas.** CrateService sigue seleccionando stock únicamente con Studio / InMemory / WritesToCloud=false y rechaza producción con ProductionBackendBlocked. El backend durable productivo sigue pendiente; no se conectó ProductionStockAdapter ni se alteraron Universe IDs/DataStores. Las cajas Premium y su monetización permanecen deshabilitadas. La política Roblox de ítems aleatorios se conserva, incluso en Studio; no se añadió un bypass.

## Verificación

- 498 aserciones nuevas aisladas: descubrimiento físico, 36 premios, todas las distribuciones exactas, duplicados, modelos faltantes, compra/apertura/x5/reintentos, stock y bloqueos productivos.
- Regresiones: 271 perfiles/equipamiento/trade, 17 registro real de Shop, 73 admin/práctica, 150 combate, 86 Shop/economía y 6 resolver. Total aislado: 1.101.
- 236 comprobaciones en Edit: Tools/Models completos, MeshPart/Union, colores, highlights, mecánica original, catálogo fresco, doce cajas, configuración Gold, protección Premium/producción y Studio/InMemory/WritesToCloud=false.
- 189 scripts compilan; ambos builds Rojo y git diff --check PASS. Diez scripts sincronizados verificando Source y draft; preservados los cambios anteriores.
- No se ejecutaron Play, Run, Start Server, aperturas con jugadores, compras reales, escrituras cloud, publicaciones, commits ni push.
- Gameplay/cámara/UI final y entrega multicliente: NOT RUN; validación del desarrollador pendiente. Las pruebas históricas de la matriz anterior/pending/UniquePerPlayer no son el criterio del balance nuevo aprobado.

## Archivos y recuperación

Nuevo: src/server/Services/Crates/SlapResourceRegistry.luau. Modificados: Bootstrap.server.luau, AdminService.luau, CrateService.luau y Shared/SlapCrates/{SlapDefinitions,InitialOdds,CrateDefinitions,Odds,Catalog,CrateShopView}.luau. No se modificaron precios, combate, PlayerService, persistencia, HUD o mapas.

Cinco snapshots nuevos en src/assets: SlapBaseToolsV3.rbxm, SlapVariationToolsV3.rbxm, SlapCatalogV3.rbxm, SlapVariationPreviewsV3.rbxm y SlapRewardPreviewsV3.rbxm. Ambos proyectos los mapean; SAFE incluye el nuevo módulo (189 scripts). Se extendió el runner de pruebas y la prueba del resolver para el contrato físico nuevo. No se borraron assets históricos.

Respaldo específico: tests/assets/backups/CrateTiersV3, con scripts/proyectos previos y exportaciones de bases/variantes/previews. El respaldo integral anterior permanece intacto. No se guardó ni cerró el lugar abierto; el desarrollador debe guardar sus cambios de Edit cuando corresponda.

## Validación manual

1. Iniciar vos una sesión nueva. Revisar Output: Studio, InMemory, WritesToCloud=false; `[SlapCatalog] Registered 3 physical Slap models`; registro de proveedores Crates y Slaps sin errores.
2. ADMIN: concederte Coins de prueba. Abrir Shop → Cajas → Gold → consultar probabilidades. Debe mostrar nueve resultados: Gold de los tres modelos al 20% cada uno, Rare/Arcoiris de los tres modelos aproximadamente al 6,6667% cada uno. Ninguna otra variación.
3. Comprar Gold por 4.500 Coins. Comprobar descuento único y caja cerrada en inventario. Abrir en su stand; comprobar modelo completo y recompensa en inventario sin segundo cobro.
4. Repetir y probar x5/x10 con suficientes cajas. Los duplicados deben aparecer como unidades independientes. Verificar un nuevo modelo desde inventario, equiparlo y probarlo vos en el maniquí/partida.
5. Revisar Basic (80/20 Common) y Galaxy (80/20 Blood), y coincidencia de probabilidades mostradas al poseer ya los premios. No inferir porcentajes reales solo de unas pocas aperturas: la distribución exacta está comprobada por tests deterministas.
6. Si falla, enviar Output desde arranque y mensaje/caja/acción. No activar producción ni Premium para intentar sortear el error.
