# Current

## v0.11-alpha (work in progress)
### Engine
- Updated engine binaries (3.x as of 16th April 2023).
- Fixed culling issues (objects and lights) caused by camera far-z plane glitch.
### Models
- Fixed some improper LODs.
- Implemented sphere decals (for planets).
- Reworked Phoenix Heavy ship model.
- Reworked engine exhaust models.
### Controls
- Improved touch controls (event sorting).
### Camera
- Improved and fixed camera behavior.
- Tweaked warp camera effect (stretch and brightness are now more smooth).
### Environment
- Environment zones (locally adjustable brightness, saturation, contrast).
- New global nebula.
- New star cluster Moirai.
- Stars are adjusted according to their types (size, color, light ranges).
- Added placeholder fake stars (sprites) to make space look less empty and for testing.
- Added death zones (around stars for now) for future gameplay use.
- Implemented mechnism which hides nebula environments or global nebula when needed.
### Shaders
- Tweaked shaders for performance (significant boost due to using vertex shading).
- Re-introduced star core shader, optimized this time. Distance-modified brightness.
- New different star sprites.
- Clamped shaders alpha to prevent unexpected bugs.
- Star sprite shader is adaptable with distance.
- Added star halo (glow) shader based on camera angle.
- Added opaque cloud and shade (like proximity fog) shaders.
- Gas planet shader added.
- Gas planet shader added.
- Planetary rings shaders added.
- Added decal shaders.
- Vertex-lit shader is improved for solid materials to imitate per-pixel lighting.
### Textures
- Added crater decals.
### Locales
- Initiated localization (EN and UA).
- Connected localization strings with interface, added language switching button.
### Interface
- GUI is now scaleable, and will adapt to any screen (16:9 and wider).
- Separate navigation lists for different stellar objects and structures.
- Reworked touchscreen controls. They can be swapped.
- Reworked options menus.
- Reworked desktop GUI layout.
- Implemented object info window.
- Theme color and intensity can be selected now.
- Improved UI readability.
- Moved readouts to the bottom of the screen.
- Ship model can be hidden.
- Reworking debug menu and output.
- Character info panel added.
### Audio
- Ambient music added.
### Refactoring
- Refactored whole project to heavily rely on autoload for persistent data.
- Refactored autopilot code to be more reliable.
- Refactored UI code to be more reliable.
- Refactored meshes of primitives and used unified names.
- Refactoring meshes to use .gltf format directly.
### Documentation
- Universe reference papers (presets, test, random systems).
- Lore: Xenohive alien race.
### Tools
- Universe generator script in Python3 added (works stand-alone).
- Main sequence stars generator algorithm implemented.

# Previous

## v0.10-alpha (last release)
- CCD is disabled upon reaching specific velocity threshold.
- Tweaked autopilot to perform some rotation (approach is slightly spiraled).
- Introduced star system coordinates databank for main galaxy (50k stars for now).
- Split targeting into "selection" and "autopilot" controls for clarity.
- Upon picking a stellar coordinate - spawn a system scene there (currently only a star).
- Keep a track of recently visited star systems and do not despawn them if their number is within limit.
- Proper spawner / despawner of stellar systems upon selecting them in order to create seamless travel.
- Moved galaxy mesh into decoration background (scoping the space down for gameplay sake).
- Temporarily disabled procedural coords.
- Tweaked systems.
- Tweaked velocity, damping is implemented in the game (due to recent engine changes).
- Removed textures and uneeded sources.
- Refactored UI a little.
- Added panic screen.
- Refactored cloud shaders.
- Re-implemented LOD system (again).
- Refactored cloud meshes.
- Tweaked camera decorations.
- Optimized background decorations.
- Reworked primitive shapes scene (for importing).
- Implemented planet surface shader (based on old implementation of star surface shader, but not animated).
- Tweaked planetary shader to include lava layer.
- Added a sector-level nebula.
- Refactored names of local spaces and markers to reflect what they are clearly.
- Added a new star system.
- Added a new planetary shader (ice).
- Pre-release tweaks.

## v0.9-alpha
- Tweaks to desktop UI.
- Fixed lag due to complex collision trimesh.
- Autopilot added.
- New UI elements.
- Default window size is 720p.
- Some tweaks to superliminal velocity effects.

## v0.8-alpha
- A new star system!
- Switched to full-scale stellar bodies (stars and planets are up to scale now).
- Using `meters` instead of `units` now. Updated distance prefixes according to 
https://en.wikipedia.org/wiki/Metric_prefix.
- Updated galaxy mesh and colors.
- Updtaed camera motion on acceleartion for smoother experience.
- Updated velocity increment mechanism, it is now exponential, which allows to 
accelerate rapidly.
- Space markers are removed from `Debug` overlay.
- Switched to custom LOD script which is based on zones.
- Refactored stellar objects and their hierarchy for clarity.
- Implemented multilayer local space, which tackles precision errors in object positioning.
- Adjusted camera decorations to act as a boundary zone a size of 9e18 to prevent flickering.
(9e18 seems to be a sort of safe margin for transforms?)
- Fixed OmniLight and camera flickering (workarounds but robust).
- Removed unrelated files from within project scope.
- Removed Calinou's LOD plugin files.
- New dynamic star shader. Stars are much less in polycount now.
- Added icons for custom zone nodes.
- Optimized paths.
- Some temporary fixes for collision model (caused stuttering due to polygon number).

