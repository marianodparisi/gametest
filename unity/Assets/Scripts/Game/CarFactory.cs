using UnityEngine;

/// Crea un auto completo: Rigidbody + ruedas raycast + modelo glb (con
/// fallback a primitivas). Pinta superficies cuyo material se llama "Paint".
public static class CarFactory
{
    public static readonly string[] Models =
    {
        "Models/Cars/car_0_rally_hatch", "Models/Cars/car_1_muscle",
        "Models/Cars/car_2_buggy", "Models/Cars/car_3_classic",
        "Models/Cars/car_4_van", "Models/Cars/car_5_wedge",
    };

    public static readonly string[] StyleNames =
        { "Rally Hatch", "Muscle", "Buggy", "Classic", "Van", "Wedge" };

    // {engine multiplier, rearGrip} — más potencia = menos grip
    public static readonly float[][] StyleStats =
    {
        new[] { 1f, 1.8f }, new[] { 1.15f, 1.5f }, new[] { 0.95f, 2.2f },
        new[] { 0.9f, 2f }, new[] { 0.85f, 2.4f }, new[] { 1.2f, 1.6f },
    };

    public static CarController Create(int style, Color color, Vector3 pos, Quaternion rot)
    {
        var go = new GameObject($"Car_{StyleNames[style % 6]}");
        go.transform.SetPositionAndRotation(pos, rot);

        var rb = go.AddComponent<Rigidbody>();
        rb.interpolation = RigidbodyInterpolation.Interpolate;

        // Colisión del chasis
        var col = go.AddComponent<BoxCollider>();
        col.center = new Vector3(0, 0.25f, 0);
        col.size = new Vector3(1.6f, 0.5f, 3.6f);
        var phys = new PhysicsMaterial { dynamicFriction = 0.2f, staticFriction = 0.2f, bounciness = 0.1f };
        col.material = phys;

        var ctrl = go.AddComponent<CarController>();
        var stats = StyleStats[style % 6];
        ctrl.engineForce *= stats[0];
        ctrl.rearGrip = stats[1];

        // Ruedas (z positivo = adelante en Unity)
        foreach (var (x, z) in new[] { (-0.75f, 1.2f), (0.75f, 1.2f), (-0.75f, -1.2f), (0.75f, -1.2f) })
            CreateWheel(go.transform, x, z);

        // Modelo visual
        var visual = BuildVisual(go.transform, style);
        Paint(visual, color);

        return ctrl;
    }

    static void CreateWheel(Transform parent, float x, float z)
    {
        var wgo = new GameObject($"Wheel_{x}_{z}");
        wgo.transform.SetParent(parent);
        wgo.transform.localPosition = new Vector3(x, 0.1f, z);
        wgo.AddComponent<Wheel>();

        var prefab = Resources.Load<GameObject>("Models/Props/wheel");
        GameObject vis;
        if (prefab != null)
        {
            vis = Object.Instantiate(prefab, wgo.transform);
        }
        else
        {
            vis = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            Object.Destroy(vis.GetComponent<Collider>());
            vis.transform.SetParent(wgo.transform);
            vis.transform.localScale = new Vector3(0.56f, 0.11f, 0.56f);
            vis.transform.localRotation = Quaternion.Euler(0, 0, 90);
        }
        vis.transform.localPosition = new Vector3(0, -0.42f, 0);
        // Sin colliders en la rueda visual
        foreach (var c in vis.GetComponentsInChildren<Collider>()) Object.Destroy(c);
    }

    static GameObject BuildVisual(Transform parent, int style)
    {
        var prefab = Resources.Load<GameObject>(Models[style % Models.Length]);
        if (prefab != null)
        {
            var vis = Object.Instantiate(prefab, parent);
            vis.transform.localPosition = Vector3.zero;
            // El glb viene con la trompa a -Z (convención Godot); en Unity es +Z
            vis.transform.localRotation = Quaternion.Euler(0, 180, 0);
            foreach (var c in vis.GetComponentsInChildren<Collider>()) Object.Destroy(c);
            return vis;
        }

        // Fallback: caja simple
        var box = GameObject.CreatePrimitive(PrimitiveType.Cube);
        Object.Destroy(box.GetComponent<Collider>());
        box.transform.SetParent(parent);
        box.transform.localPosition = new Vector3(0, 0.35f, 0);
        box.transform.localScale = new Vector3(1.6f, 0.45f, 3.6f);
        return box;
    }

    static void Paint(GameObject visual, Color color)
    {
        foreach (var mr in visual.GetComponentsInChildren<MeshRenderer>())
        {
            var mats = mr.materials;
            bool changed = false;
            for (int i = 0; i < mats.Length; i++)
            {
                if (mats[i] != null && mats[i].name.StartsWith("Paint"))
                {
                    mats[i].color = color;
                    changed = true;
                }
            }
            if (changed) mr.materials = mats;
        }
    }
}
