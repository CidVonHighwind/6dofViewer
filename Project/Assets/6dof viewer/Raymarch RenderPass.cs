using UnityEngine;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.HighDefinition;

public class RaymarchRenderPass : CustomPass
{
    public Image_Viewer imageProvider;
    public VLCMinimalPlayback videoPlayer;
    public FFmpegPlayer ffmpegPlayer;

    public Material fullscreenMaterial;
    public Material raymarchMaterial;
    public Material downsampleMaterial;
    public Material edgeDetectionMaterial;

    public bool drawDepth;
    public bool drawDepthSmall;
    public bool drawEdges;
    public bool edgePass;

    private RTHandle colorRT;
    private RTHandle depthRT;
    private RTHandle depthRTHalf;
    private RTHandle depthRTQuad;
    private RTHandle edgesRT;
    private RTHandle edgesRTQuad;

    private ShaderTagId shaderTags;

    protected override void Setup(ScriptableRenderContext renderContext, CommandBuffer cmd)
    {
        shaderTags = new ShaderTagId("CustomOnly");

        var colorFormat = GraphicsFormat.B10G11R11_UFloatPack32;

        //TextureXR.dimension
        colorRT = RTHandles.Alloc(
            Vector2.one, // full size of the camera
            TextureXR.slices,
            dimension: TextureXR.dimension,
            colorFormat: colorFormat,
            useDynamicScale: true,
            name: "MyColorRT");

        depthRT = RTHandles.Alloc(
            Vector2.one,
            TextureXR.slices,
            dimension: TextureXR.dimension,
            colorFormat: GraphicsFormat.None,
            depthBufferBits: DepthBits.Depth24,
            useDynamicScale: true,
            name: "MyDepthRT");

        depthRTHalf = RTHandles.Alloc(
            Vector2.one * 0.5f,
            TextureXR.slices,
            dimension: TextureXR.dimension,
            colorFormat: GraphicsFormat.R32_SFloat,
            useDynamicScale: true,
            name: "MyDepthRTHalf");
        depthRTQuad = RTHandles.Alloc(
            Vector2.one * 0.25f,
            TextureXR.slices,
            dimension: TextureXR.dimension,
            colorFormat: GraphicsFormat.R32_SFloat,
            useDynamicScale: true,
            name: "MyDepthRTQuad");

        edgesRT = RTHandles.Alloc(
            Vector2.one * 0.5f,
            TextureXR.slices,
            dimension: TextureXR.dimension,
            colorFormat: GraphicsFormat.R32_SFloat,
            useDynamicScale: true,
            name: "MyEdgesRT");
        edgesRTQuad = RTHandles.Alloc(
            Vector2.one * 0.25f,
            TextureXR.slices,
            dimension: TextureXR.dimension,
            colorFormat: GraphicsFormat.R32_SFloat,
            useDynamicScale: true,
            name: "MyEdgesRTQuad");

        RTHandles.SetReferenceSize(Screen.width, Screen.height);
    }

    protected override void Execute(CustomPassContext ctx)
    {
        var cmd = ctx.cmd;
        fullscreenMaterial.SetInt("_DepthMode", drawDepth || drawDepthSmall ? 1 : 0);
        fullscreenMaterial.SetInt("_EdgeMode", drawEdges ? 1 : 0);

        // render the initial raymarched output with its depth map
        {
            //if (ffmpegPlayer != null && ffmpegPlayer.ColorTexture != null)
            //    ctx.propertyBlock.SetTexture("_MainTex", ffmpegPlayer.ColorTexture);
            //else 
            if (videoPlayer != null && videoPlayer.ColorTexture != null)
                ctx.propertyBlock.SetTexture("_MainTex", videoPlayer.ColorTexture);
            else if (imageProvider != null && imageProvider.ColorTexture != null)
                ctx.propertyBlock.SetTexture("_MainTex", imageProvider.ColorTexture);

            if (ffmpegPlayer != null && ffmpegPlayer.DepthTexture != null)
                ctx.propertyBlock.SetTexture("_DepthTex", ffmpegPlayer.DepthTexture);
            else if (videoPlayer != null && videoPlayer.DepthTexture != null)
                ctx.propertyBlock.SetTexture("_DepthTex", videoPlayer.DepthTexture);
            else if (imageProvider != null && imageProvider.DepthTexture != null)
                ctx.propertyBlock.SetTexture("_DepthTex", imageProvider.DepthTexture);

            if (imageProvider != null && imageProvider.InfillTexture != null)
                ctx.propertyBlock.SetTexture("_InfillTex", imageProvider.InfillTexture);

            CoreUtils.SetRenderTarget(cmd, colorRT, depthRT, ClearFlag.All, Color.clear);
            CoreUtils.DrawFullScreen(ctx.cmd, raymarchMaterial, ctx.propertyBlock, shaderPassId: 0);
        }

        // downsample the depth texture
        {
            ctx.propertyBlock.SetTexture("_DepthTexture", depthRT);
            CoreUtils.SetRenderTarget(ctx.cmd, depthRTHalf, ClearFlag.All, Color.clear);
            CoreUtils.DrawFullScreen(ctx.cmd, downsampleMaterial, ctx.propertyBlock, shaderPassId: 0);

            //ctx.propertyBlock.SetTexture("_DepthTexture", depthRTHalf);
            //CoreUtils.SetRenderTarget(ctx.cmd, null, depthRTQuad, ClearFlag.All, Color.clear);
            //CoreUtils.DrawFullScreen(ctx.cmd, downsampleMaterial, ctx.propertyBlock, shaderPassId: 0);
        }

        // edge detecion pass
        {
            // Draw the full screen shader
            ctx.propertyBlock.SetTexture("_DepthTexture", depthRTHalf);
            CoreUtils.SetRenderTarget(ctx.cmd, edgesRT, ClearFlag.All, Color.clear);
            CoreUtils.DrawFullScreen(ctx.cmd, edgeDetectionMaterial, ctx.propertyBlock, shaderPassId: 0);
        }

        //// downsample the edge texture
        //{
        //    ctx.propertyBlock.SetTexture("_DepthTexture", edgesRT);
        //    CoreUtils.SetRenderTarget(ctx.cmd, edgesRTQuad, ClearFlag.All, Color.clear);
        //    CoreUtils.DrawFullScreen(ctx.cmd, downsampleMaterial, ctx.propertyBlock, shaderPassId: 1);
        //}

        // render the original image to the screen
        ctx.propertyBlock.SetTexture("_InputTexture", colorRT);
        CoreUtils.SetRenderTarget(ctx.cmd, ctx.cameraColorBuffer, ClearFlag.All, Color.red);
        CoreUtils.DrawFullScreen(ctx.cmd, fullscreenMaterial, ctx.propertyBlock, shaderPassId: 0);

        // refine raymarch output at the edges
        if (edgePass)
        {
            ctx.propertyBlock.SetTexture("_EdgeTex", edgesRT);
            CoreUtils.DrawFullScreen(ctx.cmd, raymarchMaterial, ctx.propertyBlock, shaderPassId: 1);
        }

        // debug draw
        {
            if (drawEdges)
            {
                ctx.propertyBlock.SetTexture("_EdgeTexture", edgesRT);
                CoreUtils.SetRenderTarget(ctx.cmd, ctx.cameraColorBuffer, ClearFlag.All, Color.red);
                CoreUtils.DrawFullScreen(ctx.cmd, fullscreenMaterial, ctx.propertyBlock, shaderPassId: 0);
                return;
            }
            if (drawDepth)
            {
                ctx.propertyBlock.SetTexture("_DepthTexture", depthRT);
                CoreUtils.SetRenderTarget(ctx.cmd, ctx.cameraColorBuffer, ClearFlag.All, Color.red);
                CoreUtils.DrawFullScreen(ctx.cmd, fullscreenMaterial, ctx.propertyBlock, shaderPassId: 0);
                return;
            }
            if (drawDepthSmall)
            {
                ctx.propertyBlock.SetTexture("_DepthTexture", depthRTHalf);
                CoreUtils.SetRenderTarget(ctx.cmd, ctx.cameraColorBuffer, ClearFlag.All, Color.red);
                CoreUtils.DrawFullScreen(ctx.cmd, fullscreenMaterial, ctx.propertyBlock, shaderPassId: 0);
                return;
            }
        }
    }

    protected override void Cleanup()
    {
        RTHandles.Release(colorRT);
        RTHandles.Release(depthRT);
        RTHandles.Release(depthRTHalf);
        RTHandles.Release(depthRTQuad);
        RTHandles.Release(edgesRT);
        RTHandles.Release(edgesRTQuad);
    }
}
