# Party HUD y matchmaking V1 — implementación

## Entrega
Plan y procedimiento manual: SlapDuels_SDD_Documentacion/PARTY_MATCHMAKING_V1_PLAN.md.
HUD instalado físicamente en StarterGui.PartyMatchHUD (101 descendientes): Dock.Members.Slot1–Slot4 y Add, Dock.Play/Leave, InvitePanel, InviteTemplate, ModePanel.Modes.1v1–4v4, Search, Return, Status y Telemetry. Plantilla editable en src/ui/PartyMatchHUD.project.json. No se sustituyeron HUDs existentes. Las ventanas se integran con la pila de navegación.

## Archivos
- Nuevos: PartyMatchConfig, PartyMatchService, Gameplay/PartyQueueModel, Gameplay/PartyQueueStore, PartyMatchController y PartyMatchHUD.project.json.
- Integración: Bootstrap registra el servicio; MatchmakingService delega reservas Menu y excluye PartyQueueTicket de plataformas; SocialPlayEngine admite invitación Group a distancia (Duel conserva proximidad); SocialPlayController oculta solo el antiguo panel de grupo cuando el nuevo HUD existe; WindowNavigationController integra las dos ventanas.
- Exclusión de actividades: SocialService, CrateService y TrainingService rechazan nuevas interacciones incompatibles durante la cola. No se modificaron premios, combate, persistencia, RoundService, límites de concurrencia ni mapas.
- default.project.json y studio-safe.project.json incluyen los nuevos recursos. Respaldo de los archivos anteriores en tests/assets/backups/PartyMatchmakingV1, conservado junto a payloads de sincronización y builds.

## Seguridad de admisión
Servidor determina roster, modo y líder; los clientes no envían equipos. Tickets atómicos por modalidad, expiración y cancelación que no revierte asignaciones consumidas. Token Menu valida exactamente ambos equipos y se consume una vez. MemoryStore coordina una reserva privada del mismo Place. TeleportData no autoriza equipos: solo referencia un manifest servidor con destino privado y miembros. Consumo por una sola instancia receptora, espera de perfiles/roster completo y validación del ping real antes de StartTeamMatch.

El retorno al lobby usa un manifest separado para reconstruir parties completas. Fallos/expiraciones liberan los presentes. No se liberan anticipadamente perfiles persistentes; se mantiene el guardado y liberación existentes en PlayerRemoving y el rechazo de perfiles no listos.

## Resultados
| Verificación | Resultado |
|---|---|
| Suite nueva, modelo/servicio reales y transporte simulado | PASS — 105 aserciones |
| Compilación de src | PASS — 221 scripts |
| Rojo default y SAFE | PASS |
| git diff --check | PASS |
| Instalación MCP, Source/EditorSource y jerarquía Edit | PASS |
| Capturas visuales Dock y selector en Edit | Observadas |
| Studio / InMemory / WritesToCloud=false | Confirmado mediante Resolve en Edit |
| ProfileSocialV12 histórica | BLOCKED — fixture anterior sin Progression.Model |
| Jugabilidad local, móvil/consola, global, retorno real y conservación de datos tras teleport | NOT RUN — desarrollador |

No Play/Run/Start Server, partidas, publicaciones, commits/push ni escrituras cloud ejecutadas por el agente. GlobalEnabled prepara el comportamiento de una futura publicación; el backend cloud no se ejecuta en Studio. Latencia global es preferencial y medida al llegar, no garantía de datacenter ni de ping idéntico. Región del servidor no disponible: no se muestra un país inferido de los jugadores.
