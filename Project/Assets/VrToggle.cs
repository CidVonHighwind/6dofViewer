using System.Collections.Generic;
using UnityEngine;
using UnityEngine.XR;

// toggle vr mode after detecting a vr headset
public class VrToggle : MonoBehaviour
{
    public GameObject NormalCamera;
    public GameObject VrCamera;

    void Start()
    {

    }

    public static bool IsVRHeadsetConnected()
    {
        List<XRDisplaySubsystem> displays = new List<XRDisplaySubsystem>();
        SubsystemManager.GetSubsystems(displays);

        foreach (var display in displays)
        {
            if (display.running)
            {
                return true;
            }
        }

        return false;
    }

    void Update()
    {
        if (NormalCamera.activeSelf)
        {
            if (IsVRHeadsetConnected())
            {
                ToggleMode();
            }
        }
    }

    void ToggleMode()
    {
        NormalCamera.SetActive(false);
        VrCamera.SetActive(true);
    }
}
