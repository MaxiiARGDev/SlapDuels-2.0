# Premium Coins V1.2

Catálogo preparado con los cinco paquetes aprobados de la referencia:

| Coins | Precio provisional Robux |
|---:|---:|
| 1.000 | 50 |
| 10.000 | 450 |
| 35.000 | 1.250 |
| 100.000 | 3.000 |
| 400.000 | 10.000 |

## Implementación

- `src/shared/PremiumShop/Catalog/CoinPackages.luau`: sustituye las cantidades/precios anteriores, conserva los cinco IDs placeholder reservados, genera los nuevos PackageIds según la cantidad y usa ContractVersion CoinsV12. Rewards.Coins coincide con cada paquete.
- `src/client/Controllers/PremiumShopController.luau`: cantidades legibles con separadores, precios visibles también para placeholders, tarjetas de Coins oscuras con borde dorado y botón verde, estado VISTA PREVIA y precio marcado PRECIO PROVISIONAL. El detalle presenta el importe y PRÓXIMAMENTE.
- El precio sugerido nunca se convierte en PriceRobux verificado ni en autorización de compra. Cuando exista un precio real de Roblox, tiene prioridad sobre el sugerido.
- Se reutilizan ProductCardTemplate y CoinsDisplay existentes. Las cinco tarjetas se generan al abrir el catálogo, como en la arquitectura previa; no se instalaron tarjetas estáticas duplicadas ni se modificó el HUD físico. Se conserva su distribución responsive y su diseño general; no es una reproducción exacta del layout 3+2 de la imagen.
- No se cambiaron combos, cajas, economía de partidas, persistencia ni backend de recibos. PurchaseApproved=false, IsPlaceholder=true y los flags globales de compras siguen deshabilitados.

## Verificación

- **40 aserciones aisladas** del catálogo y del renderer real con GUI mocks: cantidades, precios, formato, cinco tarjetas, botones no autorizados y prioridad del precio real.
- **98 aserciones aisladas** de regresión de compras/recibos PremiumShopV11. Se actualizaron sus expectativas a las nuevas cantidades y precios aprobados.
- **216 scripts compilados**, ambos builds Rojo y git diff --check aprobados.
- Los dos módulos se sincronizaron con Studio Edit comprobando Source y EditorSource antes y después mediante SHA-256. Sus hashes están en `PremiumCoinsV12.source-hashes.json`.
- Confirmado **Studio / InMemory / WritesToCloud=false**.
- No se inició Play, Run o Start Server. No hubo compras, publicaciones, commits/push ni escrituras cloud. No se guardó ni cerró el lugar.

Copias previas: `tests/assets/backups/PremiumCoinsV12/`. Evidencias: `PremiumCoinsV12.results.txt`, `.receipts-regression.txt`, `.compile.txt`, `.default.build.txt`, `.safe.build.txt`, `.diff.txt` y ambos builds `.rbxlx`.

## Validación manual pendiente

En una sesión nueva de tu prueba, abrir Premium Shop → Coins. Deben aparecer los cinco importes anteriores, con sus precios provisionales, botones verdes y etiqueta de vista previa. Abrir los detalles de cada paquete y comprobar cantidades y estado PRÓXIMAMENTE. No debe abrirse un cobro de Roblox.

La habilitación de cobros queda pendiente de ProductIds reales, configuración de sus precios en Creator Hub y finalización/validación del puente durable de recibos. No se activó ninguna de esas funciones. La visualización real en cliente sigue pendiente del desarrollador.
