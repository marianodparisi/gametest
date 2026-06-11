# Rally Game — Unity

Port a Unity del juego de rally low-poly (versión original en Godot, en la raíz del repo).
**Todo el juego se construye por código** — no hay escenas que editar a mano.

## Cómo abrir

1. Instalar **Unity Hub** (ya instalado via brew) y desde el Hub instalar **Unity 6 (6000.x LTS)**
2. Unity Hub → Add → seleccionar esta carpeta (`rally_unity/`)
3. Abrir el proyecto — al importar se crea sola la escena `Assets/Main.unity`
4. Play ▶

La primera vez Unity descarga los packages (URP + glTFast para los modelos .glb).

## Controles

| Acción | Jugador 1 | Jugador 2 |
|---|---|---|
| Acelerar | W | ↑ |
| Freno | S | ↓ |
| Girar | A / D | ← / → |
| Freno de mano (drift) | Espacio | Enter |
| Volver al menú | Escape | Escape |

## Arquitectura (code-first)

```
Assets/Scripts/
  Car/
    Wheel.cs          ← Suspensión raycast + grip lateral escalado por masa
    CarController.cs  ← Fuerzas, drift por grip asimétrico, handbrake kick
    AIDriver.cs       ← Waypoints + velocidad por curva + anti-atasco
  Race/
    TrackBuilder.cs   ← Pista Catmull-Rom con miter joints + barreras
    RaceManager.cs    ← Posiciones, vueltas, fin de carrera
  Game/
    Stages.cs         ← Las 3 pistas (waypoints, colores, props)
    CarFactory.cs     ← Arma autos: físico + modelo .glb + stats por estilo
    RallyGame.cs      ← Orquestador: menú, countdown, split-screen, HUD, resultados
Assets/Resources/Models/  ← .glb generados con Blender (autos, ruedas, props)
```

## Qué hereda de la versión Godot

Todos los fixes ya vienen aplicados: suspensión escalada para 1200kg,
grip lateral multiplicado por masa/4, freno que se opone al movimiento
(no empuja atrás), barreras con miter joints que no cruzan la pista,
grilla de largada calculada sobre el asfalto. La dirección en Unity no
necesita inversión (+Y rotation = derecha).

Los waypoints tienen la Z invertida respecto de Godot (forward +Z vs -Z).

## Regenerar modelos 3D

Los `.glb` salen de los scripts Blender del proyecto Godot:
`tools/build_cars.py` y `tools/build_props.py` (correr con
`blender --background --python <script>` y copiar a `Assets/Resources/Models/`).

## Pendiente (vs versión Godot)

- Time trial con ghost, leaderboards persistentes, settings
- Audio (motor, drift, música)
- Partículas de polvo y skidmarks
- Gamepads (hoy solo teclado)
- Post-procesado URP (bloom, AO) — agregar Volume global
