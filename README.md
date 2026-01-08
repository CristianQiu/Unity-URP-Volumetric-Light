# Requirements

Any Unity version posterior to 2022.3 LTS (included), up to Unity 6000.3 LTS.

# Features

* Render graph and compatibility mode support for Unity 6 and above.
* Support for the main light, spot lights and point lights.
* Shadows and light cookies support for the lights described above.
* Realtime and mixed lights support.
* APV support for Unity 2023.1+.
* Perspective and orthographic projection support.
* Single pass VR rendering support. This is verified by users, since I do not work on VR.
* Seamlessly integrated into URP volume system.
* Works in forward, deferred, forward+ and deferred+ rendering paths. See limitations section. 
* Verified in DirectX11, DirectX12, OpenGLES3, OpenGLCore and Vulkan.

# Installation

The recommended way to install the package is through the package manager in Unity (UPM).
Before installing, make sure that URP is installed and correctly set up in your project.
Then you can proceed to install this package:

1. Inside Unity, go to "Window"-> "Package Manager".
2. Once the window is opened, go to the "+" symbol at the top left corner, and select "Install package from git URL". See the image below.

![Install](https://github.com/CristianQiu/Unity-Packages-Gifs/blob/main/URP-Volumetric-Light/UPM1.jpg)

3. Write the following URL: https://github.com/CristianQiu/Unity-URP-Volumetric-Light.git and click install.

# How to add volumetric fog

1. Add volumetric fog renderer feature to you URP Renderer.
2. Enable post-processing both in your camera and URP Renderer.
3. Add a volume to your scene and add override: "Custom->Volumetric Fog".
4. Tick the "Enabled" checkbox, as fog is disabled by default.
5. Make sure that "Enable Main Light Contribution" and "Enable Additional Lights Contribution" are also enabled depending on your needs, as they are also disabled by default.
6. For spot and point lights, add the component "VolumetricAdditionalLight" to those lights that you want to contribute to the volumetric fog.
7. If you still can not see the fog, play with the different volume parameters or try to increase the intensity of your lights.

# Known limitations

* Multipass VR rendering is not supported.
* WebGL is not supported. See https://github.com/CristianQiu/Unity-URP-Volumetric-Light/issues/7.
* Not tested on Switch 1/2 and PS4 consoles. Verified by users in Steam Deck, Xbox One/XSX and PS5 as of v0.5.6.
* Transparent objects are not blended correctly with fog.
* Fully baked lights are not supported.
* Fog is only rendered up to a certain distance from the camera.
* It may be possible to notice more noise in some light regions at certain view angles.
* When using forward or deferred rendering path, performance can be heavily affected when adding multiple additional lights. Forward+ or Deferred+ is highly recommended for best performance when support for additional lights is needed.

# Known Bugs

* There is an issue with volumetric shadows from lights when "Transparent Receive Shadows" is off in the URP Renderer. If you are having issues with volumetric shadows from lights you may need to turn the setting on. See https://github.com/CristianQiu/Unity-URP-Volumetric-Light/issues/10.

# TODO

There are a few things that I would like to add at some point, as I like coming back to this project from time to time in my spare time.
Some of which are (in no particular order):

* WebGL support.
* Further improvements on performance and quality: quarter resolution rendering, reprojection, better transparency support...
* New features: density volumes, noise, self shadowing...
* And of course... bug fixing! Do not hesitate to open issues for anything that you find unexpected or buggy.

# Preview

Using it in a [Tower Defense](https://www.youtube.com/watch?v=ND5eoEOw47E) I am working on as an indie dev <br><br>
![TD](https://github.com/CristianQiu/Unity-Packages-Gifs/blob/main/URP-Volumetric-Light/Towers.gif)

I am also working alongside Siesta Games studio to implement it in [Empire in Decay](https://store.steampowered.com/app/3345260/Empire_in_Decay/?utm_source=github&utm_campaign=cristianqiu&utm_medium=urp-volumetric-light), a roguelike deckbuilder chess-like game that will be released this year.
I also plan to release a new version in the future with some of the stuff that we used in the game.
You can play the [demo and wishlist](https://store.steampowered.com/app/3345260/Empire_in_Decay/?utm_source=github&utm_campaign=cristianqiu&utm_medium=urp-volumetric-light) it now! <br><br>
![Empire In Decay](https://github.com/CristianQiu/Unity-Packages-Gifs/blob/main/URP-Volumetric-Light/EiDFog2.gif)
![Empire In Decay](https://github.com/CristianQiu/Unity-Packages-Gifs/blob/main/URP-Volumetric-Light/EiDFog.gif)
