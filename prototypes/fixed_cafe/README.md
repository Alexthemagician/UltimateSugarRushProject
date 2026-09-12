# Sugar & Sunshine — fixed-view café study

A standalone Godot 4.7 project. It does not load or modify the main game's boards, progression, café, or save data.

Open `project.godot` in Godot and press F6 on `cafe.tscn`, or run `launch.ps1`.

Four selectable stations: bakery, coffee bar, candy workshop, and cake atelier. Click a station or its lower button. The orthographic camera stays fixed. Steam animates above the espresso cup.

All furniture and details are actual procedural 3D geometry, built in one coordinate system with a shared material palette and lighting. No generated meshes or separately projected station images are used.

Visual development passes are preserved as `pass_01.png` through `pass_09.png`. The ninth pass is the current appearance: cartoon light bands, glazed painted surfaces with soft sheen, colour-matched ink outlines, and additional station props. The counter lettering has been removed. This is a desktop visual prototype using Godot Forward+; it is not integrated with gameplay or optimized for Android yet.

Validation:
`godot --headless --path . --script verify.gd`

Render:
`godot --path . --resolution 1080x1200 -- --capture`


