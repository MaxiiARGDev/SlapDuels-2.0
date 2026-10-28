# Preparación mientras Studio está en Play

Registro histórico de preparación. El propietario confirmó después el retorno a Edit y se completó la instalación; el estado vigente se documenta en SlapVariationsV1.validation.md.

No se modifican fuentes sincronizadas ni objetos de Studio hasta que el propietario vuelva a Edit y se audite Classic real.

Perfiles previstos: Basic original sin partículas; Common plateado discreto; Uncommon verde suave; Rare azul con luz tenue; Gold metálico dorado; Arcoiris con gradiente multicolor de partículas (sin bucle de colores en servidor); Emote rosa con símbolo decorativo; Wings celeste con dos focos de energía; Epic violeta neón; Legendary naranja dorado con aura moderada; Blood energía roja/negra sin gore; Galaxy azul oscuro/violeta con estrellas.

Extensión genérica prevista: Appearance compartido para Tint, Material e intensidad; copia segura/idempotente de recursos visuales y posición normalizada de attachments respecto a Hand. No cambia físicas, geometría, Configuration, Swing ni sonidos existentes. Previews seguros independientes por SlapId/VariationId. CrateController selecciona un solo preview y reutiliza el mismo aplicador; no duplica efectos ni emite partículas de Basic por un burst genérico.

Pendiente requerido: detener la prueba desde Studio y confirmar Edit. El agente no detiene Play ni cambia modo.
