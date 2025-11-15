# Changelog

## [0.6.0] - 2025-XX-XX

This is the biggest update to date and it is intended to make this package the best free URP volumetric fog asset available for Unity 6.1+.
Although most values will be kept, this update is destructive due to fundamental changes. Make sure you have a backup or version control system.
If you are upgrading from any previous version, it may not be compatible with your project, read with care:

New requirements:

* Unity 6.1 or above.
* Render graph. Compatibility mode is no longer supported.
* Shader model 4.5+. WebGL no longer has the partial support it had. WebGPU is available from Unity 6.1 and should work, although it has not been tested.

New features:

* Added option for reflection probes contribution. This option requires Forward+ or Deferred+ rendering path and it is ignored otherwise.
* Added option to sample a 3D noise texture to add variation to fog. A texture is included in the package, you can find it in 'Packages->URP Volumetric Fog->Textures->Noise'.
* Added option to distort the previous noise to have smoke-like details. A texture is included in the package, you can find it in 'Packages->URP Volumetric Fog->Textures->Distortion'. Both noise textures (~40MB alltogether) should only be included in the build if any of your volumes is set to use them at build time.
* Added option to render anywhere in between half and quarter resolution.
* Added reprojection. Reprojection requires Unity's motion vectors, which are added automatically when needed. It considers the option set in the volume for motion blur, where "camera" or "camera and object" motion vectors can be output.
* Added option to add one density volume modifier with an sphere shape. The plan is to add more but there will be a cap for sure, probably in between 4-8.

Additional changes:

* Made fundamental changes on how the raymarching steps work. Quality and precision have been generally increased. Indoor scenes in enclosed environments (rooms, corridors, etc) and orthographic and top down perspective cameras whose position is closer to the ground should benefit the most from the improvements in quality. Generally, a small hit in performance could be taken in exchange for slightly better quality in favorable cases, but performance will be much more steady/stable and not depend so much on the current view now. If you are upgrading from a previous version, you will need to tweak the maximum steps and/or minimum step size. It is recommended deleting the volume settings and adding it again to start over from defaults.
* Increased the maximum scattering parameter for main light from 1 to 16.
* Changed the falloff going from the base height to the maximum height of the fog to be more appealing in an exponential fashion.
* Slightly changed the radius falloff of additional lights.
* Each blur iteration is now less aggressive (and slightly more performant as a side effect), so when rendering at quarter resolution at lower resolutions (1080p) it does not "overblur" it. Raised the number of maximum iterations that can be set.
* Reordered and renamed some volume parameters to have less groups and an easier view overall. Changed many of the default values.
* All new additions to the volume have tooltips that you can read, just like the existing parameters.
* Several minor improvements both in C# and shader code.

## [0.5.8] - 2025-09-11

* Safety check for array OOB with very high number of lights being visible in the scene.

## [0.5.7] - 2025-08-29

* Fix for Forward+ (and likely Deferred+ too) issue on Metal.

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

* Removed empty version dependency as it was throwing errors. Users should make sure that they have URP package installed before installing the volumetric light package to avoid console errors.

## [0.5.1] - 2025-02-16

* Solved error in the scattering falloff that made additional lights scattering to be stronger than it should. You may have to retweak your additional lights scattering.
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
* The color tint now only affects the main light color which makes more sense. Many volume parameters have now a descriptive tooltip.

## [0.2.1] - 2024-10-02

* Added Single pass VR rendering support.

## [0.2.0] - 2024-09-27

* Mostly code cleanup and minor fixes regarding compatibility through different versions from 2022 to Unity 6. Tested with no warnings or errors in 2022.3.47f1, 2023.1.20f1, 2023.2.20f1 and 6000.0.18f1. Removed code referencing to a 2023.3 beta version which ultimately became Unity 6, so this package should not work any longer with 2023.3 beta versions: just upgrade to Unity 6.

## [0.1.7] - 2024-09-22

* Fix bug introduced in 0.1.6 that disabled the volumetric fog when it should not. 

## [0.1.6] - 2024-09-22

* Now the main light computations will be skipped when its volume scattering parameter is set to 0. The same will happen with additional lights and their scattering parameter. Slightly changed the falloff of the volume parameter "Additional Light Radius". 

## [0.1.5] - 2024-08-10

* Increased the number of maximum steps that can be tweaked through the volume from 128 to 256.

## [0.1.4] - 2024-07-26

* Removed some text and comments.

## [0.1.3] - 2024-07-07

* Updated some texts referencing an old Unity 2023.3 beta to replace them by Unity 6 to make it clear that this package should work on Unity 6. Tested in Unity 6000.0.9f1. 
* No other functional changes were made.

## [0.1.2] - 2024-02-12

* Fixed potential issue with Unity version check in shader.

## [0.1.1] - 2024-02-01

* Fixed non matching blur iterations in render graph and non render graph paths. Cleanup typos and unused attribute.

## [0.1.0] - 2024-01-28

* Initial Release. Verified in Unity 2022.3.18f1, 2023.2.7f1 and 2023.3.0b4.