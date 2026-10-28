# V2.2 — validación manual del desarrollador

La implementación está instalada en Studio Edit. El agente no ejecutó Play. Guardá normalmente el lugar. Para actualizar scripts utilizá `Start-StudioSafeRojo.ps1`; el stand actual difiere del snapshot V2.1, por lo que no conviene aplicar una sincronización completa hasta recuperar esa diferencia.

1. Iniciá vos el test con dos clientes. Antes de comprar verificá en Output: PersistenceEnvironment=Studio, PersistenceProvider=InMemory y WritesToCloud=false. Si no coinciden, detené la prueba. Usá el flujo StudioTest existente; no habilites cajas comerciales pendientes ni cambies exclusividad/configuración para fabricar escenarios.
2. Con A como comprador y B como espectador, ubicá ambos avatares delante de CameraPoint o encima del pedestal. Abrí Shop > Cajas sin comprar: ambos deben seguir visibles.
3. Abrí una caja de prueba con A. En CameraReveal y hasta Reward, A no debe ver su avatar ni el de B; stand, caja, premio, efectos y RewardOverlay deben seguir visibles.
4. En B verificá que ambos avatares sigan visibles y que la apertura compartida conserve su presentación. Capturá ambas pantallas en la misma fase.
5. Mové B a través del encuadre y equipá un accesorio/herramienta permitido por el juego. Si el flujo permite ingreso o respawn de otro jugador, probalo mientras A está abriendo. Si requiere instrumentación, marcá ese escenario BLOCKED en vez de modificar producción.
6. Al volver la cámara de A a su personaje, verificá visibilidad normal, controles y cámara. Repetí tres aperturas, respetando el cooldown personal. No deben acumularse avatares invisibles ni cambiar el resultado/recompensa.
7. Probá primera persona antes/después y una cancelación/interrupción permitida por el juego. Si podés probar muerte, respawn o inicio de partida durante la secuencia mediante mecanismos existentes, verificá restauración sin cámara bloqueada. No fuerces MatchIds, eventos ni cambios en scripts para fabricar el caso.
8. Para ExclusiveOpening=false y Spin, ejecutá regresión solo cuando ese modo ya esté habilitado por un flujo autorizado. No es necesario modificar configuración para validar esta entrega: si no está disponible, dejalo NOT RUN. Cada comprador debe ocultar únicamente en su cliente; Spin no debe ocultar personajes.

Si algo falla, enviá Output completo con hora, cliente A/B, fase aproximada, número de apertura y si hubo respawn/cambio de cámara. Incluí captura de ambos clientes y, si es posible desde las herramientas de inspección del test, LocalTransparencyModifier antes/durante/después y Enabled de algún efecto adherido. No exportes perfiles ni secretos.

Estado inicial: automatización aislada PASS; validación visual y multicliente PENDING. No hay PASS funcional hasta tu confirmación.
