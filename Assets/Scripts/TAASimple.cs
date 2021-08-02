using UnityEngine;

[ExecuteInEditMode]
public class TAASimple : MonoBehaviour {
	public Shader taaShader;
	private Material taaMaterial;
	public Material material
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
	private int FrameCount = 0;
	private Vector2 _Jitter;
	bool m_ResetHistory = true;
	
	private RenderTexture[] m_HistoryTextures = new RenderTexture[2];

	// private RenderTexture m_History;
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
		camera.depthTextureMode = DepthTextureMode.Depth | DepthTextureMode.MotionVectors;
		camera.useJitteredProjectionMatrixForTransparentRendering = true;
	}

	private void OnPreCull()
	{
		var proj = camera.projectionMatrix;
		
		camera.nonJitteredProjectionMatrix = proj;
		FrameCount++;
		var Index = FrameCount % 8;
		_Jitter = new Vector2(
			(HaltonSequence[Index].x - 0.5f) / camera.pixelWidth,
			(HaltonSequence[Index].y - 0.5f) / camera.pixelHeight);
		proj.m02 += _Jitter.x * 2;
		proj.m12 += _Jitter.y * 2;
		camera.projectionMatrix = proj;
	}

	private void OnPostRender()
	{
		camera.ResetProjectionMatrix();
	}

	private void OnRenderImage(RenderTexture source, RenderTexture dest)
	{
		var historyRead = m_HistoryTextures[FrameCount % 2];
		if (historyRead == null || historyRead.width != Screen.width || historyRead.height != Screen.height)
		{
			if(historyRead) RenderTexture.ReleaseTemporary(historyRead);
			historyRead = RenderTexture.GetTemporary(Screen.width, Screen.height, 0, RenderTextureFormat.ARGBHalf);
			m_HistoryTextures[FrameCount % 2] = historyRead;
			m_ResetHistory = true;
		}
		var historyWrite = m_HistoryTextures[(FrameCount + 1) % 2];
		if (historyWrite == null || historyWrite.width != Screen.width || historyWrite.height != Screen.height)
		{
			if(historyWrite) RenderTexture.ReleaseTemporary(historyWrite);
			historyWrite = RenderTexture.GetTemporary(Screen.width, Screen.height, 0, RenderTextureFormat.ARGBHalf);
			m_HistoryTextures[(FrameCount + 1) % 2] = historyWrite;
		}
		// if (m_History == null || m_History.width != dest.width || m_History.height != dest.height)
		// {
		// 	if (m_History)
		// 	{
		// 		RenderTexture.ReleaseTemporary(m_History);
		// 	}
		// 	m_History = RenderTexture.GetTemporary(dest.width, dest.height, 0, dest.format);
		// }
		
		material.SetVector("_Jitter", _Jitter);
		material.SetTexture("_HistoryTex", historyRead);
		material.SetInt("_IgnoreHistory", m_ResetHistory ? 1 : 0);

		Graphics.Blit(source, historyWrite, material, 0);
		Graphics.Blit(historyWrite, dest);
		m_ResetHistory = false;
		// Graphics.Blit(source, dest);
		// IgnoreHistory = 0;
		// taaMaterial.SetTexture("_HistoryTex", m_History);

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

   //  private void OnDestroy()
   //  {
	  //   if(Camera.current && m_CommandBuffer != null)
			// Camera.current.RemoveCommandBuffer(CameraEvent.AfterForwardOpaque, m_CommandBuffer);
   //  }
}