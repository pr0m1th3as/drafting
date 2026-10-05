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

## Internal helper.  Validate a scalar that must be positive and finite, such
## as a length, a radius or a scale factor.
##
## Returns an error message BODY in ERRMSG, empty when X is valid; the caller
## emits the error under its own name.  NAME is the argument's name as the
## caller documents it.

function errmsg = __checkpos__ (X, NAME)

  errmsg = '';

  if (! isnumeric (X) || ! isreal (X) || ! isscalar (X) || ! isfinite (X)
      || X <= 0)
    errmsg = sprintf ("%s must be a positive and finite real scalar.", NAME);
  endif

endfunction

%!test
%! assert_equal (solid.__checkpos__ (2.5, 'R'), '');

%!test
%! assert_equal (solid.__checkpos__ (int8 (3), 'R'), '');

%!test
%! assert_equal (solid.__checkpos__ (0, 'DX'), ...
%!               "DX must be a positive and finite real scalar.");

%!test
%! assert_equal (solid.__checkpos__ (-1, 'DX'), ...
%!               "DX must be a positive and finite real scalar.");

%!test
%! assert_equal (solid.__checkpos__ (Inf, 'H'), ...
%!               "H must be a positive and finite real scalar.");

%!test
%! assert_equal (solid.__checkpos__ (NaN, 'H'), ...
%!               "H must be a positive and finite real scalar.");

%!test
%! assert_equal (solid.__checkpos__ ([1, 2], 'R'), ...
%!               "R must be a positive and finite real scalar.");

%!test
%! assert_equal (solid.__checkpos__ (1i, 'R'), ...
%!               "R must be a positive and finite real scalar.");

%!test
%! assert_equal (solid.__checkpos__ ('a', 'R'), ...
%!               "R must be a positive and finite real scalar.");
