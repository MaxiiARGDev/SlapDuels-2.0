# Shop unificado y adaptable — 2026-10-28

Implementado en código y en Studio Edit. Jugabilidad y compras reales: NOT RUN.

## Resultado
- La tarjeta completa selecciona la caja. No se clonan los botones % / Ver caja; se oculta el badge Consultar.
- Título, rareza y precio tienen espacios separados; se elimina el texto propio del TextButton que duplicaba el título.
- El icono de categoría es un respaldo. Una vista 2D o un ViewportFrame real lo ocultan.
- El detalle y las acciones de cajas viven en StarterGui.ShopHUD.MainFrame.Body.DetailHost.CratePanel.
- La consulta al servidor se inicia al seleccionar. Se conserva QuoteToken, OperationId, reintentos y validaciones existentes.
- El panel reutiliza Comprar y Abrir x1/x5/x10, sin una segunda ventana de probabilidades.
- Colección/detalle lado a lado desde 850 píxeles de ancho del MainFrame; por debajo, vista de detalle con Volver. Categorías horizontales en pantallas estrechas.
- Detalle con scroll vertical en pantallas bajas; botones de 44 píxeles. Galería horizontal y porcentajes enteros existentes.
- Galería libera modelos cuando un ancestro se oculta y no dibuja modelos fuera del área visible del detalle.
- UIEffects no restaura tamaños antiguos al pulsar; NeonShopMotion conserva efectos cosméticos pero deja de imponer un segundo layout.

## Verificación
- 70 aserciones sobre un clon desechable del HUD real en Edit: 320×568, 390×844, 768×1024, 844×390, 1024×600 y 1366×768.
- 34 aserciones aisladas: navegación, cantidades, operaciones pendientes, reintentos con el mismo ID, selección estable y bloqueo de sustitución durante transacciones.
- Compilación de scripts src, ambos builds Rojo y git diff --check: PASS.
- Capturas revisadas en Edit: escritorio y móvil, con contenido de muestra. No equivalen a pruebas con jugadores.
- Preview y clon de pruebas eliminados. No se inició Play/Run/Start Server, no hubo publicaciones ni commits.

## Archivos principales
- src/client/UI/ShopLayout.luau
- src/client/Controllers/ShopController.luau
- src/client/Controllers/CrateController.luau
- src/client/Controllers/WindowNavigationController.luau
- src/client/CrateOpening/CrateRewardGallery.luau
- src/ui/scripts/ShopUIEffects.client.luau
- src/ui/scripts/ShopNeonShopMotion.client.luau
- src/ui/ShopHUD.UnifiedV1.rbxm
- default.project.json y studio-safe.project.json

El build normal incluye el HUD físico actualizado. El mapa SAFE sincroniza los scripts visuales sin reemplazar el HUD; ShopLayout prepara también la jerarquía en runtime.
Respaldo anterior de la interfaz: tests/assets/backups/ShopUnifiedV1/ShopHUD.rbxm.

## Pruebas manuales pendientes
1. Abrir Shop en PC; seleccionar Basic, Common y Arcoiris. Debe aparecer una sola representación de cada caja y cambiar el detalle derecho sin abrir otra ventana.
2. Verificar icono naranja únicamente si falta el recurso propio. Confirmar animaciones 2D y modelos 3D.
3. Consultar premios: scroll horizontal, nombres, variantes y porcentajes sin decimales.
4. Comprar una caja y abrir x1. Con inventario suficiente, abrir x5 y x10; comprobar saldo, cantidades y cinematografía.
5. Pulsar repetidamente durante una operación: no debe enviar compras nuevas ni cambiar la caja de una operación pendiente.
6. Revisar todas las categorías, incluidas las vacías. Ninguna debe mostrar el detalle de una caja anterior.
7. En emulador móvil: seleccionar, Volver, desplazar categorías y detalle; cambiar orientación. Los botones inferiores se alcanzan desplazando el detalle.
8. Cerrar tienda, abrir inventario y volver a una caja; comprobar navegación. Los modelos de premios no deben quedar flotando después de cerrar.
9. Si falla, enviar Output y resolución/orientación con captura del HUD.
