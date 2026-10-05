# drafting

Planar geometry, technical drawing and solid modelling for GNU Octave.

The package is the drafting layer an engineering design package builds on,
and an alternative to OpenSCAD written in Octave itself: compute geometry,
model a part, draw it, and send it to a CAD program as DXF or STEP, to a
slicer as STL or 3MF, to a report as LaTeX, or to the screen. Solids come
through [Open CASCADE](https://dev.opencascade.org/) when the package is built
with it. All geometry is in millimetres.

## What it does

- **Outlines and curves:** polylines with arcs, splines, paths in 3-D, and
  regions with holes, which combine, offset, round, hull, mirror and repeat as
  OpenSCAD's 2-D shapes do, their arcs kept exact; text as outlines.
- **Solids:** primitives, and extrusions, revolutions, lofts, sweeps and
  helices of regions; booleans; holes, pockets, fillets, chamfers and shells
  on edges and faces chosen by what they are; sections and projections that
  are regions again; STEP in and out.
- **Meshes:** STL, OBJ, PLY and 3MF read and written with their colours, cut
  into regions and fitted back to lines and arcs, and taken into booleans.
- **Assemblies:** named parts placed together, written to STEP and 3MF with
  their structure.
- **Technical drawings:** a drawing model with a layer table of colours, line
  types and line weights, dimensions, hatches, blocks and an ISO title block;
  plotted, printed to scale, set in TikZ and written to DXF.
- **A viewer:** Open CASCADE's own window, to turn a part, pick its edges and
  faces, and pick a coordinate system with the mouse.

## Layout

```
inst/+geom      outlines, curves and planar geometry, read and written as DXF
inst/+polymesh  STL, OBJ, PLY and 3MF meshes read, written and cut
inst/+draw      the drawing model, its backends, and drawings as DXF
inst/+solid     solids through Open CASCADE, STEP, and meshes for a slicer
inst/+model     assemblies of solids and meshes, and the viewer
src             compiled code: meshes, DXF, and the interface to Open CASCADE
```

`+geom` is the middle layer and depends on none of the others: solids are made
from its regions and cut back into them, meshes are cut into them, and
drawings are made of them. How each class becomes another is set out in the
guide's [Package layout](https://pr0m1th3as.github.io/drafting/guide/layout.html).

## DXF

DXF is read and written by compiled code that needs nothing but Octave: R2000
by default, R12 on request, and any ASCII file from R12 to R2018 read. A geom
object keeps its coordinate system in the file, and a drawing its layer
table, dimensions, hatches and blocks. What each class becomes in a file and
back is set out in the guide's
[DXF and the classes](https://pr0m1th3as.github.io/drafting/guide/dxf.html).

## Tutorials

The [guide](https://pr0m1th3as.github.io/drafting/guide/) has twelve tutorials
that build parts and drawings step by step. Every output and every picture on
them is made by the code above it.

1. [A first part](https://pr0m1th3as.github.io/drafting/guide/01_first_part.html):
   a mounting plate from outline to STEP and STL.
2. [Outlines: polylines, splines, paths and regions](https://pr0m1th3as.github.io/drafting/guide/02_outlines.html):
   the four classes every shape is drawn with.
3. [Working with regions](https://pr0m1th3as.github.io/drafting/guide/03_regions.html):
   booleans, offsets, fillets, hulls, arrays and text.
4. [Coordinate systems](https://pr0m1th3as.github.io/drafting/guide/04_coordinate_systems.html):
   planes of their own, and features on the faces of a part.
5. [Solids from regions](https://pr0m1th3as.github.io/drafting/guide/05_solids_from_regions.html):
   extrude, revolve, loft, sweep and coil.
6. [Primitives, booleans and transforms](https://pr0m1th3as.github.io/drafting/guide/06_primitives_and_booleans.html):
   solids built the way OpenSCAD builds them, in colour.
7. [Features: holes, pockets, fillets, chamfers and shells](https://pr0m1th3as.github.io/drafting/guide/07_features.html):
   a bearing block finished as a machinist would finish it.
8. [Sections and projections](https://pr0m1th3as.github.io/drafting/guide/08_sections_and_projections.html):
   cuts and outlines of a solid, built from and drawn.
9. [Technical drawings](https://pr0m1th3as.github.io/drafting/guide/09_drawings.html):
   layers, dimensions, hatches, blocks, a sheet, and paper, LaTeX and DXF.
10. [Meshes](https://pr0m1th3as.github.io/drafting/guide/10_meshes.html):
    reading, writing, cutting and fitting meshes, and meshes in booleans.
11. [Assemblies](https://pr0m1th3as.github.io/drafting/guide/11_assemblies.html):
    parts placed together, saved to STEP and 3MF.
12. [For OpenSCAD users](https://pr0m1th3as.github.io/drafting/guide/12_from_openscad.html):
    OpenSCAD's words in the package's, and a classic model rebuilt.

The scripts the pages are built from are in [`docs/guide/src`](docs/guide/src).

## Documentation

Every function and class method is documented in
[texinfo](https://www.gnu.org/software/texinfo/), reachable from the Octave
prompt with `help`. Use dot notation for namespaced functions and for the
methods and properties of the classes:

```
help geom.offset
help draw.Drawing
help draw.Drawing.print
help solid.Shape.hole
```

The function reference, with every docstring and demo, is at
[https://pr0m1th3as.github.io/drafting/](https://pr0m1th3as.github.io/drafting/),
and the guide with its tutorials at
[https://pr0m1th3as.github.io/drafting/guide/](https://pr0m1th3as.github.io/drafting/guide/).
The reference can also be built locally with the
[`pkg-octave-doc`](https://github.com/gnu-octave/pkg-octave-doc) package: with
both packages installed and loaded, in any folder you can write to, run:

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

If you need to install a specific release, for example `0.2.0`, type:

  `pkg install "https://github.com/pr0m1th3as/drafting/archive/refs/tags/release-0.2.0.tar.gz"`

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
- `pkg test drafting` to run its test suite and check that it works on your
  system.
