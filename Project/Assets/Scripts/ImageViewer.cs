using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using UnityEngine;
using UnityEngine.XR;

public class Image_Viewer : MonoBehaviour
{
    public int CurrentIndex = 1;

    public Texture ColorTexture;
    public Texture InfillTexture;
    public Texture DepthTexture;

    private List<Texture> colorImages;
    private List<Texture> infillImages;
    private List<Texture> depthImages;

    private List<InputDevice> inputDevices = new List<InputDevice>();
    private InputDevice rightController;
    private Vector2 lastStickInput;

    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
        colorImages = Resources.LoadAll<Texture>("90 deg/color").OrderBy(img => ExtractNumber(img.name)).ToList();
        infillImages = Resources.LoadAll<Texture>("90 deg/infill").ToList();
        depthImages = Resources.LoadAll<Texture>("90 deg/depths").ToList();

        foreach (Texture tex in colorImages)
            Debug.Log("colorImages: " + tex.name);
        foreach (Texture tex in infillImages)
            Debug.Log("infillImages: " + tex.name);

        SetImage(CurrentIndex);
    }

    int ExtractNumber(string name)
    {
        Match match = Regex.Match(name, @"\d+");
        return match.Success ? int.Parse(match.Value) : 0;
    }

    void InitRightController()
    {
        InputDevices.GetDevicesWithCharacteristics(InputDeviceCharacteristics.Controller | InputDeviceCharacteristics.Right, inputDevices);

        if (inputDevices.Count > 0)
            rightController = inputDevices[0];
    }

    void OffsetImage(int dir)
    {
        // move left/righ through the list of all images
        var newIndex = CurrentIndex + dir;
        if (newIndex >= colorImages.Count)
            newIndex = 0;
        else if (newIndex < 0)
            newIndex = colorImages.Count - 1;

        SetImage(newIndex);
    }

    void SetImage(int index)
    {
        CurrentIndex = index;
        var imageName = colorImages[CurrentIndex].name;

        foreach (Texture tex in colorImages)
            if (tex.name == imageName)
            {
                ColorTexture = tex;
            }
        foreach (Texture tex in infillImages)
            if (tex.name == imageName)
            {
                InfillTexture = tex;
            }
        foreach (Texture tex in depthImages)
            if (tex.name == imageName)
            {
                DepthTexture = tex;
            }
    }

    // Update is called once per frame
    void Update()
    {
        if (!rightController.isValid)
            InitRightController();
        else
        {
            if (rightController.TryGetFeatureValue(CommonUsages.primary2DAxis, out Vector2 stickInput))
            {
                if (stickInput.x < -0.8 && lastStickInput.x >= -0.8)
                    OffsetImage(-1);
                if (stickInput.x > 0.8 && lastStickInput.x <= 0.8)
                    OffsetImage(1);

                lastStickInput = stickInput;
            }
        }

        if (Input.GetKeyDown(KeyCode.LeftArrow))
            OffsetImage(-1);
        if (Input.GetKeyDown(KeyCode.RightArrow))
            OffsetImage(1);
    }
}
