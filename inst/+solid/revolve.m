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
## @deftypefn  {drafting} {@var{S} =} solid.revolve (@var{P})
## @deftypefnx {drafting} {@var{S} =} solid.revolve (@var{P}, @var{ANGLE})
## @deftypefnx {drafting} {@var{S} =} solid.revolve (@var{P}, @var{ANGLE}, @var{BULGE})
##
## A solid of revolution, turned from a profile about the @math{z} axis.
##
## @code{@var{S} = solid.revolve (@var{P})} returns a @code{solid.Shape} swept
## by the closed profile @var{P} turning once about the @math{z} axis.  The
## columns of @var{P} are the radius and the height: the profile is the half
## section of the part, as a turned part is drawn.  This is how a shaft, a
## bush, a pulley or a knob is modelled.
##
## @var{P} is an @math{N}-by-2 matrix of vertices in millimetres, closed
## implicitly from the last vertex back to the first; a repeated first vertex
## at the end is accepted and dropped.  The profile may run either way round,
## but it must enclose an area, must not cross or touch itself, and must lie
## on one side of the axis: every radius, along its arcs too, nonnegative.  It
## may run along the axis, as the profile of a solid shaft does.
##
## @code{@var{S} = solid.revolve (@var{P}, @var{ANGLE})} turns the profile
## through @var{ANGLE} degrees only, anticlockwise seen from above, starting
## from the @math{xz} plane.  @var{ANGLE} is in the range @math{(0, 360]}, and
## 360 is the default.
##
## @var{BULGE} gives one value per vertex, turning the segment that leaves
## that vertex into a circular arc, as in @code{draw.Drawing.polyline}: the
## tangent of a quarter of the arc's included angle, zero for a straight
## segment and 1 for a semicircle, positive for an arc that runs
## anticlockwise.  An arc turns into a true torus or sphere, so a radiused
## shoulder or a ball end is exact.
##
## @example
## @group
## ## A shaft of diameter 20 stepping down to 12, with a 1 mm chamfer at the
## ## small end; radius in the first column, length along z in the second
## P = [0, 0; 10, 0; 10, 30; 6, 30; 6, 49; 5, 50; 0, 50];
## S = solid.revolve (P);
## volume (S)
## @result{} 1.1669e+04
## @end group
## @end example
##
## @seealso{solid.extrude, solid.loft, draw.Drawing.polyline}
## @end deftypefn

function S = revolve (P, ANGLE = 360, BULGE = [])

  ## Input validation
  if (nargin < 1 || nargin > 3)
    error ("solid.revolve: invalid number of input arguments.");
  endif
  [errmsg, P, BULGE, Q] = solid.__checkprofile__ (P, BULGE, 'P', 'BULGE');
  if (isempty (errmsg) && min (Q(:,1)) < -1e-9 * max (abs (Q(:))))
    errmsg = "P must not cross the axis: every radius must be nonnegative.";
  endif
  if (isempty (errmsg) && (! isnumeric (ANGLE) || ! isreal (ANGLE) ...
                           || ! isscalar (ANGLE) || ! (ANGLE > 0) ...
                           || ! (ANGLE <= 360)))
    errmsg = "ANGLE must be a real scalar in the range (0, 360].";
  endif
  if (isempty (errmsg))
    errmsg = solid.__checkocct__ ();
  endif
  if (! isempty (errmsg))
    error ("solid.revolve: %s", errmsg);
  endif

  S = solid.Shape (__occt__ ('revolve', 'solid.revolve', P, BULGE, ...
                             double (ANGLE)));

endfunction

%!testif ; exist ('__occt__') == 3  # a cylinder
%! S = solid.revolve ([0, 0; 4, 0; 4, 12; 0, 12]);
%! assert_equal (volume (S), 192 * pi, 1e-9);
%! assert_equal (bbox (S), [-4, -4, 0, 4, 4, 12], 1e-9);
%! assert_equal (numfaces (S), 3);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # a stepped shaft with a chamfer
%! S = solid.revolve ([0, 0; 10, 0; 10, 30; 6, 30; 6, 49; 5, 50; 0, 50]);
%! assert_equal (volume (S), pi * (3000 + 36 * 19 + (36 + 30 + 25) / 3), 1e-9);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # a bush, clear of the axis
%! S = solid.revolve ([5, 0; 8, 0; 8, 10; 5, 10]);
%! assert_equal (volume (S), pi * (64 - 25) * 10, 1e-9);
%! assert_equal (numfaces (S), 4);

%!testif ; exist ('__occt__') == 3  # a quarter turn from the xz plane
%! S = solid.revolve ([0, 0; 4, 0; 4, 12; 0, 12], 90);
%! assert_equal (volume (S), 48 * pi, 1e-9);
%! assert_equal (bbox (S), [0, 0, 0, 4, 4, 12], 1e-9);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # a sphere from a semicircle on the axis
%! S = solid.revolve ([0, -5; 0, 5], 360, [1, 0]);
%! assert_equal (volume (S), 4 / 3 * pi * 125, 1e-9);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # a torus from a circle off the axis
%! S = solid.revolve ([8, 0; 12, 0], 360, [1, 1]);
%! assert_equal (volume (S), 2 * pi ^ 2 * 10 * 4, 1e-9);
%! assert_equal (isvalid (S), true);

%!error<solid.revolve: invalid number of input arguments.> solid.revolve ()
%!error<solid.revolve: P must be an N-by-2 real matrix of finite values.> ...
%! solid.revolve ([0, 0; 1, Inf; 1, 1])
%!error<solid.revolve: P must not cross the axis: every radius must be nonnegative.> ...
%! solid.revolve ([-1, 0; 1, 0; 1, 1; -1, 1])
%!error<solid.revolve: P must not cross the axis: every radius must be nonnegative.> ...
%! solid.revolve ([1, 0; 1, 10], 360, [-1, 0])
%!error<solid.revolve: ANGLE must be a real scalar in the range \(0, 360\].> ...
%! solid.revolve ([0, 0; 1, 0; 1, 1], 0)
%!error<solid.revolve: ANGLE must be a real scalar in the range \(0, 360\].> ...
%! solid.revolve ([0, 0; 1, 0; 1, 1], 361)
%!error<solid.revolve: ANGLE must be a real scalar in the range \(0, 360\].> ...
%! solid.revolve ([0, 0; 1, 0; 1, 1], NaN)
%!error<solid.revolve: ANGLE must be a real scalar in the range \(0, 360\].> ...
%! solid.revolve ([0, 0; 1, 0; 1, 1], [90, 180])
