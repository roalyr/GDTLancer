# UI labels and their looks

Every piece of text in the game UI and the named look (theme_type_variation) that sizes it; sizes are at UI SCALE x1.0. To change one, pick another look for the node in the Godot editor (Inspector, Theme, Type Variation) or change the look itself in the theme (CONTENT.md, "The UI's look"); **Change to** is left for notes. The 2026-11-22 requests are applied; row 87 (the options' Info/Value) was removed. The words themselves are in database/strings/strings.json (CONTENT.md, "Words and languages"); "Shows" is the English. The looks are listed in CONTENT.md ("Labels use the shared sizes"). Generated 2026-11-22; debug-only text is at the end. Every tab, while open, reads in brackets in its look's amber open twin (`TabButtonOpen`, `LargeTabButtonOpen`).

## HUD: top strip

| # | Where                                   | Shows                    | Look (font)             | Change to |
|---|-----------------------------------------|--------------------------|-------------------------|-----------|
| 1 | TargetRow/Name                          | TARGET                   | `LargeLabel` (large 33) |           |
| 2 | Distance                                | 0                        | `LargeLabel` (large 33) |           |
| 3 | Threat                                  | —                        | `Label` (default 22)    |           |
| 4 | Speed                                   | 0 M/S                    | `Label` (default 22)    |           |
| 5 | Radio                                   | —                        | `SmallLabel` (small 18) |           |
| 6 | awareness_zone: HudBar captions (drawn) | HULL, ENERGY, CARGO, SIG | `Label` (default 22)    |           |
| 7 | awareness_zone: ship pips "+" (drawn)   | + past the shown pips    | `Label` (default 22)    |           |

## HUD: buttons and sliders

| #  | Where                                      | Shows          | Look (font)          | Change to |
|----|--------------------------------------------|----------------|----------------------|-----------|
| 8  | LabelContainer/LabelZoomSlider             | ZOOM           | `Label` (default 22) |           |
| 9  | ButtonOrbit/LabelButtonOrbit               | ORBIT          | `Label` (default 22) |           |
| 10 | ButtonStop/LabelButtonStop                 | STOP           | `Label` (default 22) |           |
| 11 | ButtonManualFlight/LabelButtonManualFlight | MANUAL         | `Label` (default 22) |           |
| 12 | ButtonApproach/LabelButtonApproach         | APPROACH       | `Label` (default 22) |           |
| 13 | ButtonFlee/LabelButtonFlee                 | FLEE           | `Label` (default 22) |           |
| 14 | ButtonDock/LabelButtonDock                 | DOCK           | `Label` (default 22) |           |
| 15 | ButtonInteract/LabelButtonInteract         | INTERACT       | `Label` (default 22) |           |
| 16 | ButtonTool1/Label                          | TOOL 1         | `Label` (default 22) |           |
| 17 | ButtonTool2/Label                          | TOOL 2         | `Label` (default 22) |           |
| 18 | ButtonTool3/Label                          | TOOL 3         | `Label` (default 22) |           |
| 19 | ButtonTool4/Label                          | TOOL 4         | `Label` (default 22) |           |
| 20 | ButtonLance/Label                          | LANCE          | `Label` (default 22) |           |
| 21 | ButtonAfterburner/Label                    | BURN           | `Label` (default 22) |           |
| 22 | ButtonSafety/Label                         | SAFETY         | `Label` (default 22) |           |
| 23 | ButtonHudLook/LabelButtonHudLook           | HUD / STANDARD | `Label` (default 22) |           |
| 24 | LabelContainer/LabelThrustSlider           | THRUST         | `Label` (default 22) |           |
| 25 | main_hud.gd: FPS readout                   | FPS 60         | `Label` (default 22) |           |
| 26 | main_hud.gd: tool rows' key numbers        | 1 2 3 ... 0    | `Label` (default 22) |           |

## HUD: target brackets

| #  | Where                                                 | Shows  | Look (font)             | Change to |
|----|-------------------------------------------------------|--------|-------------------------|-----------|
| 27 | DistanceLabel                                         | 0000k  | `Label` (default 22)    |           |
| 28 | InfoLabel                                             | TARGET | `Label` (default 22)    |           |
| 29 | projected_target_bracket.gd: distance, while selected | 1.2 km | `LargeLabel` (large 33) |           |

## HUD: announcements

| #  | Where | Shows | Look (font)          | Change to |
|----|-------|-------|----------------------|-----------|
| 30 | Label | —     | `Label` (default 22) |           |

## Main menu

| #  | Where                                     | Shows       | Look (font)                                          | Change to |
|----|-------------------------------------------|-------------|------------------------------------------------------|-----------|
| 31 | LabelContainerControl/LabelButtonNew      | New         | `MenuLabel` (menu 50)                                |           |
| 32 | LabelContainerControl/LabelButtonLoad     | Load        | `MenuLabel` (menu 50)                                |           |
| 33 | LabelContainerControl/LabelButtonSave     | Save        | `MenuLabel` (menu 50)                                |           |
| 34 | LabelContainerControl/LabelButtonSettings | Settings    | `MenuLabel` (menu 50)                                |           |
| 35 | LabelContainerControl/LabelButtonExit     | Exit        | `MenuLabel` (menu 50)                                |           |
| 36 | TitleLabel                                | GDTLancer   | `MenuTitleLabel` (menu title 100)                    |           |
| 37 | TimeLabel                                 | 14:45       | `MenuLabel` (menu 50)                                |           |
| 38 | VersionLabel                              | version 0.1 | `MenuLabel` (menu 50)                                |           |
| 39 | ButtonClose                               | CLOSE       | `MainMenuButton` (menu 50); shown only during a game |           |

## Docked window

| #  | Where                                     | Shows                      | Look (font)                            | Change to |
|----|-------------------------------------------|----------------------------|----------------------------------------|-----------|
| 40 | ButtonMenu                                | MENU                       | `Button` (default 22)                  |           |
| 41 | TabFitting                                | [FITTING]                  | `TabButton` (default 22, lighter fill) |           |
| 42 | TabMarket                                 | MARKET                     | `TabButton` (default 22, lighter fill) |           |
| 43 | Header/Title                              | HOME STATION               | `Label` (default 22)                   |           |
| 44 | ButtonUndock                              | UNDOCK                     | `CloseButton` (large 33, amber)        |           |
| 45 | Ship/Title                                | SHIP - tap a slot to unfit | `HeadingLabel` (large 33, amber)       |           |
| 46 | Storage/Title                             | STORAGE - fit or sell      | `HeadingLabel` (large 33, amber)       |           |
| 47 | Store/Title                               | STORE                      | `HeadingLabel` (large 33, amber)       |           |
| 48 | Content/Status                            | —                          | `Label` (default 22)                   |           |
| 49 | ship_stats.gd: stat captions              | HULL, POWER, CHARGE ...    | `StatCaption` (small 18, faded)        |           |
| 50 | ship_stats.gd: stat values (look by stat) | 85, 117, +6/s, 31 ...      | `StatHull` (medium 28, white)          |           |
| 51 | fitting_window.gd: store tabs             | SHIPS, WEAPONS ...         | `TabButton` (default 22, lighter fill) |           |

## Docked window: rows, headings, notes (made per item)

| #  | Where                               | Shows | Look (font)                       | Change to |
|----|-------------------------------------|-------|-----------------------------------|-----------|
| 52 | fitting_button: Button              | —     | `Button` (default 22)             |           |
| 53 | fitting_group_heading: GroupHeading | —     | `HeadingButton` (large 33, amber) |           |
| 54 | fitting_heading: Heading            | —     | `HeadingLabel` (large 33, amber)  |           |
| 55 | fitting_note: Note                  | —     | `NoteLabel` (default 22, faded)   |           |
| 56 | fitting_row: Text/Name              | —     | `Label` (default 22)              |           |
| 57 | fitting_row: Text/Detail            | —     | `NoteLabel` (default 22, faded)   |           |
| 58 | fitting_row_button: Button          | —     | `Button` (default 22)             |           |
| 59 | hull_preview: Name                  | —     | `Label` (default 22)              |           |

## Interaction window

| #  | Where              | Shows                                     | Look (font)                               | Change to |
|----|--------------------|-------------------------------------------|-------------------------------------------|-----------|
| 60 | Header/Title       | INTERACT                                  | `TitleLabel` (large 33)                   |           |
| 61 | ButtonClose        | CLOSE                                     | `CloseButton` (large 33, amber)           |           |
| 62 | ButtonAsk          | ASK                                       | `LargeTabButton` (large 33, lighter fill) |           |
| 63 | ButtonPilot        | PILOT                                     | `LargeTabButton` (large 33, lighter fill) |           |
| 64 | Layout/Side        | ALLIED                                    | `NoteLabel` (default 22, faded)           |           |
| 65 | Options/Option     | OPTION: OFF                               | `LargeButton` (large 33)                  |           |
| 66 | Options/OptionNote | —                                         | `NoteLabel` (default 22, faded)           |           |
| 67 | Pilot/Key          | KEY                                       | `NoteLabel` (default 22, faded)           |           |
| 68 | Pilot/Value        | VALUE                                     | `Label` (default 22)                      |           |
| 69 | Layout/Note        | THE GAME IS PAUSED WHILE THIS IS OPEN. T… | `SmallNoteLabel` (small 18, faded)        |           |

## Map window

| #  | Where                                 | Shows                                     | Look (font)                              | Change to |
|----|---------------------------------------|-------------------------------------------|------------------------------------------|-----------|
| 70 | Header/Title                          | MAP                                       | `TitleLabel` (large 33)                  |           |
| 71 | TabSector                             | [SECTOR]                                  | `TabButton` (default 22, lighter fill)   |           |
| 72 | TabGlobal                             | GLOBAL                                    | `TabButton` (default 22, lighter fill)   |           |
| 73 | ButtonClose                           | CLOSE                                     | `CloseButton` (large 33, amber)          |           |
| 74 | ButtonZoomIn                          | +                                         | `SymbolButton` (menu 50, lighter fill)   |           |
| 75 | ButtonZoomOut                         | −                                         | `SymbolButton` (menu 50, lighter fill)   |           |
| 76 | ButtonFit                             | FIT                                       | `LightButton` (default 22, lighter fill) |           |
| 77 | ButtonCentre                          | CENTRE ON SHIP                            | `LightButton` (default 22, lighter fill) |           |
| 78 | Side/Info                             | TAP A THING TO SEE IT.                    | `NoteLabel` (default 22, faded)          |           |
| 79 | ButtonTarget                          | TARGET                                    | `Button` (default 22)                    |           |
| 80 | Layout/Note                           | THE GAME IS PAUSED WHILE THIS IS OPEN. D… | `SmallNoteLabel` (small 18, faded)       |           |
| 81 | map_window.gd: filter switches        | SHIPS: ON                                 | `Button` (default 22)                    |           |
| 82 | map_view.gd: names on the map (drawn) | ELACE, FREE PORT ...                      | `SmallLabel` (small 18)                  |           |
| 83 | map_view.gd: scale bar (drawn)        | 10 km                                     | `SmallLabel` (small 18)                  |           |

## Options window

| #  | Where                                    | Shows                                     | Look (font)                               | Change to |
|----|------------------------------------------|-------------------------------------------|-------------------------------------------|-----------|
| 84 | Header/Title                             | OPTIONS                                   | `TitleLabel` (large 33)                   |           |
| 85 | ButtonClose                              | CLOSE                                     | `CloseButton` (large 33, amber)           |           |
| 86 | Info/Title                               | the tapped option (right half)            | `HeadingLabel` (large 33, amber)          |           |
| 88 | Info/Text                                | what it does                              | `LargeLabel` (large 33)                   |           |
| 89 | Info/Values                              | the values it takes                       | `NoteLabel` (default 22, faded)           |           |
| 90 | Layout/Note                              | THE GAME IS PAUSED WHILE THIS IS OPEN. T… | `SmallNoteLabel` (small 18, faded)        |           |
| 91 | options_window.gd: category tabs         | GAME, GRAPHICS, SOUND, INTERFACE          | `LargeTabButton` (large 33, lighter fill) |           |
| 92 | options_window.gd: row names             | SAVE ON DOCKING                           | `Label` (default 22)                      |           |
| 93 | options_window.gd: row values (OFF grey) | ON, x1.0, 100%                            | `LargeValueLabel` (large 33, amber)       |           |

## Pilot window

| #  | Where                                | Shows                                  | Look (font)                        | Change to |
|----|--------------------------------------|----------------------------------------|------------------------------------|-----------|
| 94 | Header/Title                         | PILOT                                  | `TitleLabel` (large 33)            |           |
| 95 | ButtonClose                          | CLOSE                                  | `CloseButton` (large 33, amber)    |           |
| 96 | Layout/Summary                       | —                                      | `Label` (default 22)               |           |
| 97 | Layout/Note                          | THE GAME IS PAUSED WHILE THIS IS OPEN. | `SmallNoteLabel` (small 18, faded) |           |
| 98 | ship_stats.gd (same cells as docked) | captions and values                    | `StatCaption` (small 18, faded)    |           |

## Ship window

| #   | Where                                | Shows                                  | Look (font)                        | Change to |
|-----|--------------------------------------|----------------------------------------|------------------------------------|-----------|
| 99  | Header/Title                         | SHIP                                   | `TitleLabel` (large 33)            |           |
| 100 | ButtonClose                          | CLOSE                                  | `CloseButton` (large 33, amber)    |           |
| 101 | Layout/Summary                       | —                                      | `Label` (default 22)               |           |
| 102 | Layout/Note                          | THE GAME IS PAUSED WHILE THIS IS OPEN. | `SmallNoteLabel` (small 18, faded) |           |
| 103 | ship_stats.gd (same cells as docked) | captions and values                    | `StatCaption` (small 18, faded)    |           |

## Prompts (yes/no questions)

| #   | Where          | Shows | Look (font)                      | Change to |
|-----|----------------|-------|----------------------------------|-----------|
| 104 | Box/Title      | —     | `HeadingLabel` (large 33, amber) |           |
| 105 | Box/Text       | —     | `Label` (default 22)             |           |
| 106 | Choices/Choice | —     | `Button` (default 22)            |           |

## Debug only (overlay, debug map)

Plain `Button` (default 22) for their buttons, `DebugLabel` (debug 18) for the readouts, `TitleLabel` for the debug map's title.
