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
## @deftypefn  {drafting} {@var{S} =} solid.helix (@var{R}, @var{PITCH}, @var{TURNS})
##
## A coil, swept by a region turning about its own axis as it rises.
##
## @code{@var{S} = solid.helix (@var{R}, @var{PITCH}, @var{TURNS})} returns a
## @code{solid.Shape} traced by the @code{geom.Region} @var{R} as it turns
## @var{TURNS} times about the @math{y} axis of its plane, through the plane's
## origin, rising @var{PITCH} millimetres along that axis on every turn.  As
## for @code{solid.revolve}, the region's @math{x} coordinate is the radius
## and its @math{y} coordinate the position along the axis, and the region
## stays in the plane through the axis all the way round, as the profile of a
## thread does.  This is how a coil spring, a thread or a worm is modelled.  A
## hole in the region makes the coil a tube.
##
## A region in the default @math{xy} plane coils about the model's @math{y}
## axis; draw it in the @math{xz} plane for a coil along @math{z}.  The coil
## turns anticlockwise seen from the tip of its axis, which is a right-hand
## helix; mirror it with @code{solid.Shape.mirror} for a left-hand one.
## @var{TURNS} need not be a whole number.
##
## The region must lie clear of the axis, every point of it at a positive
## @math{x}, and must be shorter along its @math{y} axis than @var{PITCH}, or
## one turn would run into the next.
##
## A coil's volume is its region's area times the distance the region's
## centroid travels round the axis, @math{2 \pi r} on every turn; the rise
## adds nothing.  The surfaces are splines fitted to the exact helix, so a
## volume or extent agrees with that to a few parts in a million.
##
## @example
## @group
## ## A compression spring along z: wire of diameter 2 on a mean diameter of
## ## 20, five turns at a pitch of 4
## R = geom.Region ([9, 1, 1; 11, 1, 1]);
## R.UCS = geom.UCS ([0, -1, 0], [0, 0, 0]);   # the xz plane: y is world z
## S = solid.helix (R, 4, 5);
## @end group
## @end example
##
## @seealso{geom.Region, solid.revolve, solid.sweep}
## @end deftypefn

function S = helix (R, PITCH, TURNS)

  ## Input validation
  if (nargin != 3)
    error ("solid.helix: invalid number of input arguments.");
  endif
  [errmsg, D] = solid.__region__ (R, 'R');
  if (isempty (errmsg))
    Q = __sample__ (R.Outline);
    if (min (Q(:,1)) <= 0)
      errmsg = strcat ("R must lie clear of its axis: every point of it", ...
                       " must have a positive x.");
    endif
  endif
  if (isempty (errmsg))
    errmsg = solid.__checkpos__ (PITCH, 'PITCH');
  endif
  if (isempty (errmsg) && max (Q(:,2)) - min (Q(:,2)) >= PITCH)
    errmsg = strcat ("R must be shorter along its axis than PITCH, or one", ...
                     " turn would run into the next.");
  endif
  if (isempty (errmsg))
    errmsg = solid.__checkpos__ (TURNS, 'TURNS');
  endif
  if (! isempty (errmsg))
    error ("solid.helix: %s", errmsg);
  endif

  ## The spine runs through the middle of the region's radial extent
  r = (min (Q(:,1)) + max (Q(:,1))) / 2;
  S = solid.Shape (__occt__ ('helix', 'solid.helix', D, double (PITCH), ...
                             double (TURNS), r));

endfunction

%!test  # a square section, two turns about y
%! S = solid.helix (geom.Region ([9.5, 0; 10.5, 0; 10.5, 1; 9.5, 1]), 3, 2);
%! assert_equal (volume (S), 2 * pi * 10 * 2, -5e-6);
%! assert_equal (bbox (S), [-10.5, 0, -10.5, 10.5, 7, 10.5], 1e-4);
%! assert_equal (isvalid (S), true);

%!test  # a spring of round wire along z
%! R = geom.Region ([9, 1, 1; 11, 1, 1]);
%! R.UCS = geom.UCS ([0, -1, 0], [0, 0, 0]);
%! S = solid.helix (R, 4, 5);
%! assert_equal (volume (S), pi * 2 * pi * 10 * 5, -5e-6);
%! assert_equal (bbox (S)([3, 6]), [0, 22], 1e-4);
%! assert_equal (isvalid (S), true);

%!test  # a triangular thread, half a turn
%! S = solid.helix (geom.Region ([5, 0; 6, 0.5; 5, 1]), 2, 0.5);
%! assert_equal (volume (S), 0.5 * 2 * pi * (5 + 1 / 3) * 0.5, -5e-6);
%! assert_equal (bbox (S)([2, 5]), [0, 2], 1e-4);
%! assert_equal (isvalid (S), true);

%!test  # a coiled tube, its hole carried round
%! R = geom.Region ([9, 1, 1; 11, 1, 1], {[9.5, 1, 1; 10.5, 1, 1]});
%! S = solid.helix (R, 4, 1);
%! assert_equal (volume (S), (pi - pi / 4) * 2 * pi * 10, -5e-6);
%! assert_equal (isvalid (S), true);

%!test  # a section of a closed spline
%! R = geom.Region (geom.Spline ([10, 0; 12, 0; 13, 1.5; 11, 2.5; 9.5, 1.2], ...
%!                               'Closed', true));
%! S = solid.helix (R, 4, 2);
%! assert_equal (numsolids (S), 1);
%! assert_equal (isvalid (S), true);

%!error<solid.helix: invalid number of input arguments.> ...
%! solid.helix (geom.Region ([1, 0; 2, 0; 2, 1]), 2)
%!error<solid.helix: R must be a geom.Region object.> ...
%! solid.helix ([1, 0; 2, 0; 2, 1], 2, 1)
%!error<solid.helix: R must lie clear of its axis: every point of it must have a positive x.> ...
%! solid.helix (geom.Region ([0, 0; 2, 0; 2, 1]), 2, 1)
%!error<solid.helix: R must lie clear of its axis: every point of it must have a positive x.> ...
%! solid.helix (geom.Region ([1, 0, 0; 1, 4, 1]), 5, 1)
%!error<solid.helix: PITCH must be a positive and finite real scalar.> ...
%! solid.helix (geom.Region ([1, 0; 2, 0; 2, 1]), 0, 1)
%!error<solid.helix: R must be shorter along its axis than PITCH, or one turn would run into the next.> ...
%! solid.helix (geom.Region ([1, 0; 2, 0; 2, 1]), 1, 1)
%!error<solid.helix: TURNS must be a positive and finite real scalar.> ...
%! solid.helix (geom.Region ([1, 0; 2, 0; 2, 1]), 2, -1)
