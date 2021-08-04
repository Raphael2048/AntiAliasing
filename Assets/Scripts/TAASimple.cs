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

		material.SetVector("_Jitter", _Jitter);
		material.SetTexture("_HistoryTex", historyRead);
		material.SetInt("_IgnoreHistory", m_ResetHistory ? 1 : 0);

		Graphics.Blit(source, historyWrite, material, 0);
		Graphics.Blit(historyWrite, dest);
		m_ResetHistory = false;
	}
}