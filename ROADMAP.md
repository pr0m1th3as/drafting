# drafting roadmap

This is where the package is going and why. It is a statement of intent, not a
schedule: the work is ordered by what unblocks what, and the version tags are
indicative. Anything here may be reordered by what turns out to be needed.

Version 0.2.0 made the package an alternative to OpenSCAD: exact solids,
meshes, assemblies and a viewer, built on the outline classes of `+geom`, with
DXF read and written by compiled code and a layer table in every drawing. How
it fits together, and what each class becomes in a DXF file, is set out in the
[guide](https://pr0m1th3as.github.io/drafting/guide/).

The geometry half of the package is strong. The drafting half, the part that
encodes what a technical drawing *means* rather than what shape it is, is
thinner, and most of this roadmap is about closing that gap.

## Scope

The package covers **planar geometry, the drawing model built on it, the
formats that model is emitted in, and solids, modelled through Open CASCADE
and drawn as technical drawings**. Two boundaries follow, and both are
deliberate:

- A drawing describes a part. It does not machine one. Toolpath generation,
  cutter compensation, feeds and speeds, and post-processor dialects belong to
  a CAM package that consumes this one.
- The kernel is not ours. Solids, the booleans and offsets of regions, and any
  exact operation on curves are Open CASCADE's, bound in compiled functions.
  Open CASCADE is required, so nothing in the package is written twice to
  work without it.

`+geom` stays the middle layer and depends on none of the other namespaces:
solids and meshes give and take its objects, and a drawing takes nothing else
that is geometry.

## Standing requirements

These apply to all the work below and are not restated in it.

- Correctness first, verified at the edges: degenerate input, coincident
  points, zero-length segments, NaN and Inf.
- Built-in self-tests are a deliverable, covering normal use, edge cases and
  every error branch.
- Texinfo help must explain the function completely without recourse to the
  source.
- Every feature is shown working, rendered and looked at, in a `%!demo` block
  or on a tutorial page of the guide. A demo that runs is not a demo that
  reads, and no test can tell the two apart.
- Anything new a drawing holds is added to its lowering and to *every*
  backend, the DXF writer included. A backend that silently ignores an entity
  type produces a plausible and incomplete figure, which is worse than an
  error.

## Surfaces through a grid (0.2.1)

A shape written as a grid of points, rows and columns as `meshgrid` makes
them, is how many OpenSCAD users think, and it suits Octave. The grid stays
the input; what comes out is exact and smooth, where `solid.polyhedron` on the
same grid gives facets.

`S = solid.surface (X, Y, Z, H)` has Open CASCADE fit an exact B-spline
surface through the grid (`GeomAPI_PointsToBSplineSurface`) and returns the
solid that surface makes thickened along its normals
(`BRepOffsetAPI_MakeThickSolid`). It always returns a solid: a bare face is
no `solid.Shape`, which holds the boundary of solids.

**The normal** is the step from one column to the next crossed with the step
from one row to the next. For a `meshgrid` grid that is x then y, so the
normal points up, +z. Transposing `X`, `Y` and `Z` turns it round.

**Thickness** `H` is taken exactly as `solid.extrude` takes its height: a
positive scalar along the normal, a negative one against it, `[H1, H2]`, both
positive, to both sides, `H1` along the normal and `H2` against it.
`[0.5, 0.5]` is a skin of 1 centred on the surface.

**Curvature.** Thickening folds over itself wherever the surface curves
tighter than the material reaching that side: the thickness along the
normal on that side, the thickness against it on the other. That is checked on the fitted surface before Open CASCADE is asked,
and refused with an error naming the side.

**Shown** on a tutorial page of the guide: a rippled surface from `meshgrid`,
built once with `solid.polyhedron` and once with `solid.surface`, and the
one-sided thickness the curvature check refuses.

## The language of a technical drawing (0.3.0)

The difference between a picture of a part and a drawing of a part is that the
second one is a specification. The package can draw a profile beautifully and
cannot state a tolerance on it.

This is mostly careful text composition and symbol construction over
machinery that already exists, so the cost per item is low relative to how much
it changes what the package is. In rough order of value:

| Group | Content |
|---|---|
| Dimensional tolerances | symmetric (`±0.05`), limit dimensions (`25.05/24.95`), and ISO fits (`H7`, `g6`) resolved to real limits from the standard tables |
| Feature control frames | profile and runout first, the frames on every blade, vane, printed part and shaft; then position, flatness, concentricity and perpendicularity; with datum references and material-condition modifiers |
| Baseline and chain dimensions | datum-referenced running dimensions over a point set, building on `ordinate`, and chain-dimension helpers |
| Surface finish and welds | Ra/Rz finish symbols, and weld symbols per ISO 2553 |
| Section and detail marks | cutting planes with view direction, circled detail callouts carrying their own scale |
| Balloons and parts list | numbered leaders and a bill of materials table |

Tolerances and feature control frames come first: without them the output
cannot specify a part. `draw.coordtable` and `draw.titleblock` set the pattern
the new work follows: a function that returns a `Drawing`, on layers of its
own, to be merged onto the sheet.

## Exact curve operations

The planar curve functions, `curvature`, `curvesample`, `curveoffset`,
`resample`, `simplify` and `arclength`, take points and return points, so a
profile handed to them is frozen into points. The work carries what they do
onto the exact classes, bound from Open CASCADE as the region booleans are,
with the sampled functions kept and unchanged:

- the meeting points of polylines, splines and paths, and splitting one at a
  point;
- length, area and curvature evaluated on the curve, `geom.Polyline` and
  `geom.Region` included;
- offsets of open polylines and paths with their arcs and splines kept exact.

It needs nothing from the drawing work and can go before or alongside it.
General queries, the distance to a curve, the nearest point on it, the
smallest enclosing circle or box, wait until a package built on this one
needs them.

## Sheets and multi-view composition (0.4.0)

`draw.Drawing.print` places one drawing on one sheet at one scale. A real
drawing is three orthographic views, an isometric and a detail at 2:1, each in
its own viewport at its own scale, arranged around a title block.

A `draw.Sheet` holding placed, independently scaled viewports over a set of
`Drawing`s turns the package's main output from a figure into a drawing. It is
where the section and detail marks of 0.3.0 acquire something to point at, and
the natural home for DXF paper-space layouts, which R2000 can hold. `print`
already emits true vector PDF, so a sheet of viewports prints as vector.

## Drawings of solids (0.5.0)

A part is designed as a solid, whether it is printed or machined, and a part
made on a manual lathe or mill is made from a drawing. This draws the solids
on a `draw.Sheet` for the machinist, so one script describes a part, whatever
makes it.

**Views.** `projection` and `section` already give exact `+geom` objects that a
drawing takes as they are. Visible edges go on a thick continuous layer and
hidden ones on a thin dashed layer, per ISO 128, which the layer table states
once for the whole sheet. The seam edge of a cylinder or cone is never drawn,
and an edge between tangent faces is drawn thin or omitted, never as an
outline. A section is a set of regions, hatched with their holes left clear.

Annotation that follows from the geometry is generated, not placed by hand:

- centre lines on every hole and boss seen side-on, centre marks seen end-on;
- hole callouts, with a count when a pattern repeats (`4 × ⌀8`);
- overall dimensions of each view;
- section views with their cutting-plane line and labels, and detail views with
  their circle, label and scale;
- first-angle projection by default, per ISO 5456-2, third-angle on request;
- the title block, through `draw.titleblock`.

**Dimensions from intent.** A solid built in code records what it was built
from: a revolved profile its diameters and lengths, a hole its size and its
position from a datum. The drawing dimensions those, which is what a machinist
working by hand needs. A turned part is drawn as one view about its centre
line, diameters taken from the profile and lengths from a face; a milled part
carries ordinate dimensions from its datum corner. A solid read from a STEP
file records no intent, so it gets the geometric annotation only.

**Order.** Views need the sheet of 0.4.0, with a viewport that can be clipped
to a circle for a detail view. Dimensions from intent need the tolerances,
fits and section and detail marks of 0.3.0.

**Verifying it.** Drawings are asserted as the DXF output is: the extent of
each view, the centres and radii of projected holes, which edges are hidden
and on which layer.

## Alongside: blocks nothing

**Drawings made by other applications.** A file this package writes cannot
reach a path its own output never takes. Fixtures drawn in another CAD
program, saved as DXF 2000 and checked in under `inst/tests/fixtures/` with
the values they were drawn to, are read by tests that assert them: the
entities only a later version stores (hatches with holes, ellipses, splines,
multi-line text), nested blocks under rotated and mirrored inserts, and a
layer table with line weights and hidden and non-plotting layers.

**Verifying the DXF work.** `ezdxf` is the development-time oracle: it covers
R12 through R2018 both ways, and its auditor checks what is easy to get wrong
in R2000 (handle uniqueness, owner pointers, dangling table references). Its
ordinary loader silently repairs what it reads, so the audit result is
asserted, not assumed; and it checks its own model of the format, not
AutoCAD's, so a clean audit is necessary and not sufficient. It is an oracle,
not a gate: findings are verified once and written into BISTs as literal
expectations, and the test suite remains `pkg test`.

**SVG backend.** No dependency, exact affine control, and it draws from the
same lowered list that `plot` and `tikz` take, so it is a third consumer rather
than a new architecture. It serves documentation, the web, and everyone without
a CAD program.

## Other platforms

The package builds on Linux, and ports to Windows and macOS are not planned.
A port is welcome as a contribution. Windows needs Open CASCADE built with the
MinGW that builds Octave, since the MSVC binaries do not link against it, and
on both the viewer, written for X11, needs a window of the platform's own.

## Deliberately out of scope

| Not here | Why |
|---|---|
| G-code and CAM | a different discipline with a different failure mode; belongs to a package that consumes this one |
| DWG | proprietary and undocumented; the only routes are a closed converter or an experimental writer |
| Solids in DXF (`3DSOLID`) | the geometry is ACIS, proprietary and unreadable by Open CASCADE; solids are exchanged as STEP, and reach DXF as drawings |
| A solid-modelling kernel of our own | decades of work that Open CASCADE already holds; the package binds it instead |
| Parametric constraint solving | genuinely valuable and genuinely a research project: degree-of-freedom analysis, conditioning, and useful diagnostics for under- and over-constrained sketches. Its own package if ever |
| GD&T as PMI in STEP AP242 | a maker turns PMI back into a drawing and charges for it; tolerances go on the drawing, sent as PDF and DXF beside the STEP model |
| `minkowski` and `multmatrix` | rounding a shape is `fillet` and the offsets, a Minkowski sum of exact solids has no counterpart in Open CASCADE, and a part is placed by a `geom.UCS`, which never shears it |
