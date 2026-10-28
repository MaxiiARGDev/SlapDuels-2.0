# Corrección de acceso a perfiles — V1

Implementada y sincronizada en **Studio Edit**. No se inició Play/Run/servidor, no se controlaron personajes y no se ejecutaron partidas. La validación con jugadores corresponde al desarrollador.

## Cambios

- `src/client/Social/Targeting.luau`: prioriza el jugador apuntado si es válido y visible; si no, elige el jugador visible más cercano dentro de los 10 studs existentes. Desempates por UserId, sin transformar identificadores negativos de Studio.
- Se excluyen el propio jugador, desconectados, personajes sin Humanoid/raíz, jugadores muertos y participantes con MatchId. El observador también debe estar vivo y fuera de partida.
- La comprobación de obstáculos excluye ambos Characters completos, incluidos torso y Slap de espalda. Verifica un camino desde la raíz del observador a la raíz del objetivo y otro desde la cámara a su cabeza. Se consideran obstáculos colisionables mediante RaycastParams.RespectCanCollide; las decoraciones sin colisión no se usan como paredes.
- `src/client/Controllers/SocialController.luau`: el prompt usa RequiresLineOfSight=false porque la visibilidad se valida con esos raycasts antes de seleccionarlo y otra vez al activarlo. Así el torso no oculta su propio prompt y se conserva el rechazo de paredes físicas.
- Se muestra un solo prompt social local con Exclusivity=AlwaysShow. Interacción: **mantener F durante 0,5 s en PC**, **Y en mando** o tocar el prompt. E/X quedan para las tiendas/NPCs próximos; no se cambiaron esos sistemas.
- La misma selección no recrea el prompt constantemente. Cambio de personaje/objetivo, ventanas bloqueantes, combate o cierre limpian prompt y highlight. Un callback antiguo comprueba objetivo, prompt y Character antes de intentar abrir un perfil.
- Los errores con perfil cerrado usan `SocialPlayController:Notice`, que muestra el TextLabel físico existente `StarterGui.SocialPlayHUD.Notice`. Con una ventana social abierta se conserva su Status. Si ese controlador no está disponible, se registra un warning; no se crea otro ScreenGui.

## Autoridad y preservación

No se modificaron SocialService, SocialConfig, remotes, inventarios, trading, grupo, desafíos, mapas, HUDs físicos ni economía. Los checks del cliente son de presentación; el servidor conserva la validación de elegibilidad, distancia, pertenencia y rate limit.

Copias previas de los dos módulos: `tests/assets/backups/SocialProfilePromptFixV1/`.

## Verificaciones

| Comprobación | Resultado |
|---|---|
| Selección sin cursor y prioridad del apuntado | PASS aislado |
| Distancia, vida, desconexión y partida | PASS aislado |
| Exclusión de avatares y obstáculos desde cuerpo/cámara | PASS con raycasts simulados |
| F/Y/touch, rango y duración del prompt | PASS aislado |
| Cambio de Character y callbacks obsoletos | PASS aislado |
| Limpieza y ventanas bloqueantes | PASS aislado |
| Rechazo del servidor con perfil cerrado | PASS mediante RPC simulado y aviso existente |
| Total de suite específica | **32 aserciones aprobadas** |
| Compilación | **216 scripts src aprobados** |
| Rojo default y SAFE | **Ambos aprobados** |
| git diff --check | **Aprobado** |
| SocialService y SocialConfig | Hashes idénticos a la auditoría |
| Fuentes nativas / EditorSource | SHA-256 iguales a los archivos locales para ambos módulos |
| Persistencia observada en Edit | **Studio / InMemory / WritesToCloud=false** |
| Visibilidad, controles y apertura con dos clientes reales | **NOT RUN — pendiente del desarrollador** |

La sincronización comprobó Source y EditorSource frente al hash previo o final y volvió a validar el borrador dentro de UpdateSourceAsync. Solo se escribieron los dos módulos existentes. No se aplicó el árbol completo de Rojo ni se guardó/cerró/publicó el lugar.

Evidencias: `SocialProfilePromptFixV1.results.txt`, `.compile.txt`, `.default.build.txt`, `.safe.build.txt`, `.diff.txt`, `.source-hashes.json`; builds `.default.rbxlx` y `.safe.rbxlx`.

## Prueba manual

1. Iniciar tu prueba de Studio con dos jugadores. Confirmar Studio / InMemory / WritesToCloud=false en Output.
2. En lobby acercarse a menos de 10 studs del otro jugador, sin necesidad de apuntarlo. Deben aparecer el highlight y **F · Ver perfil**.
3. Mantener F durante 0,5 segundos: debe abrirse el perfil de ese jugador, con sus artículos/equipamiento y acciones habituales. Cerrarlo y repetir.
4. Apuntar a otro jugador dentro de alcance: debe tener prioridad sobre el más cercano. Salir de alcance o entrar en combate: no debe quedar un prompt utilizable.
5. Probar distintos ángulos frente al torso y Slap de espalda. El avatar no debe ocultar su propio prompt. Una pared colisionable entre jugadores o entre cámara y objetivo sí debe impedir la selección/apertura.
6. Probar cerca de tiendas/NPCs: sus prompts E deben seguir funcionando y el social F debe ser independiente. En mando usar Y; en móvil tocar el prompt visible.
7. Reemplazar/respawnear el objetivo y reconectarlo: no debe duplicarse el prompt ni abrirse un perfil desde un callback de su Character anterior.
8. Si el objetivo sale de alcance/partida o se desconecta durante una solicitud y el servidor la rechaza, comprobar el aviso visible en SocialPlayHUD. Capturar Output y el texto del aviso si falla.

No se declara resuelto visualmente en multijugador hasta tu validación. No hubo commits, push, publicaciones ni escrituras cloud.
