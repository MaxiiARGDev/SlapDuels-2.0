# Dos progresiones visibles

## Ajuste posterior: distribución y aviso de reclamos

La pantalla principal ya no muestra barras de nivel/EXP ni avisos emergentes de EXP. Conserva el botón PASE. El menú del pase muestra únicamente la tarjeta de EXP del pase, a ancho completo. El perfil conserva ambas tarjetas. Se mantiene la tarjeta compacta antigua oculta para compatibilidad de jerarquía; Render/Tick nunca la habilitan.

ClaimDot es un Frame rojo persistente bajo ProgressionHUD.OpenButton y PlayerProfileHUD.MainFrame.ProgressCards.Pass.Open. Se calcula con las etapas desbloqueadas no reclamadas de la edición activa; desaparece al reclamar todas o vencer la temporada. No depende de un contador local de clics. Prueba de presentación ampliada a 19 aserciones, aprobadas en Edit con clones de GUI.

Implementadas tarjetas celestes de nivel permanente y doradas de etapa del pase en StarterGui.ProgressionHUD.ProgressCards, ProgressionHUD.MainFrame.ProgressCards y PlayerProfileHUD.MainFrame.ProgressCards. Componentes: Player/Pass, Title, XP, Track.Fill, Hint; Pass.Open abre el pase y muestra cuántos premios están pendientes. El próximo premio usa la etiqueta del catálogo de la edición recibida del servidor.

La barra permanente usa LevelXP/LevelCost. La del pase usa PassXP menos las etapas alcanzadas multiplicadas por StageXP, sin cambiar la economía ni los requisitos. Se contemplan cambio de etapa exacto, finalización de las 30 etapas, ausencia de temporada y vencimiento local. El aviso de EXP de partida distingue jugador y pase.

El perfil propio muestra ambas progresiones. El ajeno solo muestra el nivel público replicado por el servidor, sin EXP ni premios privados del pase. Las tarjetas se ocultan al entrar al inventario para conservar sus controles. El acceso al pase utiliza la navegación de ventanas existente para volver al perfil al cerrar. Las tarjetas compactas se ocultan mientras el menú del pase o el perfil están abiertos (actualización durante Render/Tick).

Instalación y revisión visual mediante previews temporales en Studio Edit, retiradas al finalizar; sin Play, jugadores controlados, RPC ni persistencia cloud. Se conservaron las imágenes de estadísticas existentes en Studio, ajustándolas al tamaño reducido de las tarjetas.

Validación: 14 aserciones de presentación con clones reales de GUI y 5 de inicialización/enlaces del controlador. Compilación Luau de controladores y pruebas, ambos builds Rojo y git diff --check aprobados. La UI proyectada conserva los recursos previamente existentes; las imágenes opcionales creadas exclusivamente en Studio se preservan allí.

Pendiente de validación humana en una nueva prueba:
1. Sumar 800 EXP con el comando de pruebas: comprobar nivel y etapa en HUD y Mi perfil.
2. Abrir el pase desde el perfil y volver con X; revisar próximo premio y pendientes tras reclamar.
3. Abrir Ver artículos y equipar normalmente; volver al perfil.
4. Inspeccionar a otro jugador: únicamente nivel público, sin progreso del pase.
5. Revisar teléfono/consola y liquidación real de EXP al cerrar una partida.

No se modificaron reglas de EXP, persistencia, recompensas ni permisos administrativos. Sin commits, push ni publicación.
