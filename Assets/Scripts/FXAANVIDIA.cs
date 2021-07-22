﻿using UnityEngine;
using System;

[ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class FXAANVIDIA : MonoBehaviour {

	public enum FXAAMode
	{
		Quality = 0,
		Console = 1,
	};

	public FXAAMode mode;

	public Shader fxaaShader;
	

	[NonSerialized]
	Material fxaaMaterial;

	void OnRenderImage (RenderTexture source, RenderTexture destination) {
		if (fxaaMaterial == null) {
			fxaaMaterial = new Material(fxaaShader);
			fxaaMaterial.hideFlags = HideFlags.HideAndDontSave;
		}

		Graphics.Blit(source, destination, fxaaMaterial, (int)mode);
	}
}