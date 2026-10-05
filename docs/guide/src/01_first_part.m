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

## # A first part
##
## A mounting plate from sketch to files: an outline drawn as a region, made
## solid, drilled, edged, measured, and saved for a CAD program and a slicer.
##
## ## The outline
##
## A part starts as a flat shape. Its outline here is a rectangle 90 by 50
## millimetres, given by its corners as a closed `geom.Polyline`, and `fillet`
## rounds every corner of it.

outline = geom.Polyline ([0, 0; 90, 0; 90, 50; 0, 50], 'Closed', true);
outline = fillet (outline, 8)

## A slot is two straight sides and two half circles. A polyline draws it as
## one shape: each vertex is `[x, y, bulge]`, and a bulge of 1 makes the
## segment leaving that vertex a half circle.

slot = geom.Polyline ([35, 19, 0; 55, 19, 1; 55, 31, 0; 35, 31, 1], ...
                      'Closed', true)

## `geom.Region` holds a flat area: one outline, and any holes in it given as
## a cell array. It checks that they make a valid shape, so a hole that
## crossed the outline would be refused here and not later.

R = geom.Region (outline, {slot})

## A region is drawn by putting it in a `draw.Drawing` and plotting that.

plot (draw.Drawing ().region (R));

## ## The solid
##
## `solid.extrude` raises the region along the normal of its plane, here the
## *z* axis, into a solid 6 millimetres thick. `show` draws it in a window of
## its own; the picture below is that window.

S = solid.extrude (R, 6);
show (S);

## ## Holes and edges
##
## `hole` drills at points on the surface, straight down unless told
## otherwise, and a depth of `Inf` goes right through. Four clearance holes
## for M5 countersunk screws, 5.5 millimetres across, each with a 90 degree
## seat 10.4 millimetres across at the surface:

P = [10, 10, 6; 80, 10, 6; 10, 40, 6; 80, 40, 6];
S = hole (S, P, 5.5, Inf, 'Countersink', 10.4);

## Edges are chosen by what they are rather than by number. `faces` with a
## `'Normal'` picks the faces looking up, `edges` with `'Face'` the edges
## round them, and `chamfer` bevels those, 0.5 millimetres each way.

F = faces (S, 'Normal', [0, 0, 1]);
S = chamfer (S, edges (S, 'Face', F), 0.5);
show (S);

## ## Measuring
##
## A solid knows its volume in cubic millimetres, its surface area, and its
## size along each axis, the second output of `bbox`.

volume (S)
area (S)
[~, L] = bbox (S)

## ## Files
##
## `write` saves the part in the format the file's extension names. A STEP
## file keeps the exact geometry, for a CAD program; an STL file holds
## triangles, for a slicer. A colour set on the solid travels with it into
## the STEP file and into the viewer.

S.Colour = [0.25, 0.45, 0.75];
write (S, 'plate.step');
write (S, 'plate.stl');
show (S);

## Reading the STEP file back gives the same solid.

B = solid.read ('plate.step');
volume (B)
