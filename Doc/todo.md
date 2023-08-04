# TODO list!
Highlighted entries are "Work in progress".

## New features
- Make autopilot detect obstacles.
- Make primitive building blocks with simple collision shapes (performace).
- Make "Orient only" autopilot feature.
- **Infocards. Accessible from targeting and in-game list. (WIP)**
- Internal game wiki.  
- **Pause the game while menu (options) window is on.**
- Sandbox (debug) mode separate from gameplay mode.
- **Save game state and options. Make autosave on entering planetary systems.**
- **Ship switching (in debug) (https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html).**
- Make different "print()" debug calls into a proper logging system.
- **Add "Credits" info panel in options to feature contributors.**
- Make stellar objects accessible at certain ranges or in certain zones (i.e. you would have to fly to a planetary system to access its planets coordinates).
- Universe generator: brown and Wwhite dwarfs, giant stars.
- Temperature / flux zones (distance-affected) and gauge.
- Reflective ship / base coating materials.
- **Basic gameplay loop(s).**
- Space markers hierarchy (make planets appear on lists when in respective system).

## Improvements
- Investigate enabling/disabling trimesh collision shapes on the go.
- Option for debanding.
- Remove objects (zone contents) that are way too far.
- Examine PID regulator applicability (https://github.com/slavfox/godot_pid_controller or https://github.com/fire/godot-pid/blob/master/PID_Controller/PID_Controller.gd).
- Info tab: make clickable entries that expand to tutorial entries.
- Split LOD system into objects / environment / ship categories and allow maximum LOD level.
- Take into account star death zone based on ship's reflection / radiation ability.
- Add solar prominences.

## Refactor
- Refactor ship code.
- **Rename all the space objects to their proper names.**
- Refactor nav list scripts.

## Fix
- Keyboard keys behavior (also refactor).
- Panic screen scaling.
