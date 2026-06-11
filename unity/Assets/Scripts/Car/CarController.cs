using UnityEngine;

/// Controlador del auto: orquesta las 4 ruedas, input, drag y drift.
/// Port de car_controller.gd. En Unity +Y rotation = giro a la derecha,
/// así que NO hace falta invertir el steer (bug histórico de la versión Godot).
[RequireComponent(typeof(Rigidbody))]
public class CarController : MonoBehaviour
{
    [Header("Motor")]
    public float engineForce = 9000f;
    public float dragLinear = 0.35f;    // Terminal ~150 km/h
    public float dragAngular = 2.2f;

    [Header("Frenos")]
    public float brakeForce = 14000f;
    public float handbrakeGrip = 0.25f;
    public float handbrakeKick = 9000f; // El "flick" para iniciar drift

    [Header("Dirección")]
    public float maxSteerAngle = 32f;
    public float steerSpeed = 6f;

    [Header("Grip (núcleo del drift)")]
    public float frontGrip = 4f;
    public float rearGrip = 1.8f;

    [Header("Jugador")]
    public int playerIndex;             // 0=P1, 1=P2, -1=IA
    public bool controlsEnabled = true;

    [HideInInspector] public float inputThrottle;
    [HideInInspector] public float inputSteer;
    [HideInInspector] public float inputBrake;
    [HideInInspector] public bool inputHandbrake;

    public Rigidbody Body { get; private set; }
    public Wheel[] Wheels { get; private set; }

    Wheel _fl, _fr, _rl, _rr;
    float _currentSteer;

    void Awake()
    {
        Body = GetComponent<Rigidbody>();
        Body.mass = 1200f;
        Body.centerOfMass = new Vector3(0, 0.1f, 0);

        Wheels = GetComponentsInChildren<Wheel>();
        foreach (var w in Wheels)
        {
            w.massShare = Body.mass / 4f;
            bool front = w.transform.localPosition.z > 0;
            w.isSteering = front;
            w.isDriven = !front;
            w.grip = front ? frontGrip : rearGrip;
            if (front) { if (_fl == null) _fl = w; else _fr = w; }
            else { if (_rl == null) _rl = w; else _rr = w; }
        }
    }

    void FixedUpdate()
    {
        ReadPlayerInput();
        if (!controlsEnabled)
        {
            inputThrottle = 0f; inputBrake = 1f;
            inputSteer = 0f; inputHandbrake = false;
        }

        UpdateSteering();
        ApplyForces();
        ApplyDrag();
    }

    void ReadPlayerInput()
    {
        if (playerIndex < 0) return;  // IA setea input via SetAIInput

        if (playerIndex == 0)
        {
            inputThrottle = Input.GetKey(KeyCode.W) ? 1f : 0f;
            inputBrake = Input.GetKey(KeyCode.S) ? 1f : 0f;
            inputSteer = (Input.GetKey(KeyCode.D) ? 1f : 0f) - (Input.GetKey(KeyCode.A) ? 1f : 0f);
            inputHandbrake = Input.GetKey(KeyCode.Space);
        }
        else
        {
            inputThrottle = Input.GetKey(KeyCode.UpArrow) ? 1f : 0f;
            inputBrake = Input.GetKey(KeyCode.DownArrow) ? 1f : 0f;
            inputSteer = (Input.GetKey(KeyCode.RightArrow) ? 1f : 0f) - (Input.GetKey(KeyCode.LeftArrow) ? 1f : 0f);
            inputHandbrake = Input.GetKey(KeyCode.Return);
        }
    }

    void UpdateSteering()
    {
        _currentSteer = Mathf.Lerp(_currentSteer, inputSteer, steerSpeed * Time.fixedDeltaTime);
        var rot = Quaternion.Euler(0, maxSteerAngle * _currentSteer, 0);
        if (_fl) _fl.transform.localRotation = rot;
        if (_fr) _fr.transform.localRotation = rot;
    }

    void ApplyForces()
    {
        float effectiveRearGrip = inputHandbrake ? handbrakeGrip : rearGrip;
        if (_rl) _rl.grip = effectiveRearGrip;
        if (_rr) _rr.grip = effectiveRearGrip;

        // Kick de rotación con freno de mano (inicia el drift)
        if (inputHandbrake && Body.linearVelocity.magnitude > 5f && Mathf.Abs(inputSteer) > 0.1f)
            Body.AddTorque(Vector3.up * inputSteer * handbrakeKick);

        float dt = Time.fixedDeltaTime;
        foreach (var w in Wheels)
        {
            w.UpdateRaycast();
            Body.AddForceAtPosition(w.GetSuspensionForce(dt), w.transform.position);
            Body.AddForceAtPosition(w.GetLateralForce(Body.linearVelocity), w.transform.position);

            float throttle = inputThrottle * engineForce * 0.5f;
            float brake = inputBrake * brakeForce * 0.25f;
            Body.AddForceAtPosition(
                w.GetLongitudinalForce(throttle, brake, inputHandbrake, Body.linearVelocity),
                w.transform.position);
        }
    }

    void ApplyDrag()
    {
        Body.linearVelocity -= Body.linearVelocity * dragLinear * Time.fixedDeltaTime;
        Body.angularVelocity -= Body.angularVelocity * dragAngular * Time.fixedDeltaTime;
    }

    // ── API para la IA ──
    public void SetAIInput(float throttle, float steer, float brake, bool handbrake = false)
    {
        inputThrottle = Mathf.Clamp01(throttle);
        inputSteer = Mathf.Clamp(steer, -1f, 1f);
        inputBrake = Mathf.Clamp01(brake);
        inputHandbrake = handbrake;
    }

    public float SpeedKmh => Body.linearVelocity.magnitude * 3.6f;
}
