using System;
using System.Collections;
using System.IO;
using UnityEngine;

public class CameraCapture : MonoBehaviour
{
    public int fileCounter;
    public KeyCode screenshotKey;
    public KeyCode videoKey;

    public Camera Camera;
    public Camera Depth;

    public float IPD = 0.03f;

    private RenderTexture frameColorRT;
    private Texture2D frameColorTexture;

    private RenderTexture frameDepthRT;
    private Texture2D frameDepthTexture;

    private Color[] colorLeft;
    private Color[] colorRight;

    private int FrameCounter = 0;
    private int VideoFrameCounter = 300;
    private bool VideoRecording = true;

    private string VideoRecordingPath;

    void Start()
    {
        Time.captureFramerate = 60;

        VideoRecordingPath = "C:\\Users\\Patrick\\Desktop\\video test\\";
        Directory.CreateDirectory(VideoRecordingPath + "\\color");
        Directory.CreateDirectory(VideoRecordingPath + "\\depth");

        Directory.CreateDirectory(Path.GetDirectoryName(Application.dataPath + "/3D Camera/Captures/color"));
        Directory.CreateDirectory(Path.GetDirectoryName(Application.dataPath + "/3D Camera/Captures/depth"));

        frameColorRT = new RenderTexture(Camera.targetTexture.width, Camera.targetTexture.height, 16, RenderTextureFormat.ARGB32);
        frameColorTexture = new Texture2D(Camera.targetTexture.width, Camera.targetTexture.height, TextureFormat.ARGB32, false, true);

        frameDepthRT = new RenderTexture(Camera.targetTexture.width, Camera.targetTexture.height, 16, RenderTextureFormat.R16);
        frameDepthTexture = new Texture2D(Camera.targetTexture.width, Camera.targetTexture.height, TextureFormat.R16, false, true);

        colorLeft = new Color[Camera.targetTexture.width * Camera.targetTexture.height];
        colorRight = new Color[Camera.targetTexture.width * Camera.targetTexture.height];
    }

    private void LateUpdate()
    {
        if (Input.GetKeyDown(screenshotKey))
            CaptureImage();
        if (Input.GetKeyDown(videoKey))
            CaptureVideo();

        if (VideoRecording)
        {
            CaptureFrame(Camera, VideoRecordingPath + "color\\frame_" + FrameCounter.ToString("D04") + ".png", frameColorRT, frameColorTexture, TextureFormat.ARGB32);
            CaptureFrame(Depth, VideoRecordingPath + "depth\\frame_" + FrameCounter.ToString("D04") + ".png", frameDepthRT, frameDepthTexture, TextureFormat.R16);

            FrameCounter++;
            if (FrameCounter > VideoFrameCounter)
                VideoRecording = false;
        }
    }

    public void CaptureVideo()
    {
        // start recoding a video
        if (!VideoRecording)
        {
            VideoRecording = true;
            FrameCounter = 0;
        }
        // stop recording a video
        else
        {
            VideoRecording = false;

        }
    }

    public void CaptureFrame(Camera camera, string path, RenderTexture renderTexture, Texture2D texture, TextureFormat textureFormat)
    {
        camera.transform.position = transform.position - transform.right * IPD;
        colorLeft = CaptureStereoFrame(camera, renderTexture, texture);
        camera.transform.position = transform.position + transform.right * IPD;
        colorRight = CaptureStereoFrame(camera, renderTexture, texture);

        // merge images
        var combined = new Texture2D(camera.targetTexture.width * 2, camera.targetTexture.height, textureFormat, false, true);
        combined.SetPixels(0, 0, camera.targetTexture.width, camera.targetTexture.height, colorLeft);
        combined.SetPixels(camera.targetTexture.width, 0, camera.targetTexture.width, camera.targetTexture.height, colorRight);
        combined.Apply();

        byte[] combinedBytes = combined.EncodeToPNG();
        File.WriteAllBytes(path, combinedBytes);
    }

    public Color[] CaptureStereoFrame(Camera camera, RenderTexture renderTexture, Texture2D texture)
    {
        RenderTexture.active = renderTexture;

        camera.targetTexture = renderTexture;
        camera.Render();

        texture.ReadPixels(new Rect(0, 0, camera.targetTexture.width, camera.targetTexture.height), 0, 0);
        texture.Apply();

        return texture.GetPixels();
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
        var colorL = Capture(camera, rtFormat, textureFormat);
        camera.transform.position = transform.position + transform.right * IPD;
        var colorR = Capture(camera, rtFormat, textureFormat);

        // merge images
        var combined = new Texture2D(camera.targetTexture.width * 2, camera.targetTexture.height, textureFormat, false, true);
        combined.SetPixels(0, 0, camera.targetTexture.width, camera.targetTexture.height, colorL);
        combined.SetPixels(camera.targetTexture.width, 0, camera.targetTexture.width, camera.targetTexture.height, colorR);
        combined.Apply();

        byte[] combinedBytes = combined.EncodeToPNG();
        File.WriteAllBytes(Application.dataPath + "/3D Camera/Captures/" + path + ".png", combinedBytes);
    }

    public Color[] Capture(Camera camera, RenderTextureFormat rtFormat, TextureFormat textureFormat)
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