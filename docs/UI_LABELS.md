# UI labels and their looks

Every piece of text in the game UI and the named look (theme_type_variation) that sizes it; sizes are at UI SCALE x1.0. To change assignments in one go, fill in **Change to** with another look (or a new one to add) and hand the file back. The looks are listed in CONTENT.md ("Labels use the shared sizes"). Generated 2026-11-22; debug-only text is at the end.

## HUD: top strip

| # | Where | Shows | Look (font) | Change to |
|---|---|---|---|---|
| 1 | TargetRow/Name | TARGET | `LargeLabel` (large 33) | |
| 2 | Distance | 0 | `LargeLabel` (large 33) | |
| 3 | Threat | DEADLY · ROOKIE | `Label` (default 22) | |
| 4 | Speed | 0 M/S | `Label` (default 22) | |
| 5 | Radio | Violet VI-00021: Working a rock. | `SmallLabel` (small 18) | |
| 6 | awareness_zone: HudBar captions (drawn) | HULL, ENERGY, CARGO, SIG | `Label` (default 22) | |
| 7 | awareness_zone: ship pips "+" (drawn) | + past the shown pips | `Label` (default 22) | |

## HUD: buttons and sliders

| # | Where | Shows | Look (font) | Change to |
|---|---|---|---|---|
| 8 | LabelContainer/LabelZoomSlider | ZOOM | `Label` (default 22) | |
| 9 | ButtonOrbit/LabelButtonOrbit | ORBIT | `Label` (default 22) | |
| 10 | ButtonStop/LabelButtonStop | STOP | `Label` (default 22) | |
| 11 | ButtonManualFlight/LabelButtonManualFlight | MANUAL | `Label` (default 22) | |
| 12 | ButtonApproach/LabelButtonApproach | APPROACH | `Label` (default 22) | |
| 13 | ButtonFlee/LabelButtonFlee | FLEE | `Label` (default 22) | |
| 14 | ButtonDock/LabelButtonDock | DOCK | `Label` (default 22) | |
| 15 | ButtonInteract/LabelButtonInteract | INTERACT | `Label` (default 22) | |
| 16 | ButtonTool1/Label | TOOL 1 | `Label` (default 22) | |
| 17 | ButtonTool2/Label | TOOL 2 | `Label` (default 22) | |
| 18 | ButtonTool3/Label | TOOL 3 | `Label` (default 22) | |
| 19 | ButtonTool4/Label | TOOL 4 | `Label` (default 22) | |
| 20 | ButtonLance/Label | LANCE | `Label` (default 22) | |
| 21 | ButtonAfterburner/Label | BURN | `Label` (default 22) | |
| 22 | ButtonSafety/Label | SAFETY | `Label` (default 22) | |
| 23 | ButtonHudLook/LabelButtonHudLook | HUD / STANDARD | `Label` (default 22) | |
| 24 | LabelContainer/LabelThrustSlider | THRUST | `Label` (default 22) | |
| 25 | main_hud.gd: FPS readout | FPS 60 | `Label` (default 22) | |
| 26 | main_hud.gd: tool rows' key numbers | 1 2 3 ... 0 | `Label` (default 22) | |

## HUD: target brackets

| # | Where | Shows | Look (font) | Change to |
|---|---|---|---|---|
| 27 | DistanceLabel | 0000k | `Label` (default 22) | |
| 28 | InfoLabel | TARGET | `Label` (default 22) | |
| 29 | projected_target_bracket.gd: distance, while selected | 1.2 km | `LargeLabel` (large 33) | |

## HUD: announcements

| # | Where | Shows | Look (font) | Change to |
|---|---|---|---|---|
| 30 | Label | announcement text | `Label` (default 22) | |

## Main menu

| # | Where | Shows | Look (font) | Change to |
|---|---|---|---|---|
| 31 | LabelContainerControl/LabelButtonNew | New | `MenuLabel` (menu 50) | |
| 32 | LabelContainerControl/LabelButtonLoad | Load | `MenuLabel` (menu 50) | |
| 33 | LabelContainerControl/LabelButtonSave | Save | `MenuLabel` (menu 50) | |
| 34 | LabelContainerControl/LabelButtonSettings | Settings | `MenuLabel` (menu 50) | |
| 35 | LabelContainerControl/LabelButtonExit | Exit | `MenuLabel` (menu 50) | |
| 36 | TitleLabel | GDTLancer | `MenuTitleLabel` (menu title 100) | |
| 37 | TimeLabel | 14:45 | `MenuLabel` (menu 50) | |
| 38 | VersionLabel | version 0.1 | `MenuLabel` (menu 50) | |
| 39 | ButtonClose | CLOSE | `Button` (default 22) | |

## Docked window

| # | Where | Shows | Look (font) | Change to |
|---|---|---|---|---|
| 40 | ButtonMenu | MENU | `Button` (default 22) | |
| 41 | TabFitting | [FITTING] | `TabButton` (default 22, lighter fill) | |
| 42 | TabMarket | MARKET | `TabButton` (default 22, lighter fill) | |
| 43 | Header/Title | HOME STATION | `TitleLabel` (large 33) | |
| 44 | ButtonUndock | UNDOCK | `Button` (default 22) | |
| 45 | Ship/Title | SHIP - tap a slot to unfit | `HeadingLabel` (default 22, amber) | |
| 46 | Storage/Title | STORAGE - fit or sell | `HeadingLabel` (default 22, amber) | |
| 47 | Store/Title | STORE | `HeadingLabel` (default 22, amber) | |
| 48 | Content/Status | what a fit or sale did | `Label` (default 22) | |
| 49 | ship_stats.gd: stat captions | HULL, POWER, CHARGE ... | `StatCaption` (small 18, faded) | |
| 50 | ship_stats.gd: stat values (look by stat) | 85, 117, +6/s, 31 ... | `StatHull` (medium 28, white) | |
| 51 | fitting_window.gd: store tabs | SHIPS, WEAPONS ... | `TabButton` (default 22, lighter fill) | |

## Docked window: rows, headings, notes (made per item)

| # | Where | Shows | Look (font) | Change to |
|---|---|---|---|---|
| 52 | fitting_button: Button | slot list (SMALL TOOL: LASER MK I-LIGHT), SELL HOLD | `Button` (default 22) | |
| 53 | fitting_group_heading: GroupHeading | LIGHT HULLS (5) - | `HeadingButton` (default 22, amber) | |
| 54 | fitting_heading: Heading | a store section's heading | `HeadingLabel` (default 22, amber) | |
| 55 | fitting_note: Note | Tap a ship to see its hull above... | `NoteLabel` (default 22, faded) | |
| 56 | fitting_row: Text/Name | AFTERBURNER MK I-MEDIUM  X1 | `Label` (default 22) | |
| 57 | fitting_row: Text/Detail | medium, +439 kN thrust lit, 0.3 t | `NoteLabel` (default 22, faded) | |
| 58 | fitting_row_button: Button | FIT, SELL 466, BUY +1932 | `Button` (default 22) | |
| 59 | hull_preview: Name | RAIDER MK I-HEAVY | `Label` (default 22) | |

## Interaction window

| # | Where | Shows | Look (font) | Change to |
|---|---|---|---|---|
| 60 | Header/Title | INTERACT | `TitleLabel` (large 33) | |
| 61 | ButtonClose | CLOSE | `Button` (default 22) | |
| 62 | ButtonAsk | ASK | `TabButton` (default 22, lighter fill) | |
| 63 | ButtonPilot | PILOT | `TabButton` (default 22, lighter fill) | |
| 64 | Layout/Side | ALLIED | `NoteLabel` (default 22, faded) | |
| 65 | Options/Option | OPTION: OFF | `Button` (default 22) | |
| 66 | Options/OptionNote | what the option does | `NoteLabel` (default 22, faded) | |
| 67 | Pilot/Key | KEY | `NoteLabel` (default 22, faded) | |
| 68 | Pilot/Value | VALUE | `Label` (default 22) | |
| 69 | Layout/Note | THE GAME IS PAUSED WHILE THIS IS OPEN. T… | `NoteLabel` (default 22, faded) | |

## Map window

| # | Where | Shows | Look (font) | Change to |
|---|---|---|---|---|
| 70 | Header/Title | MAP | `TitleLabel` (large 33) | |
| 71 | TabSector | [SECTOR] | `TabButton` (default 22, lighter fill) | |
| 72 | TabGlobal | GLOBAL | `TabButton` (default 22, lighter fill) | |
| 73 | ButtonClose | CLOSE | `Button` (default 22) | |
| 74 | ButtonZoomIn | + | `SymbolButton` (menu 50) | |
| 75 | ButtonZoomOut | − | `SymbolButton` (menu 50) | |
| 76 | ButtonFit | FIT | `Button` (default 22) | |
| 77 | ButtonCentre | CENTRE ON SHIP | `Button` (default 22) | |
| 78 | Side/Info | TAP A THING TO SEE IT. | `Label` (default 22) | |
| 79 | ButtonTarget | TARGET | `Button` (default 22) | |
| 80 | Layout/Note | THE GAME IS PAUSED WHILE THIS IS OPEN. D… | `NoteLabel` (default 22, faded) | |
| 81 | map_window.gd: filter switches | SHIPS: ON | `Button` (default 22) | |
| 82 | map_view.gd: names on the map (drawn) | ELACE, FREE PORT ... | `SmallLabel` (small 18) | |
| 83 | map_view.gd: scale bar (drawn) | 10 km | `SmallLabel` (small 18) | |

## Options window

| # | Where | Shows | Look (font) | Change to |
|---|---|---|---|---|
| 84 | Header/Title | OPTIONS | `TitleLabel` (large 33) | |
| 85 | ButtonClose | CLOSE | `Button` (default 22) | |
| 86 | Layout/Note | THE GAME IS PAUSED WHILE THIS IS OPEN. T… | `NoteLabel` (default 22, faded) | |
| 87 | options_window.gd: category tabs | GAME, DISPLAY ... | `TabButton` (default 22, lighter fill) | |
| 88 | options_window.gd: row names | SAVE ON DOCKING | `LargeLabel` (large 33) | |
| 89 | options_window.gd: row values (OFF grey) | ON, x1.0, 100% | `LargeValueLabel` (large 33, amber) | |

## Pilot window

| # | Where | Shows | Look (font) | Change to |
|---|---|---|---|---|
| 90 | Header/Title | PILOT | `TitleLabel` (large 33) | |
| 91 | ButtonClose | CLOSE | `Button` (default 22) | |
| 92 | Layout/Summary | the window's summary lines | `Label` (default 22) | |
| 93 | Layout/Note | THE GAME IS PAUSED WHILE THIS IS OPEN. | `NoteLabel` (default 22, faded) | |
| 94 | ship_stats.gd (same cells as docked) | captions and values | `StatCaption` (small 18, faded) | |

## Ship window

| # | Where | Shows | Look (font) | Change to |
|---|---|---|---|---|
| 95 | Header/Title | SHIP | `TitleLabel` (large 33) | |
| 96 | ButtonClose | CLOSE | `Button` (default 22) | |
| 97 | Layout/Summary | the window's summary lines | `Label` (default 22) | |
| 98 | Layout/Note | THE GAME IS PAUSED WHILE THIS IS OPEN. | `NoteLabel` (default 22, faded) | |
| 99 | ship_stats.gd (same cells as docked) | captions and values | `StatCaption` (small 18, faded) | |

## Prompts (yes/no questions)

| # | Where | Shows | Look (font) | Change to |
|---|---|---|---|---|
| 100 | Box/Title | SAVE BEFORE EXITING? | `TitleLabel` (large 33) | |
| 101 | Box/Text | UNSAVED PLAY IS LOST ON EXIT. | `Label` (default 22) | |
| 102 | Choices/Choice | SAVE AND EXIT, EXIT, CANCEL | `LargeButton` (large 33) | |

## Debug only (overlay, debug map)

Plain `Button` (default 22) for their buttons, `DebugLabel` (debug 18) for the readouts, `TitleLabel` for the debug map's title.
