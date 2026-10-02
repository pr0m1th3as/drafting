# drafting

Planar geometry, CAD input and output, and a technical drawing model for GNU
Octave.

The package provides the drafting layer an engineering design package needs:
compute geometry, build a drawing from it, and emit that drawing as a DXF file a
CAD program or a CNC machine will accept, as a solid for a slicer, as LaTeX for
a report, or as a figure on screen. Solids proper, built, combined and
exchanged as STEP, come through Open CASCADE when the package is built with it.

Forty-three public functions across five namespaces plus the
`draw.Drawing`, `solid.Shape` and `solid.Viewer` classes, 1123 built-in
self-tests and 67 `%!demo` blocks,
nearly all of which end in a `plot` call, so the documentation shows what a
function does rather than only describing it.

## Layout

```
inst/+geom    planar geometry (no file formats, no drawing semantics)
inst/+dxf     AutoCAD R12 (AC1009) ASCII DXF, both directions
inst/+stl     binary STL from a stack of planar sections
inst/+draw    format-agnostic drawing model, and the backends that render it
inst/+solid   solids through Open CASCADE, STEP and STL
inst/tests    classdef .m-tst suites
src           the compiled interface to Open CASCADE
```

Dependencies point downward only: `+draw` builds on `+geom` and emits through
`+dxf`; `+geom`, `+dxf` and `+stl` know nothing of drawings. `+solid` builds
on `+geom` and on Open CASCADE.

`+geom` covers primitives (signed area, bounding box, centroid, affine
transform, offset, largest inscribed rectangle, triangulation), curve geometry
(curvature, sampling, offsetting, self-intersection, arc length) and
construction geometry (line and circle intersections, tangent points, fillets).
Polylines can be resampled or simplified.

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
D = D.polyline ([-40, -40; 40, -40; 40, 40; -40, 40], true);
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

Solids come from the same planar model:

```
stl.write ('plate.stl', [-40, -40; 40, -40; 40, 40; -40, 40], [0, 6]);
```

`stl.write` also takes a struct array of sections, each with its own profile,
`z` range and holes, which expresses a stepped or eccentric shaft without
leaving the planar model. Each section is written as its own closed shell, so a
single section is a closed manifold and a stack of several is not. Slicers
union it without complaint; a tool demanding one closed surface will not.

`+solid` models solids through [Open CASCADE](https://dev.opencascade.org/),
the kernel FreeCAD is built on, so curved faces stay exact. `solid.Shape` holds
a solid, with the booleans `union`, `subtract` and `intersect`, translation,
rotation, mirroring and scaling, and volume, area, centroid and bounding box;
`solid.box`, `solid.cylinder`, `solid.cone`, `solid.sphere` and `solid.torus`
make the primitives; `solid.extrude`, `solid.revolve`, `solid.loft`,
`solid.sweep` and `solid.helix` make a solid from planar profiles, with
bulges, as `draw.Drawing.polyline` takes them, carried as true arcs. Methods
drill holes (plain, counterbored, countersunk, tapping size), round and bevel
edges and hollow a shape, on edges and faces chosen by kind, direction and
position. `solid.read` reads STEP, and `solid.write` writes STEP for a CAD
program or STL for a slicer:

```
plate = solid.box (80, 40, 12);
plate = hole (plate, [20, 20, 12; 60, 20, 12], 'M8', Inf);
plate = fillet (plate, edges (plate, 'Direction', [0, 0, 1], ...
                              'Type', 'line'), 5);
solid.write ('plate.step', plate);
solid.write ('plate.stl', plate);

shaft = solid.revolve ([0, 0; 10, 0; 10, 30; 6, 30; 6, 50; 0, 50]);
```

`solid.show` shows a solid in a window Open CASCADE draws in a process of its
own, so a complex part turns smoothly and never holds up the prompt. Each call
redraws the same window and keeps the camera, and `solid.show ('part.m')`
runs a script again every time it is saved, as OpenSCAD's preview does.
`pick` on the viewer returns the edges and faces clicked, and prints the
`edges` or `faces` query that finds them again, for the script to use in place
of the numbers:

```
V = solid.show (plate);
E = pick (V, 'edge');     # click edges, then press Enter
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

The viewer behind `solid.show` is a program of its own, built where the X11
headers are found as well, and needs Open CASCADE's visualization libraries:

  `sudo apt install libocct-visualization-dev libx11-dev`

If the headers are elsewhere, name their directory before installing, for
example `setenv ("OCCT_INC", "/opt/occt/include/opencascade")`; the libraries
must be where the linker finds them. Linux is supported first; Windows and
macOS are not yet.

After installation, type:
- `pkg load drafting` to load the **drafting** package.
- `news drafting` to review all the user visible changes since last version.
- `pkg test drafting` to run a test suite for all 46 functions and class
  definitions currently available and ensure that they work properly on your
  system.

## License

GPLv3. See [`COPYING`](COPYING).
