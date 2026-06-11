using UnityEngine;
using System.Collections.Generic;

/// IA por waypoints: control de velocidad en curvas + recuperación de choques.
/// Port de ai_driver.gd.
public class AIDriver : MonoBehaviour
{
    public float speedFactor = 1f;
    public int lookahead = 1;
    public bool isLinearStage;

    const float SpeedStraight = 26f;
    const float SpeedCorner = 6.5f;

    List<Vector3> _waypoints = new();
    CarController _car;
    int _currentWp;
    bool _finished;
    float _stuckTimer;
    float _reversing;

    void Awake() => _car = GetComponent<CarController>();

    public void SetWaypoints(List<Vector3> wps) { _waypoints = wps; _currentWp = 0; }

    void FixedUpdate()
    {
        if (_waypoints.Count == 0 || _finished) { _car.SetAIInput(0, 0, 0); return; }

        if (_reversing > 0f)
        {
            _reversing -= Time.fixedDeltaTime;
            _car.SetAIInput(0f, -CalcSteer() * 0.7f, 0f);
            _car.Body.AddForce(-transform.forward * 7000f);
            return;
        }

        DetectStuck();
        AdvanceWaypoint();

        float steer = CalcSteer();
        float speed = _car.Body.linearVelocity.magnitude;
        float targetSpeed = Mathf.Lerp(SpeedStraight, SpeedCorner, Mathf.Abs(steer)) * speedFactor;

        float throttle = speed < targetSpeed ? 1f : 0f;
        float brake = speed > targetSpeed * 1.1f ? 0.8f : 0f;
        _car.SetAIInput(throttle, steer, brake);
    }

    void DetectStuck()
    {
        if (!_car.controlsEnabled) { _stuckTimer = 0f; return; }
        if (_car.Body.linearVelocity.magnitude < 1f)
        {
            _stuckTimer += Time.fixedDeltaTime;
            if (_stuckTimer > 1.5f) { _reversing = 1.5f; _stuckTimer = 0f; }
        }
        else _stuckTimer = 0f;
    }

    void AdvanceWaypoint()
    {
        if (_currentWp >= _waypoints.Count) return;
        if (Vector3.Distance(transform.position, _waypoints[_currentWp]) < 8f)
        {
            _currentWp++;
            if (_currentWp >= _waypoints.Count)
            {
                if (isLinearStage) _finished = true;
                else _currentWp = 0;
            }
        }
    }

    float CalcSteer()
    {
        if (_currentWp >= _waypoints.Count) return 0f;
        int target = isLinearStage
            ? Mathf.Min(_currentWp + lookahead, _waypoints.Count - 1)
            : (_currentWp + lookahead) % _waypoints.Count;

        Vector3 local = transform.InverseTransformPoint(_waypoints[target]);
        float steer = local.x / (Mathf.Abs(local.x) + Mathf.Abs(local.z) + 0.001f);
        // Target atrás (z negativo en Unity = atrás): girar a fondo
        if (local.z < 0f)
            steer = Mathf.Abs(steer) > 0.05f ? Mathf.Sign(steer) : 1f;
        return Mathf.Clamp(steer * 2f, -1f, 1f);
    }
}
