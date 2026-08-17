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

## Internal helper.  Validate and normalise a polygon vertex list.
##
## Returns an error message BODY in ERRMSG (empty when valid); the caller emits
## the error under its own name.  P is returned with an explicitly repeated
## closing vertex removed, so that callers always see an implicitly closed ring.

function [errmsg, P] = __checkpoly__ (P)

  [errmsg, P] = geom.__checkpts__ (P);
  if (! isempty (errmsg))
    return;
  endif

  ## Accept the explicitly closed form used by DXF and drop the repeat
  if (rows (P) > 1 && isequal (P(1,:), P(end,:)))
    P(end,:) = [];
  endif

  if (rows (P) < 3)
    errmsg = "P must be a polygon with at least 3 vertices.";
    return;
  endif

endfunction

%!test
%! [errmsg, P] = geom.__checkpoly__ ([0, 0; 4, 0; 4, 3]);
%! assert_equal (errmsg, '');
%! assert_equal (P, [0, 0; 4, 0; 4, 3]);

%!test  # explicitly closed input loses its repeated vertex
%! [errmsg, P] = geom.__checkpoly__ ([0, 0; 4, 0; 4, 3; 0, 0]);
%! assert_equal (errmsg, '');
%! assert_equal (P, [0, 0; 4, 0; 4, 3]);

%!test  # closing the ring must not drop below 3 vertices
%! errmsg = geom.__checkpoly__ ([0, 0; 4, 0; 0, 0]);
%! assert_equal (errmsg, "P must be a polygon with at least 3 vertices.");

%!test
%! errmsg = geom.__checkpoly__ ([0, 0; 4, 0]);
%! assert_equal (errmsg, "P must be a polygon with at least 3 vertices.");

%!test  # validation is delegated to __checkpts__
%! errmsg = geom.__checkpoly__ ([1, 2, 3]);
%! assert_equal (errmsg, "P must be an N-by-2 matrix of point coordinates.");
