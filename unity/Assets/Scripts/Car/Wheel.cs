using UnityEngine;

/// Rueda raycast: suspensión resorte+amortiguador, grip lateral escalado por
/// masa, fuerza longitudinal con freno que se opone al movimiento.
/// Port de wheel.gd (Godot) con todos los fixes ya aplicados.
public class Wheel : MonoBehaviour
{
    [Header("Suspensión")]
    public float restLength = 0.35f;
    public float stiffness = 20000f;   // Debe sostener ~300kg por rueda
    public float damping = 2000f;
    public float radius = 0.28f;

    [Header("Comportamiento")]
    public float grip = 4f;            // Bajo en traseras = drift
    public bool isDriven;
    public bool isSteering;

    [HideInInspector] public float massShare = 300f;  // mass/4, lo setea CarController
    [HideInInspector] public bool isGrounded;

    float _prevCompression;
    Transform _visual;
    RaycastHit _hit;

    void Awake()
    {
        if (transform.childCount > 0)
            _visual = transform.GetChild(0);
    }

    public void UpdateRaycast()
    {
        float rayLength = restLength + radius;
        isGrounded = Physics.Raycast(transform.position, -transform.up, out _hit, rayLength);
    }

    public Vector3 GetSuspensionForce(float dt)
    {
        if (!isGrounded) { _prevCompression = 0f; return Vector3.zero; }

        float compression = (restLength + radius) - _hit.distance;
        compression = Mathf.Clamp(compression, 0f, restLength);

        float compressionVel = (compression - _prevCompression) / dt;
        _prevCompression = compression;

        float force = compression * stiffness + compressionVel * damping;
        return transform.up * Mathf.Max(force, 0f);
    }

    /// Grip lateral: tasa de decaimiento (1/s) independiente de la masa.
    public Vector3 GetLateralForce(Vector3 carVelocity)
    {
        if (!isGrounded) return Vector3.zero;
        float lateralVel = Vector3.Dot(carVelocity, transform.right);
        return -transform.right * lateralVel * grip * massShare;
    }

    /// Motor + freno. El freno se opone a la dirección de movimiento.
    public Vector3 GetLongitudinalForce(float throttleForce, float brakeForce,
                                        bool handbrake, Vector3 carVelocity)
    {
        if (!isGrounded) return Vector3.zero;

        Vector3 force = Vector3.zero;
        Vector3 fwd = transform.forward;

        if (isDriven) force += fwd * throttleForce;

        if (brakeForce > 0f)
        {
            float fwdSpeed = Vector3.Dot(carVelocity, fwd);
            if (Mathf.Abs(fwdSpeed) > 0.3f)
                force -= fwd * Mathf.Sign(fwdSpeed) * brakeForce;
        }

        if (handbrake && !isSteering) force = Vector3.zero;
        return force;
    }

    void FixedUpdate()
    {
        // La rueda visual sigue la suspensión
        if (_visual == null) return;
        float targetY = isGrounded ? -(_hit.distance - radius) : -restLength;
        var p = _visual.localPosition;
        p.y = Mathf.Lerp(p.y, targetY, 0.5f);
        _visual.localPosition = p;
    }
}
