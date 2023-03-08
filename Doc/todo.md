# TODO list!
Highlighted entries are "Work in progress".

## New features
- Make autopilot detect obstacles.
- Make primitive building blocks with simple collision shapes (performace).
- Make "Orient only" autopilot feature.
- **Infocards. Accessible from targeting and in-game list. (WIP)**
- **Internal game wiki. (WIP)** 
- Pause the game while menu (options) window is on.
- Sandbox (debug) mode separate from gameplay mode.
- **Ambient music and sounds. (WIP)**
- **Save game state and options. Make autosave on entering planetary systems.**
- **Ship switching (in debug) (https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html).**
- Make different "print()" debug calls into a proper logging system.
- **Add "Credits" info panel in options to feature contributors.**
- Make stellar objects accessible at certain ranges or in certain zones (i.e. you would have to fly to a planetary system to access its planets coordinates).
- Move readouts to the bottom of the screen (targeting infor, autopilot, etc).
- Universe generator: brown and Wwhite dwarfs, giant stars.

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
- E-kill touchscreen button.

## Refactor
- **Re-attach models directly into scenes (make editable). (WIP)**
- **Refactor ship code.**
- Paths and common to autoload (https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html)
- Rename all the space objects to their proper names.
- Refactor nav list scripts.

## Fix
- Investigate flickering on high velocity.
- Keyboard keys behavior (also refactor).
