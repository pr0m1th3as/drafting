# drafting

Planar geometry, ASCII DXF input and output, and a technical drawing model for
GNU Octave.

The package provides the drafting layer an engineering design package needs:
compute geometry, build a drawing from it, and emit that drawing as a DXF file a
CAD program or a CNC machine will accept, or as LaTeX for a report.

## Layout

```
inst/+geom    planar geometry — no file formats, no drawing semantics
inst/+dxf     AutoCAD R12 (AC1009) ASCII DXF, both directions
inst/+draw    format-agnostic drawing model, with DXF and TikZ backends
inst/tests    classdef .m-tst suites
```

Dependencies point downward only: `+draw` builds on `+geom` and emits through
`+dxf`; `+geom` and `+dxf` know nothing of drawings.

## Example

```
D = draw.Drawing ('plate');
D = D.circle ([0, 0], 25);
D = D.polyline ([-40, -40; 40, -40; 40, 40; -40, 40], true);
D = D.dim ([-40, -40], [40, -40], -10, 'horizontal');
dxf.write ('plate.dxf', draw.entities (D));
```

All geometry is in millimetres.

## Why R12 rather than a later DXF revision

R12 needs no entity handles, no object dictionary and no class table, so the
files are small, readable and accepted essentially everywhere. The one cost is
that R12 has no `SPLINE` and no `LWPOLYLINE`; polylines are written as
`POLYLINE` with a vertex list, which is what a manufacturing toolpath wants in
any case.

## Testing

```bash
pkg test drafting
```

During development, test the working copy by path — namespaced names do not
resolve through `test`:

```bash
octave --eval "addpath ('inst'); test ('inst/+geom/offset.m')"
```

## License

GPLv3. See [`COPYING`](COPYING).
