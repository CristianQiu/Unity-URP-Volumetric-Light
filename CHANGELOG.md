# Changelog

## [0.5.6] - 2025-05-09

* Minor change to prevent PS5 error reported by user.

## [0.5.5] - 2025-04-30

* Updated some of the documentation to make it clear that the package supports deferred+ on Unity 6000.1.0f1.
* Updated additional information from the readme and updated the license year.
* No functional changes made.

## [0.5.4] - 2025-04-07

* Added initial APV support for Unity 2023.1+. It can be toggled from the volume. 

## [0.5.3] - 2025-03-19

* Fix for situational null reference in Create() from the volumetric fog renderer feature.
* Replaced custom render pass event enum values to read the ones from URP's enum.

## [0.5.2] - 2025-02-23

* Removed empty version dependency as it was throwing errors. User should make sure that they have URP package installed before installing the volumetric light package to avoid console errors.

## [0.5.1] - 2025-02-16

* Solved error in the scattering falloff that made additional lights scattering to be stronger than it should. You may have to retweak your additional lights scattering. [Sorry :(]
* Reduced noise at certain, extreme combinations of near plane, camera field of view, fog density and light scattering.
* Exposed render pass event field in the volume settings. Overriding can still happen per volume.  
* Replaced obsolete method by its newest version in non RG path in Unity 6.
* Other minor improvements/cleanups.

## [0.5.0] - 2025-01-19

* Added orthographic camera support.
* Decrease CPU work when setting parameters for lights during the volumetric fog render pass.
* Upsample uses texture gather when shader model 4.5+ is available.
* Cleanups in VolumetricFogRenderPass.cs and VolumetricFog.hlsl.
* Verified supported graphics APIs: DirectX11, DirectX12, OpenGLES3, OpenGLCore and Vulkan.

## [0.4.1] - 2025-01-13

* Address issue with lights potentially picking wrong parameters to affect the volumetric fog depending on whether there is a main light enabled in the scene.
* Correctly clamp the anisotropy value for additional lights when setting the property from code.
* Renamed main light parameters from the volume to not have the prefix "Main Light..." since additional lights are no longer displayed there since 0.4.0.
* Minor cleanups.

## [0.4.0] - 2025-01-02

* A new component has been added: VolumetricAdditionalLight. This component now must be added to each point and spot light that you want to influence the volumetric fog. Because of that, now it is possible to have different settings per light.
The main light settings are still configured in the volume, as it should still be used with Unity's volume workflow (mainly for blending purposes).
* Shadow sampling during raymarching now ignores whether soft shadows are enabled and its quality level. This greatly enhances performance when using soft shadows with a barely noticeable loss in quality.
* Changed blur to use point sampling instead of bilinear since source and target are the same size.
* Added back shader model 4.5 instruction to increase the downsample depth pass performance, while also having an alternate path to support cases where it is not possible to use it.

## [0.3.7] - 2024-12-29

* Removed shader model 4.5 requirement for broader support.
* Solved issues related to OpenGL.

## [0.3.6] - 2024-12-02

* Set proper texture usage flags for the camera depth texture and rendergraph path.

## [0.3.5] - 2024-11-29

* Additional checks to skip rendering when not necessary.

## [0.3.4] - 2024-11-16

* Tweaked the minimum distance from the volume that can be set for the fog to be rendered.

## [0.3.3] - 2024-11-12

* Added more optimal flags for some textures usage in rendergraph.

## [0.3.2] - 2024-11-12

* Added obsolete attributes to the overrided methods for Unity 6 and the non rendergraph path to avoid warnings in certain situations.

## [0.3.1] - 2024-11-08

* Added missing tooltips from the volume. Minor tweak to the fog shader when there is more than 1 directional light in the scene.

## [0.3.0] - 2024-10-06

* Added custom editor for the volumetric fog volume, which should slightly improve the usage. Added ground height parameter that allows fog to not be rendered below a certain height, for slightly better compatibility with transparencies like an ocean.
The color tint now only affects the main light color which makes more sense. Many volume parameters have now a descriptive tooltip.

## [0.2.1] - 2024-10-02

* Added Single pass VR rendering support.

## [0.2.0] - 2024-09-27

* Mostly code cleanup and minor fixes regarding compatibility through different versions from 2022 to Unity 6. Tested with no warnings or errors in 2022.3.47f1, 2023.1.20f1, 2023.2.20f1 and 6000.0.18f1. Removed code referencing to a 2023.3 beta version which ultimately became Unity 6, so this package should not work any longer with 2023.3 beta versions : just upgrade to Unity 6.

## [0.1.7] - 2024-09-22

* Fix bug introduced in 0.1.6 that disabled the volumetric fog when it should not. 

## [0.1.6] - 2024-09-22

* Now the main light computations will be skipped when its volume scattering parameter is set to 0. The same will happen with additional lights and their scattering parameter. Slightly changed the falloff of the volume parameter "Additional Light Radius". 

## [0.1.5] - 2024-08-10

* Increased the number of maximum steps that can be tweaked through the volume from 128 to 256.

## [0.1.4] - 2024-07-26

* Removed some text and comments.

## [0.1.3] - 2024-07-07

* Updated some texts referencing old Unity 2023.3 beta to replace them by Unity 6 to make it clear that this package should work on Unity 6. Tested in Unity 6000.0.9f1. 
* No other functional changes were made.

## [0.1.2] - 2024-02-12

* Fixed potential issue with Unity version check in shader.

## [0.1.1] - 2024-02-01

* Fixed non matching blur iterations in render graph and non render graph paths. Cleanup typos and unused attribute.

## [0.1.0] - 2024-01-28

* Initial Release. Verified in Unity 2022.3.18f1, 2023.2.7f1 and 2023.3.0b4.
