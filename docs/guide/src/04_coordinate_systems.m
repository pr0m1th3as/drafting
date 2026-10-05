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

## # Coordinate systems
##
## Every outline in the package lies in a `geom.UCS`, a plane with an origin
## and axes of its own. This tutorial makes them, moves points in and out of
## them, and uses them to put features on the faces of a part.
##
## ## The world and other planes
##
## `geom.UCS ()` is the world: the *xy* plane, its origin at the world
## origin. Every polyline, spline, path and region lies in it unless told
## otherwise.

W = geom.UCS ()

## Any other plane is given by its normal, the way it faces, and a point on
## it, its origin. A third point sets where the *x* axis points. This is the
## front face of a block 80 by 40 by 30 standing at the origin: it faces
## down the *y* axis, its origin is the lower left corner, and its *x* axis
## runs along the bottom edge.

front = geom.UCS ([0, -1, 0], [0, 0, 0], [80, 0, 0])

## The *y* axis is always the normal crossed with the *x* axis, so the axes
## are right handed. On this face it points up.

front.YAxis

## Without the third point the *x* axis is chosen for you, by the rule DXF
## uses: level, and running to the right as the face is seen from the side it
## faces. So *y* points up the face again. This is the right side face.

right = geom.UCS ([1, 0, 0], [80, 0, 0])

## Three points give a UCS as CAD programs do: the origin, a point along
## *+x*, and a point on the *+y* side. These three lie on the top face.

top = geom.UCS.threepoint ([0, 0, 30], [80, 0, 30], [0, 40, 30])

## ## Points in a UCS
##
## `toworld` turns coordinates in a UCS into world coordinates, and
## `tolocal` turns them back, with a third column for the height above the
## plane. The point 10 along and 5 up the front face:

toworld (front, [10, 5])

## A point 3 millimetres in front of that face is 3 above its plane, since
## the plane's normal points out of the block.

tolocal (front, [10, -3, 5])

## ## A profile on a face
##
## A region is drawn in its own coordinates, and its `UCS` says where those
## are. Draw a boss as if on paper, a ring 20 across with a bore of 8, centred
## 40 along and 15 up. Giving it the front face's UCS moves it onto that face,
## shape unchanged.

block = solid.box (80, 40, 30);
boss = geom.Region ([30, 15, 1; 50, 15, 1], {[36, 15, 1; 44, 15, 1]});
boss.UCS = front;

## `solid.extrude` raises a region along its plane's normal, so on the front
## face it grows out of the block, towards *-y*. United with the block, the
## boss stands 12 proud of the face.

part = union (block, solid.extrude (boss, 12));
show (part);

## ## Placing primitives
##
## The primitives take a UCS as their last argument and are built in it. A
## cylinder stands on the origin of its UCS, along the normal. With the
## origin at the middle of the top face, a pin 12 across and 15 high stands
## there.

U = geom.UCS ([0, 0, 1], [40, 20, 30]);
pin = solid.cylinder (6, 15, U);

## `'Anchor'` says which point of the primitive lands on the origin. A box
## sits by its corner unless told otherwise; with `'base'` the centre of its
## bottom face lands there. With the origin at the middle of the right face,
## a lug 20 by 20 stands out of that face, centred on it.

lug = solid.box (20, 20, 10, geom.UCS ([1, 0, 0], [80, 20, 15]), ...
                 'Anchor', 'base');
part = union (part, pin, lug);
show (part);

[~, L] = bbox (part)

## ## Picking a UCS with the mouse
##
## A UCS can also be picked on a shape in the viewer: click a flat face and
## two points along it for the axes, or with `'points'` three points, then a
## point for the origin. Every click snaps to a corner, the centre of a round
## edge or the middle of a straight one. The pick prints the line that makes
## the same UCS from coordinates, to paste into the script, so the script
## never depends on a person at the mouse. Those lines need someone at the
## window, so they are shown here and not run.

V = show (part);                     #: not run
U = geom.UCS (V);                    #: not run
U = pickucs (V, 'points');           #: not run
