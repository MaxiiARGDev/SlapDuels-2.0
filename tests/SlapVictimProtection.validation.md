# Protección de víctima tras palmada — 2026-10-18

Implementado únicamente en `CombatService.luau` y `SlapService.luau`.

- Impacto confirmado reserva inmunidad por `Config.Combat.DefaultSlapKnockdownDuration` (3 s), usando `os.clock()` del servidor. No se agregan constantes de balance.
- Selección y registro final consultan el mismo guard. El registro vuelve a comprobarlo después de los hooks de habilidades, sin yield entre comprobación y reserva.
- Protección vinculada a identidad de sesión, ronda, Character y ArenaPhysicsGeneration. ClearCombatTag/ClearMatch la eliminan junto con el registro existente.
- Durante protección no hay nuevos impactos, tags, impulso, renovación de ragdoll ni consumo de StrongSlap. Un swing sin objetivo elegible conserva ventana de 0,10 s y recuperación por fallo de 0,45 s al cerrarla.
- Se conserva recuperación del atacante de 0,15 s tras acierto. Esa recuperación no cancela la protección de la víctima.
- La ventana de impacto existente permanece activa: si alcanza el instante de expiración, puede acertar desde ese instante. No hay impactos antes del deadline.
- No se cambia la física ni el temporizador de levantarse. El deadline autoritativo no se prolonga por retrasos de animación o del scheduler; la representación física sigue dependiendo de los frames de Roblox.

## Verificación

| Comprobación | Resultado |
|---|---|
| Regresión adaptada de combate/cliente/UI + protección, límites temporales, cleanup y carrera después del hook | PASS: 150 aserciones aisladas |
| Regresión de habilidades | PASS: 164 aserciones aisladas |
| Registry y seguridad | PASS: 89 aserciones aisladas |
| Compilación Luau de los dos servicios y spec | PASS |
| Rojo default y studio-safe | PASS |
| git diff --check | PASS; advertencias previas de LF/CRLF |
| Studio Edit: Source y editor coinciden con archivos locales por SHA-256 normalizado | PASS |
| Partida y física con dos clientes reales | NOT RUN; a cargo del desarrollador |

Studio observado: IsStudio=true, IsRunning=false, Workspace.ActiveMatches=0, diagnóstico desactivado. La rama Studio del selector de persistencia conserva Studio/InMemory/WritesToCloud=false por inspección de código; no se inicializaron servicios ni se accedió a DataStores para probarlo.

Hashes finales normalizados:

- CombatService: `2377eab8574fb159c3644f670151abac849e5e4f6cf3ffa86102cdc0f523f6d0`
- SlapService: `55e02fc4ade9e415f389e25f3faa7403fe2027961f30ed79b1054de9b6c4555e`

Copias previas: `tests/assets/backups/SlapVictimProtection`, con manifest de hashes. Los respaldos anteriores se preservaron. El archivo histórico CombatSystemV132.spec conserva expectativas previas a esta nueva regla; ejecutar la variante SlapVictimProtection.spec para el comportamiento actual.

No se inició Play/Run/Start Server; no hubo cambios de mapas, HUD, balance, persistencia, publicaciones, commits ni push.

## Prueba manual del desarrollador

1. Iniciar tu prueba con dos clientes y confirmar en Output Studio / InMemory / WritesToCloud=false antes de combatir.
2. Acertar una palmada. Confirmar lanzamiento y levantamiento habitual después de 3 s.
3. Acercarse y atacar mientras la víctima sigue protegida: no debe relanzarse, reiniciar los 3 s ni acumular impactos. El slot del atacante debe mostrar recuperación por fallo.
4. Esperar a que se cumplan los 3 s y acertar otra palmada dentro del alcance: debe contar y lanzar de nuevo. La víctima también debe poder actuar al recuperarse.
5. Completar tres impactos válidos separados por las recuperaciones de la víctima: una sola eliminación. Los intentos durante protección no cuentan para esos tres.
6. Repetir con StrongSlap armado: golpear durante protección no debe consumirlo; un impacto elegible posterior sí conserva su comportamiento.
7. Verificar tras reposicionamiento, nueva vida y nueva ronda que no quede protección residual.

Si falla, capturar Output de servidor y ambos clientes, indicando qué jugador golpeó, cuándo cayó/se levantó y si ocurrió nuevo impulso, incremento de golpes o solo animación. La vía existente `[SlapTrace]` informa `VictimHitProtected` y Outcome=Miss cuando está habilitada manualmente en la prueba. La etiqueta Build preexistente sigue siendo CombatSystemV132; verificar estos hashes si se necesita identificar esta revisión.
