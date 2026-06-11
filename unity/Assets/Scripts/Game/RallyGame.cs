using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using System.Linq;

/// Orquestador principal — TODO el juego se construye por código desde acá.
/// Para correr: escena vacía + un GameObject con este componente. Play.
public class RallyGame : MonoBehaviour
{
    enum State { Menu, Countdown, Racing, Results }

    static readonly Color[] CarColors =
    {
        new(0.95f, 0.8f, 0.15f), new(0.3f, 0.7f, 0.95f), new(0.85f, 0.25f, 0.2f),
        new(0.9f, 0.9f, 0.92f), new(0.25f, 0.6f, 0.3f), new(0.6f, 0.35f, 0.75f),
    };

    State _state = State.Menu;
    int _stageIndex;
    int _playerCount = 1;
    int _aiCount = 4;
    float _aiSpeedMin = 0.82f, _aiSpeedMax = 1.02f;
    int _difficultyIndex = 1;
    static readonly string[] DiffNames = { "Easy", "Normal", "Hard" };
    static readonly float[][] DiffRanges = { new[] {0.65f, 0.85f}, new[] {0.82f, 1.02f}, new[] {0.95f, 1.12f} };

    GameObject _stageRoot;
    RaceManager _race;
    List<CarController> _cars = new();
    Camera _cam1, _cam2;
    string _countdownText = "";
    List<RaceManager.Result> _results;
    Material _baseMat;

    void Awake()
    {
        Application.targetFrameRate = 60;
        // Elegir shader según el pipeline ACTIVO (URP/Lit sin URP activo = magenta)
        bool urpActive = UnityEngine.Rendering.GraphicsSettings.currentRenderPipeline != null;
        var shader = urpActive
            ? Shader.Find("Universal Render Pipeline/Lit")
            : Shader.Find("Standard");
        _baseMat = new Material(shader);
    }

    // ── CONSTRUCCIÓN DEL STAGE ───────────────────────────────────────────────

    void BuildStage(Stages.StageDef def)
    {
        _stageRoot = new GameObject("Stage");

        // Piso
        var ground = GameObject.CreatePrimitive(PrimitiveType.Cube);
        ground.name = "Ground";
        ground.transform.SetParent(_stageRoot.transform);
        ground.transform.position = new Vector3(10, -0.15f, 0);
        ground.transform.localScale = new Vector3(260, 0.3f, 260);
        ground.GetComponent<MeshRenderer>().material = new Material(_baseMat) { color = def.grassColor };

        // Pista
        var wps = def.waypoints.ToList();
        var track = TrackBuilder.Build(wps, def.isCircuit, def.roadWidth, def.roadColor, _baseMat);
        track.transform.SetParent(_stageRoot.transform);

        // Props alrededor (random determinístico por stage)
        var rng = new System.Random(_stageIndex * 31 + 7);
        for (int i = 0; i < 26; i++)
        {
            float ang = (float)rng.NextDouble() * Mathf.PI * 2f;
            float dist = 70f + (float)rng.NextDouble() * 60f;
            var pos = new Vector3(Mathf.Cos(ang) * dist + 10f, 0, Mathf.Sin(ang) * dist);
            string path = i % 2 == 0 ? def.propA : def.propB;
            var prefab = Resources.Load<GameObject>(path);
            if (prefab == null) continue;
            var prop = Instantiate(prefab, _stageRoot.transform);
            prop.transform.position = pos;
            prop.transform.rotation = Quaternion.Euler(0, (float)rng.NextDouble() * 360f, 0);
            float s = 0.8f + (float)rng.NextDouble() * 0.8f;
            prop.transform.localScale = Vector3.one * s;
        }

        // Sol + ambiente
        var sun = new GameObject("Sun").AddComponent<Light>();
        sun.transform.SetParent(_stageRoot.transform);
        sun.type = LightType.Directional;
        sun.transform.rotation = Quaternion.Euler(45, -30, 0);
        sun.intensity = 1.3f;
        sun.shadows = LightShadows.Soft;
        sun.color = new Color(1f, 0.95f, 0.85f);
        RenderSettings.ambientLight = new Color(0.55f, 0.57f, 0.62f);
        var cam = Camera.main;
        RenderSettings.fog = true;
        RenderSettings.fogColor = def.skyColor;
        RenderSettings.fogMode = FogMode.Exponential;
        RenderSettings.fogDensity = 0.0035f;

        // Race manager
        _race = _stageRoot.AddComponent<RaceManager>();
        _race.totalLaps = def.laps;
        _race.isCircuit = def.isCircuit;
        _race.playerCount = _playerCount;
        _race.RaceFinished += OnRaceFinished;
    }

    // ── SPAWN DE AUTOS Y CÁMARAS ─────────────────────────────────────────────

    void SpawnCars(Stages.StageDef def)
    {
        _cars.Clear();
        var wps = def.waypoints.ToList();

        Vector3 startPos = wps[0];
        Vector3 raceDir = (wps[1] - wps[0]); raceDir.y = 0; raceDir.Normalize();
        Vector3 raceRight = Vector3.Cross(Vector3.up, raceDir);
        Vector3 backDir = -raceDir;
        if (def.isCircuit)
        {
            backDir = wps[^1] - wps[0]; backDir.y = 0; backDir.Normalize();
        }
        var gridRot = Quaternion.LookRotation(raceDir);

        int total = _playerCount + _aiCount;
        for (int i = 0; i < total; i++)
        {
            int col = i % 2, row = i / 2;
            Vector3 pos = startPos + backDir * (4f + row * 6.5f)
                        + raceRight * ((col - 0.5f) * 3.6f) + Vector3.up * 0.6f;

            var car = CarFactory.Create(i % 6, CarColors[i % CarColors.Length], pos, gridRot);
            car.transform.SetParent(_stageRoot.transform);
            car.controlsEnabled = false;

            if (i < _playerCount)
            {
                car.playerIndex = i;
            }
            else
            {
                car.playerIndex = -1;
                var ai = car.gameObject.AddComponent<AIDriver>();
                ai.speedFactor = Random.Range(_aiSpeedMin, _aiSpeedMax);
                ai.isLinearStage = !def.isCircuit;
                ai.SetWaypoints(wps);
            }
            _cars.Add(car);
        }

        // Cámaras (split-screen por viewport rect — trivial en Unity)
        _cam1 = CreateCamera("Cam_P1", def.skyColor);
        if (_playerCount > 1)
        {
            _cam1.rect = new Rect(0, 0, 0.5f, 1);
            _cam2 = CreateCamera("Cam_P2", def.skyColor);
            _cam2.rect = new Rect(0.5f, 0, 0.5f, 1);
        }
    }

    Camera CreateCamera(string name, Color sky)
    {
        var go = new GameObject(name);
        go.transform.SetParent(_stageRoot.transform);
        var cam = go.AddComponent<Camera>();
        cam.fieldOfView = 65;
        cam.clearFlags = CameraClearFlags.SolidColor;
        cam.backgroundColor = sky;
        go.AddComponent<AudioListener>().enabled = name == "Cam_P1";
        return cam;
    }

    void LateUpdate()
    {
        if (_state == State.Menu) return;
        FollowCam(_cam1, 0);
        if (_cam2 != null) FollowCam(_cam2, 1);
    }

    void FollowCam(Camera cam, int carIdx)
    {
        if (cam == null || carIdx >= _cars.Count || _cars[carIdx] == null) return;
        var car = _cars[carIdx].transform;
        // Vista alta y atrás estilo Art of Rally (atrás = -forward del auto)
        Vector3 target = car.position - car.forward * 9f + Vector3.up * 4.5f;
        cam.transform.position = Vector3.Lerp(cam.transform.position, target, 8f * Time.deltaTime);
        cam.transform.LookAt(car.position + Vector3.up * 0.5f);
    }

    // ── FLUJO DE JUEGO ───────────────────────────────────────────────────────

    void StartGame()
    {
        var def = Stages.All[_stageIndex];
        var diff = DiffRanges[_difficultyIndex];
        _aiSpeedMin = diff[0]; _aiSpeedMax = diff[1];

        BuildStage(def);
        SpawnCars(def);
        StartCoroutine(CountdownRoutine(def));
    }

    IEnumerator CountdownRoutine(Stages.StageDef def)
    {
        _state = State.Countdown;
        foreach (var s in new[] { "3", "2", "1" })
        {
            _countdownText = s;
            yield return new WaitForSeconds(1f);
        }
        _countdownText = "GO!";
        foreach (var c in _cars) c.controlsEnabled = true;
        _race.StartRace(_cars, def.waypoints.ToList());
        _state = State.Racing;
        yield return new WaitForSeconds(0.8f);
        _countdownText = "";
    }

    void OnRaceFinished(List<RaceManager.Result> results)
    {
        _results = results;
        _state = State.Results;
        Time.timeScale = 0f;
    }

    void BackToMenu()
    {
        Time.timeScale = 1f;
        if (_stageRoot != null) Destroy(_stageRoot);
        _cars.Clear();
        _state = State.Menu;
    }

    void Update()
    {
        if (_state == State.Racing && Input.GetKeyDown(KeyCode.Escape))
            BackToMenu();
    }

    // ── UI (OnGUI: cero setup de escena) ─────────────────────────────────────

    void OnGUI()
    {
        GUI.skin.label.fontSize = 18;
        GUI.skin.button.fontSize = 18;

        switch (_state)
        {
            case State.Menu: DrawMenu(); break;
            case State.Countdown:
            case State.Racing: DrawHUD(); DrawCountdown(); break;
            case State.Results: DrawResults(); break;
        }
    }

    void DrawMenu()
    {
        float w = 380, x = (Screen.width - w) / 2, y = Screen.height * 0.18f;

        var title = new GUIStyle(GUI.skin.label) { fontSize = 56, alignment = TextAnchor.MiddleCenter };
        title.normal.textColor = new Color(0.95f, 0.85f, 0.2f);
        GUI.Label(new Rect(x, y, w, 70), "RALLY", title);
        y += 90;

        var def = Stages.All[_stageIndex];
        GUI.Label(new Rect(x, y, w, 28), $"Stage: {def.name}");
        if (GUI.Button(new Rect(x + w - 80, y, 35, 28), "◀")) _stageIndex = (_stageIndex + Stages.All.Length - 1) % Stages.All.Length;
        if (GUI.Button(new Rect(x + w - 40, y, 35, 28), "▶")) _stageIndex = (_stageIndex + 1) % Stages.All.Length;
        y += 38;

        GUI.Label(new Rect(x, y, w, 28), $"AI: {DiffNames[_difficultyIndex]}");
        if (GUI.Button(new Rect(x + w - 80, y, 35, 28), "◀")) _difficultyIndex = (_difficultyIndex + 2) % 3;
        if (GUI.Button(new Rect(x + w - 40, y, 35, 28), "▶")) _difficultyIndex = (_difficultyIndex + 1) % 3;
        y += 50;

        if (GUI.Button(new Rect(x, y, w, 44), "1 Player")) { _playerCount = 1; _aiCount = 4; StartGame(); }
        y += 52;
        if (GUI.Button(new Rect(x, y, w, 44), "2 Players — Split Screen")) { _playerCount = 2; _aiCount = 4; StartGame(); }
        y += 52;
        if (GUI.Button(new Rect(x, y, w, 44), "Time Trial")) { _playerCount = 1; _aiCount = 0; StartGame(); }
        y += 52;
        if (GUI.Button(new Rect(x, y, w, 36), "Quit")) Application.Quit();
    }

    void DrawHUD()
    {
        if (_race == null || _race.Cars.Count == 0) return;
        for (int p = 0; p < _playerCount && p < _race.Data.Count; p++)
        {
            float x = p == 0 ? 12 : Screen.width - 192;
            var d = _race.Data[p];
            GUI.Box(new Rect(x, 10, 180, 100), "");
            GUI.Label(new Rect(x + 10, 14, 170, 30), $"P{d.position}/{_race.Cars.Count}");
            GUI.Label(new Rect(x + 10, 40, 170, 26), $"{(int)_cars[p].SpeedKmh} km/h");
            string lap = _race.isCircuit ? $"Lap {Mathf.Min(d.laps + 1, _race.totalLaps)}/{_race.totalLaps}" : "Stage";
            GUI.Label(new Rect(x + 10, 62, 170, 26), lap);
            GUI.Label(new Rect(x + 10, 82, 170, 26), FormatTime(_race.RaceTime));
        }
    }

    void DrawCountdown()
    {
        if (string.IsNullOrEmpty(_countdownText)) return;
        var style = new GUIStyle(GUI.skin.label)
        { fontSize = 120, alignment = TextAnchor.MiddleCenter, fontStyle = FontStyle.Bold };
        style.normal.textColor = _countdownText == "GO!" ? Color.green : Color.yellow;
        GUI.Label(new Rect(0, 0, Screen.width, Screen.height), _countdownText, style);
    }

    void DrawResults()
    {
        float w = 420, h = 90 + _results.Count * 32 + 70;
        float x = (Screen.width - w) / 2, y = (Screen.height - h) / 2;
        GUI.Box(new Rect(x, y, w, h), "");

        var title = new GUIStyle(GUI.skin.label) { fontSize = 34, alignment = TextAnchor.MiddleCenter };
        title.normal.textColor = new Color(0.95f, 0.85f, 0.2f);
        GUI.Label(new Rect(x, y + 10, w, 44), "RESULTS", title);

        float ry = y + 64;
        foreach (var r in _results)
        {
            string who = r.carIndex < _playerCount
                ? $"Player {r.carIndex + 1}" : $"CPU {r.carIndex - _playerCount + 1}";
            string time = r.finishTime > 0 ? FormatTime(r.finishTime) : "DNF";
            GUI.Label(new Rect(x + 24, ry, w - 48, 28),
                $"P{r.position}  {who} · {CarFactory.StyleNames[r.carIndex % 6]}   {time}");
            ry += 32;
        }

        if (GUI.Button(new Rect(x + 20, y + h - 56, (w - 56) / 2, 40), "Retry"))
        { BackToMenu(); StartGame(); }
        if (GUI.Button(new Rect(x + w / 2 + 8, y + h - 56, (w - 56) / 2, 40), "Menu"))
            BackToMenu();
    }

    static string FormatTime(float t) =>
        $"{(int)t / 60}:{(int)t % 60:00}.{(int)(t % 1f * 100):00}";
}
