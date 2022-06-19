#ifndef OPENGL_LIGHT_TRANSPORT_RENDERER_H
#define OPENGL_LIGHT_TRANSPORT_RENDERER_H

#include "../misc/Window.h"
#include "VertexArray.h"
#include "Buffer.h"
#include "Shader.h"
#include "Texture.h"
#include "../math/Camera.h"

class Renderer {
public:
	void Initialize(Window* ptr, const char* scenePath, const char* env_path);
	void CleanUp();

	void RenderFrame(const Camera& camera);
	void Present();

	void ResetSamples();
private:
	uint32_t viewportWidth, viewportHeight, numPixels;
	Window* bindedWindow;

	Buffer quadBuf;
	VertexArray screenQuad;
	ShaderRasterization present;
	Texture2D colorTexture;

	// Wavefront path tracing
	Buffer rayBuffer;
	Buffer rayCounter;

	Buffer randomState;

	ShaderCompute generate;
	ShaderCompute extend;
	ShaderCompute shade;

	Scene scene;

	int frameCounter;
	int* atomicCounterClear;

	int numSamples;

};

#endif
