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
## @deftypefn {drafting} {@var{S} =} solid.torus (@var{R1}, @var{R2})
##
## A torus, the solid of a ring.
##
## @code{@var{S} = solid.torus (@var{R1}, @var{R2})} returns a
## @code{solid.Shape} whose tube of radius @var{R2} circles the @math{z} axis
## at radius @var{R1}, centred on the origin in the @math{xy} plane: the shape
## of an O-ring, or of the groove one sits in.
##
## @var{R2} must be smaller than @var{R1}.  A tube as wide as its circle or
## wider would pass through the axis and the solid would intersect itself.
##
## @seealso{solid.Shape, solid.sphere}
## @end deftypefn

function S = torus (R1, R2)

  ## Input validation
  if (nargin != 2)
    error ("solid.torus: invalid number of input arguments.");
  endif
  errmsg = solid.__checkpos__ (R1, 'R1');
  if (isempty (errmsg))
    errmsg = solid.__checkpos__ (R2, 'R2');
  endif
  if (isempty (errmsg) && R2 >= R1)
    errmsg = "R2 must be smaller than R1.";
  endif
  if (isempty (errmsg))
    errmsg = solid.__checkocct__ ();
  endif
  if (! isempty (errmsg))
    error ("solid.torus: %s", errmsg);
  endif

  S = solid.Shape (__occt__ ('torus', 'solid.torus', double (R1), ...
                             double (R2)));

endfunction

%!testif ; exist ('__occt__') == 3
%! S = solid.torus (10, 2);
%! assert_equal (volume (S), 2 * pi ^ 2 * 10 * 4, 1e-9);
%! assert_equal (area (S), 4 * pi ^ 2 * 10 * 2, 1e-9);
%! assert_equal (bbox (S), [-12, -12, -2, 12, 12, 2], 1e-6);
%! assert_equal (isvalid (S), true);

%!error<solid.torus: invalid number of input arguments.> solid.torus (1)
%!error<solid.torus: R1 must be a positive and finite real scalar.> ...
%! solid.torus (0, 1)
%!error<solid.torus: R2 must be a positive and finite real scalar.> ...
%! solid.torus (5, -1)
%!error<solid.torus: R2 must be smaller than R1.> solid.torus (5, 5)
