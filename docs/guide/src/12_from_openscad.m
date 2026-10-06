## Copyright (C) 2026 Andreas Bertsatos <abertsatos@biol.uoa.gr>
##
## This file is part of the drafting package for GNU Octave.
##
## This program is free software; you can redistribute it and/or modify it under
## the terms of the GNU General Public License as published by the Free Software
## Foundation; either version 3 of the License, or (at your option) any later
## version.
##
## This program is distributed in the hope that it will be useful, but WITHOUT
## ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
## FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
## details.
##
## You should have received a copy of the GNU General Public License along with
## this program; if not, see <http://www.gnu.org/licenses/>.

## # For OpenSCAD users
##
## OpenSCAD's modelling words, nearly all of them, have a counterpart here,
## in Octave and with exact geometry. This page maps one to the other and
## rebuilds a classic OpenSCAD model.
##
## ## What changes
##
## - A shape is a value in a variable, not a node in a tree: `S = subtract
##   (A, B)` makes a new shape and leaves `A` and `B` as they were. A module
##   is an Octave function that returns a shape.
## - Geometry is exact. There is no `$fn`: a cylinder is a true cylinder,
##   and facets are made only when a mesh is written, to a tolerance
##   `tessellate` and `write` take.
## - A flat shape is a `geom.Region` lying in a plane, a `geom.UCS`; a solid
##   is a `solid.Shape`. Lengths are millimetres and angles degrees.
## - Operations that can give several pieces, on regions, return a cell array
##   of regions, largest first.
##
## ## Solids
##
## - `cube ([x, y, z])` is `solid.box (DX, DY, DZ)`, and `center = true` is
##   `'Anchor', 'centroid'`.
## - `cylinder (h, r)` is `solid.cylinder (R, H)`, and `cylinder (h, r1, r2)`
##   is `solid.cone (R1, R2, H)`; `center = true` is `'Anchor', 'centroid'`.
## - `sphere (r)` is `solid.sphere (R)`.
## - `polyhedron (points, faces)` is `solid.polyhedron (polymesh.Mesh (V,
##   F))`, the faces given as triangles.
## - `surface (file)` builds a solid from a grid of heights down to a base;
##   `solid.surface (X, Y, Z, H)` fits an exact surface through such a grid
##   and makes a skin of it, `H` thick.
## - `solid.wedge`, `solid.ellipsoid` and `solid.torus` have no OpenSCAD
##   counterpart.
##
## ## Flat shapes
##
## - `square` and `polygon (points, paths)` are `geom.Region (OUTLINE,
##   HOLES)`, from corners.
## - `circle (r)` is `geom.Region ([r, 0, 1; -r, 0, 1])`: two half circles,
##   the third column the bulge of each.
## - `text ("...")` is `geom.text ('...')`, the outlines of the letters in
##   any installed font.
##
## ## Moving and changing
##
## - `translate (v)` is `translate (S, V)`.
## - `rotate (a, v)` is `rotate (S, A, V)`; `rotate ([ax, ay, az])` is three
##   rotations, about *x*, then *y*, then *z*.
## - `mirror (v)` is `mirror (S, N)`.
## - `scale (f)` is `scale (S, F)`. `scale ([fx, fy, fz])` is `resize` with
##   `'Uniform', false`, which takes sizes rather than factors: `resize (S,
##   [fx, fy, fz] .* L, 'Uniform', false)`, with `L` the sizes from `[~, L] =
##   bbox (S)`. It keeps the corner of the bounding box at the least *x*, *y*
##   and *z* in place, where OpenSCAD keeps the origin.
## - `resize (newsize)` is `resize (S, SZ, 'Uniform', false)`. Without the
##   option, `resize (S, SZ)` scales evenly, as large as fits within `SZ`.
## - `color ([r, g, b])` is `S.Colour = [r, g, b]`, kept in STEP and 3MF
##   files.
## - A region is moved by giving it another plane, `R.UCS = U`, and has
##   `mirror` and `resize` of its own.
##
## ## Booleans and hulls
##
## - `union`, `difference` and `intersection` are `union`, `subtract` and
##   `intersect`, for solids and for regions alike, each taking any number
##   of shapes.
## - `hull` is `hull`. On regions it is exact, its lines tangent to the arcs;
##   on solids it has flat faces, within a tolerance of the curved ones.
##
## ## From flat to solid and back
##
## - `linear_extrude (height = h)` is `solid.extrude (R, H)`; `center =
##   true` is `solid.extrude (R, [H/2, H/2])`, and `twist` and `scale` are
##   the options `'Twist'` and `'Scale'`. OpenSCAD turns a positive twist
##   clockwise, the package anticlockwise, so the sign changes.
## - `rotate_extrude (angle = a)` is `solid.revolve (R, A)`. The package
##   turns a region about the *y* axis of its own plane; laid in the *xz*
##   plane, `R.UCS = geom.UCS ([0, -1, 0], [0, 0, 0])`, it turns about the
##   *z* axis as in OpenSCAD.
## - `offset (r = d)` is `offset (R, D)`; `offset (delta = d)` adds
##   `'Corners', 'sharp'`, and `chamfer = true` makes it `'chamfer'`.
## - `projection ()` is `projection (S)`, and `projection (cut = true)` is
##   `section (S, geom.UCS ())`.
##
## ## Repeating
##
## - A `for` loop of `translate` is `copy (S, D)`, a row of `D` for each
##   copy; a grid is `rectarray`, and copies round an axis are `polararray`.
## - Any other loop is an Octave loop with `union`.
##
## ## Files
##
## - `import` is `solid.read` for STEP, `polymesh.read` for STL, OBJ, PLY
##   and 3MF, and `geom.read` for DXF.
## - `export` is `write`, a method of the shape written, the format named by
##   the file's extension.
##
## `minkowski` and `multmatrix` are not provided. A part is placed by a
## `geom.UCS`, which turns and moves it but never shears it.
##
## ## A classic model, rebuilt
##
## A cube and a sphere intersected, and three bores along the axes taken out
## of what is left. In OpenSCAD:

difference () {                                        #: not run
  intersection () {                                    #: not run
    cube (15, center = true);                          #: not run
    sphere (10);                                       #: not run
  }                                                    #: not run
  cylinder (h = 20, r = 5, center = true);             #: not run
  rotate ([90, 0, 0]) cylinder (h = 20, r = 5, center = true);   #: not run
  rotate ([0, 90, 0]) cylinder (h = 20, r = 5, center = true);   #: not run
}                                                      #: not run

## And here:

body = intersect (solid.box (15, 15, 15, 'Anchor', 'centroid'), ...
                  solid.sphere (10));
c = solid.cylinder (5, 20, 'Anchor', 'centroid');
S = subtract (body, c, rotate (c, 90, [1, 0, 0]), rotate (c, 90, [0, 1, 0]))
show (S);

## ## What the package adds
##
## The edges of the result are exact circles, so they can be chosen by what
## they are and rounded. `edges` with `'Type', 'circle'` picks the rims of
## the bores and of the sphere, and `fillet` rounds them:

F = fillet (S, edges (S, 'Type', 'circle'), 0.8);
show (F);

## A section is exact too, lines, arcs and splines rather than a polygon, so
## it can be built from again. The cut through the middle falls into four
## pieces:

R = section (F, geom.UCS ());
numel (R)
R{1}.Outline

## And the part goes to a CAD program as STEP, its curved faces kept, as
## well as to a slicer:

write (F, 'csg.step');
write (F, 'csg.stl');
volume (solid.read ('csg.step'))
