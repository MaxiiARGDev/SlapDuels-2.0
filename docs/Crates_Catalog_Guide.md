# Catálogo y Especificación de Cajas de Monedas (Coins) - Slap Duels 2.0

Documento de referencia para la generación e integración de imágenes 2D de las cajas en sustitución de los modelos 3D (`ViewportFrame`).

---

## 1. Especificaciones Técnicas Recomendadas

* **Formato:** PNG con fondo transparente (recorte limpio).
* **Resolución recomendada:** 512x512 píxeles (ó 256x256 píxeles optimizado para Roblox UI).
* **Perspectiva:** Perspectiva isométrica o vista 3/4 frontal (ligeramente inclinada desde arriba) para mantener consistencia entre las 12 cajas.
* **Integración:** Cada imagen podrá asignarse vía `rbxassetid://<ID>` o mediante spritesheet/asset local.

---

## 2. Listado Completo de las 12 Cajas

| # | Id en Código (`Id`) | Nombre en Pantalla | Precio (Coins) | Rareza / Tier | Temática y Estilo Visual |
| :-: | :--- | :--- | :-: | :-: | :--- |
| **1** | `Basic` | **Caja Basic** | **500** | Common | Madera simple, refuerzos metálicos gris claro, apariencia rústica e inicial. |
| **2** | `Common` | **Caja Common** | **1,000** | Common | Acero pulido / metal gris con ribetes plateados o azul sutil. |
| **3** | `Uncommon` | **Caja Uncommon** | **1,750** | Uncommon | Tonos **verdes** esmeralda / lima vibrante con detalles metálicos. |
| **4** | `Rare` | **Caja Rare** | **3,000** | Rare | Tonos **azules** zafiro / celeste eléctrico con acabados brillantes. |
| **5** | `Gold` | **Caja Gold** | **4,500** | Epic | Oro macizo, lingotes dorados pulidos, gemas amarillas y destellos de brillo. |
| **6** | `Arcoiris` | **Caja Arcoiris** | **7,000** | Legendary | Estilo **Rainbow** / prisma multicolor brillante, efecto holográfico o iridiscente. |
| **7** | `Emote` | **Caja Emote** | **10,000** | Rare | Temática divertida / animada, caritas o emojis estilizados, tonos violeta/magenta o amarillo fiesta. |
| **8** | `Wings` | **Caja Wings** | **13,500** | Epic | Temática celestial / alada: alas angelicales o etéreas, plumas, tonos celestes, blanco y dorado. |
| **9** | `Epic` | **Caja Epic** | **19,000** | Epic | Tonos **morados / púrpuras** profundos, cristales de amatista y runas de poder místico. |
| **10** | `Legendary` | **Caja Legendary** | **27,500** | Legendary | Tonos **naranjas / ámbar / fuego**, runas doradas, aspecto ornamentado y exclusivo. |
| **11** | `Blood` | **Caja Blood** | **37,500** | Mythic | Tonos **rojo carmesí / sangre**, obsidiana oscura, aspecto gótico/demoníaco y runas rojas brillantes. |
| **12** | `Galaxy` | **Caja Galaxy** | **50,000** | Mythic | Temática **espacial / cósmica**: nebulosas, estrellas brillantes, tonos azul marino, violeta profundo y polvo estelar. |

---

## 3. Mapeo de Archivos en el Código

* **Definición de Cajas:** [`src/shared/SlapCrates/CrateDefinitions.luau`](file:///h:/repos-github/SlapDuels-2.0/src/shared/SlapCrates/CrateDefinitions.luau)
* **Modelos 3D actuales:** `game.ReplicatedStorage.CrateEffects[Id]`
* **Renderizado en Tienda:** [`src/client/Controllers/ShopController.luau`](file:///h:/repos-github/SlapDuels-2.0/src/client/Controllers/ShopController.luau) (`_cratePreview`)
* **Apertura e Inspección:** [`src/client/Controllers/CrateController.luau`](file:///h:/repos-github/SlapDuels-2.0/src/client/Controllers/CrateController.luau) (`CratePanel`)
