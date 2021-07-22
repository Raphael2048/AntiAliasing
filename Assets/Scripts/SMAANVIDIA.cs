using UnityEngine;
using System;
using UnityEngine.Experimental.Rendering;

[ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class SMAANVIDIA : MonoBehaviour {

	public Shader shader;

	public Texture areaTexture;
	public Texture searchTexture;
	[NonSerialized]
	Material material;

	void OnRenderImage (RenderTexture source, RenderTexture destination) {
		if (material == null) {
			material = new Material(shader);
			material.hideFlags = HideFlags.HideAndDontSave;
		}
		RenderTexture edge = RenderTexture.GetTemporary(source.width, source.height, 0, RenderTextureFormat.RG16);
		RenderTexture blend = RenderTexture.GetTemporary(source.width, source.height, 0, RenderTextureFormat.BGRA32);
		Graphics.Blit(source, edge, material, 0);
		material.SetTexture("_AreaTex", areaTexture);
		material.SetTexture("_SearchTex", searchTexture);
		Graphics.Blit(edge, blend, material, 1);
		material.SetTexture("_BlendTex", blend);
		Graphics.Blit(source, destination, material, 2);
		
		RenderTexture.ReleaseTemporary(edge);
		RenderTexture.ReleaseTemporary(blend);
	}
}