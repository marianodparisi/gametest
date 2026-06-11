using UnityEngine;
using System.Collections.Generic;

/// Genera la pista desde waypoints: spline Catmull-Rom con miter joints
/// (los quads comparten bordes, las barreras siguen el borde real).
/// Port de track_builder.gd con los fixes de geometría.
public static class TrackBuilder
{
    public static GameObject Build(List<Vector3> controlPoints, bool loop,
                                   float roadWidth, Color roadColor, Material baseMat)
    {
        var root = new GameObject("Track");

        var pts = CatmullRom(controlPoints, 8, loop);
        for (int i = 0; i < pts.Count; i++) pts[i] += Vector3.up * 0.08f;

        // Perpendicular por punto (promedia segmentos adyacentes)
        int n = pts.Count;
        var rights = new Vector3[n];
        for (int i = 0; i < n; i++)
        {
            Vector3 dirIn, dirOut;
            if (loop)
            {
                dirIn = pts[i] - pts[(i - 1 + n) % n];
                dirOut = pts[(i + 1) % n] - pts[i];
            }
            else
            {
                dirIn = i > 0 ? pts[i] - pts[i - 1] : pts[1] - pts[0];
                dirOut = i < n - 1 ? pts[i + 1] - pts[i] : pts[n - 1] - pts[n - 2];
            }
            var avg = dirIn.normalized + dirOut.normalized;
            if (avg.magnitude < 0.001f) avg = dirOut;
            avg.y = 0;
            rights[i] = Vector3.Cross(Vector3.up, avg.normalized).normalized * -1f;
        }

        BuildRoad(root, pts, rights, loop, roadWidth, roadColor, baseMat);
        BuildBarriers(root, pts, rights, loop, roadWidth, baseMat);
        return root;
    }

    static void BuildRoad(GameObject root, List<Vector3> pts, Vector3[] rights,
                          bool loop, float width, Color color, Material baseMat)
    {
        int n = pts.Count;
        int segs = loop ? n : n - 1;
        float half = width * 0.5f;

        var verts = new List<Vector3>();
        var tris = new List<int>();

        for (int i = 0; i < segs; i++)
        {
            int j = (i + 1) % n;
            int v = verts.Count;
            verts.Add(pts[i] - rights[i] * half);  // al
            verts.Add(pts[i] + rights[i] * half);  // ar
            verts.Add(pts[j] + rights[j] * half);  // br
            verts.Add(pts[j] - rights[j] * half);  // bl
            tris.AddRange(new[] { v, v + 1, v + 2, v, v + 2, v + 3 });
        }

        var mesh = new Mesh { indexFormat = UnityEngine.Rendering.IndexFormat.UInt32 };
        mesh.SetVertices(verts);
        mesh.SetTriangles(tris, 0);
        mesh.RecalculateNormals();

        var go = new GameObject("Road");
        go.transform.SetParent(root.transform);
        go.AddComponent<MeshFilter>().mesh = mesh;
        var mr = go.AddComponent<MeshRenderer>();
        var mat = new Material(baseMat) { color = color };
        mr.material = mat;
        go.AddComponent<MeshCollider>().sharedMesh = mesh;
    }

    static void BuildBarriers(GameObject root, List<Vector3> pts, Vector3[] rights,
                              bool loop, float roadWidth, Material baseMat)
    {
        int n = pts.Count;
        int segs = loop ? n : n - 1;
        float offset = roadWidth * 0.5f + 1.2f;

        var barrierMat = new Material(baseMat) { color = new Color(0.92f, 0.92f, 0.92f) };
        var parent = new GameObject("Barriers");
        parent.transform.SetParent(root.transform);

        for (int i = 0; i < segs; i++)
        {
            int j = (i + 1) % n;
            foreach (float side in new[] { -1f, 1f })
            {
                Vector3 a = pts[i] + rights[i] * offset * side;
                Vector3 b = pts[j] + rights[j] * offset * side;
                Vector3 seg = b - a;
                if (seg.magnitude < 0.1f) continue;

                var bar = GameObject.CreatePrimitive(PrimitiveType.Cube);
                bar.name = "Barrier";
                bar.transform.SetParent(parent.transform);
                bar.transform.position = (a + b) * 0.5f + Vector3.up * 0.45f;
                bar.transform.rotation = Quaternion.LookRotation(seg.normalized);
                bar.transform.localScale = new Vector3(0.35f, 0.9f, seg.magnitude + 0.3f);
                bar.GetComponent<MeshRenderer>().material = barrierMat;
            }
        }
    }

    public static List<Vector3> CatmullRom(List<Vector3> pts, int subdivisions, bool loop)
    {
        var result = new List<Vector3>();
        int n = pts.Count;
        int segs = loop ? n : n - 1;
        for (int i = 0; i < segs; i++)
        {
            Vector3 p0 = pts[(i - 1 + n) % n];
            Vector3 p1 = pts[i];
            Vector3 p2 = pts[(i + 1) % n];
            Vector3 p3 = pts[(i + 2) % n];
            for (int s = 0; s < subdivisions; s++)
            {
                float t = (float)s / subdivisions;
                result.Add(Interp(p0, p1, p2, p3, t));
            }
        }
        if (!loop) result.Add(pts[n - 1]);
        return result;
    }

    static Vector3 Interp(Vector3 p0, Vector3 p1, Vector3 p2, Vector3 p3, float t)
    {
        float t2 = t * t, t3 = t2 * t;
        return 0.5f * (2f * p1 + (-p0 + p2) * t
            + (2f * p0 - 5f * p1 + 4f * p2 - p3) * t2
            + (-p0 + 3f * p1 - 3f * p2 + p3) * t3);
    }
}
