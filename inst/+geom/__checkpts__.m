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

## Internal helper.  Validate an N-by-2 matrix of planar point coordinates.
##
## Returns an error message BODY in ERRMSG (empty when valid); the caller emits
## the error under its own name.  P is returned unchanged and is only echoed so
## that callers can use a single assignment.

function [errmsg, P] = __checkpts__ (P)

  errmsg = '';

  if (! isnumeric (P) || ! isreal (P))
    errmsg = "P must be a real numeric matrix.";
    return;
  endif
  if (ndims (P) != 2 || columns (P) != 2)
    errmsg = "P must be an N-by-2 matrix of point coordinates.";
    return;
  endif
  if (rows (P) < 1)
    errmsg = "P must contain at least one point.";
    return;
  endif
  if (! all (isfinite (P(:))))
    errmsg = "P must not contain NaN or Inf values.";
    return;
  endif

endfunction

%!test
%! [errmsg, P] = geom.__checkpts__ ([0, 0; 1, 1]);
%! assert_equal (errmsg, '');
%! assert_equal (P, [0, 0; 1, 1]);

%!test
%! [errmsg, P] = geom.__checkpts__ ([1, 2]);
%! assert_equal (errmsg, '');

%!test
%! errmsg = geom.__checkpts__ ('abc');
%! assert_equal (errmsg, "P must be a real numeric matrix.");

%!test
%! errmsg = geom.__checkpts__ ([1, 2] + 1i);
%! assert_equal (errmsg, "P must be a real numeric matrix.");

%!test
%! errmsg = geom.__checkpts__ ([1, 2, 3]);
%! assert_equal (errmsg, "P must be an N-by-2 matrix of point coordinates.");

%!test
%! errmsg = geom.__checkpts__ (ones (2, 2, 2));
%! assert_equal (errmsg, "P must be an N-by-2 matrix of point coordinates.");

%!test
%! errmsg = geom.__checkpts__ (zeros (0, 2));
%! assert_equal (errmsg, "P must contain at least one point.");

%!test
%! errmsg = geom.__checkpts__ ([0, 0; NaN, 1]);
%! assert_equal (errmsg, "P must not contain NaN or Inf values.");

%!test
%! errmsg = geom.__checkpts__ ([0, 0; Inf, 1]);
%! assert_equal (errmsg, "P must not contain NaN or Inf values.");
