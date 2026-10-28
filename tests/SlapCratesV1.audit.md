# Auditoría previa — Slap Crates V1

Fecha: 2026-10-18. Inspección de repositorio y Studio Edit, sin cargar servicios ni ejecutar partidas.

| Área existente | Hallazgo y extensión mínima |
|---|---|
| ShopService / ShopRegistry | Providers y categorías dinámicos; registro por Category+Id. Se agregan providers Crates y Slaps desde CrateService.Start, sin reescribir ShopService. |
| ProfilePurchase | Compra cosméticos/habilidades con Owned booleano. No soporta consumibles; se conserva intacto y la API de cajas usa su propio staging sobre el MISMO perfil y el mismo lock de Shop. |
| PlayerService | Autoridad de Coins e Inventory, commit no-yield y DataUpdated. Nuevo CommitCrateState reutiliza estos caches y notificaciones. |
| PlayerDataService | Sanitiza Owned/Equipped y antes descartaba campos adicionales de Inventory. Ahora conserva Crates, SlapUnits y CrateOperations. SavePlayer ya guarda Inventory completo mediante el proveedor inyectado. |
| SlapService | GiveSlap clona ServerStorage.Slaps; Classic fallback y lock de combate. Extensión acotada para resolver selección y aplicar cosméticos sobre la misma Tool. Ningún cambio en ProcessSlap. |
| Slaps físicos | Único Tool observado: ServerStorage.Slaps.Classic, Configuration.Power=20, SlapCooldown=0.6, Swing y Hand.Hit. No hay SlapProvider, registro de cajas ni catálogo de variaciones previos. |
| Inventario | Owned/Equipped genéricos. Extensión aditiva dentro de Inventory, sin moneda ni inventario paralelo. Classic:Basic es derecho inicial; derechos legados se conservan. |
| ShopHUD | Pantallas editables, ProductCardTemplate, DetailPanel y tabs por atributo Category. Se agregan tab CAJAS, paneles de probabilidades/apertura y plantilla de botones; categorías anteriores conservadas. |
| Remotes | Shop.GetCatalog filtra Metadata solo para Ability: se añade whitelist comercial Crates para que no aparezcan precios pendientes como 0. Nueva API Remotes.Crates separa Purchase/Open/Quote/Inventory. |
| Chat | No hay adaptador de anuncios en src. Se usa TextChatService/RBXGeneral existente con evento de servidor; sin chat paralelo ni MessagingService. |
| Assets | Se reutiliza MeshId y proporciones de Classic.Hand para su preview. Se crean cajas geométricas, ParticleEmitters y Sounds vacíos editables. No se inventan SoundIds o diseños definitivos. |
| RoundService / EndCinematic | Se leen sesión y ResultsSessionId para bloquear aperturas fuera del lobby. Ambos sistemas quedan intactos. |
| Persistencia | Studio selecciona InMemory, WritesToCloud=false. La selección y Universe ID no se modifican. No existe backend de perfil transaccional con session lease para comercio entre servidores; producción bloqueada. |

La separación PurchaseCrate/OpenCrate es viable mediante una extensión aditiva pequeña del inventario actual; no hace falta alternativa de compra+apertura inseparable.

La restricción conservadora de PolicyService se aplica también a Coins. Base consultada: [Roblox: paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items). No se habilita trading.
