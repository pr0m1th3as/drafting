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
## @deftypefn  {drafting} {@var{S} =} solid.ellipsoid (@var{A}, @var{B}, @var{C})
## @deftypefnx {drafting} {@var{S} =} solid.ellipsoid (@var{A}, @var{B}, @var{C}, @var{U})
##
## An ellipsoid.
##
## @code{@var{S} = solid.ellipsoid (@var{A}, @var{B}, @var{C})} returns a
## @code{solid.Shape} centred on the origin with the semi-axes @var{A},
## @var{B} and @var{C} millimetres along the @math{x}, @math{y} and @math{z}
## axes.  Its surface is exact, the B-spline surface a sphere stretched along
## its axes becomes, so its volume is @math{4 \pi A B C / 3} to the precision
## Open CASCADE integrates to.  Equal semi-axes give a true sphere, as
## @code{solid.sphere} makes.
##
## @code{@var{S} = solid.ellipsoid (@var{A}, @var{B}, @var{C}, @var{U})}
## centres it on the origin of the @code{geom.UCS} @var{U}, @var{A} along its
## @math{x} axis, @var{B} along its @math{y} axis and @var{C} along its
## normal.
##
## @example
## @group
## ## An egg-shaped knob 30 long, 20 across and 16 high, half sunk in a plate
## K = solid.ellipsoid (15, 10, 8, geom.UCS ([0, 0, 1], [40, 30, 5]));
## P = union (solid.box (80, 60, 5), K);
## @end group
## @end example
##
## @seealso{solid.sphere, geom.Spline.ellipse, solid.Shape.resize, geom.UCS}
## @end deftypefn

function S = ellipsoid (A, B, C, varargin)

  ## Input validation
  if (nargin < 3 || nargin > 4)
    error ("solid.ellipsoid: invalid number of input arguments.");
  endif
  errmsg = solid.__checkpos__ (A, 'A');
  if (isempty (errmsg))
    errmsg = solid.__checkpos__ (B, 'B');
  endif
  if (isempty (errmsg))
    errmsg = solid.__checkpos__ (C, 'C');
  endif
  if (isempty (errmsg))
    [frame, errmsg] = solid.__place__ (varargin, {'centroid'}, [0, 0, 0]);
  endif
  if (! isempty (errmsg))
    error ("solid.ellipsoid: %s", errmsg);
  endif

  F = double ([A, B, C]);
  if (all (F == F(1)))
    S = __occt__ ('sphere', 'solid.ellipsoid', F(1));
  else
    S = __occt__ ('gscale', 'solid.ellipsoid', ...
                  __occt__ ('sphere', 'solid.ellipsoid', 1), F, [0, 0, 0]);
  endif
  S = solid.Shape (__occt__ ('place', 'solid.ellipsoid', S, frame));

endfunction

## A volume of an ellipsoid takes Open CASCADE seconds, so the tests measure
## its cuts, ellipses whose areas are known
%!test
%! S = solid.ellipsoid (20, 10, 5);
%! assert_equal (bbox (S), [-20, -10, -5, 20, 10, 5], 1e-6);
%! assert_equal (isvalid (S), true);
%! R = section (S, geom.UCS ([0, 0, 1], [0, 0, 3]));
%! assert_equal (__area__ (R{1}.Outline), 128 * pi, -1e-8);

%!test  # laid in a UCS, the semi-axes on its axes
%! U = geom.UCS ([1, 0, 0], [5, 0, 0]);
%! S = solid.ellipsoid (4, 3, 2, U);
%! [B, L] = bbox (S);
%! assert_equal (L, [4, 8, 6], 1e-6);
%! assert_equal ((B(1:3) + B(4:6)) / 2, [5, 0, 0], 1e-6);

%!test  # equal semi-axes, a true sphere
%! S = solid.ellipsoid (5, 5, 5);
%! assert_equal (numel (faces (S, 'Type', 'sphere')), 1);
%! assert_equal (volume (S), 4 / 3 * pi * 125, -1e-12);

%!test  # cut by a box, a valid solid
%! S = subtract (solid.ellipsoid (20, 10, 5), solid.box (40, 40, 40, ...
%!                                                     'Anchor', 'base'));
%! assert_equal (isvalid (S), true);
%! assert_equal (bbox (S), [-20, -10, -5, 20, 10, 0], 1e-6);

%!error<solid.ellipsoid: invalid number of input arguments.> ...
%! solid.ellipsoid (1, 2)
%!error<solid.ellipsoid: A must be a positive and finite real scalar.> ...
%! solid.ellipsoid (0, 2, 3)
%!error<solid.ellipsoid: B must be a positive and finite real scalar.> ...
%! solid.ellipsoid (1, -2, 3)
%!error<solid.ellipsoid: C must be a positive and finite real scalar.> ...
%! solid.ellipsoid (1, 2, Inf)
%!error<solid.ellipsoid: U must be a geom.UCS object.> ...
%! solid.ellipsoid (1, 2, 3, [0, 0, 1])
