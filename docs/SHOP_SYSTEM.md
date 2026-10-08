# SHOP SYSTEM

> Fuente de verdad arquitectónica para el diseño, extensibilidad e implementación del sistema de Tienda (Shop Framework) en Slap Duels 2.0.

---

## Overview

El **Shop Framework** de *Slap Duels 2.0* es un sistema modular, desacoplado y autoritativo en el servidor diseñado para catalogar, comercializar, entregar y equipar diversos tipos de productos del juego (cosméticos y consumibles).

El principio rector del sistema es la **indiferencia del núcleo hacia los productos concretos**: `ShopService` actúa exclusivamente como un orquestador transaccional. No contiene listas hardcodeadas de productos, no implementa lógica específica de ninguna categoría cosmética y no asume cómo se almacenan ni cómo se aplican los ítems en el juego. La definición de catálogo, la validación de entrega y la ejecución del equipamiento se delegan a **Product Providers** especializados registrados dinámicamente en un **ShopRegistry**.

Asimismo, el Shop Framework soporta de forma nativa y oficial dos mecanismos de moneda en su contrato base:
1. **`Coins`:** Moneda interna del juego, gobernada autoritativamente por el servidor.
2. **`Robux`:** Moneda oficial de la plataforma, procesada autoritativamente mediante las APIs de monetización de Roblox.

---

## Goals

1. **Modularidad total (Provider Pattern):** Permitir añadir nuevas familias de productos (ej. Trails, Slaps, Emotes, Auras, Titles) sin modificar una sola línea de `ShopService`.
2. **Autoridad absoluta del Servidor:** Validación estricta de existencia, disponibilidad, precios, propiedad, fondos e idempotencia en el servidor. El cliente es una terminal de visualización pasiva.
3. **Soporte oficial de divisas (Coins y Robux):** Contrato base preparado desde su diseño para transacciones con moneda interna (`Coins`) y transacciones oficiales de plataforma (`Robux`), sin tratar a ninguna como una extensión improvisada.
4. **Fuente única de verdad económica:** Integración directa con el sistema de economía y estadísticas existente (`PlayerService`), sin duplicación de saldos ni fuentes paralelas.
5. **Separación de responsabilidades:** Desacoplar catálogo (inmutable/público), inventario (propiedad genérica del jugador), procesamiento de pagos y estado de equipamiento (slots activos en runtime).
6. **Esquema de inventario agnóstico:** Estructura de posesión y equipamiento indexada dinámicamente por categoría, permitiendo registrar nuevas categorías sin alterar el esquema de datos.

---

## Non-Goals

1. **No es un sistema de combate:** El Shop no otorga ventajas pay-to-win ni altera multiplicadores de knockback o daño sin pasar por los contratos de balance autoritativos de `SlapService`/`CombatService`.
2. **No es un DataStore paralelo:** El Shop no crea archivos de persistencia separados ni bases de datos desconectadas; se integra al ciclo de vida de `PlayerDataService`.
3. **No es una UI monolítica:** El backend del Shop no conoce marcos, botones, animaciones ni templates de Roblox GUI. Expone datos y remotes agnósticos a la interfaz visual.
4. **No es exclusivo de Point Effects:** Aunque Point Effects es el primer sistema cosmético presente en el código, el Shop no está modelado alrededor de él.
5. **No otorga ítems desde el cliente:** El cliente jamás confirma una compra ni entrega ownership basándose en eventos locales.

---

## Architecture

El Shop Framework desacopla la orquestación del catálogo, los proveedores de contenido y los canales de pago:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                              CLIENT LAYER                              │
│                                                                        │
│   ┌─────────────────────┐                 ┌────────────────────────┐   │
│   │       ShopUI        │ ◄─────────────► │     ShopController     │   │
│   │   (Vistas/Frames)   │                 │   (Cache/Eventos/Req)  │   │
│   └─────────────────────┘                 └───────────┬────────────┘   │
└───────────────────────────────────────────────────────┼────────────────┘
                                                        │ Remotes (Invoke/Fire)
┌───────────────────────────────────────────────────────┼────────────────┐
│                              SERVER LAYER             ▼                │
│                                                                        │
│                            ┌─────────────┐                             │
│                            │ ShopService │ (Orquestador Transaccional) │
│                            └──────┬──────┘                             │
│                                   │                                    │
│         ┌─────────────────────────┴─────────────────────────┐          │
│         │ Resuelve categoría y catálogo                     │ Resuelve canal de pago
│         ▼                                                   ▼          │
│  ┌──────────────┐                               ┌────────────────────┐ │
│  │ ShopRegistry │                               │  Payment Layer     │ │
│  └──────┬───────┘                               │  (Currency Router) │ │
│         │                                       └─────────┬──────────┘ │
│         ├──────────────────────────┐                      │            │
│         ▼                          ▼         ┌────────────┴──────────┐ │
│  ┌──────────────┐           ┌─────────────┐  ▼                       ▼ │
│  │Cosmetic Prov.│           │Consumable P.│┌──────────────┐  ┌────────┐│
│  │(Trails,Slaps,│           │  (Coins)    ││Internal Econ │  │Roblox  ││
│  │PointEffects) │           └─────────────┘│(PlayerService│  │Market  ││
│  └──────────────┘                          │/EconomyServ.)│  │APIs    ││
│                                            └──────┬───────┘  └────────┘│
│                                                   │                    │
│                                                   ▼                    │
│                                            ┌──────────────┐            │
│                                            │PlayerDataServ│ (Persist.) │
│                                            └──────────────┘            │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Responsibilities

| Componente | Responsabilidad Principal | Qué puede modificar | Qué NO puede modificar |
| :--- | :--- | :--- | :--- |
| **`ShopService`** | Orquestar compras, verificar idempotencia/locks transaccionales, enrutar pagos según `Currency`, coordinar con `ShopRegistry`. | Estados de transacciones en curso (locks temporales). | Catálogos de items, saldos directos, almacenamiento de inventario. |
| **`ShopRegistry`** | Registro en memoria de `ProductProviders` y resolución de proveedores por `CategoryId`. | El diccionario de proveedores registrados. | Nada externo al registro. |
| **`ProductProvider`** | Definir el catálogo de su categoría, validar si un ítem puede ser comprado/equipado y aplicar el efecto de entrega física/equipamiento. | Metadatos y assets de sus productos propios. | Saldos de monedas del jugador, procesamiento de pagos Robux, persistencia global directa. |
| **`Payment Layer / Economy`** | Procesar pagos según divisa: cobro en `Coins` (vía `PlayerService`/`EconomyService`) o inicio/validación de `Robux` (vía APIs oficiales de Roblox). | Invocar deducciones o validar transacciones de plataforma. | Catálogo de productos, reglas de equipamiento. |
| **`PlayerService`** | **Única fuente de verdad en runtime** de las estadísticas (`Coins`, `Wins`, `Kills`) y del inventario del jugador. | `PlayerService._data[player]`, `leaderstats`. | Lógica de precios, catálogo de productos. |
| **`PlayerDataService`** | Serialización, deserialización, versionado y persistencia en `DataStoreService`. | Datos guardados en DataStore. | Lógica de gameplay o de catálogo en tiempo real. |
| **`ShopController`** | Recibir el catálogo del servidor, cachear estado local de ownership para la UI, emitir peticiones de compra/equipamiento. | Estado de presentación local en cliente. | Saldos, precios, ownership autoritativo en servidor. |
| **`ShopUI`** | Renderizar cuadrículas de productos, botones de compra/equip, estados visuales (Owned, Equipped, Price). | Elementos visuales de pantalla (GUI). | Ninguna regla de negocio, precios, transacciones ni validaciones. |

---

## Product Model

El modelo de producto está estandarizado para permitir que cualquier categoría y divisa se represente de manera uniforme:

```luau
export type CurrencyType = "Coins" | "Robux"

export type ProductType = "Cosmetic" | "Consumable"

export type ProductDefinition = {
    -- Campos Obligatorios
    Id: string,                      -- Identificador único del producto (ej: "Trail_Fire", "Coins_Pack_Small")
    Category: string,                -- Identificador de categoría registrada (ej: "Trails", "Coins", "Slaps")
    ProductType: ProductType,        -- "Cosmetic" o "Consumable"
    DisplayName: string,             -- Nombre legible en la interfaz (ej: "Estela de Fuego")
    Price: number,                   -- Costo en Coins (si Currency == "Coins") o display price referencial (si Currency == "Robux")
    Currency: CurrencyType,          -- Moneda oficial: "Coins" o "Robux"
    IsAvailable: boolean,            -- Bandera de disponibilidad (permite deshabilitar sin borrar)

    -- Requerido según Currency
    RobloxProductId: number?,        -- Requerido si Currency == "Robux" (DeveloperProductId o ProductId oficial)

    -- Campos Opcionales / Metadata
    Description: string?,            -- Descripción o lore del producto
    Rarity: string?,                 -- "Common", "Rare", "Epic", "Legendary" (para cosméticos)
    AssetId: string?,                -- Asset de Roblox (TextureId, SoundId, MeshId, AnimationId)
    Icon: string?,                   -- Thumbnail o rbxassetid para el botón de tienda
    Metadata: { [string]: any }?,    -- Propiedades específicas de la categoría (ej: ColorSequence, TrailLifetime)
}
```

### Diferenciación Conceptual de Estados

1. **Product Definition (Catálogo):** Datos inmutables y globales compartidos por todos los jugadores. Define qué es el ítem, cuánto cuesta, su divisa y a qué categoría pertenece.
2. **Player Ownership (Inventario):** Conjunto de IDs que un jugador específico ha desbloqueado de forma permanente.
3. **Equipped State (Ranuras Activas):** El ID de producto actualmente activo en cada ranura equipable del personaje.

---

## Currencies: Regla Fundamental y Diferencia de Precios

El Shop Framework soporta oficialmente dos divisas, cada una con reglas de autoridad y validación estrictas:

### 1. `Currency = "Coins"` (Economía Interna)
- **Significado:** El producto se adquiere debitando monedas del saldo persistente del jugador.
- **Autoridad de Precio:** El campo `Price` representa el costo autoritativo exacto definido en el `ProductDefinition` del servidor.
- **Flujo de Pago:**
  ```text
  ShopService ➔ Validación ➔ Capa Económica (PlayerService) ➔ Verificar Coins ➔ Deducir Coins ➔ Entrega
  ```

### 2. `Currency = "Robux"` (Monetización Oficial de Plataforma)
- **Significado:** El producto se adquiere mediante una transacción oficial procesada por los servicios de monetización de Roblox.
- **Requisito Obligatorio:** Debe incluir un `RobloxProductId` numérico válido en el `ProductDefinition`.
- **Diferencia Crítica de `Price`:**
  > [!IMPORTANT]
  > Para productos en Robux, el campo `Price` en `ProductDefinition` se utiliza **únicamente como metadato informativo / display para la interfaz**.  
  > **El campo `Price` NO constituye prueba de que Roblox haya procesado el pago.**  
  > La confirmación de una compra en Robux depende **exclusiva y autoritativamente del callback/recibo emitido por los servidores de Roblox**.

- **Restricciones de Cliente en Robux:**
  - El cliente **nunca** confirma una compra de Robux.
  - El cliente **nunca** envía el precio en Robux.
  - El cliente **nunca** envía el resultado de la transacción.
  - El cliente **nunca** se auto-asigna propiedad tras cerrar un diálogo de compra.
  - El servidor determina qué producto otorgar resolviendo el `RobloxProductId` recibido contra el catálogo autoritativo.

---

## Product Types

### 1. Cosmetic
- **Permanencia:** Se adquiere una sola vez por jugador. Queda registrado de forma permanente en su inventario.
- **Ciclo de vida:** `No poseído` ➔ `Comprado (Owned)` ➔ `Equipado` ↔ `Desequipado`.
- **Regla de idempotencia:** Intentar comprar un cosmético ya poseído es un error de validación inmediato y no descuenta fondos (en Coins) o no otorga duplicados (en Robux).
- **Categorías iniciales:** Trails, Slap Skins, Point Animations / Point Effects.

### 2. Consumable
- **Permanencia:** No genera propiedad permanente ni estado de equipamiento.
- **Ciclo de vida:** `Comprado` ➔ `Efecto aplicado / Recompensa entregada` ➔ `Transacción completada`.
- **Regla de idempotencia:** Puede adquirirse múltiples veces.
- **Categoría inicial:** Coins (paquetes de monedas comprados con Robux).

---

## Initial Categories

| Categoría | Tipo de Producto | Divisas Soportadas | Reglas de Ownership | Reglas de Equip | Comportamiento |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`Trails`** | Cosmetic | Coins / Robux | Permanente (`Owned.Trails[Id] = true`) | Sí (`Equipped.Trails = Id`). Máximo 1 activo a la vez. | Despliega una estela visual vinculada a los attachments del personaje. |
| **`Slaps`** | Cosmetic | Coins / Robux | Permanente (`Owned.Slaps[Id] = true`) | Sí (`Equipped.Slaps = Id`). Máximo 1 activo a la vez. | Personaliza la apariencia visual/modelo o efecto del guante de bofetada. |
| **`PointEffects`** | Cosmetic | Coins / Robux | Permanente (`Owned.PointEffects[Id] = true`) | Sí (`Equipped.PointEffects = Id`). Máximo 1 activo a la vez. | Efecto visual/auditivo reproducido al anotar un punto en `ZoneWin`. |
| **`Coins`** | Consumable | Robux | Ninguno (no se almacena en inventario de ítems). | No aplica. | Acredita una cantidad fija de monedas al saldo del jugador (`PlayerService:AddCoins()`). |

---

## Provider Contract

Cada categoría de productos es gestionada por un módulo independiente que implementa el contrato `ProductProvider`:

```luau
export type ProductProvider = {
    -- Identificación y Catálogo
    GetCategory: (self: ProductProvider) -> string,
    GetProducts: (self: ProductProvider) -> { ProductDefinition },
    GetProduct: (self: ProductProvider, productId: string) -> ProductDefinition?,

    -- Validaciones de Categoría
    CanPurchase: (self: ProductProvider, player: Player, product: ProductDefinition) -> (boolean, string?),
    CanEquip: (self: ProductProvider, player: Player, product: ProductDefinition) -> (boolean, string?),

    -- Acciones Post-Transacción (Entrega y Equipamiento Físico)
    OnPurchased: (self: ProductProvider, player: Player, product: ProductDefinition) -> (boolean, string?),
    OnEquipped: (self: ProductProvider, player: Player, product: ProductDefinition) -> (boolean, string?),
    OnUnequipped: (self: ProductProvider, player: Player, product: ProductDefinition) -> (boolean, string?),
}
```

### Regla de Independencia de Pago en los Providers
> [!NOTE]
> Los **ProductProviders no contienen lógica de pago**. No verifican saldos de Coins ni se comunican con APIs de Robux.  
> Los Providers únicamente describen el producto, validan condiciones de su dominio y ejecutan la entrega (`OnPurchased`) o el equipamiento visual (`OnEquipped`).  
> El procesamiento del cobro es responsabilidad exclusiva de `ShopService` y su capa de pago.

---

## ShopRegistry

El `ShopRegistry` desacopla a `ShopService` de cualquier proveedor concreto mediante un patrón de registro en memoria:

```luau
local ShopRegistry = {}
ShopRegistry._providers = {} :: { [string]: ProductProvider }
ShopRegistry._productsById = {} :: { [string]: ProductDefinition }
ShopRegistry._productsByRobloxId = {} :: { [number]: ProductDefinition }

-- Registra un proveedor para su categoría e indexa sus productos
function ShopRegistry:Register(provider: ProductProvider)
    local category = provider:GetCategory()
    assert(category and category ~= "", "Provider must declare a valid category")
    assert(self._providers[category] == nil, "Provider already registered for: " .. category)
    self._providers[category] = provider

    for _, prod in ipairs(provider:GetProducts()) do
        self._productsById[prod.Id] = prod
        if prod.RobloxProductId then
            self._productsByRobloxId[prod.RobloxProductId] = prod
        end
    end
end

function ShopRegistry:GetProvider(category: string): ProductProvider?
    return self._providers[category]
end

function ShopRegistry:GetProduct(productId: string): ProductDefinition?
    return self._productsById[productId]
end

function ShopRegistry:GetProductByRobloxId(robloxId: number): ProductDefinition?
    return self._productsByRobloxId[robloxId]
end

function ShopRegistry:GetAllProducts(): { ProductDefinition }
    local all = {}
    for _, prod in pairs(self._productsById) do
        table.insert(all, prod)
    end
    return all
end
```

---

## Economy Integration

La tienda enruta autoritativamente la transacción según la divisa del producto:

```text
                                ShopService
                                     │
                        ¿ProductDefinition.Currency?
                                     │
                    ┌────────────────┴────────────────┐
                    ▼                                 ▼
             Currency == "Coins"              Currency == "Robux"
                    │                                 │
                    ▼                                 ▼
        ┌───────────────────────┐         ┌────────────────────────┐
        │  Capa Económica       │         │  Roblox Monetization   │
        │  (PlayerService /     │         │  (Marketplace APIs /   │
        │   EconomyService)     │         │   Receipt Validation)  │
        └───────────┬───────────┘         └───────────┬────────────┘
                    │                                 │
                    ▼                                 ▼
             Deducción atómica              Recibo autoritativo
             en saldo de Coins              confirmado por Roblox
```

### Reglas de Integración Económica
1. **Sin saldos paralelos:** La única cantidad de `Coins` válida del jugador reside en `PlayerService._data[player].Coins`.
2. **Deducción atómica en Coins:** Si la deducción falla, la compra se aborta inmediatamente y el provider no ejecuta entrega.
3. **Validación de precios:** El precio del ítem en Coins proviene **única y exclusivamente** de `ProductDefinition.Price` en el servidor.
4. **Validación en Robux:** La entrega de un producto Robux solo ocurre tras la recepción y validación de una transacción exitosa en servidor.

---

## Ownership & Inventory

### Estructura Genérica de Inventario

El inventario está normalizado de forma genérica por categoría para garantizar que añadir nuevas categorías no requiera modificar el esquema de datos:

```luau
export type PlayerInventory = {
    -- Diccionario genérico: Category -> ProductId -> boolean
    Owned: {
        [string]: { [string]: boolean },
    },

    -- Diccionario genérico: Category -> ProductId activo (o nil)
    Equipped: {
        [string]: string?,
    },
}
```

### Ejemplo de Datos en Runtime

```luau
local inventory: PlayerInventory = {
    Owned = {
        ["Trails"] = { ["fire"] = true, ["rainbow"] = true },
        ["Slaps"] = { ["gold"] = true },
        ["PointEffects"] = { ["Basic"] = true, ["inferno"] = true },
        -- Futuras categorías se indexan sin alterar la estructura:
        -- ["Emotes"] = { ["dance"] = true },
        -- ["Auras"] = { ["sparkles"] = true },
    },
    Equipped = {
        ["Trails"] = "fire",
        ["Slaps"] = "gold",
        ["PointEffects"] = "inferno",
        -- ["Emotes"] = nil,
    },
}
```

---

## Persistence

1. **Datos Persistentes (DataStore):**
   - Saldo de `Coins`.
   - Diccionario genérico de propiedad (`Inventory.Owned`).
   - Ranuras equipadas (`Inventory.Equipped`).
2. **Datos Efímeros (Solo en Memoria Runtime):**
   - Catálogo de productos y metadatos de providers.
   - Bloqueos transaccionales de compra (in-flight request locks).
   - Instancias físicas de visuales (Beams, Attachments, Trails en el Character).
3. **Regla de Persistencia:** **El Shop no debe crear un sistema paralelo de persistencia.** Toda la información adquirida debe persistirse mediante la extensión controlada del esquema de `PlayerDataService` (`Version 2`).

---

## Robux Security

Para todas las transacciones vinculadas a Robux rigen las siguientes directivas de seguridad obligatorias:

1. **Desconfianza absoluta del cliente:** Nunca otorgar un producto porque el cliente indique que la compra fue realizada, ni porque la interfaz visual de Roblox se haya cerrado.
2. **Validación exclusiva en servidor:** El producto solo se otorga cuando el servidor procesa un recibo/callback de compra oficial de Roblox.
3. **Correspondencia estricta de producto:** El servidor valida que el identificador devuelto por Roblox (`RobloxProductId`) coincida exactamente con un producto registrado en `ShopRegistry`.
4. **Idempotencia estricta:** Una misma transacción de Roblox no debe procesar ni entregar recompensas dos veces. El sistema debe rastrear transacciones procesadas para garantizar idempotencia.
5. **Centralización del procesamiento:** Toda la recepción de transacciones Robux debe residir en un único punto centralizado del servidor. Los `ProductProviders` jamás procesan compras de Robux directamente.

---

## Client / Server Contract

```text
       CLIENTE (ShopController / ShopUI)                        SERVIDOR (ShopService / Registry)
  ┌────────────────────────────────────────┐               ┌────────────────────────────────────────┐
  │ • Muestra el catálogo visual           │               │ • Dueño absoluto de los catálogos     │
  │ • Solicita lista de productos          │ ────────────► │ • Provee catálogos vía RemoteFunction  │
  │ • Consulta su saldo local              │               │ • Valida existencia de items y precio  │
  │ • Solicita compra (ProductId)          │ ────────────► │ • Enruta canal de pago (Coins / Robux) │
  │ • Solicita equipar (ProductId)         │ ────────────► │ • Actualiza inventario y persistencia  │
  │ • Escucha confirmación y actualiza UI  │ ◄──────────── │ • Notifica resultado (Success/Error)   │
  └────────────────────────────────────────┘               └────────────────────────────────────────┘
```

### Remote API Prevista

- **`RemoteFunction` `Shop.GetCatalog`:** `() -> { ProductDefinition }`  
  Retorna todos los ítems activos de la tienda.
- **`RemoteFunction` `Shop.PurchaseProduct`:** `(productId: string) -> (boolean, string?)`  
  Solicita la compra de un producto (para Coins ejecuta la transacción; para Robux inicia el prompt oficial en servidor).
- **`RemoteFunction` `Shop.EquipProduct`:** `(productId: string) -> (boolean, string?)`  
  Solicita equipar un cosmético poseído.
- **`RemoteFunction` `Shop.UnequipProduct`:** `(category: string) -> (boolean, string?)`  
  Solicita desequipar el cosmético activo de una categoría.
- **`RemoteEvent` `Shop.InventoryUpdated`:** `(inventoryData: PlayerInventory) -> ()`  
  Emite al cliente cambios en sus posesiones o equipamientos.

---

## Purchase Flows

### Flujo A: Compra con Moneda Interna (Coins)

```text
Player presiona "Comprar" (Coins) en UI
              │
              ▼
ShopController:RequestPurchase(productId)
              │
              ▼
[RemoteFunction] Shop.PurchaseProduct(productId)
              │
              ▼
   ShopService:PurchaseProduct(player, productId)
              │
              ├─► ¿Player válido y no bloqueado por transacción en curso?
              │     └─► NO: Retornar (false, "TransactionInProgress")
              │
              ├─► ¿Producto existe en ShopRegistry y Currency == "Coins"?
              │     └─► NO: Retornar (false, "ProductNotFound")
              │
              ├─► ¿Producto disponible (IsAvailable)?
              │     └─► NO: Retornar (false, "ProductUnavailable")
              │
              ├─► Provider = ShopRegistry:GetProvider(product.Category)
              │
              ├─► Si es Cosmético: ¿Jugador ya lo posee (Inventory.Owned)?
              │     └─► SÍ: Retornar (false, "AlreadyOwned")
              │
              ├─► Provider:CanPurchase(player, product)
              │     └─► NO: Retornar (false, errorReason)
              │
              ├─► Capa Económica: ¿Tiene saldo suficiente (Saldo >= product.Price)?
              │     └─► NO: Retornar (false, "InsufficientFunds")
              │
              ▼
      EJECUCIÓN ATÓMICA EN SERVIDOR:
              │
              ├─► 1. Deducir saldo de Coins autoritativamente
              │
              ├─► 2. Si es Cosmético:
              │        Registrar Inventory.Owned[Category][productId] = true
              │      Si es Consumible:
              │        Provider:OnPurchased(player, product)
              │
              ├─► 3. Notificar actualización a PlayerService / DataUpdated
              │
              ├─► 4. Liberar bloqueo transaccional
              │
              ▼
Retornar (true, nil) al cliente ──► UI reproduce feedback y actualiza botón a "Owned"
```

---

### Flujo B: Compra con Moneda de Plataforma (Robux)

```text
Player presiona "Comprar" (Robux) en UI
              │
              ▼
ShopController:RequestPurchase(productId)
              │
              ▼
[RemoteFunction] Shop.PurchaseProduct(productId)
              │
              ▼
   ShopService:PurchaseProduct(player, productId)
              │
              ├─► ¿Producto existe en ShopRegistry y Currency == "Robux"?
              │     └─► NO: Retornar (false, "ProductNotFound")
              │
              ├─► Si es Cosmético: ¿Jugador ya lo posee?
              │     └─► SÍ: Retornar (false, "AlreadyOwned")
              │
              ├─► Resolver RobloxProductId autoritativo
              │
              ├─► Iniciar flujo oficial de compra en servidor (Prompt oficial de Roblox)
              │
              ▼
El jugador interactúa con el modal nativo de Roblox
              │
              ▼
Roblox procesa el pago y emite confirmación oficial al servidor
              │
              ▼
Callback Oficial en Servidor (Centralizado)
              │
              ├─► ¿Transacción válida y no procesada previamente (Idempotencia)?
              │     └─► NO: Rechazar recibo duplicado
              │
              ├─► Resolver ProductDefinition a partir de RobloxProductId
              │     └─► NO existe: Retornar error de producto
              │
              ├─► Provider = ShopRegistry:GetProvider(product.Category)
              │
              ├─► Si es Cosmético:
              │     Registrar Inventory.Owned[Category][productId] = true
              │   Si es Consumible (ej. Paquete de Coins):
              │     Provider:OnPurchased(player, product) (ej. PlayerService:AddCoins)
              │
              ├─► Persistir en PlayerDataService
              │
              ├─► Notificar actualización de inventario/saldo al cliente
              │
              ▼
Confirmar recibo a Roblox ──► Cliente recibe InventoryUpdated y actualiza UI
```

---

## Equip Flow

```text
Player presiona "Equipar" en UI
              │
              ▼
ShopController:RequestEquip(productId)
              │
              ▼
[RemoteFunction] Shop.EquipProduct(productId)
              │
              ▼
   ShopService:EquipProduct(player, productId)
              │
              ├─► ¿Producto existe en ShopRegistry?
              │     └─► NO: Retornar (false, "ProductNotFound")
              │
              ├─► ¿Es de tipo Cosmetic?
              │     └─► NO: Retornar (false, "NotEquippable")
              │
              ├─► ¿El jugador es dueño del ítem (Inventory.Owned[Category][productId])?
              │     └─► NO: Retornar (false, "ItemNotOwned")
              │
              ├─► Provider = ShopRegistry:GetProvider(product.Category)
              │   Provider:CanEquip(player, product)
              │     └─► NO: Retornar (false, errorReason)
              │
              ▼
      EJECUCIÓN DEL EQUIP:
              │
              ├─► 1. Si había un ítem previo equipado en esa categoría:
              │        Provider:OnUnequipped(player, oldProduct)
              │
              ├─► 2. Registrar Inventory.Equipped[Category] = productId
              │
              ├─► 3. Provider:OnEquipped(player, product)
              │        (Aplica visualmente el asset al Character en juego)
              │
              ├─► 4. Notificar actualización de inventario al cliente
              │
              ▼
Retornar (true, nil) al cliente ──► UI actualiza botón a "Equipado"
```

---

## Adding New Categories

Para ilustrar la extensibilidad del framework, supongamos que el juego desea incorporar la categoría **`Emotes`**:

```text
PASO 1: Crear Catálogo y Definiciones
        Crear src/shared/Catalog/EmoteCatalog.luau con la lista de ProductDefinitions de Emotes.
        (Cada emote puede tener Currency = "Coins" o "Robux").

PASO 2: Implementar el Provider
        Crear src/server/Shop/Providers/EmoteProvider.luau implementando ProductProvider:
        - GetCategory() -> "Emotes"
        - GetProducts() -> Catálogo de Emotes
        - CanPurchase() -> Validaciones propias
        - OnPurchased() -> Registro de entrega
        - OnEquipped()  -> Cargar y reproducir la animación en el Humanoid

PASO 3: Registrar el Provider en el Bootstrap
        En el arranque del servidor:
        ShopRegistry:Register(EmoteProvider)

PASO 4: Interfaz de Usuario (Dinámica)
        La UI de la tienda consulta ShopRegistry:GetCatalog() o agrupa por GetCategory() == "Emotes",
        generando automáticamente la pestaña sin cambios en el Core del Shop.
```

**Resultado:** `ShopService` no requiere un solo `if category == "Emotes"` ni modificación alguna de su lógica transaccional.

---

## Anti-Patterns

1. **Sentencias `if/elseif` por categoría en el ShopService:** Viola el principio Abierto/Cerrado. `ShopService` debe delegar ciegamente en `ShopRegistry:GetProvider(category)`.
2. **Definiciones de precios en el cliente:** Vulnerabilidad crítica de seguridad.
3. **Determinar ownership desde la UI:** El cliente solo refleja lo que el servidor le indica.
4. **DataStore exclusivo para la tienda:** Duplicaría los guardados del jugador y provocaría desincronizaciones de saldo vs inventario ante fallos de red.
5. **Crear monedas paralelas:** La única moneda interna son los `Coins` gobernados por `PlayerService`.
6. **Providers procesando pagos:** Los providers no deben interactuar con billeteras ni con callbacks de Robux.
7. **Providers modificando tablas privadas de otros servicios:** Toda comunicación entre servicios debe ocurrir mediante su API pública autoritativa.
8. **Equipar cosméticos no verificados:** Intentar equipar un cosmético sin consultar antes la posesión autoritativa en el servidor.
9. **Acoplar PointEffects o Slaps directamente al núcleo de la tienda:** Las particularidades de cómo se dispara un PointEffect al anotar o cómo se sostiene un guante pertenecen a sus respectivos servicios, no a `ShopService`.
10. **Asumir que el campo `Price` prueba un pago en Robux:** El precio de catálogo en Robux es solo display; el recibo oficial es la única prueba válida.

---

## Testing Strategy

1. **Pruebas Unitarias de Providers:**
   - Validar que cada provider retorne catálogos con IDs no vacíos y precios `>= 0`.
   - Validar que productos con `Currency == "Robux"` contengan un `RobloxProductId` válido.
2. **Pruebas de Transacciones Coins:**
   - Comprar con saldo suficiente: deducción correcta y asignación de ownership.
   - Comprar con saldo insuficiente: rechazo y saldo inalterado.
   - Comprar cosmético repetido: rechazo inmediato sin cobro.
   - Intentos de compra simultáneos (race condition): el lock transaccional procesa una sola transacción y rechaza colisiones.
3. **Pruebas de Transacciones Robux:**
   - Simular recepción de recibo con `RobloxProductId` válido: otorgamiento correcto e idempotente.
   - Simular recepción de recibo duplicado: rechazo de doble otorgamiento.
   - Simular recepción con `RobloxProductId` inexistente: manejo seguro de error.
4. **Pruebas de Equip:**
   - Equipar un ítem no poseído debe fallar.
   - Equipar un ítem poseído debe actualizar `Equipped[Category]`.
   - Re-equipar un ítem diferente debe desequipar el anterior limpiamente.
5. **Pruebas de Persistencia:**
   - Comprobar que tras salir y volver a entrar al juego (`PlayerRemoving` / `PlayerAdded`), los cosméticos poseídos y equipados se restauren fielmente desde DataStore.

---

## Implementation Phases

| Fase | Título | Alcance |
| :--- | :--- | :--- |
| **FASE 1** | **Documentación / Arquitectura** | Creación y aprobación de `docs/SHOP_SYSTEM.md` *(Fase actual)*. |
| **FASE 2** | **Core Framework & Currency Router** | Creación de `ShopService`, `ShopRegistry`, interfaces de Provider y soporte arquitectónico dual para `Coins` y `Robux`. |
| **FASE 3** | **Primer Provider Real** | Adaptación de `PointEffectDefinitions` a `PointEffectProvider` como prueba de concepto del framework. |
| **FASE 4** | **Ownership & Persistencia** | Extensión de `PlayerDataRecord` (Versión 2) en `PlayerDataService` para guardar inventario genérico (`Owned` y `Equipped`). |
| **FASE 5** | **Equip System** | Estandarización del ciclo de equipamiento/desequipamiento visual en el Character. |
| **FASE 6** | **Integración de Monetización de Plataforma** | Implementación del canal oficial de recibos y prompts para productos de Robux en el Payment Layer. |
| **FASE 7** | **Client / UI** | Implementación de `ShopController` y la interfaz gráfica de usuario en `PlayerGui`. |
| **FASE 8** | **Expansión de Categorías** | Creación de `CoinsProvider` (consumible), `TrailProvider` y `SlapProvider`. |
| **FASE 9** | **Hardening y Seguridad** | Pruebas de estrés de red, auditoría de idempotencia y validación multiplataforma. |

---

## Open Decisions

Las siguientes cuestiones representan decisiones arquitectónicas abiertas que deben resolverse durante las fases de implementación correspondientes:

1. **Formalización de `EconomyService` vs Facade en `PlayerService`:**
   - *Opción A:* Crear un nuevo `EconomyService` que encapsule cobros, balances, reembolsos e historial de transacciones.
   - *Opción B:* Mantener las operaciones de balance directamente como métodos de `PlayerService` (`PlayerService:DeductCoins()`).
   - *Nota:* Esta decisión concierne únicamente al manejo interno de `Coins` y no afecta el contrato de `Robux`.

2. **Esquema de migración de DataStore (`PlayerDataService`):**
   - Actualmente `PlayerDataRecord` almacena `{ Version, Coins, Wins, Losses, Kills, LastSaved }` (Versión 1).
   - Debe definirse el formato serializado exacto de `Inventory = { Owned = {...}, Equipped = {...} }` al incrementar a `Version = 2` con fallback para perfiles preexistentes.

3. **Mecánica de Slaps Cosméticos vs Slap Gameplay:**
   - Debe acordarse cómo se vinculan las skins cosméticas con `SlapService` (ej: si los cosméticos de Slap son meramente visuales/skins sobre el guante base o si en el futuro se planean guantes con habilidades especiales).

4. **Distribución del Catálogo al Cliente:**
   - Debe decidirse si el catálogo se transmite bajo demanda mediante `RemoteFunction:InvokeServer("GetCatalog")` al abrir la tienda, o si se comparte como módulo en `ReplicatedStorage.Shared.Catalog` para lectura instantánea en cliente con validación estricta en servidor.

5. **Estrategia técnica de integración con Roblox Marketplace:**
   - Debe definirse si el callback oficial de compras (`ProcessReceipt`) reside como un handler dedicado dentro del Payment Layer de `ShopService` o en un servicio centralizado de monetización que despache hacia `ShopService`.

---

## Source of Truth Rules

1. **`docs/SHOP_SYSTEM.md`** define la arquitectura, contratos, responsabilidades y reglas de diseño del Shop Framework.
2. **`SlapDuels_SDD_Documentacion/GAME_SDD.md`** define la visión general y las mecánicas globales de *Slap Duels 2.0*.
3. **`SlapDuels_SDD_Documentacion/data/PLAYER_DATA.md`** define la fuente de verdad de las estadísticas del jugador (`PlayerService._data[player]`).
4. **Respeto al código activo:** Los servicios existentes (`PlayerService`, `PlayerDataService`, `ScoreService`, `RoundService`, etc.) continúan siendo la fuente de verdad exclusiva de sus respectivos dominios.
5. **Resolución de discrepancias:** Ninguna implementación de tienda debe alterar la semántica ni contradecir el código de los servicios existentes. Si durante una fase futura se detecta una contradicción entre la documentación y el código, se debe auditar y actualizar la documentación antes de proceder con cualquier refactorización.
