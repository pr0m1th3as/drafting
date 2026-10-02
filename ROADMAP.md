# drafting roadmap

This is where the package is going and why. It is a statement of intent, not a
schedule: milestones are ordered by what unblocks what, and the version tags
are indicative. Anything here may be reordered by what turns out to be needed.

## Where the package stands

Version 0.1.0 is feature-complete for a first release: thirty public
functions across `+geom`, `+dxf`, `+stl` and `+draw`, the `draw.Drawing` class
with its three backends, 847 built-in self-tests, and a `%!demo` block on
nearly every function that ends in a plot, so the documentation shows rather
than asserts.

The suite asserts the printed artefact and not merely the numbers handed to the
renderer: the page a PDF declares, the size and resolution of a raster sheet,
that a model length arrives on paper at the stated scale, and that every entity
type reaches every backend. Writing it found three defects: a raster print that
carried no sheet, a fit computed against the figure's shape rather than the
drawing's, and a printed scale that drifted whenever the drawing carried text.

The file loop is closed in that release. `draw.Drawing.entities` lowers a
drawing to a flat entity list and `draw.fromentities` raises one back, blocks
and all, with dimensions returning as dimensions that measure their geometry
again. A DXF is a round trip rather than a one-way door, which is what makes
the ordinary workflow (open an existing drawing, add to it, write it back)
possible at all.

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
  rest of the planar model is plain Octave, and the work on triangle meshes is
  compiled, needing nothing but Octave.

Everything below is checked against those two lines.

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
  the holes clockwise. An island inside a hole is not supported; a second
  region unioned onto the solid makes one. Assigning its `UCS` moves it,
  keeping its shape in its own coordinates: a region drawn in the xy plane is
  laid on a face by giving it the face's UCS. A taper is refused on a region
  with splines if Open CASCADE cannot offset them faithfully.

A region is what a solid is made from (`solid.extrude`, `revolve`, `sweep`,
`loft`, `helix`), what a section of a solid is, and what a hatch fills, and the
polygon booleans of milestone 6 act on regions. A solid is made where its
region's plane puts it: `extrude` rises along the normal; `revolve` and `helix`
turn about the plane's own y axis through its origin, local x the radius, so a
region in the default xy plane turns about the model's y axis; `loft` takes
each section where its plane lies, sections need not be parallel, and all have
the same number of holes; `sweep` sweeps the region from where it lies along a
`geom.Path` (below). A pocket, a recess of limited depth, is an operation on a
solid, not part of a region.

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
  algorithm, so it reads and writes DXF exactly.
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

## Milestone 1: an OpenSCAD alternative (0.2.0)

The package is the base for packages like `cycloidal`, and an alternative to
OpenSCAD written in Octave itself, without OpenSCAD's limits: exact geometry
rather than facets, fillets, chamfers, shells and holes, lofts, sweeps and
helices, STEP as well as STL, sections that can be built from again, and a
real language around it all. What an OpenSCAD user reaches for is therefore
the measure of this release. Primitives, linear and rotational extrusion
(twist and scale included), the solid booleans and transforms, the cut
projection (`section`) and STL in and out are here. These are not:

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
| `color` | colour carried to the viewer and to STEP |
| `projection (cut = false)` | the outline of a solid on a plane, which milestone 4's views need as well |
| `hull ()` of solids | the hull of a solid's points, as a faceted solid |

`multmatrix` and `minkowski ()` are not planned. The common use of
`minkowski`, rounding a shape, is `fillet` and the offsets, and a Minkowski sum
of exact solids has no counterpart in Open CASCADE.

**The package's own shape.** Three pieces of the drawing side close here.

*A drawing made by another application.* Every DXF the tests read was written
by this package, and no round trip can reach a path our own output never takes:
a nested block, the layout containers a real file defines, an aligned dimension.
One such drawing is in, under `inst/tests/fixtures/`, saved by LibreCAD in every
version it offers, and it found three defects in its first minute. The rest of
the idea follows: blocks with nested inserts, the entities R12 cannot store,
polyline widths and bulges, an inch file, a layer table, each drawn elsewhere,
checked in with the values it was drawn to, and read by tests that assert them.

*DXF dimension types 5 and 6.* Type 5, angular, maps onto `angdim`; type 6,
ordinate, has no entity in the drawing model yet.

*Units in the model.* `dxf.read` converts an inch file to millimetres and
`dxf.write` declares millimetres, so nothing is mis-scaled; what is missing is
working in anything else. A `Units` property on `Drawing`, honoured by
`print`, `dxf.write` and `stl.write`, would let a drawing be authored in inches.
It is ergonomic rather than a fix, and may slip to a later release.

**Meshes.** `stl.read` reads binary and ASCII STL, `stl.section` cuts a mesh
with a plane into regions, healed to a tolerance where the mesh has gaps, and
`geom.Region.fit` turns the cut's facets back into lines, arcs and splines, so
that a faceted bore becomes a circle again. The viewer shows meshes and picks a
UCS on them. Reading, welding, cutting and fitting are compiled, in a file of
their own that needs no Open CASCADE.

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
| Ordinate and baseline dimensions | datum-referenced running dimensions over a point set, and chain-dimension helpers |
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
milestone 2 acquire something to point at, and it is the natural home for DXF
paper-space layouts should the format track below be taken up, so the two
reinforce each other rather than compete.

`print` already emits true vector PDF (embedded fonts, no image stream), and
`Resolution` applies only to the raster formats, as its docstring states. So
there is nothing to confirm before starting: a sheet composed of viewports will
print as vector, and the work can be built on that.

## Milestone 4: solids and their drawings (0.5.0)

A part is designed as a solid, whether it is printed or machined, and a part
made on a manual lathe or mill is made from a drawing. This milestone models
solids in Octave code, writes them as STEP for exchange and STL for printing,
and draws them on a `draw.Sheet` for the machinist. One script describes a
part, whatever makes it.

**The kernel is Open CASCADE (OCCT), bound and not written.** Booleans on
curved surfaces, fillets, and the tolerances where faces nearly meet are
decades of work in OCCT, which CadQuery, build123d and FreeCAD all stand on.
The package wraps it in compiled functions and writes none of that geometry
itself. OCCT is LGPL 2.1 with an exception, which GPLv3 code may link, and
Debian ships it as `libocct-*-dev`.

**OCCT is optional at build time.** Only the new `+solid` namespace needs it.
Where it is not found the package builds without it, everything else works as
before, and every `+solid` function raises an error naming the missing
library; its BISTs run under a runtime condition and skip on such a build.
Linux comes first. Windows, which needs a MinGW build of OCCT since the MSVC
binaries do not link against Octave, and macOS follow.

`+solid` sits above `+draw`: it builds solids from `+geom` profiles and emits
drawings through `+draw`, so dependencies still point downward only.

| Piece | Content |
|---|---|
| `solid.Shape` | a value class over an OCCT shape, with the booleans `union`, `subtract` and `intersect`, named as MATLAB's `polyshape` names them, each taking any number of shapes in one operation |
| Primitives | box, cylinder, cone, sphere, torus |
| From profiles | extrude, revolve, sweep and loft of `+geom` polylines, bulges carried as true arcs |
| Features | fillet, chamfer, shell; holes plain, counterbored, countersunk and tapped, recorded as holes |
| Queries | edges and faces selected by type, direction and position; volume, area, centre of mass, bounding box; validity |
| Files | `solid.read` and `solid.write`, STEP and STL |
| Viewing | `solid.show` and `solid.Viewer`: the solid in Open CASCADE's own viewer, run as a process of its own so that it turns smoothly and never blocks the prompt; redrawn in place when a shape is assigned to it; edges and faces picked with the mouse, reported as indices and as the query that finds them again |
| Drawings | views, sections and details laid out on a `draw.Sheet` |

**Drawings.** OCCT projects a solid with hidden lines removed and every edge
exact, and each edge becomes a `Drawing` entity: lines, arcs, circles and
ellipses as themselves, a B-spline as a sampled polyline until milestone 5 adds
the spline entity. Visible edges are drawn continuous and thick, hidden ones
dashed and thin, per ISO 128. The seam edge of a cylinder or cone is never
drawn, and an edge between tangent faces is drawn thin or omitted, never as an
outline. A section is OCCT's planar cut, hatched. A section through a part with
a hole is a region with an island, so `geom.hatchlines` and `Drawing.hatch`
learn to fill a boundary with holes, by an even-odd scan that needs none of
milestone 6's booleans.

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

**Order.** The first step is a spike that decides the rest: an oct-file linked
against OCCT builds a box less a cylinder, writes it as STEP and STL, and
reports its volume. Then the shape class, primitives, booleans and files; then
profiles and features; then `show` and the checks. None of these needs
milestones 1 to 3, so they may start before them. Drawings need milestone 3's
sheet, with a viewport that can be clipped to a circle for a detail view.
Dimensions from intent need milestone 2's tolerances and fits, ordinate
dimensions, and section and detail marks.

**Verifying it.** Every solid a test builds is checked by OCCT's validity check
and by its exact volume, area and bounding box against values worked out by
hand. STEP files written by other programs, checked in under
`inst/tests/fixtures/` with the values they were modelled to, test reading.
Drawings are asserted as the DXF output is: the extent of each view, the
centres and radii of projected holes, which edges are hidden. OCCT reports most
failures as exceptions, and every wrapper turns them into Octave errors; some
bad input crashes it instead, so input is validated before it reaches the
library.

## Milestone 5: analytic curves (0.6.0)

Every curve in the package is a sampled polyline. `curvature`, `curvesample`,
`curveoffset`, `resample`, `simplify` and `arclength` all take points and
return points. There is no Bézier, no B-spline, no NURBS.

This is the largest structural gap in the geometry half, and its consequences
compound. A profile that is analytic in origin is frozen into points when it is
authored and can never be recovered: there is no exact tangency at a join, no
re-sampling at a different resolution further down the pipeline, no `SPLINE` on
export, and offsetting accumulates discretisation error instead of being
computed on the true curve. Downstream engineering packages that generate
smooth profiles pay this cost on every part they draw.

The work is a curve representation carried as a first-class entity:

- `geom.bezier`, `geom.bspline`: evaluation, derivatives, arc length
- `geom.splinefit`: interpolation through, and approximation of, a point set
- `geom.splitcurve`, `geom.curveintersect`: subdivision and curve/curve meets
- `draw.Drawing.spline`: the entity, lowered by `entities` for every backend
- exact `curveoffset` and `fillet` on the analytic form, with the sampled
  versions kept and unchanged

Note the ordering consequence for the format track below: hatching is *not* the
reason to leave DXF R12, because `geom.hatchlines` already emits hatch as line
segments and R12 carries those. A spline has no R12 representation at all.
This milestone is what makes the format work worth doing.

## Milestone 6: polygon booleans without Open CASCADE (0.7.0)

Union, intersection and difference of regions come through Open CASCADE from
0.2.0, exact for arcs and splines. What remains is the same on plain N-by-2
polygons for a build without Open CASCADE, for hatch boundaries with islands
and clearance checks there.

It should be entered with clear eyes. Vatti, Greiner-Hormann and
Martínez-Rueda each fail on degeneracies rather than on the general case:
collinear edges, coincident vertices, self-touching boundaries, edges that meet
at a point without crossing. Making them robust is the actual project, and it
needs either exact predicates or a tolerance policy chosen up front, so nothing
else is scheduled to depend on it.

## Milestone 7: profiles to solids (0.8.0)

A closed planar profile to a triangle mesh, entirely inside the package:

- `geom.extrude`: profile plus depth, with holes carried through as inner
  loops and the caps triangulated by the existing `geom.triangulate`
- `geom.revolve`: profile about an axis, with a partial-sweep option
- `geom.sweep`: profile along a path, once milestone 5 makes the path exact

This completes a pipeline the package already half owns: geometry to profile to
mesh to `stl.write`. Extrude and revolve are markedly easier than they sound
once triangulation is in hand, and they are what lets a drawing produce a part
rather than only describe one.

## Format track: runs alongside, blocks nothing

Two output formats are worth adding, on their own schedule.

**SVG backend.** The cheapest reach per line in the package. No dependency,
exact affine control, and it consumes the same lowered entity list that
`plot`, `tikz` and `dxf.write` already take, so it is a fourth consumer rather
than a new architecture. It serves documentation, the web, and everyone without
a CAD program.

**DXF R2000 (`AC1015`).** `dxf.write` emits R12 (`AC1009`), which is the most
widely accepted flavour there is and was the right first choice. Moving up has
a fixed structural cost that buys nothing visible on its own, and there is no
cheaper intermediate: R12 is the only version without entity handles, so R13
and R14 cost the same as R2000 and offer less. The entry fee:

| Piece | Work |
|---|---|
| Handles and ownership | a hex handle allocator, `$HANDSEED`, and a correct `330` owner pointer on every entity, table record and block |
| Subclass markers | `AcDbEntity` in `putcommon`, then per-type markers; `ARC` needs two and `DIMENSION` needs two of which the second depends on the dimension kind |
| Tables | `VPORT`, `STYLE`, `APPID`, `VIEW`, `UCS` and `BLOCK_RECORD` in addition to the present `LTYPE`, `LAYER` and `DIMSTYLE` |
| Blocks and objects | `*Model_Space` and `*Paper_Space` definitions, plus a root dictionary with the layout, group, mline-style and plot-style entries |
| Header | roughly twenty variables where R12 needed three |

Call it four to six hundred lines in `dxf.write` and a few focused sessions,
almost all of it mechanical. Two things make it cheaper than it looks:
`putpair` is a genuine chokepoint through which every byte passes, and
`dxf.read` is already version-agnostic: it splits on group `0`, dispatches on
the type name, and looks up fields by code, so handles, subclass markers and
owner pointers are ignored for free.

Take it up when milestone 5 gives it a reason. When it is taken up, add it as
`dxf.write (FILE, E, 'Version', 'R2000')` with R12 remaining the default, and
factor the header, tables and objects into per-version emitters, so R12 stays
under test and the new scaffolding can be validated before any new entity type
depends on it.

**Verifying the format work.** `ezdxf` is the right development-time oracle:
it covers R12 through R2018 both ways, its auditor checks precisely what is
easy to get wrong here (handle uniqueness, owner-pointer validity, dangling
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
| A solid-modelling kernel of our own | decades of work that Open CASCADE already holds; milestone 4 binds it instead |
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
- Anything new that a backend must draw is added to `draw.Drawing.entities`
  first, and then to *every* backend. A backend that silently ignores an
  entity type produces a plausible and incomplete figure, which is worse than
  an error.
