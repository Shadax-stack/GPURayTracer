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
	void Initialize(Window* ptr, const char* scenePath);
	void CleanUp();

	void RenderFrame(const Camera& camera);
	void Present();
private:
	uint32_t viewportWidth, viewportHeight;
	Window* bindedWindow;

	Buffer quadBuf;
	VertexArray screenQuad;
	ShaderRasterization presentShader;
	Texture2D colorTexture;

	// Wavefront path tracing
	Buffer rayBuffer;
	Buffer rayCounter;

	ShaderCompute genRays;
	ShaderCompute closestHit;
	ShaderCompute shadow;

	Scene scene;

	int frameCounter;
};

#endif
