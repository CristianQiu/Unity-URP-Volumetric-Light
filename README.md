# Requirements

* Unity 6.1 or above.
* URP.
* Render graph.
* Shader model 4.5 or above.

# Features

* Support for realtime and mixed lights. Main light, spot lights and point lights, including shadows and light cookies for all of them.
* APV and reflection probes sampling support.
* Seamlessly integrated into URP volume system.
* Perspective and orthographic projection support.
* Forward, deferred, forward+ and deferred+ rendering paths support. See limitations section. 
* Verified in DirectX11, DirectX12, OpenGLES3, OpenGLCore and Vulkan.
* Single pass VR rendering support. This is verified by users, since I do not work on VR.

# Installation

The recommended way to install the package is through the package manager in Unity (UPM).
Before installing, make sure that URP is installed and correctly set up in your project.
Then you can proceed to install this package:

1. Inside Unity, go to "Window"-> "Package Manager".
2. Once the window is opened, go to the "+" symbol at the top left corner, and select "Install package from git URL". See the image below.

![Install](https://github.com/CristianQiu/Unity-Packages-Gifs/blob/main/URP-Volumetric-Light/UPM1.jpg)

3. Write the following URL: https://github.com/CristianQiu/Unity-URP-Volumetric-Light.git and click install.

# How to add volumetric fog

1. Add the volumetric fog renderer feature to you URP Renderer.
2. Enable post-processing both in your camera and URP Renderer.
3. Add a volume to your scene and add override: "Custom->Volumetric Fog".
4. Tick the "Enabled" checkbox, as fog is disabled by default.
5. Make sure that "Main Light Contribution" and "Additional Lights Contribution" are also enabled depending on your needs, as they are also disabled by default.
6. For spot and point lights, add the component "VolumetricAdditionalLight" to those lights that you want to contribute to the volumetric fog.
7. If you still can not see the fog, play with the different volume parameters or try to increase the intensity of your lights.

# Known limitations

* Fog is only rendered up to a certain distance from the camera.
* It may be possible to notice more noise in some light regions at certain view angles.
* Transparent objects are not blended correctly with fog.
* When using forward or deferred rendering path, performance can be heavily affected when adding multiple additional lights. Using forward+ or deferred+ is highly recommended for best performance when support for additional lights is needed.
* Not tested on consoles spectrum (Playstation, Xbox, Switch) but very likely to work. PS5 has been verified by users as of v0.5.6.
* Multipass VR rendering is not supported.

# Known Bugs

* There is an issue with volumetric shadows from lights when "Transparent Receive Shadows" is off in the URP Renderer. If you are having issues with volumetric shadows from lights you may need to turn the setting on. See https://github.com/CristianQiu/Unity-URP-Volumetric-Light/issues/10.

# TODO

There are a few things that I would like to add at some point, as I like coming back to this project from time to time in my spare time.
Some of which are:

* Further improvements on reprojection and enhanced transparency support.
* New features: density volumes and self shadowing.
* Bug fixing: Do not hesitate to open issues for anything that you find unexpected or buggy.

# Preview

Sponza <br><br>
![Sponza](https://github.com/CristianQiu/Unity-Packages-Gifs/blob/main/URP-Volumetric-Light/Sponza.gif)

URP Japanese Garden<br><br>
![Garden](https://github.com/CristianQiu/Unity-Packages-Gifs/blob/main/URP-Volumetric-Light/Garden.gif)

URP Terminal<br><br>
![Terminal](https://github.com/CristianQiu/Unity-Packages-Gifs/blob/main/URP-Volumetric-Light/Terminal.gif)
