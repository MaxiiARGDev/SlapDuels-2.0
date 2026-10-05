# SDD Migration Manifest

Fuente:
`Markdown(20261005-155845).md pegado`

Objetivo:
Redistribuir el SDD monolítico en documentos especializados para reducir el contexto que necesita consultar un agente de IA.

Principio:
El contenido fuente se conserva en los documentos especializados. Este manifiesto sirve para auditar la migración.

Archivos generados:
- GAME_SDD.md
- docs/architecture/ARCHITECTURE.md
- docs/architecture/SERVER_CLIENT.md
- docs/architecture/SERVICES.md
- docs/gameplay/MATCH_FLOW.md
- docs/gameplay/MATCHMAKING.md
- docs/gameplay/COMBAT.md
- docs/gameplay/SCORING.md
- docs/gameplay/ELIMINATION.md
- docs/gameplay/CHARACTER_LIFECYCLE.md
- docs/presentation/AUDIO.md
- docs/presentation/UI.md
- docs/presentation/GAME_FEEL.md
- docs/presentation/POINT_EFFECTS.md
- docs/data/PLAYER_DATA.md
- docs/standards/ASSETS.md
- docs/standards/TESTING.md
- docs/standards/DEBUGGING.md

Nota:
Algunas secciones originales contienen información transversal. En esos casos se conserva en el documento del dominio principal y se agregan referencias cruzadas para que el agente pueda saltar al documento relacionado.
