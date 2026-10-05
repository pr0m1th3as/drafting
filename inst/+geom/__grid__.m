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
## Internal helper.  The offsets of a rectangular array: COUNT copies along
## each of K axes, SPACING apart, the first where the original is.
##
## D has one row per copy, the first zero, the first axis running fastest.
## Returns an error message BODY in ERRMSG, empty when COUNT and SPACING are
## valid; the caller emits the error under its own name.

function [errmsg, D] = __grid__ (COUNT, SPACING, K)

  errmsg = '';
  D = [];

  if (! isnumeric (COUNT) || ! isreal (COUNT) || numel (COUNT) != K
      || any (COUNT != fix (COUNT)) || any (COUNT < 1))
    errmsg = sprintf (strcat ("COUNT must be a %d-element vector of", ...
                              " positive integers."), K);
  elseif (! isnumeric (SPACING) || ! isreal (SPACING)
          || numel (SPACING) != K || ! all (isfinite (SPACING)))
    errmsg = sprintf (strcat ("SPACING must be a real %d-element vector", ...
                              " of finite values."), K);
  elseif (any (COUNT(:) > 1 & SPACING(:) == 0))
    errmsg = "SPACING must be nonzero where COUNT is more than one.";
  else
    g = arrayfun (@(m) 0:m-1, double (COUNT(:)'), 'UniformOutput', false);
    I = cell (1, K);
    [I{:}] = ndgrid (g{:});
    D = cell2mat (cellfun (@(i) i(:), I, 'UniformOutput', false)) ...
        .* double (SPACING(:)');
  endif

endfunction

%!test
%! [errmsg, D] = geom.__grid__ ([3, 2], [10, -5], 2);
%! assert_equal (errmsg, '');
%! assert_equal (D, [0, 0; 10, 0; 20, 0; 0, -5; 10, -5; 20, -5]);

%!test
%! [~, D] = geom.__grid__ ([1, 1, 2], [0, 0, 4], 3);
%! assert_equal (D, [0, 0, 0; 0, 0, 4]);

%!test
%! errmsg = geom.__grid__ ([2, 0], [1, 1], 2);
%! assert_equal (errmsg, strcat ("COUNT must be a 2-element vector of", ...
%!                              " positive integers."));

%!test
%! errmsg = geom.__grid__ ([2, 2, 2], [1, NaN, 1], 3);
%! assert_equal (errmsg, strcat ("SPACING must be a real 3-element", ...
%!                              " vector of finite values."));

%!test
%! errmsg = geom.__grid__ ([2, 2], [1, 0], 2);
%! assert_equal (errmsg, strcat ("SPACING must be nonzero where COUNT", ...
%!                              " is more than one."));
