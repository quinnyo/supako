# Supako: 2D Geometry Thing for Godot

Supako is a 2D geometry drawing system/thing addon for Godot 4.
*It do shapes.*

> NOTE: This project is in an experimental / prototype state.
> I wouldn't recommend using this in production, but you might find some bits useful or interesting...


## What's it for?
* More complicated stuff than Godot's `Polygon2D`
* 2D games that aren't tile-based
* Semi-procedural 2D geometry
* Draw many unique shapes (re-)using a shared pattern


## Features
* Fine-grained rendering / appearance control
* Efficient collision shape extraction
* Effect system provides modularity and extensibility
* Boolean operations to build complex shapes
* Select segments used by effects by surface normal (angle ranges)


### Incomplete/Unimplemented
* Open paths (polylines) and effects to work with them
* Logical materials / regions
* Attach arbitrary metadata/userdata to geometry, vertex groups
* Generic geometry masking / selection -- mask geometry accessible to any effect
* More robust polygon clipping operations (and support for holes)
* Overridable effect configuration -- optionally set effect parameters in host shape (rather than in the Effect Resource)
* Multi/meta effects -- new effects via composition


## Usage | How it works
Supako drawings are constructed in the Godot scene tree using *shape nodes* (`SpkoShape`).
* Create a drawing by adding any `SpkoShape`-derived node to a scene.
* Note that `SpkoShape` itself is a base class and doesn't provide any way to add geometry manually.
  * `SpkoPath` is a shape node with a manually editable polygon. It can be edited in the 2D scene editor, in a similar way to Godot's built-in `Polygon2D`.
* Child shapes can be merged with their parent by inclusion or via boolean/clipping operations, depending on the merge operation property of the child.

Effects are a modular way to add functionality to shapes.
* Each shape's geometry gets processed by its *effects chain*
* Effects are processed in order. This can be taken advantage of to e.g. extract simplified collision shapes before bevelling the corners.
* Create new effects by extending `SpkoEffect` (a type of `Resource`)

Where possible, features are implemented as effects to avoid bloating `SpkoShape`.
Built-in effects include:
* *Fill Painter* draws polygon interior
* *Stroke Painter* draws polygon edges
* *Collision Shape* builds collision shape/s and a static body or area
* *Corners* adds chamfers/fillets to sharp corners
* *Decorator* adds decorations/sprites to surfaces
