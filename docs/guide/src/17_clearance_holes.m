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

## # Clearance holes, counterbores and countersinks
##
## A screw that clamps one part to another is tapped into the second and
## passes through a clearance hole in the first. The tutorial on holes and
## threads tapped the second part; this one drills the first: the clearance
## hole, and the counterbore or countersink that sinks the screw's head.
##
## Their sizes come from standards, and `solid.holespec` gives them before
## anything is drilled, so that a part can be laid out around them. Where
## each number comes from is set out on the standards page
## [Clearance holes, counterbores and countersinks](standards_holes.html).
##
## ## Reading a hole before drilling it
##
## `solid.holespec` takes the thread of the screw and the options `hole`
## takes. With `'Clearance'` the hole is the clearance hole of ISO 273, in
## its fine, medium or coarse series, and `'Counterbore', true` adds the
## counterbore for a socket head cap screw.

H = solid.holespec ('M6', 'Clearance', 'medium', 'Counterbore', true)

## The hole is 6.6 across, and the counterbore 11 across and 6.8 deep.
##
## ## A cover held by four cap screws
##
## A cover 60 by 40 and 10 thick is held down by four M6 cap screws. Each
## counterbore must clear the edges by 2, so the screws stand that far in
## from the corners, read from the counterbore before it is cut.

e = H.counterbore(1) / 2 + 2
P = [e, e, 10; 60 - e, e, 10; e, 40 - e, 10; 60 - e, 40 - e, 10];
cover = solid.box (60, 40, 10);
cover = hole (cover, P, 'M6', Inf, 'Clearance', 'medium', ...
              'Counterbore', true);
show (cover);

## The screw clamps through what the counterbore leaves of the cover, which
## sets its length together with the depth it is tapped into the base.

grip = 10 - H.counterbore(2)

## Cut in half through two of the screws, the cover shows the counterbores.

half = subtract (cover, solid.box (60, 7.5, 10));
show (half);

## ## On a washer
##
## A cap screw on a plain washer needs a counterbore wider and deeper by the
## washer: `'Counterbore', 'washer'`.

W = solid.holespec ('M6', 'Clearance', 'medium', 'Counterbore', 'washer');
W.counterbore

## ## Countersunk screws
##
## A countersink seats a countersunk head. `'Countersink', true` is the one
## for the slotted, cross recessed and hexalobular countersunk screws, whose
## heads ISO 7721 gives, and `'Countersink', 'socket'` the one for hexagon
## socket countersunk screws, whose heads are larger. Each is given as its
## diameter at the surface, its angle and the depth of a cylinder above the
## cone. In the medium series the countersink is a plain cone; in the fine
## series it sits under a short cylinder, so that the head can sit just
## below the surface.

A = solid.holespec ('M6', 'Clearance', 'medium', 'Countersink', true);
B = solid.holespec ('M6', 'Clearance', 'fine', 'Countersink', true);
C = solid.holespec ('M6', 'Clearance', 'fine', 'Countersink', 'socket');
[A.countersink; B.countersink; C.countersink]

## The three side by side in a strip, cut in half along their row.

strip = solid.box (90, 30, 10);
strip = hole (strip, [15, 15, 10], 'M6', Inf, 'Clearance', 'medium', ...
              'Countersink', true);
strip = hole (strip, [45, 15, 10], 'M6', Inf, 'Clearance', 'fine', ...
              'Countersink', true);
strip = hole (strip, [75, 15, 10], 'M6', Inf, 'Clearance', 'fine', ...
              'Countersink', 'socket');
show (subtract (strip, solid.box (90, 15, 10)));

## ## What the standards do not give
##
## A tapped hole has no head to seat, so a counterbore or countersink is
## refused without `'Clearance'`.

hole (cover, [30, 20, 10], 'M6', Inf, 'Counterbore', true);  #: error

## The counterbores and countersinks are given for the fine and medium
## series only, and the one for a socket head in the fine series only.

solid.holespec ('M6', 'Clearance', 'coarse', 'Counterbore', true);  #: error
solid.holespec ('M6', 'Clearance', 'medium', 'Countersink', 'socket');  #: error

## ## Numbers instead
##
## A counterbore or countersink of another size is given by its numbers,
## which are taken as given. The common case is a deeper counterbore, so
## that a screw of a standard length reaches the base: 8 deep instead of
## 6.8 leaves a grip of 2.

deep = solid.holespec ('M6', 'Clearance', 'medium', 'Counterbore', [11, 8]);
deep.counterbore
cover = solid.box (60, 40, 10);
cover = hole (cover, P, 'M6', Inf, 'Clearance', 'medium', ...
              'Counterbore', [11, 8]);

## Numbers are also how a hole for a screw outside the standards is drilled,
## from a plain diameter; the standard sizes need the thread named.

plate = hole (solid.box (40, 40, 8), [20, 20, 8], 6.6, Inf, ...
              'Countersink', [13, 90, 0.5]);
hole (plate, [20, 20, 8], 6.6, Inf, 'Counterbore', true);  #: error
