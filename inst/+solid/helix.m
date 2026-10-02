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
## @deftypefn  {drafting} {@var{S} =} solid.helix (@var{P}, @var{PITCH}, @var{TURNS})
## @deftypefnx {drafting} {@var{S} =} solid.helix (@var{P}, @var{PITCH}, @var{TURNS}, @var{BULGE})
##
## A coil, swept by a profile turning about the @math{z} axis as it rises.
##
## @code{@var{S} = solid.helix (@var{P}, @var{PITCH}, @var{TURNS})} returns a
## @code{solid.Shape} traced by the closed profile @var{P} as it turns
## @var{TURNS} times about the @math{z} axis, rising @var{PITCH} millimetres
## on every turn.  The columns of @var{P} are the radius and the height, as
## for @code{solid.revolve}, and the profile stays in the plane through the
## axis all the way round, as the profile of a thread does.  This is how a
## coil spring, a thread or a worm is modelled.
##
## @var{P} is an @math{N}-by-2 matrix of vertices in millimetres, closed
## implicitly from the last vertex back to the first; a repeated first vertex
## at the end is accepted and dropped.  It must enclose an area and must not
## cross or touch itself.  It must lie clear of the axis, every radius
## positive, and must be shorter along @math{z} than @var{PITCH}, or one turn
## would run into the next.  The coil turns anticlockwise seen from above,
## which is a right-hand helix; mirror it with @code{solid.Shape.mirror} for a
## left-hand one.  @var{TURNS} need not be a whole number.
##
## @var{BULGE} gives one value per vertex of @var{P}, turning the segment
## that leaves that vertex into a circular arc, as in
## @code{draw.Drawing.polyline}: the tangent of a quarter of the arc's
## included angle, zero for a straight segment and 1 for a semicircle,
## positive for an arc that runs anticlockwise.
##
## A coil's volume is its profile's area times the distance its centroid
## travels round the axis, @math{2 \pi r} on every turn; the rise adds
## nothing.  The surfaces are splines fitted to the exact helix, so a volume
## or extent agrees with that to a few parts in a million.
##
## @example
## @group
## ## A compression spring of wire diameter 2 on a mean diameter of 20,
## ## five turns at a pitch of 4
## S = solid.helix ([9, 1; 11, 1], 4, 5, [1, 1]);
## @end group
## @end example
##
## @seealso{solid.revolve, solid.sweep, draw.Drawing.polyline}
## @end deftypefn

function S = helix (P, PITCH, TURNS, BULGE = [])

  ## Input validation
  if (nargin < 3 || nargin > 4)
    error ("solid.helix: invalid number of input arguments.");
  endif
  [errmsg, P, BULGE, Q] = solid.__checkprofile__ (P, BULGE, 'P', 'BULGE');
  if (isempty (errmsg) && min (Q(:,1)) <= 0)
    errmsg = "P must lie clear of the axis: every radius must be positive.";
  endif
  if (isempty (errmsg))
    errmsg = solid.__checkpos__ (PITCH, 'PITCH');
  endif
  if (isempty (errmsg) && max (Q(:,2)) - min (Q(:,2)) >= PITCH)
    errmsg = strcat ("P must be shorter along z than PITCH, or one turn", ...
                     " would run into the next.");
  endif
  if (isempty (errmsg))
    errmsg = solid.__checkpos__ (TURNS, 'TURNS');
  endif
  if (isempty (errmsg))
    errmsg = solid.__checkocct__ ();
  endif
  if (! isempty (errmsg))
    error ("solid.helix: %s", errmsg);
  endif

  ## The spine runs through the middle of the profile's radial extent
  r = (min (Q(:,1)) + max (Q(:,1))) / 2;
  S = solid.Shape (__occt__ ('helix', 'solid.helix', P, BULGE, ...
                             double (PITCH), double (TURNS), r));

endfunction

%!testif ; exist ('__occt__') == 3  # a square section, two turns
%! S = solid.helix ([9.5, 0; 10.5, 0; 10.5, 1; 9.5, 1], 3, 2);
%! assert_equal (volume (S), 2 * pi * 10 * 2, -5e-6);
%! assert_equal (bbox (S), [-10.5, -10.5, 0, 10.5, 10.5, 7], 1e-4);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # a spring of round wire
%! S = solid.helix ([9, 1; 11, 1], 4, 5, [1, 1]);
%! assert_equal (volume (S), pi * 2 * pi * 10 * 5, -5e-6);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # a triangular thread, half a turn
%! S = solid.helix ([5, 0; 6, 0.5; 5, 1], 2, 0.5);
%! assert_equal (volume (S), 0.5 * 2 * pi * (5 + 1 / 3) * 0.5, -5e-6);
%! assert_equal (bbox (S)([3, 6]), [0, 2], 1e-4);
%! assert_equal (isvalid (S), true);

%!error<solid.helix: invalid number of input arguments.> ...
%! solid.helix ([1, 0; 2, 0; 2, 1], 2)
%!error<solid.helix: P must not cross or touch itself.> ...
%! solid.helix ([1, 0; 2, 1; 2, 0; 1, 1], 2, 1)
%!error<solid.helix: P must lie clear of the axis: every radius must be positive.> ...
%! solid.helix ([0, 0; 2, 0; 2, 1], 2, 1)
%!error<solid.helix: P must lie clear of the axis: every radius must be positive.> ...
%! solid.helix ([1, 0; 1, 4], 5, 1, [0, 1])
%!error<solid.helix: PITCH must be a positive and finite real scalar.> ...
%! solid.helix ([1, 0; 2, 0; 2, 1], 0, 1)
%!error<solid.helix: P must be shorter along z than PITCH, or one turn would run into the next.> ...
%! solid.helix ([1, 0; 2, 0; 2, 1], 1, 1)
%!error<solid.helix: TURNS must be a positive and finite real scalar.> ...
%! solid.helix ([1, 0; 2, 0; 2, 1], 2, -1)
