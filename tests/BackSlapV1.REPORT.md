# Slap en espalda V1

## Implementación

El servidor muestra el Slap seleccionado para partidas en Character.EquippedBackSlap. Resuelve la selección y la plantilla mediante CrateService.ResolveEquipped/GetRewardTemplate, igual que el arma real. No usa el último premio ni un modelo aproximado de preview.

Clona la plantilla completa, conserva geometría, escala, colores, texturas, Highlights, partículas y sonidos. Convierte el contenedor Tool en Model cosmético; retira scripts, interacciones y física activa. Las partes son Massless, sin colisión/contacto/consulta, unidas al Torso con Weld. No entrega otra Tool ni agrega daño o remotes. Un Highlight que apuntaba al Tool pasa a apuntar al Model.

La selección se actualiza con las notificaciones autoritativas existentes de PlayerService, protegidas contra fallos cosméticos. El refresco es idempotente. Se retira la copia mientras existe un Slap real equipado en la mano y reaparece al retirarlo. Se limpia al morir, cambiar Character o desconectarse.

Para el StarterCharacter blanco R6 se agregó aplicación de la apariencia del UserId mediante HumanoidDescription, sin recargar Character ni cambiar el tipo de rig. Solo se aplica cuando existe StarterCharacter y el UserId es positivo; los clientes ficticios negativos de Studio conservan el aspecto de prueba. Si falla la consulta se advierte en Output y no se afecta la selección ni los datos. La apariencia real todavía necesita prueba manual. Referencia de API: https://create.roblox.com/docs/reference/engine/classes/Humanoid

## Recurso físico

Se preservó el StarterCharacter R6 agregado por el desarrollador. Como todavía no tenía attachment, se creó exactamente uno en:

`StarterPlayer.StarterCharacter.Torso.slap_here`

Posición inicial local (0, 0, 0.75), inclinación Z -30 grados. Puede ajustarse artísticamente en Edit. La Hand de cada Slap se alinea con ese attachment; opcionalmente cada modelo puede definir Hand.SlapBackAttachment para un punto de montaje específico. El attachment se restaura desde la plantilla si la aplicación de apariencia reemplaza partes del cuerpo.

El modelo completo se exportó a src/assets/BackSlapV1/StarterCharacter.rbxm y se registró en ambos proyectos Rojo. Tras futuros ajustes físicos, actualizar también esa exportación antes de reconectar Rojo para evitar que vuelva a la posición respaldada.

## Cambios

- Nuevo src/server/Services/BackSlapService.luau.
- Bootstrap: registro del nuevo servicio después de CrateService.
- PlayerService: notificación cosmética protegida al actualizar datos.
- Ambos proyectos: referencia del StarterCharacter; proyecto seguro también registra el nuevo servicio.
- Nuevo recurso binario StarterCharacter con su único attachment.
- Respaldo anterior: tests/assets/backups/BackSlapV1/, incluido el StarterCharacter previo.

## Validación

- 439 aserciones aisladas en Studio Edit sobre las 36 variaciones: geometría, VFX/SFX, Highlights, seguridad de la copia, alineación, integridad de originales, reemplazo de selección, idempotencia, ocultamiento en mano y limpieza.
- 271 aserciones de regresión de inventario/equipamiento: PASS.
- Compilación de 194 scripts: PASS.
- Ambos Rojo builds: PASS; inspección de sus jerarquías confirma StarterCharacter, slap_here y BackSlapService.
- git diff --check: PASS.
- Inspección final Edit: un attachment, sin partes ancladas ni módulo temporal de auditoría.
- Apariencia real, movimiento, ragdoll, respawn y dos clientes: NOT RUN; responsabilidad del desarrollador.

No se inició Play, Run ni servidor; no se modificó persistencia, ni se hicieron commits, push o publicaciones. No se guardó ni cerró el lugar sobre los cambios del desarrollador.

## Prueba manual

1. Iniciar una prueba nueva y confirmar Studio/InMemory/WritesToCloud=false.
2. Con un usuario real positivo, comprobar la apariencia sobre el R6 blanco y el Slap en la espalda. Con clientes ficticios negativos no se consulta una apariencia de usuario inexistente.
3. Equipar otro modelo/variación desde inventario y desde Shop: debe cambiar la copia de la espalda, sin acumular modelos.
4. Revisar Highlights, partículas, sonidos y posición. Ajustar slap_here en Edit si hace falta.
5. Entrar a partida: al aparecer el Slap en la mano, la copia de espalda desaparece. Al volver al lobby reaparece la selección actual.
6. Revisar ragdoll, respawn y visibilidad desde otro cliente. Confirmar que el Slap cosmético no golpea ni bloquea movimiento.
