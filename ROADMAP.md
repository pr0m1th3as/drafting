# drafting roadmap

This is where the package is going and why. It is a statement of intent, not a
schedule: milestones are ordered by what unblocks what, and the version tags
are indicative. Anything here may be reordered by what turns out to be needed.

## Where the package stands

Version 0.1.0 shipped planar geometry, DXF reading and writing, STL output and
the `draw.Drawing` class with its plot, TikZ and DXF backends. Its suite
asserts the printed artefact and not merely the numbers handed to the
renderer: the page a PDF declares, the size and resolution of a raster sheet,
that a model length arrives on paper at the stated scale, and that every entity
type reaches every backend.

Version 0.2.0, milestone 1 below, is under way and most of it is built: the
outline classes of `+geom`, solids through Open CASCADE in `+solid`, meshes in
`+polymesh`, and assemblies and the viewer in `+model`. What is left before
its release is the DXF work described under Files, the drawings made by
another application, and a tarball install test of the compiled code.

The geometry half of the package is strong. The drafting half, the part that
encodes what a technical drawing *means* rather than what shape it is, is
thinner, and most of this roadmap is about closing that gap.

## Scope

The package covers **planar geometry, the drawing model built on it, the
formats that model is emitted in, and solids, modelled through Open CASCADE
and drawn as technical drawings**. Two boundaries follow from that, and both
are deliberate:

- A drawing describes a part. It does not machine one. Toolpath generation,
  cutter compensation, feeds and speeds, and post-processor dialects belong to
  a CAM package that consumes this one.
- The kernel is not ours. Solids are built, combined and read through Open
  CASCADE; the package writes no boolean, fillet or surface-intersection code
  of its own. The booleans and offsets of regions are Open CASCADE's too. The
  rest of the planar model is plain Octave, and the work on triangle meshes
  and on DXF files is compiled, needing nothing but Octave.

Everything below is checked against those two lines.

## How the package is layered

`+geom` is the middle layer, and the other namespaces build on it.

- Solids (`+solid`) take and give `+geom` objects: a solid is made from
  regions and paths (extrude, revolve, sweep, loft, helix), and a section or
  a projection of it is a set of regions again.
- Meshes (`+polymesh`) only give them: a cut through a mesh with the plane of
  a `geom.UCS` is regions, fitted back to lines, arcs and splines.
- Assemblies (`+model`) hold solids and meshes, each placed by a `geom.UCS`.
- A drawing (`+draw`) takes `+geom` objects and nothing else that is
  geometry.

`+geom` depends on none of them, so a solid never depends on the drawing
model, and the drawing model never depends on Open CASCADE.

## Polylines and regions

Three value classes in `+geom` are the package's one representation of
outlines and curves, each lying in a `geom.UCS` (below), used by drawings and
solids alike. Functions take the classes and nothing else; only the constructors
accept plain matrices. Point sets that carry no arcs, such as the input of
`geom.offset` or `geom.curvature`, stay N-by-2 matrices.

- **`geom.Polyline`**: the DXF polyline. `Vertices` is an N-by-3 matrix
  `[x, y, bulge]` in the coordinates of its `UCS`; an N-by-2 matrix is accepted
  and given zero bulges. It is open or `Closed`, and may cross itself.
- **`geom.Spline`**: the DXF `SPLINE`, kept apart from the polyline as DXF
  keeps it. It holds a NURBS curve, control points, weights, knots and a
  degree, in the coordinates of its `UCS`, so it carries exactly the curves a
  cut through a solid gives: conics as rational splines, and Open CASCADE's
  own B-splines. A spline drawn through points keeps them and the end
  directions as fit data, as DXF does: a cubic through an M-by-3 matrix of
  points, parametrised by the distance from point to point, a free end shaped
  as Octave's `spline` shapes it. It is open, or closed and smooth all round.
  A path takes it as one smooth segment, and a region as an outline or a
  hole, or as part of one.
- **`geom.Region`**: a closed planar area, one outline and any number of holes
  of any shape, each a closed `geom.Path` in one plane, so of straight
  segments, arcs and splines; closed polylines and splines are taken and
  carried into paths. It refuses an outline or a hole that is open, crosses
  or touches itself or encloses no area, a hole not strictly inside the
  outline, and holes that meet. It normalises the outline anticlockwise and
  the holes clockwise. An island inside a hole is a second region, unioned
  onto the solid made from the first. Assigning its `UCS` moves it, keeping
  its shape in its own coordinates: a region drawn in the xy plane is laid on
  a face by giving it the face's UCS. A taper is refused on a region with
  splines if Open CASCADE cannot offset them faithfully.

A region is what a solid is made from (`solid.extrude`, `revolve`, `sweep`,
`loft`, `helix`), what a section of a solid is, and what a hatch fills. A
solid is made where its region's plane puts it: `extrude` rises along the
normal; `revolve` and `helix` turn about the plane's own y axis through its
origin, local x the radius, so a region in the default xy plane turns about
the model's y axis; `loft` takes each section where its plane lies, sections
need not be parallel, and all have the same number of holes; `sweep` sweeps
the region from where it lies along a `geom.Path` (below). A pocket, a recess
of limited depth, is an operation on a solid, not part of a region.

`solid.Shape.section` cuts a solid with the plane of a UCS and returns the cut
as regions in that UCS, one for each separate piece, largest first, exact
enough to build from again: lines, arcs, conics as rational splines and Open
CASCADE's own B-splines. A face lying in the plane is part of the cut.

## User coordinate systems and paths

**`geom.UCS`** is a user coordinate system: an `Origin`, an `XAxis` and a
`Normal`, defining a plane with coordinates of its own. Every polyline,
spline, region and path carries one, the world xy plane by default. It is a
coordinate system and not just a plane: the origin and x axis carry meaning (a
revolution turns about its y axis), and DXF stores named UCS records of exactly
this form.

- `geom.UCS ()` is the world xy plane.
- `geom.UCS (NORMAL, ORIGIN, XPOINT)` lays the plane square to the normal
  through the origin, its x axis towards the point, projected onto the plane.
- `geom.UCS (NORMAL, ORIGIN)` takes the x axis from DXF's arbitrary axis
  algorithm, so it matches the frame DXF gives a flat entity.
- `geom.UCS.threepoint (P1, P2, P3)` is AutoCAD's three-point UCS: origin, +x,
  and a point on the +y side.
- `geom.UCS (V)` picks one with the mouse in the viewer `V`. Picking lives in
  the viewer; `+geom` only calls the method of the object it is given, so it
  never depends on `+solid`.

A UCS is picked in two steps. The axes come first, from a planar face and two
points (the face gives the normal, the points the +x direction) or from three
points (+x from the first to the second, the third on the +y side). The origin
comes second, from one point, or from two whose x and y it takes, which places
a datum corner where a fillet leaves no vertex; with none, it is the first
point. Every point snaps to a vertex, the centre of a circular edge, the
midpoint of a straight edge, or a point on a face. The pick prints the
`geom.UCS` it made, by coordinates, for the script.

**`geom.Path`** is the route a section is swept along: a chain of straight
segments, circular arcs and splines in 3-D, open or closed, its vertices
coordinates in a `geom.UCS` of its own, the world by default; assigning another
moves it. It is not a polyline: a polyline lies in one plane, and a pipe run or
a bent frame does not. An arc is kept by the point half way along it, since in
3-D a bulge leaves the arc's plane undecided.

- `geom.Path (P)` runs through the points of an M-by-3 matrix.
- `geom.Path (PL)` carries a `geom.Polyline` into 3-D in its UCS, its bulges
  kept as exact arcs.
- `fillet (P, R, IDX)` rounds corners between straight segments with tangent
  arcs, the bends of a bent tube.
- `geom.Path.arc (P1, PM, P2)` is an arc through three points, as when a
  path follows a circular edge picked in the viewer.
- `geom.Path (SP)` is the one smooth segment of a `geom.Spline`.
- `join` puts paths and splines end to end; a free end of a spline takes the
  direction of what it meets so the path runs on smoothly, unless asked not
  to. `length` measures the path.

An arc given by a centre and angles is left out on purpose: a sweep along one
arc is a revolution, which `solid.revolve` already makes. What a path adds is
assembly, one smooth solid with its section carried along, not new shapes.
A sweep along a spline is what a grip, a curved rib or a cooling channel
following the shape of a printed mould is made from.

## Solids

**The kernel is Open CASCADE (OCCT), bound and not written.** Booleans on
curved surfaces, fillets, and the tolerances where faces nearly meet are
decades of work in OCCT, which CadQuery, build123d and FreeCAD all stand on.
The package wraps it in compiled functions and writes none of that geometry
itself. OCCT is LGPL 2.1 with an exception, which GPLv3 code may link, and
Debian ships it as `libocct-*-dev`.

**OCCT is optional at build time.** Only `+solid`, and the parts of `+geom`
and `+model` that call it, need it. Where it is not found the package builds
without it, everything else works as before, and every function that needs it
raises an error naming the missing library; its BISTs run under a runtime
condition and skip on such a build. Linux comes first. Windows, which needs a
MinGW build of OCCT since the MSVC binaries do not link against Octave, and
macOS follow.

`solid.Shape` is a value class over an OCCT shape. It has primitives (box,
cylinder, cone, sphere, torus, wedge, ellipsoid), solids from regions
(extrude, revolve, sweep, loft, helix) and from closed meshes (`polyhedron`),
the booleans `union`, `subtract` and `intersect`, each taking any number of
shapes in one operation, features (`fillet`, `chamfer`, `shell`, `hole`
plain, counterbored, countersunk or at the tapping size of a metric thread,
and `pocket`), queries (edges and faces selected by type, direction and
position; volume, area, centre of mass, bounding box; validity), `section` and
`projection`, and `show` in Open CASCADE's own viewer, run as a process of its
own so that it turns smoothly and never blocks the prompt.

## Files

Reading is a function in the namespace of what it returns; writing is a method
of the object written, object first, the format chosen by the file's
extension.

| Object | Read | Write |
|---|---|---|
| `solid.Shape` | `solid.read`: STEP | `write (S, FILE)`: STEP; STL, OBJ, PLY, 3MF through `tessellate` |
| `polymesh.Mesh` | `polymesh.read`: STL, OBJ, PLY, 3MF | `write (M, FILE)` |
| `model.Assembly` | `model.read`: STEP, 3MF | `write (A, FILE)`: STEP, 3MF |
| `geom.Polyline`, `geom.Spline`, `geom.Path`, `geom.Region` | `geom.read`: DXF | `write (G, FILE)`: DXF; `geom.write (C, FILE)` for several |
| `draw.Drawing` | `draw.read`: DXF | `write (D, FILE)`: DXF; `print` and `tikz` |

**DXF.** Reading and writing are compiled, in `src/__dxf__.cc`, which takes
the objects themselves and builds them by their constructors, with no entity
list between. Each `write` method is a call to it, which validates the
arguments and raises its errors under the method's name. The writer emits
R2000 (`AC1015`) by default; `'Version', 'R12'` is accepted only for lines
and arcs, and anything R12 cannot hold is an error naming it.

- A `Polyline` is one `LWPOLYLINE` and a `Spline` one `SPLINE`. A `Path` is
  its pieces, `LINE`, `ARC` in its own plane and `SPLINE`, bound by a
  `GROUP`. A `Region` is its loops bound by a `GROUP`; `'Fill', true` adds a
  solid `HATCH`, which reads back with its group and never as a second
  region. Groups are written in model space only; a path or region in a
  block is written as its pieces.
- Geom objects carry no layer, line type or colour. `'Layer'`, `'Linetype'`
  and `'Colour'` give them, one value for every object or one per object.
  Line types are CONTINUOUS, HIDDEN, CENTER, PHANTOM, DASHED, DASHDOT and DOT;
  a colour is an AutoCAD colour index, 1 to 256, 256 meaning by layer, since
  true colour came only with R2004.
- Text is written as R2000 with every character outside ASCII escaped as
  `\U+XXXX`, so the file reads the same whatever the reader's code page.
- `geom.write (C, FILE, ...)` writes a cell of geom objects in one pass.
  There is no append mode: adding to a DXF rewrites its tables, its handles
  and its objects section.
- Every geom object carries its `UCS` as extended data under the registered
  application `DRAFTING`: the origin in group 1011 and the x axis in group 1013,
  and for a path, a spline or a region the normal in a second 1013, since a flat
  entity keeps its normal in group 210. On a group the same block names the
  class, `geom.Path` or `geom.Region`, in group 1000. `geom.read` restores the
  `UCS`, for a flat object only when the stored normal matches group 210 and the
  origin lies in the plane. The entities' own coordinates stay authoritative, so
  a stale frame can never move the geometry.
- Without that data, any plane is read: a normal of +Z in the world frame, a
  normal of -Z mirrored into +Z first, as 2-D CAD programs treat it, and any
  other normal in DXF's own frame. Paths and splines are read in world
  coordinates.
- Without `'Type'`, `geom.read` returns what is in the file: a row cell with one
  geom object per entity, nothing joined and nothing reclassified. `LINE`,
  `ARC`, `CIRCLE` and `LWPOLYLINE` are polylines, `SPLINE` and `ELLIPSE`
  splines, a `HATCH` a region; a line slanting in 3-D and a 3-D `POLYLINE` are
  paths, since no single plane holds them, and text, dimensions, inserts,
  points, meshes and solids in the file are skipped. A group the package wrote
  is one item, the class its extended data names, so what was written is what is
  read: a closed path stays a path, the route `solid.sweep` turns into a ring.
- With `'Type'` (`'path'`, `'polyline'`, `'region'`, `'spline'`) it builds
  that class and returns one object: `'path'` chains entities end to end
  (`geom.Path.chain`), `'region'` chains them and nests loops that share a
  plane (`geom.Region.nest`), and the package's own groups count as built.
  Ends within 1e-4 mm are joined and snapped to one point, which is above
  the rounding of coordinates in a file and below anything that can be made.
  More than one candidate is an error naming the layer, as is finding
  candidates on several layers with no `'Layer'` given, and finding none:
  separate parts belong on separate layers.
- `draw.read` restores everything a drawing holds: dimensions as
  dimensions, blocks and inserts, text, hatches over their regions; a hatch
  pattern the package does not define is drawn as ANSI31 and reported.
- Entities skipped, or left over under `'Type'`, are reported in one warning
  per read, counted by type.
- A `draw.Drawing` holds only flat geom objects lying in z = 0; one facing
  down is mirrored into +Z. Its `write` writes no frames; its path and
  region groups carry only their class name, from which `draw.read` gives
  them back, and a hatch is its `HATCH` alone. `write (D, FILE, ...)` takes
  `'Version'`,
  `'Dimensions'` (`'associative'`, or `'explode'` for programs that cannot
  read a `DIMENSION`), `'Blocks'` (`'reference'`, or `'expand'` for programs
  that ignore `INSERT`), `'DimScale'` and `'LTScale'`, which every `write`
  takes.
- The reader takes ASCII DXF from R12 (`AC1009`) to R2018 (`AC1032`); a
  binary DXF is an error. Text before R2007 is decoded from the code page
  the header names, and from R2007 as UTF-8.

`draw.Drawing.entities` stays as the drawing's own lowering to a flat list of
primitives, which `plot` and `tikz` draw from; it is hidden, and the DXF path
does not use it.

## Milestone 1: an OpenSCAD alternative (0.2.0)

The package is the base for packages like `cycloidal`, and an alternative to
OpenSCAD written in Octave itself, without OpenSCAD's limits: exact geometry
rather than facets, fillets, chamfers, shells and holes, lofts, sweeps and
helices, STEP as well as STL, sections that can be built from again, and a
real language around it all. What an OpenSCAD user reaches for is therefore
the measure of this release. Primitives, linear and rotational extrusion
(twist and scale included), the solid booleans and transforms, the cut
projection (`section`) and STL in and out are the base. This release adds:

| OpenSCAD | Here |
|---|---|
| `union`, `difference`, `intersection` of 2-D shapes | `union`, `subtract` and `intersect` on `geom.Region`, through Open CASCADE, arcs and splines exact |
| `offset (r)`, `offset (delta)`, `chamfer` | `offset` on `geom.Region`, its corners round, sharp or cut |
| `hull ()` of 2-D shapes | the hull of regions, its arcs exact and its lines tangent to them |
| `text ()` | the outlines of text as regions, from Open CASCADE's font builder |
| `polyhedron ()`, an STL in a boolean | a closed mesh as a `solid.Shape`, built from the mesh's own vertices, edges and triangles |
| `resize` | resizing to a size or into a box, evenly or stretched along each axis, for solids and regions |
| `mirror` of 2-D shapes | `mirror` on `geom.Region`, about a line in its plane |
| copies in a `for` loop | `copy`, `rectarray` and `polararray` on `solid.Shape` and `geom.Region`, the copies united |
| an ellipse, an ellipsoid (`scale` of a circle or a sphere) | `geom.Spline.ellipse` and `solid.ellipsoid`, both exact |
| `color` | one colour for a whole shape, shown in the viewer and carried through STEP out and in |
| several objects in one file | multipart STEP and 3MF out and in: named parts and assemblies of placed parts, through Open CASCADE's document framework (XDE) |
| `import ()` of OBJ | OBJ and PLY meshes read and written, ASCII or binary, made a solid by `solid.polyhedron` |
| `projection (cut = false)` | the outline of a solid on a plane, which milestone 4's views need as well |
| `hull ()` of solids | the hull of a solid's points, as a faceted solid |

`multmatrix` and `minkowski ()` are not planned. The common use of
`minkowski`, rounding a shape, is `fillet` and the offsets, and a Minkowski sum
of exact solids has no counterpart in Open CASCADE.

**The drawing side.** Three pieces close here.

*DXF as described under Files.* It replaces the R12 writer of 0.1.0 and the
`+dxf` namespace with it: `dxf.read`, `dxf.write` and `draw.fromentities` go,
and a drawing holds the geom classes (`spline`, `path`, `region`, and `hatch`
taking a region) where it held matrices.

*A drawing made by another application.* A file this package writes cannot
reach a path its own output never takes: a nested block, the layout containers
a real file defines, an aligned dimension. One such drawing is in, under
`inst/tests/fixtures/`, saved by LibreCAD in every version it offers, and it
found three defects in its first minute. The rest of the idea follows: blocks
with nested inserts, polyline widths and bulges, an inch file, a layer table,
each drawn elsewhere, checked in with the values it was drawn to, and read by
tests that assert them.

*Millimetres only.* Every length in the package is in millimetres, and there
is no `Units` property. An inch file is read in millimetres and the writer
declares millimetres, so nothing is mis-scaled.

**Meshes.** `polymesh.read` reads STL, OBJ, PLY and 3MF with their colours,
`section` cuts a `polymesh.Mesh` with a plane into regions, healed to a
tolerance where the mesh has gaps, and `geom.Region.fit` turns the cut's facets
back into lines, arcs and splines, so that a faceted bore becomes a circle
again. The viewer shows meshes and picks a UCS on them. Reading, welding,
cutting and fitting are compiled, in a file of their own that needs no Open
CASCADE.

General geometric queries (the distance to a curve, the nearest point on it,
the smallest enclosing circle or box) wait until a package built on this one
needs them.

## Milestone 2: the language of a technical drawing (0.3.0)

The difference between a picture of a part and a drawing of a part is that the
second one is a specification. The package can currently draw a profile
beautifully and cannot state a tolerance on it.

This milestone is mostly careful text composition and symbol construction over
machinery that already exists, so the cost per item is low relative to how much
it changes what the package is. In rough order of value:

| Group | Content |
|---|---|
| Dimensional tolerances | symmetric (`±0.05`), limit dimensions (`25.05/24.95`), and ISO fits (`H7`, `g6`) resolved to real limits from the standard tables |
| Feature control frames | position, flatness, perpendicularity, concentricity, runout and profile, with datum references and material-condition modifiers |
| Baseline and chain dimensions | datum-referenced running dimensions over a point set, building on `ordinate`, and chain-dimension helpers |
| Surface finish and welds | Ra/Rz finish symbols, and weld symbols per ISO 2553 |
| Section and detail marks | cutting planes with view direction, circled detail callouts carrying their own scale |
| Balloons and parts list | numbered leaders and a bill of materials table |

Tolerances and feature control frames come first. Without them the output
cannot specify a part, which is the whole purpose of the format it is written
in. `draw.coordtable` and `draw.titleblock` are the existing members of this
family and set the pattern the new work should follow: a function that returns
a `Drawing` to be merged onto the sheet.

## Milestone 3: sheets and multi-view composition (0.4.0)

`draw.Drawing.print` places one drawing on one sheet at one scale. A real
drawing is three orthographic views, an isometric and a detail at 2:1, each in
its own viewport at its own scale, arranged around a title block.

A `draw.Sheet` object holding placed, independently scaled viewports over a set
of `Drawing`s would turn the package's primary human-facing output from a
figure into a drawing. It is also where the section and detail marks of
milestone 2 acquire something to point at, and the natural home for DXF
paper-space layouts, which R2000 can hold, so the two reinforce each other
rather than compete.

`print` already emits true vector PDF (embedded fonts, no image stream), and
`Resolution` applies only to the raster formats, as its docstring states. So
there is nothing to confirm before starting: a sheet composed of viewports will
print as vector, and the work can be built on that.

## Milestone 4: drawings of solids (0.5.0)

A part is designed as a solid, whether it is printed or machined, and a part
made on a manual lathe or mill is made from a drawing. The solids are in from
0.2.0; this milestone draws them on a `draw.Sheet` for the machinist, so one
script describes a part, whatever makes it.

**Views.** OCCT projects a solid with hidden lines removed and every edge
exact; `projection` and `section` return the result as `+geom` objects, which
a drawing takes as they are: lines, arcs and circles as polylines, ellipses
and B-splines as splines. Visible edges are drawn continuous and thick, hidden
ones dashed and thin, per ISO 128. The seam edge of a cylinder or cone is never
drawn, and an edge between tangent faces is drawn thin or omitted, never as an
outline. A section is OCCT's planar cut, a set of regions, hatched; a section
through a part with a bore is a region with a hole, and `hatch` fills a region
with its holes left clear, by an even-odd scan that needs none of milestone
6's booleans.

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

**Order.** Views need milestone 3's sheet, with a viewport that can be clipped
to a circle for a detail view. Dimensions from intent need milestone 2's
tolerances and fits, and its section and detail marks.

**Verifying it.** Every solid a test builds is checked by OCCT's validity check
and by its exact volume, area and bounding box against values worked out by
hand. STEP files written by other programs, checked in under
`inst/tests/fixtures/` with the values they were modelled to, test reading.
Drawings are asserted as the DXF output is: the extent of each view, the
centres and radii of projected holes, which edges are hidden. OCCT reports most
failures as exceptions, and every wrapper turns them into Octave errors; some
bad input crashes it instead, so input is validated before it reaches the
library.

## Milestone 5: exact curve operations (0.6.0)

Curves are exact objects from 0.2.0: `geom.Spline` carries NURBS, `geom.Path`
arcs and splines in 3-D. The planar curve functions are not yet: `curvature`,
`curvesample`, `curveoffset`, `resample`, `simplify` and `arclength` take points
and return points, so a profile handed to them is frozen into points and can no
longer be recovered.

The work carries those operations onto the exact form, with the sampled
versions kept and unchanged:

- `geom.splitcurve`, `geom.curveintersect`: subdivision and curve/curve meets
  on polylines, splines and paths
- curvature and arc length evaluated on the curve rather than on samples
- exact `curveoffset` and `fillet` on splines, where Open CASCADE's offsets
  of regions do not already cover them

## Milestone 6: polygon booleans without Open CASCADE (0.7.0)

Union, intersection and difference of regions come through Open CASCADE from
0.2.0, exact for arcs and splines. What remains is the same on plain N-by-2
polygons for a build without Open CASCADE, for hatch boundaries and clearance
checks there.

It should be entered with clear eyes. Vatti, Greiner-Hormann and
Martínez-Rueda each fail on degeneracies rather than on the general case:
collinear edges, coincident vertices, self-touching boundaries, edges that meet
at a point without crossing. Making them robust is the actual project, and it
needs either exact predicates or a tolerance policy chosen up front, so nothing
else is scheduled to depend on it.

## Milestone 7: profiles to meshes (0.8.0)

A closed planar profile to a triangle mesh, entirely inside the package, for a
build without Open CASCADE:

- `geom.extrude`: profile plus depth, with holes carried through as inner
  loops and the caps triangulated by the existing `geom.triangulate`
- `geom.revolve`: profile about an axis, with a partial-sweep option
- `geom.sweep`: profile along a `geom.Path`

This completes a pipeline the package already half owns: geometry to profile to
mesh to file through `polymesh.Mesh`. Extrude and revolve are markedly easier
than they sound once triangulation is in hand, and they are what lets a drawing
produce a part rather than only describe one.

## Format track: runs alongside, blocks nothing

**SVG backend.** The cheapest reach per line in the package. No dependency,
exact affine control, and it draws from the same lowered list that `plot` and
`tikz` take, so it is a third consumer rather than a new architecture. It
serves documentation, the web, and everyone without a CAD program.

**Verifying the DXF work.** `ezdxf` is the right development-time oracle: it
covers R12 through R2018 both ways, its auditor checks precisely what is easy
to get wrong in R2000 (handle uniqueness, owner-pointer validity, dangling
table references), and it can write files for the reader to be tested against.
Two cautions. Its ordinary loader silently repairs what it reads, so anything
inspected after a plain load may be its corrected version rather than what was
written; the audit result must be asserted, not assumed. And it validates
against its own model of the format, not against AutoCAD; a clean audit is
necessary and not sufficient, so the manual CAD acceptance stays.

It is an oracle and not a gate. Findings are verified once and then written
into BISTs as literal expectations, exactly as any other external reference is
handled. The package's test suite remains `pkg test` and nothing else.

## Deliberately out of scope

| Not here | Why |
|---|---|
| G-code and CAM | a different discipline with a different failure mode; belongs to a package that consumes this one |
| DWG | proprietary and undocumented; the only routes are a closed converter or an experimental writer |
| Solids in DXF (`3DSOLID`) | the geometry is ACIS, proprietary and unreadable by Open CASCADE; solids are exchanged as STEP, and reach DXF as drawings |
| A solid-modelling kernel of our own | decades of work that Open CASCADE already holds; the package binds it instead |
| Parametric constraint solving | genuinely valuable and genuinely a research project: degree-of-freedom analysis, conditioning, and useful diagnostics for under- and over-constrained sketches. Its own package if ever |

## Standing requirements

These apply to every milestone and are not restated in them.

- Correctness first, verified at the edges: degenerate input, coincident
  points, zero-length segments, NaN and Inf.
- Built-in self-tests are a deliverable, covering normal use, edge cases and
  every error branch.
- Texinfo help must explain the function completely without recourse to the
  source.
- A `%!demo` block that ends in a plot, rendered and looked at. A demo that
  runs is not a demo that reads. No test can tell the two apart, so this is
  enforced by eye alone, which is why it is written down here.
- Anything new a drawing holds is added to its lowering and to *every*
  backend, the DXF writer included. A backend that silently ignores an entity
  type produces a plausible and incomplete figure, which is worse than an
  error.
