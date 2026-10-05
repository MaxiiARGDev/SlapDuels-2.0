# Slap Duels 2.0 — COMBAT

> Este documento conserva contenido del `GAME_SDD.md` original suministrado, redistribuido por dominio para reducir el contexto necesario para agentes de IA.

## 14. Slap System (Sistema Centralizado de Slaps y Combate)

### 14.1 Visión General y Principios Arquitectónicos
El **Slap System** es el núcleo de combate de *Slap Duels 2.0*. Su arquitectura desacopla estrictamente los componentes cosméticos y configurables de la lógica de combate:
- **Separación entre Asset y Lógica:** Cada Slap es una instancia física de tipo `Tool` almacenada en `ServerStorage.Slaps` que encapsula exclusivamente su apariencia visual (malla, texturas, efectos) y su configuración (`Configuration.Power` y `Configuration.SlapCooldown`).
- **Lógica Centralizada:** Ningún Tool contiene scripts de combate individuales. Toda la validación, hit detection, control de cooldowns, física de knockback y registro de tags de combate reside en el servicio central del servidor (`SlapService`).
- **Servidor Autoritativo:** El cliente únicamente reproduce feedback visual local inmediato (animación de swing) y envía la solicitud de bofetada (`PerformSlap`). El servidor valida que el jugador esté vivo, en partida activa, en estado `Playing`, respete el cooldown, y verifica espacialmente la distancia y el ángulo del objetivo antes de ejecutar el golpe.

### 14.2 Cadena de Ejecución de Combate
```mermaid
graph TD
    ClientTool["Tool.Activated (Cliente)"] -->|Swing Anim Local| SlapCtrl["SlapController"]
    SlapCtrl -->|PerformSlap Remote| SlapService["SlapService (Servidor Autoritativo)"]
    SlapService -->|1. Validar Tool & Config| SlapVal["Power / Cooldown / State == Playing"]
    SlapVal -->|2. Validar Hitbox| HitDetect["Max Reach <= 9 studs / Facing Angle"]
    HitDetect -->|3. Registrar Tag| CombatService["CombatService:RegisterHit()"]
    CombatService -->|CombatTag + LastAttacker| TagReady["Tag registrado"]
    HitDetect -->|4. Impulso & Ragdoll| RagdollService["RagdollService:ApplyRagdoll()"]
    RagdollService -->|Knockback físico| Victim["Víctima impulsada hacia KillPart"]
    Victim -->|Toca KillPart| EliminationService["EliminationService"]
    EliminationService -->|GetLastAttacker()| KillAward["+1 Kill para el atacante"]
```

### 14.3 Estructura de Assets en ServerStorage (`ServerStorage.Slaps`)
Cada Slap en el catálogo es un `Tool` configurable directamente en Studio:
```
ServerStorage
└── Slaps
    ├── Classic (Tool, CanBeDropped=false, RequiresHandle=true)
    │   ├── Handle (Part, Transparency=1, CanCollide=false)
    │   ├── Hand (MeshPart con Hit Sound)
    │   ├── WeldConstraint (Part0=Hand, Part1=Handle)
    │   ├── Swing (Animation)
    │   └── Configuration (Configuration)
    │       ├── Power (NumberValue: 40)
    │       └── SlapCooldown (NumberValue: 0.6)
    └── Gold (Tool, CanBeDropped=false, RequiresHandle=true)
        ├── Handle (Part, Transparency=1, CanCollide=false)
        ├── Hand (MeshPart dorado/metálico con Hit Sound)
        ├── WeldConstraint (Part0=Hand, Part1=Handle)
        ├── Swing (Animation)
        └── Configuration (Configuration)
            ├── Power (NumberValue: 40)
            └── SlapCooldown (NumberValue: 0.6)
```

### 14.4 Configuración Dinámica (Power y SlapCooldown)
- **`Power` (`NumberValue`):** Fuerza del impacto. Determina la velocidad y elevación del lanzamiento aplicado a la víctima:
  $$\vec{V}_{\text{launch}} = \vec{D}_{\text{horiz}} \cdot (\text{Power} \cdot 0.9) + (0, \max(\text{Power} \cdot 0.45, 26), 0)$$
- **`SlapCooldown` (`NumberValue`):** Tiempo mínimo en segundos entre bofetadas sucesivas. El servidor rastrea `_cooldowns[player]` impidiendo ataques antes de `os.clock() >= nextAllowed`.
- **Independencia en Studio:** Modificar `Power` o `SlapCooldown` de cualquier Slap en Studio se refleja de forma instantánea sin requerir modificaciones en `SlapService`.

### 14.5 Clonación y Distribución de Herramientas
- **`SlapService:GiveSlap(player, slapName)`:** Clona el Slap solicitado desde `ServerStorage.Slaps` y lo entrega al `Backpack` (o `Character`) del jugador.
- **`SlapService:RemoveSlaps(player)`:** Limpia las herramientas de combate para garantizar que los jugadores no conserven armas en el lobby ni acumulen clones.
- **Integración con `RoundService`:**
  - Al iniciar la cuenta regresiva de combate (`StartCountdown`), `RoundService` invoca `SlapService:EquipMatchPlayers(session)`, entregando el Slap a los participantes.
  - Al retornar al lobby (`ReturningToLobby`), `RoundService` invoca `SlapService:RemoveMatchPlayers(session)`, desarmando a los jugadores.
  - Al reaparecer tras un punto (`SpawnService`), se garantiza la reentrega del Slap al contendiente.

### 14.6 Hit Detection y Validaciones Autoritativas
Para evitar exploits y sincronizar la jugabilidad:
1. **Pertenencia a Match:** El atacante debe contar con una sesión activa en `RoundService`.
2. **Estado `Playing`:** Se rechaza categóricamente cualquier golpe durante `Waiting`, `StartCountdown`, `PointRestartCountdown`, `Ending` o `ReturningToLobby`.
3. **Identidad del Objetivo:** No se permite el auto-ataque (`attacker ~= victim`). La víctima debe ser el oponente de la misma partida.
4. **Rango Físico:** La distancia euclidiana entre las partes raíz (`HumanoidRootPart`) debe ser menor o igual a `MAX_SLAP_REACH` (9 studs).
5. **Ángulo Frontal:** El vector hacia la víctima debe encontrarse en el cono frontal del atacante (`LookVector:Dot(Direction) >= -0.2`), rechazando ataques a espaldas.

### 14.7 Integración con Ragdoll, Knockback y Kills
- **`CombatService:RegisterHit(attacker, victim)`:** Se invoca obligatoriamente en cada bofetada válida, registrando el `CombatTag` con `HitId` y timestamp.
- **`RagdollService:ApplyRagdoll(victimChar, duration, launchVelocity)`:** Pasa a la víctima a estado muñeco de trapo, deshabilitando restricciones motoras y aplicando el vector tridimensional de knockback tanto en el servidor como vía `StateEvent` al cliente.
- **Atribución de Kill:** Si la víctima impulsada cae y toca el `KillPart` del mapa, `EliminationService` consulta `CombatService:GetLastAttacker(victim)`, resuelve al atacante y le otorga de forma autoritativa `+1 Kill`.

### 14.8 Escalabilidad y Preparación para la Tienda Futura
- **Catálogo Único de Assets:** El mismo modelo almacenado en `ServerStorage.Slaps` funcionará tanto como herramienta de juego (`Tool`) como para la previsualización 3D en la futura tienda mediante `ViewportFrame`.
- **Estructura Extensible:** Permite añadir decenas de Slaps (`Diamond`, `Void`, `Fire`, `Emerald`, etc.) creando una nueva carpeta/Tool en `ServerStorage.Slaps` sin alterar una sola línea del código de combate.

---

## Referencias relacionadas

- Kill attribution: `ELIMINATION.md`
- Respawn tras eliminación: `CHARACTER_LIFECYCLE.md`
- Assets de Slaps: `../standards/ASSETS.md`
