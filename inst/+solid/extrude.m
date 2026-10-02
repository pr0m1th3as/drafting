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
## @deftypefn  {drafting} {@var{S} =} solid.extrude (@var{P}, @var{H})
## @deftypefnx {drafting} {@var{S} =} solid.extrude (@var{P}, @var{H}, @var{BULGE})
##
## A solid of uniform section, extruded from a profile.
##
## @code{@var{S} = solid.extrude (@var{P}, @var{H})} returns a
## @code{solid.Shape} whose section is the closed profile @var{P}, drawn in
## the @math{xy} plane, and which rises from that plane along the positive
## @math{z} axis to the height @var{H} millimetres.  This is how a plate of
## any outline, a bracket or a key is modelled: draw its outline, then give
## it a thickness.
##
## @var{P} is an @math{N}-by-2 matrix of vertices in millimetres, closed
## implicitly from the last vertex back to the first; a repeated first vertex
## at the end is accepted and dropped.  The profile may run either way round,
## but it must enclose an area and must not cross or touch itself.
##
## @var{BULGE} gives one value per vertex, turning the segment that leaves
## that vertex into a circular arc, as in @code{draw.Drawing.polyline}: the
## tangent of a quarter of the arc's included angle, zero for a straight
## segment and 1 for a semicircle, positive for an arc that runs
## anticlockwise.  The arcs become true circular edges and cylindrical faces,
## so a rounded end extruded from a profile is exactly round.
##
## @example
## @group
## ## A slot-ended link, 40 between centres and 12 wide, 5 thick
## P = [0, -6; 40, -6; 40, 6; 0, 6];
## S = solid.extrude (P, 5, [0, 1, 0, 1]);
## volume (S)
## @result{} 2965.5
## @end group
## @end example
##
## @seealso{solid.revolve, solid.loft, draw.Drawing.polyline}
## @end deftypefn

function S = extrude (P, H, BULGE = [])

  ## Input validation
  if (nargin < 2 || nargin > 3)
    error ("solid.extrude: invalid number of input arguments.");
  endif
  [errmsg, P, BULGE] = solid.__checkprofile__ (P, BULGE, 'P', 'BULGE');
  if (isempty (errmsg))
    errmsg = solid.__checkpos__ (H, 'H');
  endif
  if (isempty (errmsg))
    errmsg = solid.__checkocct__ ();
  endif
  if (! isempty (errmsg))
    error ("solid.extrude: %s", errmsg);
  endif

  S = solid.Shape (__occt__ ('extrude', 'solid.extrude', P, BULGE, ...
                             double (H)));

endfunction

%!testif ; exist ('__occt__') == 3
%! S = solid.extrude ([0, 0; 10, 0; 10, 20; 0, 20], 5);
%! assert_equal (volume (S), 1000, 1e-9);
%! assert_equal (bbox (S), [0, 0, 0, 10, 20, 5], 1e-9);
%! assert_equal (numfaces (S), 6);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # clockwise, explicitly closed
%! S = solid.extrude ([0, 0; 0, 20; 10, 20; 10, 0; 0, 0], 5);
%! assert_equal (volume (S), 1000, 1e-9);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # an L-shaped bracket
%! S = solid.extrude ([0, 0; 30, 0; 30, 5; 5, 5; 5, 20; 0, 20], 10);
%! assert_equal (volume (S), (150 + 75) * 10, 1e-9);
%! assert_equal (numfaces (S), 8);

%!testif ; exist ('__occt__') == 3  # a slot-ended link
%! S = solid.extrude ([0, -6; 40, -6; 40, 6; 0, 6], 5, [0, 1, 0, 1]);
%! assert_equal (volume (S), (480 + 36 * pi) * 5, 1e-9);
%! assert_equal (bbox (S), [-6, -6, 0, 46, 6, 5], 1e-9);
%! assert_equal (numfaces (S), 6);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # a disc from two vertices
%! S = solid.extrude ([0, 0; 10, 0], 2, [1, 1]);
%! assert_equal (volume (S), 50 * pi, 1e-9);
%! assert_equal (area (S), 50 * pi + 20 * pi, 1e-9);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # a negative bulge rounds inwards
%! S = solid.extrude ([0, 0; 20, 0; 20, 20; 0, 20], 1, [0, 0, -1, 0]);
%! assert_equal (volume (S), 400 - 50 * pi, 1e-9);
%! assert_equal (isvalid (S), true);

%!error<solid.extrude: invalid number of input arguments.> ...
%! solid.extrude ([0, 0; 1, 0; 1, 1])
%!error<solid.extrude: P must be an N-by-2 real matrix of finite values.> ...
%! solid.extrude ([0, 0, 0; 1, 0, 0; 1, 1, 0], 1)
%!error<solid.extrude: P must be an N-by-2 real matrix of finite values.> ...
%! solid.extrude ([0, 0], 1)
%!error<solid.extrude: P must be an N-by-2 real matrix of finite values.> ...
%! solid.extrude ([0, 0; 1, NaN; 1, 1], 1)
%!error<solid.extrude: P must be an N-by-2 real matrix of finite values.> ...
%! solid.extrude ({[0, 0; 1, 0; 1, 1]}, 1)
%!error<solid.extrude: BULGE must hold one finite real value per row of P.> ...
%! solid.extrude ([0, 0; 1, 0; 1, 1], 1, [0, 0])
%!error<solid.extrude: BULGE must hold one finite real value per row of P.> ...
%! solid.extrude ([0, 0; 1, 0; 1, 1], 1, [0, Inf, 0])
%!error<solid.extrude: P must not repeat a vertex consecutively.> ...
%! solid.extrude ([0, 0; 1, 0; 1, 0; 1, 1], 1)
%!error<solid.extrude: P must enclose a nonzero area.> ...
%! solid.extrude ([0, 0; 1, 0; 2, 0], 1)
%!error<solid.extrude: P must enclose a nonzero area.> ...
%! solid.extrude ([0, 0; 10, 0], 1)
%!error<solid.extrude: P must not cross or touch itself.> ...
%! solid.extrude ([0, 0; 1, 1; 1, 0; 0, 1], 1)
%!error<solid.extrude: P must not cross or touch itself.> ...
%! solid.extrude ([0, 0; 10, 0; 10, 10; 0, 10], 1, [-2, 0, 0, 0])
%!error<solid.extrude: H must be a positive and finite real scalar.> ...
%! solid.extrude ([0, 0; 1, 0; 1, 1], 0)
