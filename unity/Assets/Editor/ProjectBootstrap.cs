using UnityEngine;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

/// Configura el proyecto automáticamente al importar:
/// 1. Activa URP (crea el pipeline asset y lo asigna a Graphics/Quality)
/// 2. Crea la escena principal con el GameObject RallyGame
[InitializeOnLoad]
public static class ProjectBootstrap
{
    const string ScenePath = "Assets/Main.unity";
    const string PipelinePath = "Assets/URP_Pipeline.asset";
    const string RendererPath = "Assets/URP_Renderer.asset";

    static ProjectBootstrap()
    {
        EditorApplication.delayCall += () => { EnsureURP(); EnsureScene(); };
    }

    [MenuItem("Rally/Configurar URP")]
    public static void EnsureURP()
    {
        if (GraphicsSettings.defaultRenderPipeline != null) return;

        var existing = AssetDatabase.LoadAssetAtPath<UniversalRenderPipelineAsset>(PipelinePath);
        if (existing == null)
        {
            var rendererData = ScriptableObject.CreateInstance<UniversalRendererData>();
            AssetDatabase.CreateAsset(rendererData, RendererPath);

            existing = UniversalRenderPipelineAsset.Create(rendererData);
            existing.supportsHDR = true;
            AssetDatabase.CreateAsset(existing, PipelinePath);
            AssetDatabase.SaveAssets();
        }

        GraphicsSettings.defaultRenderPipeline = existing;
        QualitySettings.renderPipeline = existing;
        Debug.Log("Rally: URP activado (" + PipelinePath + ")");
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
