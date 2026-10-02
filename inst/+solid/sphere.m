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
## @deftypefn {drafting} {@var{S} =} solid.sphere (@var{R})
##
## A sphere.
##
## @code{@var{S} = solid.sphere (@var{R})} returns a @code{solid.Shape} of
## radius @var{R} millimetres centred on the origin.
##
## @seealso{solid.Shape, solid.torus}
## @end deftypefn

function S = sphere (R)

  ## Input validation
  if (nargin != 1)
    error ("solid.sphere: invalid number of input arguments.");
  endif
  errmsg = solid.__checkpos__ (R, 'R');
  if (isempty (errmsg))
    errmsg = solid.__checkocct__ ();
  endif
  if (! isempty (errmsg))
    error ("solid.sphere: %s", errmsg);
  endif

  S = solid.Shape (__occt__ ('sphere', 'solid.sphere', double (R)));

endfunction

%!testif ; exist ('__occt__') == 3
%! S = solid.sphere (5);
%! assert_equal (volume (S), 4 / 3 * pi * 125, 1e-9);
%! assert_equal (area (S), 4 * pi * 25, 1e-9);
%! assert_equal (centroid (S), [0, 0, 0], 1e-9);
%! assert_equal (bbox (S), [-5, -5, -5, 5, 5, 5], 1e-9);
%! assert_equal (isvalid (S), true);

%!error<solid.sphere: invalid number of input arguments.> solid.sphere ()
%!error<solid.sphere: R must be a positive and finite real scalar.> ...
%! solid.sphere (-5)
