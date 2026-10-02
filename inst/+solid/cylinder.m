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
## @deftypefn  {drafting} {@var{S} =} solid.cylinder (@var{R}, @var{H})
## @deftypefnx {drafting} {@var{S} =} solid.cylinder (@var{R}, @var{H}, @var{U})
## @deftypefnx {drafting} {@var{S} =} solid.cylinder (@dots{}, 'Anchor', @var{A})
##
## A right circular cylinder.
##
## @code{@var{S} = solid.cylinder (@var{R}, @var{H})} returns a
## @code{solid.Shape} of radius @var{R} and height @var{H} millimetres, its
## axis along the positive @math{z} axis and the centre of its base at the
## origin.  Its curved side is a true cylinder, so a hole cut with it is
## exactly round.
##
## @code{@var{S} = solid.cylinder (@var{R}, @var{H}, @var{U})} places the
## cylinder in the @code{geom.UCS} @var{U}, its axis along the normal of
## @var{U} and the centre of its base on the origin of @var{U}.
##
## The option @qcode{'Anchor'} chooses the point of the cylinder that lands
## on the origin, of @var{U} or of the world when @var{U} is left out:
## @qcode{'base'}, the centre of its base, the default, or
## @qcode{'centroid'}, the point on its axis half way up, its centre of mass.
##
## @seealso{solid.Shape, solid.cone, solid.box, geom.UCS}
## @end deftypefn

function S = cylinder (R, H, varargin)

  ## Input validation
  if (nargin < 2 || nargin > 5)
    error ("solid.cylinder: invalid number of input arguments.");
  endif
  errmsg = solid.__checkpos__ (R, 'R');
  if (isempty (errmsg))
    errmsg = solid.__checkpos__ (H, 'H');
  endif
  if (isempty (errmsg))
    [frame, errmsg] = solid.__place__ (varargin, {'base', 'centroid'}, ...
                                       [0, 0, 0; 0, 0, double(H) / 2]);
  endif
  if (isempty (errmsg))
    errmsg = solid.__checkocct__ ();
  endif
  if (! isempty (errmsg))
    error ("solid.cylinder: %s", errmsg);
  endif

  S = __occt__ ('cylinder', 'solid.cylinder', double (R), double (H));
  S = solid.Shape (__occt__ ('place', 'solid.cylinder', S, frame));

endfunction

%!testif ; exist ('__occt__') == 3
%! S = solid.cylinder (4, 12);
%! assert_equal (volume (S), 192 * pi, 1e-9);
%! assert_equal (area (S), 2 * pi * 4 * 12 + 2 * pi * 16, 1e-9);
%! assert_equal (bbox (S), [-4, -4, 0, 4, 4, 12], 1e-9);
%! assert_equal (numfaces (S), 3);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # lying along x, centred on a point
%! U = geom.UCS ([1, 0, 0], [5, 6, 7]);
%! S = solid.cylinder (2, 10, U, 'Anchor', 'centroid');
%! assert_equal (bbox (S), [0, 4, 5, 10, 8, 9], 1e-9);
%! assert_equal (centroid (S), [5, 6, 7], 1e-9);

%!testif ; exist ('__occt__') == 3  # standing on a point of a UCS
%! U = geom.UCS ([0, 0, -1], [1, 2, 3]);
%! S = solid.cylinder (2, 10, U);
%! assert_equal (bbox (S), [-1, 0, -7, 3, 4, 3], 1e-9);

%!error<solid.cylinder: invalid number of input arguments.> solid.cylinder (1)
%!error<solid.cylinder: invalid number of input arguments.> ...
%! solid.cylinder (1, 2, geom.UCS (), 'Anchor', 'base', 3)
%!error<solid.cylinder: R must be a positive and finite real scalar.> ...
%! solid.cylinder (0, 2)
%!error<solid.cylinder: H must be a positive and finite real scalar.> ...
%! solid.cylinder (1, NaN)
%!error<solid.cylinder: U must be a geom.UCS object.> solid.cylinder (1, 2, 3)
%!error<solid.cylinder: Name/Value arguments must come in pairs.> ...
%! solid.cylinder (1, 2, geom.UCS (), 'Anchor')
%!error<solid.cylinder: unknown parameter.> ...
%! solid.cylinder (1, 2, 'Axis', 'base')
%!error<solid.cylinder: Anchor must be 'base' or 'centroid'.> ...
%! solid.cylinder (1, 2, 'Anchor', 'corner')
