# Crate Design V4.1

Rediseño exclusivamente visual basado en StarterGui.ShopHUD.MainFrame: tipografía Bangers copiada del título y botón de la tienda, degradados azul/violeta, borde cian/violeta, separador luminoso, tarjetas con panel inferior degradado, esquinas redondeadas, límites de tamaño de texto y botones con brillo y contorno.

Se conserva transparente la franja de modelos 3D para mantener partículas y Highlights existentes. No se alteraron cámara, premios, compras, precios, probabilidades, navegación ni servidor. MainFrame se utilizó solo como referencia, sin modificarlo.

El tooltip de cada Slap ahora usa la misma presentación sin decimales que la tarjeta: porcentaje entero aproximado y categoría. Los valores inferiores al 1 % se muestran como <1 %, evitando representar una probabilidad no nula como cero. Se eliminó la promesa visual de mostrar porcentajes exactos.

Instalado en Studio Edit: StarterGui.ShopHUD.CratePanel, 84 descendientes. Sin Play, Run ni servidor. La apariencia durante gameplay queda pendiente de revisión visual del desarrollador.

## Archivos

- src/client/CrateOpening/CrateRewardGallery.luau: únicamente texto del tooltip.
- src/ui/CratePanel.project.json: estilo editable para proyecto seguro.
- src/ui/ShopHUD.CrateGalleryV4.rbxm: ShopHUD exportado desde Edit para proyecto default.
- tests/tools/crate_design_v41.luau: aplicación de estilo.
- tests/tools/crate_gallery_v4_ui.py: conserva snapshot de diseño V4.1.
- tests/CrateDesignV41.panel.json: snapshot del panel.

Respaldo anterior local y de Studio: tests/assets/backups/CrateDesignV41/.

## Verificación

- Compilación Luau del módulo modificado: PASS.
- Rojo default: PASS.
- Rojo seguro: PASS.
- git diff --check: PASS.
- Inspección MCP en Edit: panel, 84 descendientes, tipografía Bangers, cuatro acciones y ausencia del formato decimal en tooltip confirmados.
- No se realizaron commits, push, publicaciones ni escrituras cloud.

El desarrollador debe abrir una caja, revisar títulos/tarjetas/botones, pasar el cursor sobre una tarjeta y comprobar el porcentaje sin decimales. No se declara validación visual de gameplay.
