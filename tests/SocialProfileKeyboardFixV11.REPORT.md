# Perfil social — corrección de teclado V1.1

El desarrollador confirmó que el clic abre el perfil pero mantener F no lo hace. La versión anterior configuraba KeyboardKeyCode y esperaba exclusivamente ProximityPrompt.Triggered; no tenía una ruta de entrada propia.

No se encontró otro binding explícito de F en los scripts accesibles del juego. El consumo o falta de entrega del input por la ruta nativa/CoreGui/foco de ventana **no pudo confirmarse sin la prueba del desarrollador**. No se atribuye el fallo a una causa no observada.

## Implementación

Solo cambia en producción `src/client/Controllers/SocialController.luau`:

- ContextActionService registra `SlapDuelsSocialProfile` para F/Y con prioridad High, exclusivamente mientras existe un objetivo válido.
- Mantener la tecla inicia una espera local de los mismos 0,5 segundos configurados. No requiere mouse sobre el prompt ni depende de que el teclado nativo dispare Triggered.
- Se solicita InputHoldBegin/InputHoldEnd para conservar la presentación de progreso nativa. El clic/touch continúa usando el mismo prompt.
- Teclado y Triggered comparten ActivateProfileTarget. Este revalida personaje, objetivo, distancia, obstáculos, estado de partida, ventanas e inventario antes de solicitar el perfil al servidor.
- Antes de iniciar la solicitud se consume el prompt y se retira el binding: un evento nativo tardío no duplica la apertura. Tampoco se ofrece otro prompt mientras hay una solicitud pendiente.
- Soltar antes de tiempo, recibir Cancel, perder foco de ventana, enfocar un TextBox, cambiar de objetivo/personaje o salir de alcance cancela/invalida la espera.
- F/Y se dejan pasar al escribir en un TextBox. No se agregan botones táctiles de ContextActionService ni interfaces nuevas.
- SocialService, Targeting y los permisos del servidor permanecen intactos; no se modifica economía, persistencia, HUD físico ni gameplay.

## Validación

- **45 aserciones aisladas aprobadas**, incluyendo F sin ningún Triggered nativo ni mouse, tiempo mínimo, liberación temprana, Y, Begin repetido, Cancel, cambios de objetivo, callback atrasado, muro durante hold y ausencia de apertura duplicada.
- **216 scripts compilados**, ambos builds Rojo y git diff --check aprobados.
- Source y EditorSource de SocialController verificados por SHA-256 en Studio Edit.
- Confirmado **Studio / InMemory / WritesToCloud=false**.
- No se inició Play, Run ni Start Server, no se controlaron personajes, no hubo publicaciones, commits, push ni escrituras cloud.
- **Entrada física del teclado y comportamiento real de CoreGui: NOT RUN, pendiente del desarrollador.**

Evidencias `SocialProfileKeyboardFixV11.results.txt`, `.compile.txt`, `.default.build.txt`, `.safe.build.txt`, `.diff.txt`, `.source-hashes.json`, `.studio-edit.json`. Se amplió la suite `SocialProfilePromptFixV1.spec.luau`; el validador existente acepta el prefijo de esta revisión. Copia previa del módulo en `tests/assets/backups/SocialProfileKeyboardFixV11/`.

## Prueba manual

1. Iniciar **una prueba nueva** para cargar el LocalScript actualizado. Dar foco a la ventana del juego; no dejar el cursor de escritura en chat/Command Bar.
2. Acercarse al otro jugador, dejar el mouse fuera del prompt y mantener **F durante 0,5 segundos**. Debe abrir su perfil sin clic.
3. Soltar F antes de los 0,5 segundos: no debe abrirse. Repetir correctamente; una pulsación no debe producir dos solicitudes/aperturas.
4. Comprobar clic/touch y Y, escribir una F en chat sin abrir perfiles y probar cancelación al alejarse/cambiar de objetivo durante el hold.

Si F sigue sin responder, habilitar temporalmente las trazas **desde Command Bar del cliente de la prueba**:

```lua
game:GetService("Players").LocalPlayer:SetAttribute("SocialProfileInputDebug", true)
```

Luego volver a enfocar la ventana del juego y repetir F. Capturar Output del cliente con `[SocialProfileInput]`: `Bound`, `HoldBegin`, `HoldComplete`, `Activate`, `HoldCancelled`, `TextFocus`, `RejectedOrStale` o `NativeTriggered`.

Sin HoldBegin no puede afirmarse que el cliente recibió F; revisar foco y bindings de la sesión. HoldComplete seguido de RejectedOrStale indica que cambió alguna condición de apertura. Activate confirma el paso a OpenProfile, cuyo rechazo de servidor se muestra en el aviso existente. Desactivar con el mismo atributo en false.

Se espera la validación del desarrollador antes de declarar resuelto el fallo en teclado real.
