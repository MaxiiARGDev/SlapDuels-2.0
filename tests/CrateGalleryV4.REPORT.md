# Crate Gallery V4 — implementación y validación

## Resultado

Instalado en Studio Edit y en ambos proyectos Rojo: galería horizontal de Slaps completos, rotación local, fondo por rareza y Highlights del modelo. Los cuatro botones principales son Comprar, Abrir x1, Abrir x5 y Abrir x10. Se conserva el botón de cierre. La información técnica de persistencia y stock no aparece en el panel.

Las probabilidades se presentan como porcentajes enteros o aproximados y categorías legibles. El detalle al pasar el cursor o tocar conserva la probabilidad exacta del servidor. No se cambiaron las probabilidades, premios, precios ni transacciones autoritativas.

La navegación conserva las ventanas cubiertas y restaura la anterior al cerrar. Se registraron Shop, Premium, cajas, apertura, perfil, trade, ajustes, administración y solicitudes sociales. Se invalida el historial al entrar en partida, resultados o al retirar el Character. No se restauran permisos administrativos revocados ni invitaciones caducadas.

## Presentación 3D

Se clonan los recursos completos de ReplicatedStorage.SlapVariationPreviews en Workspace local, delante de la cámara, sin moverla ni controlar al jugador. Se mantienen hasta seis modelos completamente visibles; los demás se liberan al desplazarse. Se eliminan scripts de las copias y se desactivan colisiones, consultas y contactos.

Se conservan los Highlights y las partículas. La previsualización limita la emisión continua a 12 por segundo por emisor y admite ráfagas acotadas para emisores de Rate=0. PreviewEnabled=false permite excluir emisores. Los sonidos quedan silenciados para evitar reproducir simultáneamente todos los modelos. Los originales no se modifican. Al ocultar o cerrar se limpian modelos, fondos y partículas.

Las cotizaciones se actualizan automáticamente; errores transitorios admiten reintento. Una operación incierta mantiene su OperationId y cantidad original, sin permitir otra compra mientras se resuelve.

## Recursos y sincronización

- Nuevos: WindowStack, WindowNavigationController, CrateOddsLabels y CrateRewardGallery.
- Modificados: CrateController, ShopController, PremiumShopController, SocialController y CrateStandCinematicController.
- UI: src/ui/CratePanel.project.json y src/ui/ShopHUD.CrateGalleryV4.rbxm.
- Proyectos: default.project.json y studio-safe.project.json.
- Pruebas/generador: tests/CrateGalleryV4.spec.luau y tests/tools/crate_gallery_v4_ui.py.
- Respaldo previo: tests/assets/backups/CrateGalleryV4/.

El proyecto default usa el ShopHUD binario completo exportado desde Edit. Un override anidado no reemplazaba el CratePanel que ya existía dentro del binario anterior; se detectó inspeccionando el resultado del build y se corrigió. El proyecto seguro usa el panel JSON explícito. Ambos builds contienen la nueva jerarquía de 40 descendientes. El MainFrame original de Shop mantuvo su hash.

En la comprobación final de la conexión actual de Studio, en Edit, los nueve scripts coincidieron por SHA-256 tanto en Source como en el contenido del editor. StarterGui.ShopHUD.CratePanel conserva sus 40 descendientes, RewardScroll y OpenActions. No fue necesario sobrescribir nada en esa comprobación.

## Verificación

| Comprobación | Resultado |
| --- | --- |
| Pruebas aisladas de galería, acciones y navegación | PASS: 31 aserciones |
| Regresión de inventario/equipamiento | PASS: 271 aserciones |
| Regresión de premios y probabilidades CrateTiersV3 | PASS: 498 aserciones |
| Total automatizado aislado | PASS: 800 aserciones |
| Inspección/pruebas de copias en Studio Edit | PASS: 9 aserciones, sin render de gameplay |
| Compilación final Luau | PASS: 193 scripts |
| Rojo default y seguro | PASS |
| Jerarquía del panel dentro de ambos builds | PASS: 40 descendientes |
| git diff --check | PASS |
| Render real, móvil y navegación durante gameplay | NOT RUN: validación del desarrollador |

No se inició Play, Run ni servidor. No se realizaron commits, push, publicaciones ni escrituras cloud. El proveedor de persistencia no fue modificado. La inspección previa confirmó InMemory/WritesToCloud=false; en la nueva conexión Edit esos atributos no están expuestos en game, por lo que deben confirmarse nuevamente en el servidor antes de las pruebas del desarrollador. El backend de cajas de producción continúa con su bloqueo preexistente.

## Prueba manual del desarrollador

1. Iniciar la prueba y confirmar Studio / InMemory / WritesToCloud=false en el servidor.
2. Abrir Shop y caja Gold. Shop debe ocultarse; deben verse modelos completos girando, fondo por rareza, Highlights y probabilidades simplificadas.
3. Desplazar horizontalmente, también en resolución móvil; pasar el cursor o tocar una tarjeta para consultar el porcentaje exacto.
4. Comprobar Comprar y Abrir x1/x5/x10. Las cantidades insuficientes deben estar deshabilitadas. Verificar descuento y entrega única; una operación pendiente debe conservar el mismo reintento.
5. Cerrar la caja: debe volver Shop con su selección. Probar Shop → Premium → caja y volver; repetir con perfil, ajustes y administración. Cerrar la cinemática debe devolver el panel anterior cuando corresponda.
6. Confirmar que entrar en partida o respawnear no restaura menús antiguos.
7. Revisar una variante con partículas continuas o de ráfaga: deben verse en su tarjeta y desaparecer al ocultarla. No se espera audio en la galería.
8. Informar capturas, resolución y Output si hay recortes, modelos mal orientados o una ventana no se restaura. La apariencia y el comportamiento multijugador quedan pendientes de esta validación.
