# drafting — roadmap

This is where the package is going and why. It is a statement of intent, not a
schedule: milestones are ordered by what unblocks what, and the version tags
are indicative. Anything here may be reordered by what turns out to be needed.

## Where the package stands

Version 0.1.0 is feature-complete for a first release: thirty-one public
functions across `+geom`, `+dxf`, `+stl` and `+draw`, the `draw.Drawing` class
with its three backends, 814 built-in self-tests, and a `%!demo` block on
nearly every function that ends in a plot, so the documentation shows rather
than asserts.

The file loop is closed in that release. `draw.Drawing.entities` lowers a
drawing to a flat entity list and `draw.fromentities` raises one back, blocks
and all, with dimensions returning as dimensions that measure their geometry
again. A DXF is a round trip rather than a one-way door, which is what makes
the ordinary workflow — open an existing drawing, add to it, write it back —
possible at all.

The geometry half of the package is strong. The drafting half — the part that
encodes what a technical drawing *means* rather than what shape it is — is
thinner, and most of this roadmap is about closing that gap.

## Scope

The package covers **planar geometry, the drawing model built on it, and the
formats that model is emitted in**. Two boundaries follow from that, and both
are deliberate:

- A drawing describes a part. It does not machine one. Toolpath generation,
  cutter compensation, feeds and speeds, and post-processor dialects belong to
  a CAM package that consumes this one.
- The model is planar. Meshes are produced *from* planar profiles and written
  out, but the package holds no solid-modelling kernel and no B-rep.

Everything below is checked against those two lines.

## Milestone 1 — close the package's own shape (0.2.0)

Small, unglamorous work that removes asymmetries in what is already here. Each
item costs little and each one is noticed the moment it is missing.

**A test that renders.** Nothing in the suite draws a page or prints a figure.
Every visual defect found so far was caught by eye and by nothing else: geometry
sitting on the axes and reading as part of them, a fillet demo leaving a stray
marker in the frame, tangent radii drawn on a centre line type that renders as a
squiggle over a short span, five line types collapsing into one at figure size.
Every one of those passed its tests. The standing requirement below asks for a
demo rendered and looked at, and that discipline has earned its place — but it
is a habit, and a habit is not a gate.

A fixture drawing whose *output* is asserted would make it one: that a printed
sheet comes out at the paper size and scale asked for, that the geometry falls
clear of the frame, that a dimension's text clears its own dimension line, that
every entity type reaches every backend. It costs little, it goes first because
it protects everything after it, and it is the difference between a package that
happens to render correctly and one that will notice when it stops.

**Units in the model.** The millimetre loop is closed and correct: `dxf.read`
converts an inch file to millimetres on the way in — a one-inch line arrives as
25.4 — and `dxf.write` declares `$INSUNITS` as millimetres on the way out. So
this is not a correctness hole, and nothing is silently mis-scaled.

What is missing is the ability to *work* in anything else. A `Units` property on
`Drawing`, honoured by `print`, `dxf.write` and `stl.write`, would let a drawing
be authored in inches and say so in its output, rather than requiring the author
to convert in their head. Worth having, and an ergonomic feature rather than a
fix — so it earns its place here on cost, not on urgency.

**Elementary geometric queries.** The package can offset a polygon and find the
largest rectangle inside it, but cannot answer where the nearest point on a
polyline is. The following are each between five and thirty lines, and their
absence forces every downstream package to write them again, worse:

| Function | What it answers |
|---|---|
| `geom.distance` | point to segment, polyline or polygon boundary |
| `geom.nearestpoint` | the closest point on a curve, and its parameter |
| `geom.projectpoint` | orthogonal projection onto a line or segment |
| `geom.convexhull` | the hull of a point set, consistently oriented |
| `geom.orientedbbox` | minimum-area enclosing rectangle — the circumscribed dual of `largestrect` |
| `geom.minimumcircle` | smallest enclosing circle |

**`stl.read`.** The `stl` namespace writes and cannot read. Both the ASCII and
binary forms are an afternoon's work, and a package that emits meshes for other
tools ought to be able to take them back.

## Milestone 2 — the language of a technical drawing (0.3.0)

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

## Milestone 3 — sheets and multi-view composition (0.4.0)

`draw.Drawing.print` places one drawing on one sheet at one scale. A real
drawing is three orthographic views, an isometric and a detail at 2:1, each in
its own viewport at its own scale, arranged around a title block.

A `draw.Sheet` object holding placed, independently scaled viewports over a set
of `Drawing`s would turn the package's primary human-facing output from a
figure into a drawing. It is also where the section and detail marks of
milestone 2 acquire something to point at, and it is the natural home for DXF
paper-space layouts should the format track below be taken up — so the two
reinforce each other rather than compete.

`print` already emits true vector PDF — embedded fonts, no image stream — and
`Resolution` applies only to the raster formats, as its docstring states. So
there is nothing to confirm before starting: a sheet composed of viewports will
print as vector, and the work can be built on that.

## Milestone 4 — analytic curves (0.5.0)

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

- `geom.bezier`, `geom.bspline` — evaluation, derivatives, arc length
- `geom.splinefit` — interpolation through, and approximation of, a point set
- `geom.splitcurve`, `geom.curveintersect` — subdivision and curve/curve meets
- `draw.Drawing.spline` — the entity, lowered by `entities` for every backend
- exact `curveoffset` and `fillet` on the analytic form, with the sampled
  versions kept and unchanged

Note the ordering consequence for the format track below: hatching is *not* the
reason to leave DXF R12, because `geom.hatchlines` already emits hatch as line
segments and R12 carries those. A spline has no R12 representation at all.
This milestone is what makes the format work worth doing.

## Milestone 5 — polygon booleans (0.6.0)

Union, intersection, difference and exclusive-or on polygons with holes. This
is the workhorse operation of two-dimensional CAD, and core Octave has nothing
like it. It unlocks hatch boundaries with islands, clearance and interference
checks, material-removal work, and profile combination.

It should be entered with clear eyes. Vatti, Greiner–Hormann and
Martínez–Rueda are each of publishable quality, and every one of them fails on
degeneracies rather than on the general case: collinear edges, coincident
vertices, self-touching boundaries, and edges that meet at a point without
crossing. Getting the happy path working is a week. Making it robust is the
actual project, and it requires either exact geometric predicates or a
deliberate, documented and tested tolerance policy — chosen up front, not
discovered.

Because of that risk this milestone stands alone, and nothing else should be
scheduled to depend on it landing on time.

## Milestone 6 — profiles to solids (0.7.0)

A closed planar profile to a triangle mesh, entirely inside the package:

- `geom.extrude` — profile plus depth, with holes carried through as inner
  loops and the caps triangulated by the existing `geom.triangulate`
- `geom.revolve` — profile about an axis, with a partial-sweep option
- `geom.sweep` — profile along a path, once milestone 4 makes the path exact

This completes a pipeline the package already half owns: geometry to profile to
mesh to `stl.write`. Extrude and revolve are markedly easier than they sound
once triangulation is in hand, and they are what lets a drawing produce a part
rather than only describe one.

## Format track — runs alongside, blocks nothing

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
`dxf.read` is already version-agnostic — it splits on group `0`, dispatches on
the type name, and looks up fields by code, so handles, subclass markers and
owner pointers are ignored for free.

Take it up when milestone 4 gives it a reason. When it is taken up, add it as
`dxf.write (FILE, E, 'Version', 'R2000')` with R12 remaining the default, and
factor the header, tables and objects into per-version emitters — so R12 stays
under test and the new scaffolding can be validated before any new entity type
depends on it.

**Verifying the format work.** `ezdxf` is the right development-time oracle:
it covers R12 through R2018 both ways, its auditor checks precisely what is
easy to get wrong here (handle uniqueness, owner-pointer validity, dangling
table references), and it can write files for the reader to be tested against.
Two cautions. Its ordinary loader silently repairs what it reads, so anything
inspected after a plain load may be its corrected version rather than what was
written — the audit result must be asserted, not assumed. And it validates
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
| Solid modelling, B-rep | a kernel, not a package |
| Parametric constraint solving | genuinely valuable and genuinely a research project — degree-of-freedom analysis, conditioning, and useful diagnostics for under- and over-constrained sketches. Its own package if ever |
| Hidden-line removal from meshes | the one item worth revisiting later: orthographic and isometric views generated from a solid would be a real capability, but doing it robustly on triangle soup is hard |

## Standing requirements

These apply to every milestone and are not restated in them.

- Correctness first, verified at the edges: degenerate input, coincident
  points, zero-length segments, NaN and Inf.
- Built-in self-tests are a deliverable, covering normal use, edge cases and
  every error branch.
- Texinfo help must explain the function completely without recourse to the
  source.
- A `%!demo` block that ends in a plot, rendered and looked at. A demo that
  runs is not a demo that reads. Until the rendering gate of milestone 1 is in
  place this is enforced by eye alone, which is why it is written down here.
- Anything new that a backend must draw is added to `draw.Drawing.entities`
  first, and then to *every* backend. A backend that silently ignores an
  entity type produces a plausible and incomplete figure, which is worse than
  an error.
