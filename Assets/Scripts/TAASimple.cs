using System;
using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using Random = UnityEngine.Random;

[ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class TAASimple : MonoBehaviour {
	[Range(0.0312f, 0.0833f)]
	public float contrastThreshold = 0.0312f;

	[Range(0.063f, 0.333f)]
	public float relativeThreshold = 0.063f;

	public Shader taaShader;

	private Material taaMaterial;

	public Material Material
	{
		get
		{
			if (taaMaterial == null)
			{
				if (taaShader == null) return null;
				taaMaterial = new Material(taaShader);
			}

			return taaMaterial;
		}
	}
	private Camera m_Camera;
	public new Camera camera
	{
		get
		{
			if (m_Camera == null)
				m_Camera = GetComponent<Camera>();

			return m_Camera;
		}
	}
	
	private CommandBuffer m_CommandBuffer;
	private RenderTexture m_LastFrame, m_ThisFrame, m_Depth;
	private Matrix4x4 m_LastProj, m_LastView;
	private int FrameCount = 0;
	
	//长度为8的Halton序列
	private Vector2[] HaltonSequence = new Vector2[]
	{
		new Vector2(0.5f, 1.0f / 3),
		new Vector2(0.25f, 2.0f / 3),
		new Vector2(0.75f, 1.0f / 9),
		new Vector2(0.125f, 4.0f / 9),
		new Vector2(0.625f, 7.0f / 9),
		new Vector2(0.375f, 2.0f / 9),
		new Vector2(0.875f, 5.0f / 9),
		new Vector2(0.0625f, 8.0f / 9),
	};

	private void OnEnable()
	{
		Camera.main.depthTextureMode = DepthTextureMode.Depth | DepthTextureMode.MotionVectors;
	}

	private void OnPreCull()
	{
		var proj = camera.projectionMatrix;
		
		camera.nonJitteredProjectionMatrix = proj;
		FrameCount++;
		var Index = FrameCount % 8;
		proj.m03 = (HaltonSequence[Index].x - 0.5f) / camera.pixelWidth;
		proj.m13 = (HaltonSequence[Index].y - 0.5f) / camera.pixelHeight;
		camera.projectionMatrix = proj;

	}

	private void OnPostRender()
	{
		camera.ResetProjectionMatrix();
	}

	// private void OnPreRender()
 //    {
	//     if (taaMaterial == null)
	//     {
	// 	    taaMaterial = new Material(taaShader);
	// 	    taaMaterial.hideFlags = HideFlags.HideAndDontSave;
	//     }
 //        if(m_CommandBuffer == null)
 //        {
	// 		m_CommandBuffer = new CommandBuffer();
	// 		m_CommandBuffer.name = "TAA";
	// 		Camera.current.AddCommandBuffer(CameraEvent.AfterForwardOpaque, m_CommandBuffer);
	// 	}
 //
 //        if (m_ThisFrame == null || m_ThisFrame.height != Screen.height || m_ThisFrame.width != Screen.width)
 //        {
	//         if (m_ThisFrame) m_ThisFrame.Release();
	//         if(m_Depth) m_Depth.Release();
	//         m_ThisFrame = new RenderTexture(Screen.width, Screen.height, 0, RenderTextureFormat.RGB111110Float);
	//         m_ThisFrame.Create();
	//         m_Depth = new RenderTexture(Screen.width, Screen.height, 32, RenderTextureFormat.Depth);
	//         m_Depth.Create();
 //        }
 //
 //        var cam = Camera.current;
 //
	// 	m_CommandBuffer.Clear();
	// 	var renderers = GameObject.FindObjectsOfType<Renderer>();
 //
	// 	var proj = cam.projectionMatrix;
	// 	var Index = FrameCount % 8;
 //
	// 	proj.m03 = (HaltonSequence[Index].x - 0.5f) / Screen.width;
	// 	proj.m13 = (HaltonSequence[Index].y - 0.5f) / Screen.height;
	// 	m_CommandBuffer.SetRenderTarget(m_ThisFrame, m_Depth);
	// 	m_CommandBuffer.ClearRenderTarget(true, true, Color.black);
	//     m_CommandBuffer.SetViewProjectionMatrices(cam.worldToCameraMatrix,  proj);
	//     foreach (var r in renderers)
	// 	{
	// 		r.sharedMaterial.EnableKeyword("LIGHTPROBE_SH");
	// 		m_CommandBuffer.DrawRenderer(r, r.sharedMaterial, 0, 0);
	// 	}
	//     
	//     
	//     m_CommandBuffer.Blit(m_ThisFrame, BuiltinRenderTextureType.CameraTarget, taaMaterial, 0);
	//     m_CommandBuffer.SetRenderTarget(BuiltinRenderTextureType.CameraTarget);
	//     ++FrameCount;
 //    }

    private void OnDestroy()
    {
	    if(Camera.current && m_CommandBuffer != null)
			Camera.current.RemoveCommandBuffer(CameraEvent.AfterForwardOpaque, m_CommandBuffer);
    }
}