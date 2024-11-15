# Changelog

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
