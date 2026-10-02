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
## @deftypefn {drafting} {@var{S} =} solid.cylinder (@var{R}, @var{H})
##
## A right circular cylinder.
##
## @code{@var{S} = solid.cylinder (@var{R}, @var{H})} returns a
## @code{solid.Shape} of radius @var{R} and height @var{H} millimetres, its
## axis along the positive @math{z} axis and the centre of its base at the
## origin.  Its curved side is a true cylinder, so a hole cut with it is
## exactly round.
##
## @seealso{solid.Shape, solid.cone, solid.box}
## @end deftypefn

function S = cylinder (R, H)

  ## Input validation
  if (nargin != 2)
    error ("solid.cylinder: invalid number of input arguments.");
  endif
  errmsg = solid.__checkpos__ (R, 'R');
  if (isempty (errmsg))
    errmsg = solid.__checkpos__ (H, 'H');
  endif
  if (isempty (errmsg))
    errmsg = solid.__checkocct__ ();
  endif
  if (! isempty (errmsg))
    error ("solid.cylinder: %s", errmsg);
  endif

  S = solid.Shape (__occt__ ('cylinder', 'solid.cylinder', double (R), ...
                             double (H)));

endfunction

%!testif ; exist ('__occt__') == 3
%! S = solid.cylinder (4, 12);
%! assert_equal (volume (S), 192 * pi, 1e-9);
%! assert_equal (area (S), 2 * pi * 4 * 12 + 2 * pi * 16, 1e-9);
%! assert_equal (bbox (S), [-4, -4, 0, 4, 4, 12], 1e-9);
%! assert_equal (numfaces (S), 3);
%! assert_equal (isvalid (S), true);

%!error<solid.cylinder: invalid number of input arguments.> solid.cylinder (1)
%!error<solid.cylinder: R must be a positive and finite real scalar.> ...
%! solid.cylinder (0, 2)
%!error<solid.cylinder: H must be a positive and finite real scalar.> ...
%! solid.cylinder (1, NaN)
