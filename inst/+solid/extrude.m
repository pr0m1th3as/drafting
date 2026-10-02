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


## -*- texinfo -*-
## @deftypefn {drafting} {@var{S} =} solid.extrude (@var{R}, @var{H})
##
## A solid of uniform section, extruded from a region.
##
## @code{@var{S} = solid.extrude (@var{R}, @var{H})} returns a
## @code{solid.Shape} whose section is the @code{geom.Region} @var{R}, rising
## from the region's plane along its normal to the height @var{H}
## millimetres.  This is how a plate of any outline, a bracket or a key is
## modelled: draw its outline, then give it a thickness.  The holes of the
## region go right through.
##
## A region in the default @math{xy} plane rises along @math{+z}.  A region on
## another plane rises square to it, so a boss on a sloping face is a region
## in the plane of that face, extruded.  Arcs in the outlines become true
## circular edges and cylindrical faces, so a rounded end or a round hole is
## exact.
##
## @example
## @group
## ## A flange 3 thick: rounded ends, a bore of 20 and two holes of 6
## R = geom.Region ([-20, -20, 0; 20, -20, 1; 20, 20, 0; -20, 20, 1], ...
##                  @{[10, 0, 1; -10, 0, 1], [-22, 0, 1; -28, 0, 1], ...
##                   [28, 0, 1; 22, 0, 1]@});
## S = solid.extrude (R, 3);
## @end group
## @end example
##
## @seealso{geom.Region, solid.revolve, solid.loft, solid.sweep}
## @end deftypefn

function S = extrude (R, H)

  ## Input validation
  if (nargin != 2)
    error ("solid.extrude: invalid number of input arguments.");
  endif
  [errmsg, D] = solid.__region__ (R, 'R');
  if (isempty (errmsg))
    errmsg = solid.__checkpos__ (H, 'H');
  endif
  if (isempty (errmsg))
    errmsg = solid.__checkocct__ ();
  endif
  if (! isempty (errmsg))
    error ("solid.extrude: %s", errmsg);
  endif

  S = solid.Shape (__occt__ ('extrude', 'solid.extrude', D, double (H)));

endfunction

%!testif ; exist ('__occt__') == 3
%! S = solid.extrude (geom.Region ([0, 0; 10, 0; 10, 20; 0, 20]), 5);
%! assert_equal (volume (S), 1000, 1e-9);
%! assert_equal (bbox (S), [0, 0, 0, 10, 20, 5], 1e-9);
%! assert_equal (numfaces (S), 6);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # an L-shaped bracket
%! R = geom.Region ([0, 0; 30, 0; 30, 5; 5, 5; 5, 20; 0, 20]);
%! S = solid.extrude (R, 10);
%! assert_equal (volume (S), (150 + 75) * 10, 1e-9);
%! assert_equal (numfaces (S), 8);

%!testif ; exist ('__occt__') == 3  # a slot-ended link
%! R = geom.Region ([0, -6, 0; 40, -6, 1; 40, 6, 0; 0, 6, 1]);
%! S = solid.extrude (R, 5);
%! assert_equal (volume (S), (480 + 36 * pi) * 5, 1e-9);
%! assert_equal (bbox (S), [-6, -6, 0, 46, 6, 5], 1e-9);
%! assert_equal (numfaces (S), 6);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # a disc from two vertices
%! S = solid.extrude (geom.Region ([0, 0, 1; 10, 0, 1]), 2);
%! assert_equal (volume (S), 50 * pi, 1e-9);
%! assert_equal (area (S), 50 * pi + 20 * pi, 1e-9);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # a negative bulge rounds inwards
%! R = geom.Region ([0, 0, 0; 20, 0, 0; 20, 20, -1; 0, 20, 0]);
%! S = solid.extrude (R, 1);
%! assert_equal (volume (S), 400 - 50 * pi, 1e-9);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # holes of any shape go right through
%! R = geom.Region ([0, 0; 60, 0; 60, 40; 0, 40], ...
%!                  {[20, 20, 1; 40, 20, 1], [4, 4; 10, 4; 10, 10; 4, 10]});
%! S = solid.extrude (R, 3);
%! assert_equal (volume (S), (2400 - 100 * pi - 36) * 3, 1e-9);
%! assert_equal (numfaces (S), 6 + 2 + 4);   # a bore of two arcs, two faces
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # square to a sloping plane
%! n = [0, -0.6, 0.8];
%! R = geom.Region ([0, 0; 10, 0; 10, 10; 0, 10]);
%! R.UCS = geom.UCS (n, [0, 0, 5]);
%! S = solid.extrude (R, 4);
%! assert_equal (volume (S), 400, 1e-9);
%! c = [0, 0, 5] + 5 * R.UCS.XAxis + 5 * R.UCS.YAxis + 2 * n;
%! assert_equal (centroid (S), c, 1e-9);
%! assert_equal (isvalid (S), true);

%!error<solid.extrude: invalid number of input arguments.> ...
%! solid.extrude (geom.Region ([0, 0; 1, 0; 1, 1]))
%!error<solid.extrude: R must be a geom.Region object.> ...
%! solid.extrude ([0, 0; 1, 0; 1, 1], 1)
%!error<solid.extrude: R must be a geom.Region object.> ...
%! solid.extrude (geom.Polyline ([0, 0; 1, 0; 1, 1], 'Closed', true), 1)
%!error<solid.extrude: H must be a positive and finite real scalar.> ...
%! solid.extrude (geom.Region ([0, 0; 1, 0; 1, 1]), 0)
