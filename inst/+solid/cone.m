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
## @deftypefn  {drafting} {@var{S} =} solid.cone (@var{R1}, @var{R2}, @var{H})
## @deftypefnx {drafting} {@var{S} =} solid.cone (@var{R1}, @var{R2}, @var{H}, @var{U})
##
## A right circular cone or truncated cone.
##
## @code{@var{S} = solid.cone (@var{R1}, @var{R2}, @var{H})} returns a
## @code{solid.Shape} of height @var{H} millimetres along the positive
## @math{z} axis, with radius @var{R1} at its base, centred on the origin, and
## radius @var{R2} at its top.  One of the two radii may be zero, which gives
## a cone with a point; with both nonzero it is a frustum, the shape of a
## chamfer or a countersink.
##
## The radii must differ: a cone with equal radii is a cylinder, and
## @code{solid.cylinder} makes it.
##
## @code{@var{S} = solid.cone (@var{R1}, @var{R2}, @var{H}, @var{U})} places
## the cone in the @code{geom.UCS} @var{U}, its axis along the normal of
## @var{U} and the centre of its base on the origin of @var{U}.
##
## @seealso{solid.Shape, solid.cylinder, geom.UCS}
## @end deftypefn

function S = cone (R1, R2, H, varargin)

  ## Input validation
  if (nargin < 3 || nargin > 4)
    error ("solid.cone: invalid number of input arguments.");
  endif
  errmsg = checkradius (R1, 'R1');
  if (isempty (errmsg))
    errmsg = checkradius (R2, 'R2');
  endif
  if (isempty (errmsg))
    errmsg = solid.__checkpos__ (H, 'H');
  endif
  if (isempty (errmsg) && R1 == R2)
    errmsg = strcat ("R1 and R2 must differ; a cone with equal radii", ...
                     " is a cylinder.");
  endif
  if (isempty (errmsg))
    [frame, errmsg] = solid.__place__ (varargin, {'base'}, [0, 0, 0]);
  endif
  if (! isempty (errmsg))
    error ("solid.cone: %s", errmsg);
  endif

  S = __occt__ ('cone', 'solid.cone', double (R1), double (R2), double (H));
  S = solid.Shape (__occt__ ('place', 'solid.cone', S, frame));

endfunction

## A radius that may be zero
function errmsg = checkradius (R, name)

  errmsg = '';
  if (! isnumeric (R) || ! isreal (R) || ! isscalar (R) || ! isfinite (R)
      || R < 0)
    errmsg = sprintf ("%s must be a non-negative and finite real scalar.", ...
                      name);
  endif

endfunction

%!test  # a pointed cone
%! S = solid.cone (3, 0, 10);
%! assert_equal (volume (S), pi * 9 * 10 / 3, 1e-9);
%! assert_equal (bbox (S), [-3, -3, 0, 3, 3, 10], 1e-9);
%! assert_equal (isvalid (S), true);

%!test  # pointing down
%! S = solid.cone (0, 3, 10);
%! assert_equal (volume (S), pi * 9 * 10 / 3, 1e-9);

%!test  # a frustum
%! S = solid.cone (5, 2, 6);
%! assert_equal (volume (S), pi * 6 * (25 + 10 + 4) / 3, 1e-9);
%! assert_equal (numfaces (S), 3);

%!test  # pointing along -y from a point
%! U = geom.UCS ([0, -1, 0], [1, 2, 3]);
%! S = solid.cone (3, 0, 10, U);
%! assert_equal (bbox (S), [-2, -8, 0, 4, 2, 6], 1e-9);
%! assert_equal (centroid (S), [1, -0.5, 3], 1e-9);

%!error<solid.cone: invalid number of input arguments.> solid.cone (1, 2)
%!error<solid.cone: invalid number of input arguments.> ...
%! solid.cone (1, 2, 3, geom.UCS (), 'Anchor')
%!error<solid.cone: U must be a geom.UCS object.> solid.cone (1, 2, 3, 'base')
%!error<solid.cone: R1 must be a non-negative and finite real scalar.> ...
%! solid.cone (-1, 2, 3)
%!error<solid.cone: R2 must be a non-negative and finite real scalar.> ...
%! solid.cone (1, Inf, 3)
%!error<solid.cone: R2 must be a non-negative and finite real scalar.> ...
%! solid.cone (1, [1, 2], 3)
%!error<solid.cone: H must be a positive and finite real scalar.> ...
%! solid.cone (1, 2, 0)
%!error<solid.cone: R1 and R2 must differ; a cone with equal radii is a cylinder.> ...
%! solid.cone (2, 2, 3)
%!error<solid.cone: R1 and R2 must differ; a cone with equal radii is a cylinder.> ...
%! solid.cone (0, 0, 3)
