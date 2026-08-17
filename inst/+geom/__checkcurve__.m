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

## Internal helper.  Validate a sampled planar curve.
##
## Returns an error message BODY in ERRMSG (empty when valid); the caller emits
## the error under its own name.  Unlike __checkpoly__, a curve may be open, so
## the repeated closing vertex is dropped only when CLOSED is true.  Three
## points are the minimum a three-point stencil can work on.

function [errmsg, P] = __checkcurve__ (P, CLOSED)

  [errmsg, P] = geom.__checkpts__ (P);
  if (! isempty (errmsg))
    return;
  endif

  if (CLOSED && rows (P) > 1 && isequal (P(1,:), P(end,:)))
    P(end,:) = [];
  endif

  if (rows (P) < 3)
    errmsg = "P must be a curve with at least 3 points.";
    return;
  endif

endfunction

%!test
%! [errmsg, P] = geom.__checkcurve__ ([0, 0; 1, 0; 1, 1], false);
%! assert_equal (errmsg, '');
%! assert_equal (P, [0, 0; 1, 0; 1, 1]);

%!test  # an open curve keeps a coincident endpoint
%! [errmsg, P] = geom.__checkcurve__ ([0, 0; 1, 0; 1, 1; 0, 0], false);
%! assert_equal (errmsg, '');
%! assert_equal (rows (P), 4);

%!test  # a closed curve drops the repeated closing vertex
%! [errmsg, P] = geom.__checkcurve__ ([0, 0; 1, 0; 1, 1; 0, 0], true);
%! assert_equal (errmsg, '');
%! assert_equal (P, [0, 0; 1, 0; 1, 1]);

%!test
%! errmsg = geom.__checkcurve__ ([0, 0; 1, 1], false);
%! assert_equal (errmsg, "P must be a curve with at least 3 points.");

%!test  # closing the ring must not drop below 3 points
%! errmsg = geom.__checkcurve__ ([0, 0; 1, 0; 0, 0], true);
%! assert_equal (errmsg, "P must be a curve with at least 3 points.");

%!test
%! errmsg = geom.__checkcurve__ ('abc', false);
%! assert_equal (errmsg, "P must be a real numeric matrix.");

%!test
%! errmsg = geom.__checkcurve__ ([0, 0; 1, 0; NaN, 1], false);
%! assert_equal (errmsg, "P must not contain NaN or Inf values.");
