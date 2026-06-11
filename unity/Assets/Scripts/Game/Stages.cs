using UnityEngine;
using System.Collections.Generic;

/// Definición de las 3 pistas (waypoints portados de la versión Godot).
public static class Stages
{
    public class StageDef
    {
        public string name;
        public bool isCircuit;
        public int laps;
        public float roadWidth;
        public Color roadColor, grassColor, skyColor;
        public string propA, propB;   // Resources paths
        public Vector3[] waypoints;
    }

    public static readonly StageDef[] All =
    {
        new StageDef
        {
            name = "Circuit — Lakeside", isCircuit = true, laps = 3, roadWidth = 10f,
            roadColor = new Color(0.36f, 0.35f, 0.37f),
            grassColor = new Color(0.26f, 0.46f, 0.2f),
            skyColor = new Color(0.35f, 0.58f, 0.82f),
            propA = "Models/Props/tree", propB = "Models/Props/pine",
            waypoints = new[]
            {
                new Vector3(0, 0, 55), new Vector3(20, 0, 50), new Vector3(42, 0, 35),
                new Vector3(52, 0, 10), new Vector3(48, 0, -20), new Vector3(30, 0, -42),
                new Vector3(0, 0, -55), new Vector3(-30, 0, -42), new Vector3(-52, 0, -18),
                new Vector3(-48, 0, 12), new Vector3(-30, 0, 42), new Vector3(-18, 0, 52),
            },
        },
        new StageDef
        {
            name = "Rally — Mountain Pass", isCircuit = false, laps = 1, roadWidth = 10.5f,
            roadColor = new Color(0.42f, 0.38f, 0.32f),
            grassColor = new Color(0.3f, 0.42f, 0.22f),
            skyColor = new Color(0.45f, 0.5f, 0.65f),
            propA = "Models/Props/pine", propB = "Models/Props/rock",
            waypoints = new[]
            {
                new Vector3(0, 0, 0), new Vector3(5, 0, 25), new Vector3(18, 0.5f, 55),
                new Vector3(35, 1.5f, 75), new Vector3(55, 2.5f, 80), new Vector3(70, 3.5f, 65),
                new Vector3(65, 4.5f, 40), new Vector3(50, 5f, 20), new Vector3(55, 5.5f, -10),
                new Vector3(70, 6f, -35), new Vector3(60, 7f, -65), new Vector3(35, 7.5f, -80),
                new Vector3(10, 7.8f, -90), new Vector3(-15, 8f, -95), new Vector3(-35, 8.2f, -80),
            },
        },
        new StageDef
        {
            name = "Circuit — Desert Dunes", isCircuit = true, laps = 3, roadWidth = 11f,
            roadColor = new Color(0.52f, 0.45f, 0.36f),
            grassColor = new Color(0.85f, 0.72f, 0.5f),
            skyColor = new Color(0.55f, 0.65f, 0.85f),
            propA = "Models/Props/cactus", propB = "Models/Props/rock",
            waypoints = new[]
            {
                new Vector3(0, 0, 60), new Vector3(30, 0, 58), new Vector3(48, 0, 42),
                new Vector3(40, 0, 18), new Vector3(55, 0, 0), new Vector3(48, 0, -25),
                new Vector3(25, 0, -35), new Vector3(15, 0, -55), new Vector3(-10, 0, -62),
                new Vector3(-32, 0, -50), new Vector3(-40, 0, -28), new Vector3(-28, 0, -10),
                new Vector3(-45, 0, 8), new Vector3(-52, 0, 30), new Vector3(-35, 0, 50),
            },
        },
    };

    // Nota: las Z de los waypoints están invertidas respecto de Godot
    // (Godot forward = -Z, Unity forward = +Z) para que el sentido de giro
    // de cada circuito se conserve.
}
