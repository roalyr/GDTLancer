# TODO list!
Highlighted entries are "Work in progress".

## New features
- Make autopilot detect obstacles.
- Make primitive building blocks with simple collision shapes (performace).
- Make "Orient only" autopilot feature.
- **Infocards. Accessible from targeting and in-game list.**
- **Info about an object in-game.**
- Internal game wiki. 
- Pause the game while menu (options) window is on.
- Sandbox (debug) mode separate from gameplay mode.
- **Ambient music and sounds.**
- **Save game state and options.**
- **Ship switching (in debug) (https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html).**
- Make different "print()" debug calls into a proper logging system.

## Improvements
- Make star sprites diminish in size with distance (script).
- Investigate enabling/disabling trimesh collision shapes on the go.
- Option for debanding.
- Engine kill button for touch UI.
- Improve pad X direction movement on scaling.
- Remove objects (zone contents) that are way too far.
- Make a "UI state" autoload object to store UI data and synchronize states.
- Examine PID regulator applicability (https://github.com/slavfox/godot_pid_controller or https://github.com/fire/godot-pid/blob/master/PID_Controller/PID_Controller.gd).
- Info tab: make clickable entries that expand to tutorial entries.

## Refactor
- **Re-attach models directly into scenes (make editable).**
- **Refactor ship code.**
- Paths and common to autoload (https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html)
- Rename all the space objects to their proper names.
- Refactor nav list scripts.

## Fix
- Investigate flickering on high velocity.
- Keyboard keys (also refactor).