using System;
using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using UnityEngine.Rendering;

[ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class TAASimple : MonoBehaviour {
	[Range(0.0312f, 0.0833f)]
	public float contrastThreshold = 0.0312f;

	[Range(0.063f, 0.333f)]
	public float relativeThreshold = 0.063f;

	public Shader taaShader;
	


	[NonSerialized]
	Material taaMaterial;

	private CommandBuffer m_CommandBuffer;
	private RenderTexture m_LastFrame, m_ThisFrame;
    private void OnPreRender()
    {
        if(m_CommandBuffer == null)
        {
			m_CommandBuffer = new CommandBuffer();
			m_CommandBuffer.name = "TAA";
			Camera.current.AddCommandBuffer(CameraEvent.AfterForwardOpaque, m_CommandBuffer);
		}

		m_CommandBuffer.Clear();
		var renderers = GameObject.FindObjectsOfType<Renderer>();
		foreach (var r in renderers)
		{
			m_CommandBuffer.DrawRenderer(r, r.sharedMaterial, 0, 0);
		}
		// m_CommandBuffer.SetMa

    }

    // private void OnRenderImage(RenderTexture src, RenderTexture dest)
    // {
	   //  
    // }
}