# Rally Game — low poly racing

Juego de carreras 3D low-poly estilo Art of Rally. Split-screen local, 6 autos (2 jugadores + 4 IA).

## Cómo jugar

```bash
godot /Users/m.parisi/rally_game/project.godot
```

Presionar **F5** (Play). Flujo: Menú → elegir pista con ◀▶ → 1P o 2P Split Screen → countdown → carrera → resultados.

## Controles

| Acción | Jugador 1 (teclado) | Jugador 2 (teclado) | Gamepad (1→P1, 2→P2) |
|---|---|---|---|
| Acelerar | W | Flecha Arriba | Gatillo derecho (R2/RT) |
| Freno | S | Flecha Abajo | Gatillo izquierdo (L2/LT) |
| Girar | A / D | Flechas Izq/Der | Stick izquierdo |
| Freno de mano (drift) | Espacio | Enter | A / Cross |
| Pausa | Escape | Escape | — |

## Pistas

- **Circuit — Lakeside**: circuito cerrado, 3 vueltas, curvas Catmull-Rom, árboles y montañas
- **Rally — Mountain Pass**: stage lineal A→B con subidas y hairpins, estética de montaña
- **Circuit — Desert Dunes**: circuito técnico con chicanas y horquilla, cactus y dunas

## Modos de juego

- **1 Player**: vs 4 IA
- **2 Players Split Screen**: vs 4 IA
- **Time Trial**: solo contra el reloj, con **ghost** de tu mejor corrida

## Features

- Física raycast por rueda con drift por asimetría de grip (rear 1.8 vs front 4.0)
- Split-screen con `world_3d` compartido — un solo motor de física, dos cámaras
- 4 IA por waypoints con **dificultad seleccionable** (Easy / Normal / Hard)
- Countdown 3-2-1-GO con autos frenados en grilla
- HUD por jugador: posición, velocidad, vuelta, tiempo
- Pantalla de resultados con banner **NEW RECORD** y mejor tiempo histórico
- **Leaderboards locales**: top 5 tiempos por stage, persistidos en `user://best_times.json`
- **Ghost en Time Trial**: graba tu mejor vuelta y corré contra tu fantasma
- Polvo al driftear, skidmarks, **squeal de neumáticos** y sonido de motor procedural
- **Música generativa** estilo chill (Am-F-C-G con arpegio) — sin assets de audio
- **Settings persistentes**: volumen master, volumen música, música on/off
- Pista generada por spline desde waypoints (`track_builder.gd`)
- **6 modelos de auto** con siluetas y stats propios: Rally Hatch, Muscle, Buggy, Classic, Van, Wedge (más potencia = menos grip trasero)
- Soporte de gamepads (2 mandos o mando + teclado)

## Estructura

```
scenes/
  game/Game.tscn        ← Escena orquestadora (split-screen + overlays)
  stages/               ← Circuit01, RallyStage01
  ui/                   ← MainMenu, Countdown, PauseMenu, ResultsScreen
scripts/
  car/                  ← car_controller, wheel, ai_driver, car_effects
  race/                 ← race_manager, track_builder
  game/game.gd          ← Carga stage, spawna autos, cámaras, flujo de carrera
  stages/               ← setup procedural de cada pista (terreno, props)
```

## Tuning del drift

En `Car.tscn` (inspector del nodo raíz):
- `rear_grip` más bajo = más drift (default 1.8)
- `handbrake_grip` = grip trasero durante freno de mano (default 0.4)
- `engine_force`, `max_steer_angle`, `drag_linear` para el feel general

## Próximos pasos (Phase 3+)

- Modelos de autos low-poly en Blender (reemplazar las cajas)
- Más stages — agregar entrada en `GameState.STAGES` + escena con `Waypoints`, `GridStart`, `RaceManager`, `TrackBuilder`
- Música de fondo, mejores sonidos
- Gamepads para P1/P2

## Referencias

- [Hotlap (Godot 4)](https://github.com/YYYYOINKER/Hotlap) — base de la física
- [Car Physics Theory](https://rsms.me/etc/car-physics/)
