# About URP volumetric fog

* Verified in Unity 2022.3.18f1, 2023.2.7f1 and 2023.3.0b4.
* Seamlessly integrated into URP volume system.
* Supports additional lights, shadows and cookies. Render graph support is also available for Unity 2023.3.0. 
* If you do not want to use rendergraph, compatibility mode is also supported for Unity 2023.3.0.

## How to add volumetric fog

* Add volumetric fog renderer feature to you URP Renderer.
* Enable post-processing both in your camera and URP Renderer.
* Add a volume to your scene and add override: "Custom->Volumetric Fog".
* Tick the "Enabled" checkbox, as the fog is disabled by default.
* If you still can not see the fog, play with the different volume parameters or try to increase the intensity of your lights.

## This solution has several limitations

* Transparent objects will not be blended correctly with fog.
* When using forward or deferred rendering path, performance can be heavily affected when adding multiple additional lights, specially when using shadows. Forward+ is highly recommended for best performance.
* For certain viewing angles it may be possible to notice more noise in some light regions.
* Fog is only rendered up to a certain distance from the camera.