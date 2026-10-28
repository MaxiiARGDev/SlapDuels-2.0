# V2.3 — prueba manual

1. Guardá normalmente el lugar. La implementación ya está en Edit. Si sincronizás scripts, usá SAFE; no hace falta importar recursos ni ejecutar un instalador.
2. Antes de Play, si querés probar los whooshes nuevos, asigná SoundId a `Workspace.CrateStands.MainCrateStand.PresentationTemplate.Effects.FXAnchor.WhooshClose` y `WhooshOpen`. Actualmente están vacíos. El resto de los sonidos existentes se conservó.
3. Iniciá vos una prueba de dos clientes. Confirmá en Output **Studio / InMemory / WritesToCloud=false** antes de realizar compras. Si no coincide, detené la prueba. Usá la caja de prueba existente, sin habilitar cajas comerciales pendientes ni cambiar probabilidades/exclusividad.
4. En A abrí Shop > Cajas, sin iniciar apertura: prompt y personajes deben conservar el comportamiento normal. Dejá a B delante del stand para comprobar también V2.2.
5. Abrí una caja con A. El prompt del stand debe desaparecer inmediatamente en A y permanecer oculto hasta acabar. En B no debe aparecer una ocultación local impuesta por A; el servidor puede seguir mostrando su estado de stand ocupado habitual.
6. Verificá el cierre desde ambos bordes hasta negro. Al abrir, la cámara debe venir desde un encuadre elevado, descender y asentarse con un rebote leve. Los personajes no deben tapar la cámara de A; B sigue viendo personajes normalmente.
7. Durante Growth/Shake, comprobá movimiento leve y legible, sin saltos ni mareo. En Flash debe haber una reacción más marcada que se amortigua rápidamente.
8. En Reward, verificá premio, nombre y variación en la escena 3D. **No debe aparecer RewardOverlay en pantalla**. El premio y sus datos deben coincidir con el inventario, como antes.
9. En Outro debe cerrarse otra vez la pantalla, devolver la cámara y abrir sobre el personaje. Verificá controles, visibilidad de personajes y retorno del prompt cuando corresponda por estado del servidor.
10. Repetí tres aperturas respetando el cooldown. Probá una cancelación/interrupción permitida por el juego y, si es posible sin instrumentación, respawn o prioridad de partida. No deben quedar shutters, prompt oculto, cámara ni personajes bloqueados.
11. Revisá PC y móvil/emulación de resolución para comprobar cobertura de pantalla y encuadre del billboard. Spin debe regresionarse solo si está disponible mediante un flujo autorizado; no cambies configuración para fabricar ese caso. Su implementación no fue modificada.

Si algo falla, enviá Output con hora, cliente A/B, fase, captura o video del movimiento y si hubo cancelación/cambio de cámara. Para ajustes artísticos indicá si querés más/menos altura, rebote, shake o duración. Esos parámetros están en `StarterPlayer.StarterPlayerScripts.CrateOpening.CinematicConfig`.

Aceptación visual/funcional: **PENDING** hasta tu prueba. El agente no ejecutó Play/Test.
