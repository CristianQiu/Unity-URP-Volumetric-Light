# About

* Supported Unity versions are 2022.3, 2023.1, 2023.2 and Unity 6.
* Render graph support for Unity 6. Compatibility mode is also supported.
* Supports directional lights, point lights, and spot lights, including shadows and cookies for all of them.
* Seamlessly integrated into URP volume system.

# How to add volumetric fog

* Add volumetric fog renderer feature to you URP Renderer.
* Enable post-processing both in your camera and URP Renderer.
* Add a volume to your scene and add override: "Custom->Volumetric Fog".
* Tick the "Enabled" checkbox, as fog is disabled by default.
* If you still can not see the fog, play with the different volume parameters or try to increase the intensity of your lights.

# Known limitations

* Transparent objects are not blended correctly with fog.
* When using forward or deferred rendering path, performance can be heavily affected when adding multiple additional lights, specially when using shadows. Forward+ is highly recommended for best performance.
* Some of the settings are shared between all additional lights, like scattering or anisotropy.
* It is currently not possible to selectively exclude additional lights from the volumetric fog.
* For certain viewing angles it may be possible to notice more noise in some light regions.
* Fog is only rendered up to a certain distance from the camera.

# Preview
![alt-text](https://github.com/CristianQiu/Unity-Packages-Gifs/blob/main/URP-Volumetric-Light/Teaser.gif)
