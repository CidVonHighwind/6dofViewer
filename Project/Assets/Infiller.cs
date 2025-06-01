using System.IO;
using System.Linq;
using UnityEngine;

public class Infiller : MonoBehaviour
{
    public Material downsampler;
    public Material infiller;

    private bool _init;

    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
        var colorImages = Resources.LoadAll<Texture2D>("90 deg/color").ToList();
        var depthImages = Resources.LoadAll<Texture2D>("90 deg/depths").ToList();

        //var image = colorImages[1];
        foreach (var image in colorImages)
        {
            var depthImage = depthImages.Where(x => x.name == image.name).FirstOrDefault();

            if (depthImage != null)
            {
                InfillImage(image, depthImage, 5);
            }
        }
    }

    // Update is called once per frame
    void Update()
    {
        if (!_init)
        {
            _init = true;
        }
    }

    void InfillImage(Texture2D color, Texture2D depth, int count)
    {
        var colorTexture = new Texture2D[count + 1];
        var depthTexture = new Texture2D[count + 1];

        colorTexture[0] = color;
        depthTexture[0] = depth;

        depthTexture[1] = depthTexture[0];// DownsampleTexture(depthTexture[i]);

        for (int i = 0; i < count; i++)
        {
            colorTexture[i + 1] = InfillTexture(colorTexture[i], depthTexture[1], 0.8f);
            colorTexture[i + 1] = InfillTexture(colorTexture[i + 1], depthTexture[1], 1.0f);

            //depthTexture[i + 1] = InfillTexture(depthTexture[i], depthTexture[i + 1], 0.8f);
            //depthTexture[i + 1] = InfillTexture(depthTexture[i + 1], depthTexture[i + 1], 1.0f);

            //byte[] depthBytes = depthTexture[i + 1].EncodeToPNG();
            //File.WriteAllBytes(Application.dataPath + "\\Resources\\90 deg\\infill\\d " + color.name + i + ".png", depthBytes);

            //byte[] colorBytes = colorTexture[i + 1].EncodeToPNG();
            //File.WriteAllBytes(Application.dataPath + "\\Resources\\90 deg\\infill\\" + color.name + i + ".png", colorBytes);
        }

        byte[] colorBytes = colorTexture[count].EncodeToPNG();
        File.WriteAllBytes(Application.dataPath + "\\Resources\\90 deg\\infill\\" + color.name + ".png", colorBytes);
    }

    Texture2D InfillTexture(Texture2D source, Texture2D depth, float scale)
    {
        int newWidth = (int)(source.width * scale);
        int newHeight = (int)(source.height * scale);

        // Create a RenderTexture for the downsampled result
        RenderTexture rt = new RenderTexture(newWidth, newHeight, 0);
        rt.filterMode = FilterMode.Bilinear;

        infiller.SetTexture("_MainTex", source);
        infiller.SetTexture("_DepthTex", depth);
        infiller.SetFloat("_SizeX", 1.0f / source.width);
        infiller.SetFloat("_SizeY", 1.0f / source.height);

        // Blit from original to the smaller RT
        Graphics.Blit(source, rt, infiller);

        // Optional: Read back to a Texture2D
        RenderTexture.active = rt;
        Texture2D downsampled = new Texture2D(newWidth, newHeight, TextureFormat.RGBA32, false);
        //Texture2D downsampled = new Texture2D(newWidth, newHeight, TextureFormat.R16, false, true);
        downsampled.ReadPixels(new Rect(0, 0, newWidth, newHeight), 0, 0);
        downsampled.Apply();
        RenderTexture.active = null;

        return downsampled;
    }

    Texture2D DownsampleTexture(Texture2D source)
    {
        int newWidth = source.width / 2;
        int newHeight = source.height / 2;

        // Create a RenderTexture for the downsampled result
        RenderTexture rt = new RenderTexture(newWidth, newHeight, 0);
        rt.filterMode = FilterMode.Bilinear;

        downsampler.SetTexture("_MainTex", source);
        downsampler.SetFloat("_SizeX", 1.0f / source.width);
        downsampler.SetFloat("_SizeY", 1.0f / source.height);

        // Blit from original to the smaller RT
        Graphics.Blit(source, rt, downsampler);

        // Optional: Read back to a Texture2D
        RenderTexture.active = rt;
        Texture2D downsampled = new Texture2D(newWidth, newHeight, TextureFormat.RGBA32, false);
        //Texture2D downsampled = new Texture2D(newWidth, newHeight, TextureFormat.R16, false, true);
        downsampled.ReadPixels(new Rect(0, 0, newWidth, newHeight), 0, 0);
        downsampled.Apply();
        RenderTexture.active = null;

        return downsampled;
    }
}
