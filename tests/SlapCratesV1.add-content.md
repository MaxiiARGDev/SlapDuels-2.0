# Incorporar contenido — Slap Crates V1

Los registros están en ReplicatedStorage.Shared.SlapCrates.Catalog: Variations, Crates, Slaps y Rewards. Registry.Build valida IDs y rechaza duplicados. Solo se requieren módulos de la manifest explícita; no se ejecutan módulos descubiertos en carpetas o enviados por clientes. Los módulos sensibles permanecen en ServerScriptService.Services.Crates.

## Slap base

1. Crear Tool válido en ServerStorage.Slaps con Configuration.Power/SlapCooldown, Swing y geometría/Hand existentes. No agregar scripts de activación paralelos.
2. Añadir definición en SlapDefinitions: SlapId estable, DisplayName, Model (nombre exacto de Tool), VariationIds autorizados. Una definición puede estar en un ModuleScript nuevo requerido explícitamente desde esa manifest.
3. Añadir modelo visual sin scripts en ReplicatedStorage.CrateRewardPreviews[SlapId], con partes Anchored y sin colisiones/touch/query. No replicar la Tool autoritativa.
4. No modificar SlapService, ShopService ni HUD. Catalog genera RewardId=SlapId:VariationId; un nuevo Slap divide el peso de su variación entre más resultados elegibles, por lo que se debe revisar la aprobación de probabilidades.

## Variación

1. Definición en VariationDefinitions o módulo requerido explícitamente por esa manifest: Id, DisplayName, Description, SortOrder, Color, Icon, VisualProfile, VFX, SFX, AnnounceInChat, LimitedStock, DefaultStock, AdditionalConfig.
2. Crear ReplicatedStorage.SlapVariationEffects[VisualProfile]. Tint es atributo Color3; ParticleEmitters/Attachments se copian a Hand. Un Sound llamado Hit, con SoundId aprobado, puede reemplazar únicamente SoundId/Volume/PlaybackSpeed de Hand.Hit. No editar Configuration ni Swing para una skin.
3. Añadir VariationId a los SlapDefinitions que la admiten y pesos de las cajas correspondientes. No se otorgan automáticamente todas las variaciones de un Slap.
4. Emote/Wings son perfiles cosméticos, no sistemas de emotes/alas.

## Caja

Crear definición en CrateDefinitions o ModuleScript nuevo incluido expresamente en esa manifest:

```
CrateId, SortOrder (número finito obligatorio), DisplayName, Description, Icon, Model,
PriceCoins, PriceApproved, OddsApproved, ApprovalStatus, Enabled,
RollDuration (1..30), AnimationProfile, VFX, SFX,
Weights = { [VariationId] = peso },
DuplicatePolicy = "UniquePerPlayer" o "AllowDuplicates",
SoldOutPolicy = "ExcludeAndRenormalize", StockRules
```

Model corresponde a ReplicatedStorage.CrateEffects[Model] con Body/Lid; nombres VFX/SFX remiten a perfiles configurables del mismo recurso. La presentación Horizontal de V1 utiliza Body/Lid, ParticleEmitters y Sounds dentro del modelo; ampliar AnimationProfile con una dependencia visual nueva requiere implementar su adaptador antes de habilitar ese perfil. V1 no ejecuta perfiles arbitrarios ni finge soportar otro tipo de animación.

Desde V1.2, las cajas se ordenan por SortOrder ascendente y CrateId como desempate. Los valores actuales avanzan de 10 en 10: una caja futura con SortOrder=35 se ubica entre Uncommon y Rare. Las demás categorías conservan su orden anterior. Ver SlapCratesV12.manual.md para la fixture habilitada en Edit.

Crear modelos/partículas/audio editables y aprobarlos. Sounds vacíos significan audio pendiente, no usar IDs inventados. Registrar recursos en los .project.json para que el build los conserve. La nueva caja aparece mediante el provider existente sin editar ShopService/controladores.

Mantener Enabled=false, PriceApproved=false y OddsApproved=false hasta aprobación humana. No interpretar nil como gratuito. No cambiar StudioTest en una caja comercial: es una fixture opt-in con precio 1 y pesos 3:1 solo de prueba.

## Probabilidades reales

Odds.Resolve excluye resultados no disponibles, sin stock o ya poseídos bajo UniquePerPlayer. Para cada variación divide su peso entre sus SlapId elegibles y luego normaliza los pesos efectivos globales. La UI recibe porcentaje por RewardId, no porcentaje de variación presentado como probabilidad individual. Variaciones sin resultados no contribuyen al denominador. Pesos negativos, NaN, infinitos, desconocidos o tabla sin resultados bloquean la apertura.

Consultar Quote antes de comprar/abrir. El token dura 30 s y compara distribución y remanentes con los actuales. Si cambian, se requiere volver a mostrarlos. Cada caja puede tener pesos propios; compartir nombre con una variación no garantiza obtenerla.

## Ediciones limitadas y stock

StockDefinitions es una manifest separada sin cantidades aprobadas actualmente. Configurar Rewards[RewardId] con LimitedStock=true, TotalSupply aprobado y EditionId inmutable. Para límite agregado usar Variations[VariationId] con DefaultStock y EditionId. Cada emisión descuenta una unidad de ambos límites activos. No cambiar cantidades de una edición utilizada; no hay compensaciones por duplicados habilitadas.

Revisar SlapCratesV1.persistence.md. InMemory no es global y producción permanece bloqueada aunque se aprueben estos campos.

## Anuncios

AnnounceInChat=true en la definición deseada; ninguna variación anuncia por su nombre automáticamente. El servidor usa OpeningId/RewardId reales y el cliente escribe en TextChatService.RBXGeneral. No hay MessagingService; adaptador de anuncios globales y outbox durable son trabajo posterior, sin conexión cloud en V1.

## Validación de una incorporación

Ejecutar pruebas de registros, probabilidades finales, propiedad exacta, últimas unidades y equipamiento; ambos builds y comparación de fuentes con Studio Edit. Después el desarrollador prueba presentación/sonidos/dos observadores en Play. No declarar aprobados visuales o stock entre servidores mediante mocks.
