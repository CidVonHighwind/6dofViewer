using System.Collections.Generic;
using UnityEngine;
using UnityEngine.XR;

public class CameraPositionSetter : MonoBehaviour
{
    private bool resetView;

    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
        List<XRInputSubsystem> subsystems = new List<XRInputSubsystem>();
        SubsystemManager.GetSubsystems(subsystems);

        foreach (var subsystem in subsystems)
        {
            subsystem.trackingOriginUpdated += OnTrackingOriginUpdated;
        }
    }
    
    void OnTrackingOriginUpdated(XRInputSubsystem subsystem)
    {
        resetView = true;
    }

    // Update is called once per frame
    void Update()
    {
        if (resetView)
        {
            // move the camera infront of the image
            Debug.Log("Reset origin: " + Camera.main.transform.position);
            transform.SetPositionAndRotation(-Camera.main.transform.position + transform.position, Quaternion.identity);
            resetView = false;
        }
    }
}
