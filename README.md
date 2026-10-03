# drafting

Planar geometry, CAD input and output, and a technical drawing model for GNU
Octave.

The package provides the drafting layer an engineering design package needs:
compute geometry, build a drawing from it, and emit that drawing as a DXF file a
CAD program or a CNC machine will accept, as a solid for a slicer, as LaTeX for
a report, or as a figure on screen. Solids proper, built, combined and
exchanged as STEP, come through Open CASCADE when the package is built with it.

Forty-seven public functions across six namespaces plus the `draw.Drawing`,
`geom.Polyline`, `geom.Spline`, `geom.Region`, `geom.Path`, `geom.UCS`,
`polymesh.Mesh`, `solid.Shape`, `model.Assembly` and `model.Viewer` classes,
1851 built-in self-tests and 67 `%!demo` blocks, nearly all of which end in a
`plot` call, so the documentation shows what a function does rather than only
describing it.

## Layout

```
inst/+geom      planar geometry (no file formats, no drawing semantics)
inst/+dxf       AutoCAD R12 (AC1009) ASCII DXF, both directions
inst/+polymesh  STL, OBJ and PLY meshes read, written and cut
inst/+draw      format-agnostic drawing model, and the backends that render it
inst/+solid     solids through Open CASCADE, STEP and STL
inst/tests      classdef .m-tst suites
src             compiled code: meshes, and the interface to Open CASCADE
```

Dependencies point downward only: `+draw` builds on `+geom` and emits through
`+dxf`; `+geom`, `+dxf` and `+polymesh` know nothing of drawings. `+solid`
builds on `+geom` and on Open CASCADE.

`+geom` covers primitives (signed area, bounding box, centroid, affine
transform, offset, largest inscribed rectangle, triangulation), curve geometry
(curvature, sampling, offsetting, self-intersection, arc length) and
construction geometry (line and circle intersections, tangent points, fillets).
Polylines can be resampled or simplified.

Outlines and curves are value classes. A `geom.Polyline` is a DXF polyline,
open or closed: vertices `[x, y, bulge]` in a plane of its own, an origin, an x
axis and a normal, the xy plane unless told otherwise, so a sketch can be laid
on any face. A `geom.Spline` is a NURBS curve, drawn through points or given
by its control points, knots and weights, open or closed, an exact ellipse
among them. A `geom.Region` is a
closed area, one outline with holes of any shape in it, straight segments, arcs
and splines, checked to be valid; it is what a solid is made from. A
`geom.Path` is a route in 3-D of straight segments, arcs and splines, along
which a region is swept; its corners are rounded into bends with `fillet`.
Regions combine with `union`, `subtract` and `intersect` and grow or shrink
with `offset`, round, sharp or chamfered at the corners: OpenSCAD's 2-D
operations, with arcs exact, computed by Open CASCADE. `hull` wraps regions
and points as OpenSCAD's `hull` does, its lines truly tangent to the arcs, so
two circles make a lever and four a rounded plate. `geom.text` gives the
outlines of text in any installed font as regions, to extrude, engrave or
emboss. A region is resized, evenly or stretched, mirrored in a line, and
copied, in rows and columns or round a point, the copies united. Functions take the
classes; only their constructors take plain matrices.

`draw.Drawing` is a value class carrying lines, polylines with per-vertex
bulges, arcs, circles, ellipses, text, hatches, blocks and inserts, and a full
set of dimension entities (linear, diameter, radius and angular, plus centre
marks and leaders) on named layers with line types and colours. Drawings
compose: `transform` places one, `merge` assembles several into a sheet, and
`draw.titleblock` frames it.

## One lowering, three backends

`entities` lowers a `Drawing` into a flat entity list, and every backend
consumes that list rather than walking the drawing itself:

```
D = draw.Drawing ('plate');
D.Layer = 'OUTLINE';
D = D.polyline (geom.Polyline ([-40, -40; 40, -40; 40, 40; -40, 40], ...
                               'Closed', true));
D = D.circle ([0, 0], 25);

D.Layer = 'DIMENSIONS';
D = D.dim ([-40, -40], [40, -40], -12, 'horizontal');
D = D.diam ([0, 0], 25);

plot (D);                                # on screen
dxf.write ('plate.dxf', entities (D));   # to CAD
tex = tikz (D);                          # into a report
```

The figure therefore shows the entities the file will contain rather than a
more flattering rendering of them. This is not a stylistic preference: before
the backends were unified, `draw.tikz` rendered from the drawing model directly
and silently ignored five entity types it had never been taught, producing a
plausible but incomplete figure.

Line-type dash lengths follow one rule everywhere: model units times a scale
factor, as CAD's `LTSCALE` does. `dxf.write` states `$LTSCALE` in the
header, so a written file's dashes no longer depend on the recipient's setting.

`draw.fromentities` is the inverse of `entities`: it raises an entity list read
from a file, with its block definitions, back into a `Drawing`. Dimensions come
back as dimensions and measure their geometry again, so a DXF is a round trip
rather than a one-way door.

`polymesh.read` reads an STL, OBJ, PLY or 3MF file, binary or ASCII, into a
`polymesh.Mesh`, with the colours of its vertices or faces where the file has
them, cutting faces of more than three corners into triangles and welding the
corners an STL file repeats. Its `write` saves a mesh to any of the three, OBJ
and PLY exactly, and its `section` cuts it with the plane of a `geom.UCS` into
`geom.Region` objects, as `solid.Shape.section` cuts a solid, healing small gaps
in the mesh to a tolerance and returning what will not close; the regions build
solids like any others. `fit` on a region turns the cut's facets back into
lines, arcs and splines within a tolerance, absolute or relative, so a faceted
bore is a circle again and a filleted corner an arc. All of them are compiled
and need nothing but Octave:

```
M = polymesh.read ('bracket.stl');
R = section (M, geom.UCS ([0, 0, 1], [0, 0, 5]));
R = fit (R{1}, 'arcs', 'AbsTol', 0.01);
```

`+solid` models solids through [Open CASCADE](https://dev.opencascade.org/), the
kernel FreeCAD is built on, so curved faces stay exact. `solid.Shape` holds a
solid, each of its parts in a colour of its own if wished, with the booleans
`union`, `subtract` and `intersect`, translation, rotation, mirroring and
scaling, resizing to a box, evenly or stretched, copies in rows, columns and
layers or round an axis, the convex hull of shapes and points, and volume, area,
centroid and bounding box; `solid.box`, `solid.wedge`, `solid.cylinder`,
`solid.cone`, `solid.sphere`, `solid.ellipsoid` and `solid.torus` make the
primitives, placed in a `geom.UCS` by a corner, the centre of the base or the
centroid; `solid.extrude`, `solid.revolve`, `solid.loft`, `solid.sweep` and
`solid.helix` make a solid from a `geom.Region`, where the region's plane puts
it, its arcs carried as true arcs and its holes right through. Methods drill
holes (plain, counterbored, countersunk, tapping size), cut pockets, round and
bevel edges and hollow a shape, on edges and faces chosen by kind, direction and
position. `section` cuts a solid with a plane into regions exact enough to build
from again, and `projection` gives its outline seen along a direction, the
shadow it casts, as OpenSCAD's `projection` does. `solid.polyhedron` makes a solid of a closed `polymesh.Mesh`,
so a mesh `polymesh.read` reads takes part in booleans like any other, and
`tessellate` turns a solid into a mesh within a tolerance. `solid.read` reads
STEP, and `solid.write` writes STEP for a CAD program, or STL, OBJ or PLY,
tessellated, for a slicer:

```
plate = solid.box (80, 40, 12);
plate = hole (plate, [20, 20, 12; 60, 20, 12], 'M8', Inf);
plate = fillet (plate, edges (plate, 'Direction', [0, 0, 1], ...
                              'Type', 'line'), 5);
solid.write ('plate.step', plate);
solid.write ('plate.stl', plate);

section = geom.Region ([0, 0; 10, 0; 10, 30; 6, 30; 6, 50; 0, 50]);
section.UCS = geom.UCS ([0, -1, 0], [0, 0, 0]);  # the xz plane: y is world z
shaft = solid.revolve (section);                  # turned about z
```

A `model.Assembly` places named parts, solids or meshes, in the frames of
`geom.UCS` objects, a part defined once however often it is placed, and
sub-assemblies the same way. `write` saves it to STEP with its structure, names
and colours, so a CAD program opens the product as it was built, or to 3MF, the
archive slicers take, each part a mesh written once and placed as often as it is
used; and `model.read` reads either back:

```
ring = model.Assembly ('ring');
ring = add (ring, 'plate', plate, geom.UCS ());
ring = add (ring, 'shaft', shaft, geom.UCS ([0, 0, 1], [20, 20, 12]));
write (ring, 'ring.step');
```

`show` shows a solid in a `model.Viewer`, a window Open CASCADE draws in a
process of its own, so a complex part turns smoothly and never holds up the
prompt. Every variable gets a window of its own, titled with its name; showing
it again redraws that window and keeps the camera, as does assigning to the
`Shape` of the viewer it returns. `pick` on the viewer returns the edges and
faces clicked, and prints the `edges` or `faces` query that finds them again,
for the script to use in place of the numbers:

```
V = show (plate);
E = pick (V, 'edge');     # click edges, then press Enter
U = geom.UCS (V);         # click a face, two points for +x, then the origin
```

A `geom.UCS` is a user coordinate system, a plane with an origin and axes of
its own. Every polyline and region lies in one, and assigning a region another
moves it there, so a profile drawn in the xy plane is laid on any face of a
part. It is made from a normal and points, or picked with the mouse as above,
and the pick prints the line that makes it again from coordinates.

The viewer shows a `polymesh.Mesh` as well, millions of triangles shaded facet
by facet in its faces' colours, its vertices' or grey, which the key C turns
between, with its triangle edges drawn when the key E asks for them. A UCS
picked on it, from a facet or three points snapped to corners and the middles of
sides, is the plane to cut it with, and `pick` returns points clicked on it with
the triangle each lies on:

```
M = polymesh.read ('bracket.stl');
V = show (M);
R = section (M, pickucs (V));
```

Open CASCADE is optional: a package built without it works as before, and
every `solid` function raises an error saying so.

All geometry is in millimetres.

## Why R12 rather than a later DXF revision

R12 needs no entity handles, no object dictionary and no class table, so the
files are small, readable and accepted essentially everywhere. The costs are
known and bounded: R12 has no `SPLINE` and no `LWPOLYLINE`, so polylines are
written as `POLYLINE` with a vertex list, which is what a manufacturing
toolpath wants in any case; it has no `ELLIPSE`, so an ellipse is sampled to a
closed polyline, and `draw.entities` records that as a loss; and it has no
`HATCH`, so a hatch is generated as explicit fill lines, which loses nothing:
the recipient sees the section hatched.

Nothing outside `dxf.write` depends on the choice.

## Documentation

Every function and class method is documented in
[texinfo](https://www.gnu.org/software/texinfo/), reachable from the Octave
prompt with `help`. Use dot notation for namespaced functions and for the
methods and properties of `draw.Drawing`:

```
help geom.offset
help draw.Drawing
help draw.Drawing.print
help draw.Drawing.Layer
```

You can also find the entire documentation of the **drafting** package along
with its function index at
[https://pr0m1th3as.github.io/drafting/](https://pr0m1th3as.github.io/drafting/).
Alternatively, you can build the online documentation locally using the
[`pkg-octave-doc`](https://github.com/gnu-octave/pkg-octave-doc) package.
Assuming both packages are installed and loaded, browse to any directory of
your choice with *write* permission and run:

```
package_texi2html ("drafting")
```

## Where it is going

[`ROADMAP.md`](ROADMAP.md) sets out what is planned and why, ordered by what
unblocks what. Just as usefully, it sets out what is deliberately out of
scope: no CAM, no DWG, no solid-modelling kernel of its own, no constraint
solver, each with the reason it was ruled out.

## Install

To install the latest release, you need Octave (>=11.1.0) installed on your
system. The **drafting** package has no further required dependencies. Install
it by typing:

  `pkg install drafting`

You can automatically download and install the latest development version of the
**drafting** package found [here](https://github.com/pr0m1th3as/drafting/archive/refs/heads/main.zip) by typing:

  `pkg install "https://github.com/pr0m1th3as/drafting/archive/refs/heads/main.zip"`

If you need to install a specific release, for example `0.1.0`, type:

  `pkg install "https://github.com/pr0m1th3as/drafting/archive/refs/tags/release-0.1.0.tar.gz"`

The `+solid` namespace needs Open CASCADE 7.8 or later at build time, and is
built only where its headers are found, by default in
`/usr/include/opencascade`. On Debian or Ubuntu, where the packaged version is
7.8 or later, install them before the package with:

  `sudo apt install libocct-foundation-dev libocct-modeling-data-dev libocct-modeling-algorithms-dev libocct-data-exchange-dev`

The viewer behind `model.Viewer` is a program of its own, built where the X11
headers are found as well, and needs Open CASCADE's visualization libraries,
which `geom.text` needs too:

  `sudo apt install libocct-visualization-dev libx11-dev`

If the headers are elsewhere, name their directory before installing, for
example `setenv ("OCCT_INC", "/opt/occt/include/opencascade")`; the libraries
must be where the linker finds them. Linux is supported first; Windows and
macOS are not yet.

After installation, type:
- `pkg load drafting` to load the **drafting** package.
- `news drafting` to review all the user visible changes since last version.
- `pkg test drafting` to run a test suite for all 50 functions and class
  definitions currently available and ensure that they work properly on your
  system.

## License

GPLv3. See [`COPYING`](COPYING).
