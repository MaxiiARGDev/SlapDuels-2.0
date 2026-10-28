# ProductNotFound al equipar Slap administrativo

## Causa demostrada

Output de la prueba iniciada por el desarrollador:

`[Bootstrap] Error en Start() de CrateService: ServerScriptService.Shop.ShopRegistry:55: [ShopRegistry] Producto Robux 'PremiumI' requiere un RobloxProductId numérico positivo obligatorio`

CrateService registra primero el provider Crates y luego Slaps. Crates:GetProducts devolvía el catálogo completo, incluidos tres borradores Premium con Currency=Robux y sin IDs de producto. ShopRegistry los rechaza correctamente. La excepción aborta Start antes de registrar Slaps; por eso un entitlement administrativo válido Classic:Blood aparece en inventario pero EquipProduct devuelve ProductNotFound. No es un rechazo por falta de unidad comerciable ni un problema de propiedad. La captura de la pestaña no demuestra una categoría enviada incorrectamente.

## Cambio puntual

CrateProviders.Crates:GetProducts ahora solo devuelve productos Currency=Coins y sin Metadata.PremiumOnly. El catálogo general de CrateService y el flujo Premium separado se conservan. No se debilita ShopRegistry, no se asignan IDs falsos y no se habilitan ventas, probabilidades, producción o transferencias. CrateProviders es el único script de producto modificado.

## Pruebas

17 aserciones aisladas con Catalog, CrateProviders, ShopRegistry, ShopService y PlayerService reales: reproduce el fallo exacto con el provider mezclado anterior; comprueba que el nuevo provider registra doce cajas normales y los Slaps; entrega Classic:Blood con AddItem, lo equipa mediante EquipProduct y confirma Inventory.Equipped.Slaps sin gastar Coins. Categoría incorrecta rechazada y Premium/commerce permanecen bloqueados. Ambos builds Rojo, compilación del módulo y git diff --check PASS.

No se inició ni detuvo Play/Run, no se controlaron jugadores ni se cambiaron perfiles durante la sesión del usuario. Durante Play solo se leyó Output y propiedades/source para diagnóstico. Un require de diagnóstico MCP no comparte necesariamente el estado inicializado de servicios; su registro vacío no se tomó como evidencia. La causa se apoya en Output y reproducción aislada.

## Estado

Corregido en repositorio y **sincronizado en Studio Edit** después de que el desarrollador detuvo su prueba. Se verificaron Source y draft de ServerScriptService.Shop.Providers.CrateProviders contra SHA-256 `5739e7d33287c661d5278a09ca3e3a4904d13770104a4f43d07fa6232fa90a6b`, con preflight que acepta únicamente el contenido anterior respaldado o el resultado esperado. Studio/InMemory/WritesToCloud=false confirmado. Queda pendiente repetir la prueba manual en una sesión nueva; no se ejecutó jugabilidad. Respaldo del módulo anterior en tests/assets/backups/InventoryEquipFixV121/CrateProviders.luau.

Cuando Studio vuelva a Edit: sincronizar Source y draft de ServerScriptService.Shop.Providers.CrateProviders con guardia de hashes. El desarrollador debe iniciar una sesión nueva, concederse Blood por ADMIN (InMemory no conserva la sesión anterior), abrir MI PERFIL/Ver artículos/Slaps y equiparlo. Output debe mostrar el registro exitoso del provider Slaps y no debe repetir el error de RobloxProductId en Start de CrateService.
