# Inventario personal: equipamiento y selección pública

Implementado en código y Studio **Edit**. No se ejecutaron Play, Run, Start Server, jugadores, compras, transferencias, cloud, publicaciones, commits ni push. La validación visual y multijugador corresponde al desarrollador.

## Resultado

MI PERFIL → Ver artículos presenta tres categorías: Slaps, efectos de punto y efectos de muerte (Kill Effects). Solo muestra artículos poseídos del catálogo correspondiente. Tocar una tarjeta propia no equipada solicita equiparla; las tarjetas distinguen EQUIPAR, EQUIPADO y NO DISPONIBLE. Ver el perfil de otro jugador permite consultar las mismas categorías sin equipar sus artículos.

El resumen mantiene el Slap seleccionado con su preview completa e incorpora el nombre del efecto de punto y del efecto de muerte seleccionados. El resumen se proyecta independientemente de la categoría/página consultada. Los cambios confirmados se reflejan en el perfil y en el inventario que utiliza Shop; no hay una preferencia paralela ni una nueva economía.

## Autoridad y reutilización

Nuevo RemoteFunction `ReplicatedStorage.Remotes.Social.Equip`. Acepta categoría, ProductId y página; NO acepta jugador objetivo. La identidad es exclusivamente el caller autenticado por Roblox. SocialService valida categoría explícita (Slaps/PointEffects/DeathEffects), formato, perfil cargado, identidad/conexión real, ausencia de sesión competitiva/resultados y ausencia de negociación activa. Requiere propiedad en el inventario del servidor.

La mutación se delega a `ShopService:EquipProduct` y por lo tanto reutiliza el lock, catálogo, disponibilidad y validaciones del provider de Shop. No se modifica ShopService, PlayerService, DataStores, combate o recursos físicos de Slaps/efectos. No se gastan Coins, compran objetos ni modifican las unidades individuales.

El cliente tiene una sola petición de equipamiento pendiente, solo habilita la interacción propia, espera la respuesta del servidor para renderizar la selección y descarta respuestas que lleguen después de cerrar/cambiar el contexto. No permite usar la respuesta para reabrir el perfil. El refresco periódico y DataUpdated continúan leyendo el perfil autoritativo, incluidos cambios hechos desde Shop.

## Intercambios

PublicInventory.Build permanece exclusivamente para Slaps y sigue siendo el origen de Unit y del inventario de negociación. Las filas de PointEffects/DeathEffects se proyectan aparte, con Tradable=false, sin UnitId y sin procedencia de caja artificial. No pueden ofrecerse en un trade.

Se conservan las restricciones anteriores: no todos los Slaps son comerciables; los entitlements base/admin no equivalen a unidades verificadas de caja. **La transferencia real de trade sigue bloqueada por la implementación durable pendiente**, como antes de esta tarea. No se habilitó mediante configuración ni se declaró funcional una transferencia real.

## UI física y preservación

Se agregaron a StarterGui.PlayerProfileHUD:

- MainFrame.InventoryTabs.Slaps / PointEffects / DeathEffects.
- MainFrame.SelectedEffects.PointEffects / DeathEffects.
- CardTemplate.EffectBadge para tarjetas de efectos; no reproduce partículas/audio del efecto en el inventario.

Se ajustaron Collection, CollectionTitle, CollectionHint y Status para acomodar las categorías. Se conserva el diseño del perfil existente; el UIGradient del CanvasGroup raíz continúa desactivado. No se regeneró el diseño histórico que causaba el oscurecimiento. Los hashes serializados de PlayerHUD, ShopHUD, PremiumShopHUD, TradeHUD, TradeRequestHUD, SocialPlayHUD y EndCinematicHUD coinciden con el estado previo. Equip existe una sola vez y las tres pestañas están presentes en Edit.

El lugar abierto no se cerró ni se guardó encima del archivo del usuario. Guardar los cambios de Edit cuando corresponda. Se mantiene Studio / InMemory / WritesToCloud=false, observado mediante Resolve en Edit.

## Verificación

| Comprobación | Resultado |
| --- | --- |
| Regresión social/trade previa | PASS, 121 aserciones aisladas |
| Regresión perfil propio previa | PASS, 104 aserciones aisladas; fixture adaptado al parámetro categoría y fingerprint nuevo |
| Casos nuevos equipamiento | PASS, 46 aserciones aisladas: proyección, solo poseídos, categorías, caller, sesiones, negociación, rate limit, disponibilidad, actualización y respuesta tardía; Shop delegado con doble controlado |
| Shop/economía vigentes | PASS, 86 aserciones aisladas sobre módulos existentes |
| Compilación Luau | PASS, 188 scripts |
| Rojo default y SAFE | PASS ambos |
| git diff --check | PASS |
| Jerarquía y preservación física | PASS, inspección MCP Edit |
| Jugabilidad, visual/móvil y dos clientes | NOT RUN |
| Persistencia real, compras o transferencias | NOT RUN |

Se ejecutó además la suite histórica AbilityShopV13.shop: falla en su aserción obsoleta de recompensas 50/50 (línea 113). El balance actual ya era gol=150 y Kill=30 antes de esta tarea. No se cambió economía para acomodar esa prueba. EconomyBalanceV1.shop es su contraparte vigente y pasó las 86 aserciones. Ambos resultados quedaron registrados.

## Archivos

Modificados: src/server/Services/SocialService.luau, src/server/Services/Trading/PublicInventory.luau, src/client/Controllers/SocialController.luau, src/ui/PlayerProfileHUD.project.json, ambos proyectos JSON y el fixture tests/PlayerInventoryV11.spec.luau.

Agregados: tests/InventoryLoadoutV12.spec.luau, tests/tools/run_inventory_loadout_v12.py, tests/tools/inventory_loadout_v12_ui.py y evidencias InventoryLoadoutV12.*. Respaldo específico de scripts, interfaz previa nativa/base64 y proyectos: tests/assets/backups/InventoryLoadoutV12. No se tocó el respaldo integral existente.

## Validación manual

1. Iniciar vos la prueba y confirmar Studio/InMemory/WritesToCloud=false. Abrir MI PERFIL → Ver artículos.
2. Slaps: seleccionar una variación poseída. Ver EQUIPADO y el cambio del resumen. Entrar a práctica o a una partida y comprobar que se usa esa selección.
3. Efectos de punto: seleccionar uno poseído distinto del actual. Volver al resumen, comprobar el nombre y comprobar también la selección en Shop. Anotar para verificar el efecto durante tu partida.
4. Efectos de muerte: repetir con un Kill Effect poseído y verificarlo durante una eliminación válida. No confundirlo con el efecto de caída sin atacante.
5. Cambiar selección desde Shop y volver al perfil: deben coincidir. Salir/reabrir inventario no debe resetear la selección. En Studio InMemory las selecciones no persisten después de reiniciar el servidor por diseño.
6. Con otro cliente consultar tu perfil: debe ver las tres selecciones y sus categorías, pero tocar tus tarjetas no debe equiparle ni modificarte nada. Revisar páginas, pestañas y pantalla móvil.
7. Comprobar negociación: solo Slaps elegibles pueden ofrecerse. No deben aparecer efectos en las ofertas. Intentar equipar durante una negociación o partida debe rechazarse.
8. Revisar Output por errores SocialService/SocialController/ClientBootstrap y enviar el paso y categoría si algo falla. Esperar validación del desarrollador antes de ampliar el alcance.
