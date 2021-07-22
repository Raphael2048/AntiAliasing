using UnityEngine;
using System;

[ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class FXAASelf : MonoBehaviour {

	public enum FXAAMode
	{
		Quality = 0,
		Console = 1,
	};

	public FXAAMode mode;

	[Range(0.0312f, 0.0833f)]
	public float contrastThreshold = 0.0312f;

	[Range(0.063f, 0.333f)]
	public float relativeThreshold = 0.063f;

	public Shader fxaaShader;
	

	[NonSerialized]
	Material fxaaMaterial;

	void OnRenderImage (RenderTexture source, RenderTexture destination) {
		if (fxaaMaterial == null) {
			fxaaMaterial = new Material(fxaaShader);
			fxaaMaterial.hideFlags = HideFlags.HideAndDontSave;
		}

		fxaaMaterial.SetFloat("_ContrastThreshold", contrastThreshold);
		fxaaMaterial.SetFloat("_RelativeThreshold", relativeThreshold);
		
		Graphics.Blit(source, destination, fxaaMaterial, (int)mode);
	}
}