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
## @deftypefn {drafting} {@var{S} =} solid.cone (@var{R1}, @var{R2}, @var{H})
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
## @seealso{solid.Shape, solid.cylinder}
## @end deftypefn

function S = cone (R1, R2, H)

  ## Input validation
  if (nargin != 3)
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
    errmsg = solid.__checkocct__ ();
  endif
  if (! isempty (errmsg))
    error ("solid.cone: %s", errmsg);
  endif

  S = solid.Shape (__occt__ ('cone', 'solid.cone', double (R1), ...
                             double (R2), double (H)));

endfunction

## A radius that may be zero
function errmsg = checkradius (R, name)

  errmsg = '';
  if (! isnumeric (R) || ! isreal (R) || ! isscalar (R) || ! isfinite (R) ...
      || R < 0)
    errmsg = sprintf ("%s must be a non-negative and finite real scalar.", ...
                      name);
  endif

endfunction

%!testif ; exist ('__occt__') == 3  # a pointed cone
%! S = solid.cone (3, 0, 10);
%! assert_equal (volume (S), pi * 9 * 10 / 3, 1e-9);
%! assert_equal (bbox (S), [-3, -3, 0, 3, 3, 10], 1e-9);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # pointing down
%! S = solid.cone (0, 3, 10);
%! assert_equal (volume (S), pi * 9 * 10 / 3, 1e-9);

%!testif ; exist ('__occt__') == 3  # a frustum
%! S = solid.cone (5, 2, 6);
%! assert_equal (volume (S), pi * 6 * (25 + 10 + 4) / 3, 1e-9);
%! assert_equal (numfaces (S), 3);

%!error<solid.cone: invalid number of input arguments.> solid.cone (1, 2)
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
