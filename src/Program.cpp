#include <iostream>
#include <stdio.h>
#include "misc/Window.h"
#include "core/Renderer.h"
#include "core/Buffer.h"
#include "core/VertexArray.h"
#include "core/Shader.h"
#include "core/Texture.h"
#include "math/Camera.h"
#include "misc/TimeUtil.h"
#include "core/Scene.h"
#include <SOIL2.h>
#include <ctime>
#include <string>

uint32_t Width = 1280;
uint32_t Height = 720;

// Camera params 
constexpr float kCameraSetting = 1.0f;

constexpr float CameraSpeed = 2000.000f * 0.5f * kCameraSetting;
constexpr float CameraSensitivity = 0.001f;
glm::vec2 LastCursorPosition;


// I need class here because Intellisense is not detecting the camera type
Camera camera((float)Width / Height, glm::radians(45.0f), 900.0f * kCameraSetting, 3.0f * kCameraSetting);

bool needResetSamples = false;

void MouseCallback(GLFWwindow* Window, double X, double Y) {
	glm::vec2 CurrentCursorPosition = glm::vec2(X, Y);

	glm::vec2 DeltaPosition = CurrentCursorPosition - LastCursorPosition;

	DeltaPosition.y = -DeltaPosition.y;
	//DeltaPosition.x = -DeltaPosition.x;

	DeltaPosition *= CameraSensitivity;

	camera.AddRotation(glm::vec3(DeltaPosition, 0.0f));

	LastCursorPosition = CurrentCursorPosition;
	needResetSamples = true;
}

int main(int argc, char** argv) {
	std::cout << "Working Directory: " << argv[0] << '\n';

	Window Window;
	Window.Open("OpenGL Light Transport", Width, Height, false);

	LastCursorPosition = glm::vec2(Width, Height) / 2.0f;
	Window.SetInputCallback(MouseCallback);

	

	Renderer* renderer = new Renderer;
	renderer->Initialize(&Window, "res/de_dust2/dust2fixed2.obj", "res/sky/logl/cubemap.txt");
	camera.SetPosition(glm::vec3(-0.25f, 2.79f, 6.0));

	Timer FrameTimer;

	while (!Window.ShouldClose()) {
		FrameTimer.Begin();

		if (Window.GetKey(GLFW_KEY_W)) {
			camera.Move(CameraSpeed * (float)FrameTimer.Delta);
			needResetSamples = true;
		}
		else if (Window.GetKey(GLFW_KEY_S)) {
			camera.Move(-CameraSpeed * (float)FrameTimer.Delta);
			needResetSamples = true;
		}

		if (needResetSamples) {
			renderer->ResetSamples();
			needResetSamples = false;
		}

		camera.GenerateImagePlane();

		renderer->RenderFrame(camera);
		renderer->Present();

		Window.Update();

		// Take screenshot at the end of rendering
		if (Window.GetKey(GLFW_KEY_F2)) {
			renderer->SaveScreenshot("res/screenshots/" + std::to_string(std::time(nullptr)) + ".png");
		}
		else if (Window.GetKey(GLFW_KEY_R)) {
			std::cout << "RENDERING REFERENCE Go grab a cup of coffee. This is going to take a while.\n";
			Timer referenceTimer;
			referenceTimer.Begin();

			renderer->RenderReference(camera);

			referenceTimer.End();
			referenceTimer.DebugTime();
		}

		FrameTimer.End();
		FrameTimer.DebugTime();
	}

	renderer->CleanUp();
	Window.Close();

	delete renderer;
}