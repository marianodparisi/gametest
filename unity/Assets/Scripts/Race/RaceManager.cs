using UnityEngine;
using System;
using System.Collections.Generic;
using System.Linq;

/// Posiciones en tiempo real, vueltas, tiempos por vuelta y fin de carrera.
/// La carrera termina cuando llegan los jugadores humanos (IA rezagada = DNF).
public class RaceManager : MonoBehaviour
{
    public int totalLaps = 3;
    public bool isCircuit = true;
    public int playerCount = 1;

    public event Action<List<Result>> RaceFinished;

    public class CarData
    {
        public int laps, checkpoint, position;
        public float distanceToNext, finishTime = -1f, lapStart, lastLap = -1f, bestLap = -1f;
        public bool finished;
    }

    public struct Result { public int carIndex, position; public float finishTime; }

    public List<CarController> Cars { get; } = new();
    public List<CarData> Data { get; } = new();
    public float RaceTime { get; private set; }

    List<Vector3> _waypoints = new();
    bool _running;
    int _finishedCount;

    public void StartRace(List<CarController> cars, List<Vector3> waypoints)
    {
        Cars.Clear(); Data.Clear();
        Cars.AddRange(cars);
        foreach (var _ in cars) Data.Add(new CarData());
        _waypoints = waypoints;
        RaceTime = 0f;
        _running = true;
    }

    void FixedUpdate()
    {
        if (!_running) return;
        RaceTime += Time.fixedDeltaTime;
        UpdateCheckpoints();
        UpdatePositions();
    }

    void UpdateCheckpoints()
    {
        if (_waypoints.Count == 0) return;
        for (int i = 0; i < Cars.Count; i++)
        {
            var d = Data[i];
            if (d.finished) continue;

            Vector3 next = _waypoints[d.checkpoint % _waypoints.Count];
            d.distanceToNext = Vector3.Distance(Cars[i].transform.position, next);

            if (d.distanceToNext < 7f)
            {
                d.checkpoint++;
                if (d.checkpoint % _waypoints.Count == 0)
                {
                    d.laps++;
                    float lapTime = RaceTime - d.lapStart;
                    d.lastLap = lapTime;
                    d.lapStart = RaceTime;
                    if (d.bestLap < 0 || lapTime < d.bestLap) d.bestLap = lapTime;

                    if (isCircuit && d.laps >= totalLaps) FinishCar(i);
                    else if (!isCircuit && d.checkpoint >= _waypoints.Count) FinishCar(i);
                }
            }
        }
    }

    void FinishCar(int index)
    {
        Data[index].finished = true;
        Data[index].finishTime = RaceTime;
        _finishedCount++;

        bool playersDone = true;
        for (int i = 0; i < Mathf.Min(playerCount, Cars.Count); i++)
            if (!Data[i].finished) { playersDone = false; break; }

        if (playersDone || _finishedCount >= Cars.Count)
        {
            _running = false;
            RaceFinished?.Invoke(BuildResults());
        }
    }

    void UpdatePositions()
    {
        var order = Enumerable.Range(0, Cars.Count).OrderByDescending(i => Data[i].finished)
            .ThenByDescending(i => Data[i].laps)
            .ThenByDescending(i => Data[i].checkpoint)
            .ThenBy(i => Data[i].distanceToNext).ToList();
        for (int pos = 0; pos < order.Count; pos++)
            Data[order[pos]].position = pos + 1;
    }

    List<Result> BuildResults() =>
        Enumerable.Range(0, Cars.Count)
            .Select(i => new Result { carIndex = i, position = Data[i].position, finishTime = Data[i].finishTime })
            .OrderBy(r => r.position).ToList();
}
