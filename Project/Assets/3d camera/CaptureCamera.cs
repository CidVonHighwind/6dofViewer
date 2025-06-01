using System.IO;
using UnityEngine;

public class CameraCapture : MonoBehaviour
{
    public int fileCounter;
    public KeyCode screenshotKey;

    public Camera Camera;
    public Camera Depth;

    public float IPD = 0.03f;

    void Start()
    {
        Directory.CreateDirectory(Path.GetDirectoryName(Application.dataPath + "/3D Camera/Captures/color"));
        Directory.CreateDirectory(Path.GetDirectoryName(Application.dataPath + "/3D Camera/Captures/depth"));
    }

    private void LateUpdate()
    {
        if (Input.GetKeyDown(screenshotKey))
            CaptureImage();
    }

    public void CaptureImage()
    {
        var fileName = fileCounter + " 90 90 0 0";
        // capture color
        CaptureStereo(Camera, "color/" + fileName, RenderTextureFormat.ARGB32, TextureFormat.ARGB32);

        // capture depth to R16
        CaptureStereo(Depth, "depth/" + fileName, RenderTextureFormat.R16, TextureFormat.R16);

        Debug.Log("captured: " + fileName);

        fileCounter++;
    }

    public void CaptureStereo(Camera camera, string path, RenderTextureFormat rtFormat, TextureFormat textureFormat)
    {
        // caputre offset images
        camera.transform.position = transform.position - transform.right * IPD;
        var colorL = Capture(camera, "l", rtFormat, textureFormat);
        camera.transform.position = transform.position + transform.right * IPD;
        var colorR = Capture(camera, "r", rtFormat, textureFormat);

        // merge images
        var combined = new Texture2D(camera.targetTexture.width * 2, camera.targetTexture.height, textureFormat, false, true);
        combined.SetPixels(0, 0, camera.targetTexture.width, camera.targetTexture.height, colorL);
        combined.SetPixels(camera.targetTexture.width, 0, camera.targetTexture.width, camera.targetTexture.height, colorR);
        combined.Apply();

        //if (rtFormat == RenderTextureFormat.ARGB32)
        //{
            byte[] combinedBytes = combined.EncodeToPNG();
            File.WriteAllBytes(Application.dataPath + "/3D Camera/Captures/" + path + ".png", combinedBytes);
        //}
        //else
        //{
        //    byte[] combinedBytes = combined.EncodeToEXR(Texture2D.EXRFlags.OutputAsFloat);
        //    File.WriteAllBytes(Application.dataPath + "/3D Camera/Captures/" + path + ".exr", combinedBytes);
        //}
    }

    public Color[] Capture(Camera camera, string fileName, RenderTextureFormat rtFormat, TextureFormat textureFormat)
    {
        if (camera == null)
            return null;

        RenderTexture tempRT = new RenderTexture(camera.targetTexture.width, camera.targetTexture.height, 16, rtFormat);
        RenderTexture.active = tempRT;

        camera.targetTexture = tempRT;
        camera.Render();

        Texture2D image = new Texture2D(camera.targetTexture.width, camera.targetTexture.height, textureFormat, false, true);
        image.ReadPixels(new Rect(0, 0, camera.targetTexture.width, camera.targetTexture.height), 0, 0);
        image.Apply();

        return image.GetPixels();
    }
}