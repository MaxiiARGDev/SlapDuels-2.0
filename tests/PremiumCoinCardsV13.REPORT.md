# Premium Coin Cards V1.3 — tarjetas persistentes

Instalación verificada mediante MCP en Studio Edit, sin Play/Run. HUD y MainFrame visibles.

Ruta común: `StarterGui.PremiumShopHUD.MainFrame.Catalog`.

| Tarjeta física | Coins | Robux previstos |
|---|---:|---:|
| Product_Coins_1000 | 1.000 | 50 |
| Product_Coins_10000 | 10.000 | 450 |
| Product_Coins_35000 | 35.000 | 1.250 |
| Product_Coins_100000 | 100.000 | 3.000 |
| Product_Coins_400000 | 400.000 | 10.000 |

Cada tarjeta contiene Title, Description, Content, Price, Status, Buy y Preview con WorldModel, CoinsDisplay y Camera. Un ejemplar por ID; Visible=true y PremiumPersistentCard=true. El controlador reutiliza las tarjetas y conserva sus colores/modelos editables. Al cambiar de categoría oculta las tarjetas de Coins; cerrar la tienda oculta el HUD. No se destruyen al cerrar. El catálogo sigue definido en src/shared/PremiumShop/Catalog/CoinPackages.luau. Los precios son provisionales y los cobros siguen deshabilitados.

Se exportó el HUD actual preservando el diseño de Studio a src/assets/PremiumCoinCardsV13. Default usa ese HUD; SAFE agrega solo las cinco tarjetas y preserva elementos desconocidos. Respaldo anterior y builds de verificación en tests/assets/backups/PremiumCoinCardsV13.

Validación: 48 aserciones de tarjetas y 98 de regresión premium aprobadas; 216 scripts compilados; ambos Rojo builds aprobados; cinco tarjetas y cámaras serializadas comprobadas en cada build. CurrentCamera se serializa mediante CameraCFrame/CameraFieldOfView; el vínculo vivo también fue comprobado en Studio. git diff --check aprobado, con avisos de conversión LF/CRLF preexistentes. Source y EditorSource del controlador sincronizados.

Prueba manual pendiente: abrir Premium/Coins, verificar los cinco paquetes desplazando el catálogo; cerrar y reabrir; alternar categorías; confirmar ausencia de duplicados y conservar edición visual. No se ejecutaron compras, partidas ni escrituras cloud.
