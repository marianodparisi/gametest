using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine.SceneManagement;

/// Crea la escena de arranque automáticamente al importar el proyecto.
/// La escena es solo un GameObject con RallyGame — todo lo demás es código.
[InitializeOnLoad]
public static class ProjectBootstrap
{
    const string ScenePath = "Assets/Main.unity";

    static ProjectBootstrap()
    {
        EditorApplication.delayCall += EnsureScene;
    }

    [MenuItem("Rally/Crear escena principal")]
    public static void EnsureScene()
    {
        if (System.IO.File.Exists(ScenePath)) return;

        var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
        var go = new GameObject("RallyGame");
        go.AddComponent<RallyGame>();
        EditorSceneManager.SaveScene(scene, ScenePath);

        EditorBuildSettings.scenes = new[] { new EditorBuildSettingsScene(ScenePath, true) };
        Debug.Log("Rally: escena principal creada en " + ScenePath);
    }
}
