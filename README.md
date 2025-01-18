# Requirements

Unity 2022.3, 2023.1, 2023.2 or Unity 6.

# Features

* Render graph support for Unity 6.
* Compatibility mode is also supported.
* Support for the main light, spot lights and point lights.
* Shadows and light cookies support for the lights described above.
* Seamlessly integrated into URP volume system.
* Perspective and orthographic projection support.
* Single pass VR rendering support. This is verified by users, since I do not work on VR.
* Forward, Deferred, and Forward+ rendering paths. See limitations section. 
* Verified graphics APIs: DirectX11, DirectX12, OpenGLES3, OpenGLCore and Vulkan.

# How to add volumetric fog

* Add volumetric fog renderer feature to you URP Renderer.
* Enable post-processing both in your camera and URP Renderer.
* Add a volume to your scene and add override: "Custom->Volumetric Fog".
* Tick the "Enabled" checkbox, as fog is disabled by default.
* Make sure that "Enable Main Light Contribution" and "Enable Additional Lights Contribution" are also enabled depending on your needs, as they are also disabled by default.
* For spot and point lights, add the component "VolumetricAdditionalLight" to those lights that you want to contribute to the volumetric fog.
* If you still can not see the fog, play with the different volume parameters or try to increase the intensity of your lights.

# Known limitations

* WebGL is not supported. See https://github.com/CristianQiu/Unity-URP-Volumetric-Light/issues/7.
* Multipass VR rendering is not supported.
* When using forward or deferred rendering path, performance can be heavily affected when adding multiple additional lights. Forward+ is highly recommended for best performance when support for additional lights is needed.
* Transparent objects are not blended correctly with fog.
* It may be possible to notice more noise in some light regions at certain view angles.
* Fog is only rendered up to a certain distance from the camera.

# Known Bugs

* There is an issue with volumetric shadows from lights when "Transparent Receive Shadows" is off in the URP Renderer. If you are having issues with volumetric shadows from lights you may need to turn the setting on. See https://github.com/CristianQiu/Unity-URP-Volumetric-Light/issues/10.

# TODO

There are a few things that I would like to add at some point, as I like coming back to this project from time to time in my spare time.
Some of which are (in no particular order):

* Deferred+ support for Unity 6.1 when it goes out of beta. I would expect the package to work without any dramatic changes.
* WebGL / WebGPU support.
* Further improvements on performance and quality: quarter resolution rendering, reprojection...
* New features: density volumes, noise, self shadowing...
* And of course... bug fixing! Do not hesitate to open issues for anything that you find unexpected or buggy.

# Preview
URP Japanese Garden<br><br>
![Garden](https://github.com/CristianQiu/Unity-Packages-Gifs/blob/main/URP-Volumetric-Light/Garden.gif)

URP Terminal<br><br>
![Terminal](https://github.com/CristianQiu/Unity-Packages-Gifs/blob/main/URP-Volumetric-Light/Terminal.gif)
