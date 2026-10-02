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
## @deftypefn {drafting} {@var{S} =} solid.box (@var{DX}, @var{DY}, @var{DZ})
##
## A rectangular block.
##
## @code{@var{S} = solid.box (@var{DX}, @var{DY}, @var{DZ})} returns a
## @code{solid.Shape} measuring @var{DX} by @var{DY} by @var{DZ} millimetres,
## with one corner at the origin and the block extending along the positive
## @math{x}, @math{y} and @math{z} axes.  Place it with
## @code{solid.Shape.translate}.
##
## @seealso{solid.Shape, solid.cylinder, solid.Shape.translate}
## @end deftypefn

function S = box (DX, DY, DZ)

  ## Input validation
  if (nargin != 3)
    error ("solid.box: invalid number of input arguments.");
  endif
  errmsg = solid.__checkpos__ (DX, 'DX');
  if (isempty (errmsg))
    errmsg = solid.__checkpos__ (DY, 'DY');
  endif
  if (isempty (errmsg))
    errmsg = solid.__checkpos__ (DZ, 'DZ');
  endif
  if (isempty (errmsg))
    errmsg = solid.__checkocct__ ();
  endif
  if (! isempty (errmsg))
    error ("solid.box: %s", errmsg);
  endif

  S = solid.Shape (__occt__ ('box', 'solid.box', double (DX), double (DY), ...
                             double (DZ)));

endfunction

%!testif ; exist ('__occt__') == 3
%! S = solid.box (10, 20, 30);
%! assert_equal (volume (S), 6000, 1e-9);
%! assert_equal (bbox (S), [0, 0, 0, 10, 20, 30], 1e-9);
%! assert_equal (numfaces (S), 6);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # integer-valued input
%! assert_equal (volume (solid.box (int16 (2), 3, 4)), 24, 1e-9);

%!error<solid.box: invalid number of input arguments.> solid.box (1, 2)
%!error<solid.box: DX must be a positive and finite real scalar.> ...
%! solid.box (0, 2, 3)
%!error<solid.box: DY must be a positive and finite real scalar.> ...
%! solid.box (1, -2, 3)
%!error<solid.box: DZ must be a positive and finite real scalar.> ...
%! solid.box (1, 2, Inf)
%!error<solid.box: DX must be a positive and finite real scalar.> ...
%! solid.box ([1, 2], 2, 3)
