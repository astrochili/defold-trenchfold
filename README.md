![logo](https://user-images.githubusercontent.com/4752473/179576684-bea03ccb-0b52-4346-819a-927e4d5d3c0e.jpg)
[![astronachos](https://raw.githubusercontent.com/astronachos/astronachos.github.io/master/static/badges/astronachos.svg)](https://astronachos.com) [![twitter](https://raw.githubusercontent.com/astronachos/astronachos.github.io/master/static/badges/twitter.svg)](https://twitter.com/astronachos) [![telegram](https://raw.githubusercontent.com/astronachos/astronachos.github.io/master/static/badges/telegram.svg)](https://t.me/astronachos) [![buymeacoffee](https://raw.githubusercontent.com/astronachos/astronachos.github.io/master/static/badges/buymeacoffee.svg)](https://www.buymeacoffee.com/astrochili) [![tinkoff](https://raw.githubusercontent.com/astronachos/astronachos.github.io/master/static/badges/tinkoff.svg)](https://www.tinkoff.ru/cf/4B9FjHDHA5a)

# TrenchBroom extension for Defold

📼 Also in this series:
- 👖 [Kinematic Walker](https://github.com/astrochili/defold-kinematic-walker)
- 🎥 [Operator](https://github.com/astrochili/defold-operator)
- 🎄 [Illumination](https://github.com/astrochili/defold-illumination)
- 🚧 [Blockout Textures](https://github.com/astrochili/blockout-textures)

## Overview

This is a kit of game configuration files and importing scripts to design your level with [TrenchBroom](https://trenchbroom.github.io/) and export it to [Defold](https://defold.com/) as the collection.

TrenchBroom was originally created to design Quake-format levels, but thanks to its flexible game configurations it's suitable for any other game with low-polygon level geometry. It's cross-platform, has a great [manual](https://trenchbroom.github.io/manual/latest/) and usability.

🎮 [Play HTML5 demo](https://astronachos.com/defold/trenchbroom).

💬 [Discuss on the forum](https://forum.defold.com/t/trenchbroom-extension-for-defold/71284).

🧪 Look at [Retro Texture Pack](https://little-martian.itch.io/retro-texture-pack) by [Little Martian](https://little-martian.dev/) used in the demo.

## Features

- [x] Convert level geometry to meshes and collision objects.
- [x] Use flag textures and checkboxes to define faces behavior.
- [x] Place triggers, kinematic or dynamic bodies.
- [x] Convert entities to game objects.
- [x] Attach file components to your entities.
- [x] Set custom entity properties and read them from the game logic.
- [x] Define areas and handle their coordinates in scripts.
- [x] Run importing with the editor script or the standalone lua module.
- [x] Expand the game configuration file with your own classes.
- [ ] Request by [adding an issue or contribute](https://github.com/astrochili/defold-trenchbroom/issues).

## Running the Example

To run the example project, you first need to run two editor extension functions on a map file provided, according the [Export and Import](#export-and-import) part.

With the project open in Defold, right click on the [level.map](https://github.com/astrochili/defold-trenchbroom/blob/master/assets/maps/level/level.map) file then click on `Prepare Map Components Folders`. Next right click on the .map file and click `Convert Map to Collection`. This will create a variety of folders and files next to the .map file. You can now build and run the example. 

## Install

1. Add link to the zip-archive of the latest version of [defold-trenchbroom](https://github.com/astrochili/defold-trenchbroom/releases) to your Defold project as [dependency](http://www.defold.com/manuals/libraries/).
2. Copy the `trenchbroom/games/Defold` folder according [this instruction](https://trenchbroom.github.io/manual/latest/#game_configuration_files) to TrenchBroom user data folder.
3. Place your texture packs at path `assets/textures` to use them in TrenchBroom.
4. Set your game project path as the game path in TrenchBroom preferences when creating the first map.
5. Setup `textel_size` and `material` in the [worldspawn](#worldspawn) entity.

## Export and Import

### Export

Before import you need to export `.obj` file from TrenchBroom by menu `File / Export / Wavefront OBJ`. The importing script uses `.obj` data to parse vertices, so it must be done every time the geometry is changed.

It would be possible to skip this step by solving the issue [#1](https://github.com/astrochili/defold-trenchbroom/issues/1).

### Import with Editor Script

Find your `.map` file in the resources pane of the editor and right click on it to see two actions.

1. `Prepare Map Components Folders`. It clears and creates the required folders for file components. It's required to do before the next action.
2. `Convert Map to Collection`. It does the magic and creates the collection file and all the components files: buffers, meshes, convexshapes, collisionobjects and some scripts.

These actions are separated because of the editor scripts limitation, upvote for the Defold issue [#6810](https://github.com/defold/defold/issues/6810).

### Import with Lua Module

There is also the `trenchbroom/cli.lua` module to run the import script outside the editor. Just pass it two arguments - `relative/map_folder` and `map_name`. It will do everything, including preparing folders. For example, you can add the launch task to VSCode to run it.

## Textures

![](https://user-images.githubusercontent.com/4752473/179556704-78346b90-569b-419d-a5b1-e3ed35555ab4.png)

The game configuration includes marking textures at `flags/textures`. They are handled by the exporting script to provide specific behaviour to the faces without normal textures.

### unused

This face will be skipped when exporting.

Use it to remove useless faces from the geometry. 

### clip

Creates a collision object without texture.

Use it to create invisible walls and useful collision geometry.

### trigger

Creates a trigger collision object.

### area

Doesn't create collision objects but its vertices positions will be sent to the object with the `init_area` message.

Use it to process the area programmaticaly.

## Flags

There are few content flags in the face properties.

### ghost

The face isn't solid and doesn't generate a collision object vertices.

Use it on objects that can be passed through or that the player will never reach.

### separated

The face generates a separate plane collision object.

A rare use case is when you have a wall corner with two solid faces and you don't want to create a triangular prism collision shape on its vertices.

## Entities

![](https://user-images.githubusercontent.com/4752473/179557292-05914789-7700-4f4b-931c-51fd5961bf98.png)

There are brush entities and point entities. The difference is that a brush entity contains geometry brushes, while the point entity has only an origin position and rotation.

### worldspawn

The default entity for all the geometry outside of the other entities. Also has some general settings of exporting.

- `textel_size` — how much Trenchbroom grid units are equal to one unit in Defold metrics. 
- `material` — the relative path to the material that will be used for generated meshes by default.
- `textureN` — path to the texture where `N` is number from `1` to `7`. See [texture path patterns](#texture-path-patterns).
- `physics_*` — collision object properties used by default.

### static*

A brush entity with the static collision type. The only reason to use it is to attach components and set properties because the `worldspawn` is static by default. To use [areas](#area) or destroy parts of the level, e.g.

- `id` — the identifier of the game object.
- `#component_id` — the relative path to the file component that will be attached to this game object as `component_id`.
- `#component_id.property` — the script component property override.
- `material` — the relative path to the material that will be set in generated meshes.
- `textureN` — path to the texture where `N` is number from `1` to `7`. See [texture path patterns](#texture-path-patterns).
- `physics_*` — collision object properties related to static collision type.

### trigger*

To be fair, triggers are created by the [trigger](#trigger) texture, not the entity. But you also need to put scripts and parameters on this trigger, so which is what this entity is for.

If you place brushes with normal textures to this entity they also become triggers.

- `id` — the identifier of the game object.
- `#component_id` — the relative path to the file component that will be attached to this game object as `component_id`.
- `#component_id.property` — the script component property override.
- `physics_*` — collision object properties related to trigger collision type.

### kinematic*

A brush entity with the kinematic collision type. Use it for moving platforms or sliding doors, for example.

- `id` — the identifier of the game object.
- `#component_id` — the relative path to the file component that will be attached to this game object as `component_id`.
- `#component_id.property` — the script component property override.
- `material` — the relative path to the material that will be set in generated meshes.
- `textureN` — path to the texture where `N` is number from `1` to `7`. See [texture path patterns](#texture-path-patterns).
- `physics_*` — collision object properties related to kinematic collision type.

### dynamic*

A brush entity with dthe ynamic collision type. This could be, for example, a crate that the player can move.

- `id` — the identifier of the game object.
- `#component_id` — the relative path to the file component that will be attached to this game object as `component_id`.
- `#component_id.property` — the script component property override.
- `material` — the relative path to the material that will be set in generated meshes.
- `textureN` — path to the texture where `N` is number from `1` to `7`. See [texture path patterns](#texture-path-patterns).
- `physics_*` — collision object properties related to dynamic collision type.

### go

This is a point entity to add a game object without meshes and collision objects. You can attach any file components to it or replace it with you `.go` file.

- `origin` — the position of the game object that defined automatically when you place it.
- `angle` — the Y-axis rotation of the game object that defined automatically when you rotate it.
- `rotation` — X, Y and Z-axis rotation of the game object. Y-axis will be ignored if the `angle` property exists.
- `id` — the identifier of the game object.
- `go` — the relative path to the `.go` file that should replace the entity.
- `#component_id` — the relative path to the file component that will be attached to this game object as `component_id`. Ignored if the `go` property exists. 
- `#component_id.property` — the script component property override.

### illumination, light_point, light_spot

These are helpers for placing 💡 [Illumination](https://github.com/astrochili/defold-illumination) objects on the map. Don't forget to fill the `go` property with default value.

## Texture Path Patterns

The `textureN` property allows to set additional material textures 1-7. The next patterns are available:

- `/path/to/texture.png` — a specific texture.
- `/path/to/prefix_*_suffix.png` — a specific path where * is texture0 original name.
- `/path/to/alternative/*` — a specific folder with the same texture file name.
- `prefix_*_suffix.png` — the same folder.
- `prefix_*_suffix` — the same folder and extension.

## Custom Properties

All the custom properties will be a part of the script component with the `properties` identifier that attached to the game object. These properties can be accessed in runtime by calling `go.get()`.

```lua
go.get('#properties', 'property')
```

### bool

The values `true` and `false` are converted to boolean.

### number

The value which can be handled with `tonumber()` is converted to number.

If the number is flags value then you can parse it with `utils.flags_from_integer(value)` from the `trenchbroom/utils.lua` module.

### vectors

- Value `x y` is converted to `math.vector3(x, y, 0)`.
- Value `x y z` is converted to `math.vector3(x, y, w)`.
- Value `x y z w` is converted to `math.vector4(x, y, z, w)`.

### *url

Property ending with `url` is converted to `msg.url('value')`.

### hash

Any other string property is converted to `hash 'value'`.

# Credits

- [TrenchBroom](https://trenchbroom.github.io/) by [Kristian Duske](https://twitter.com/kristianduske).
- [Retro Texture Pack](https://little-martian.itch.io/retro-texture-pack) by [Little Martian](https://little-martian.dev/).