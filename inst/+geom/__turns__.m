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
## Internal helper.  The angles of a polar array: N copies spread over ANGLE
## degrees, anticlockwise for a positive ANGLE.
##
## A whole turn, ANGLE of 360 either way, spaces them ANGLE / N apart; less
## puts one at each end, ANGLE / (N - 1) apart.  A is a row of the angles in
## degrees, the first 0.  Returns an error message BODY in ERRMSG, empty when
## N and ANGLE are valid; the caller emits the error under its own name.

function [errmsg, A] = __turns__ (N, ANGLE)

  errmsg = '';
  A = [];

  if (! isnumeric (N) || ! isreal (N) || ! isscalar (N) || N != fix (N) ...
      || ! (N >= 1))
    errmsg = "N must be a positive integer.";
  elseif (! isnumeric (ANGLE) || ! isreal (ANGLE) || ! isscalar (ANGLE) ...
          || ! (ANGLE != 0) || ! (abs (ANGLE) <= 360))
    errmsg = "ANGLE must be a nonzero real scalar of at most 360 degrees.";
  elseif (abs (ANGLE) == 360)
    A = (0:N-1) * double (ANGLE) / double (N);
  else
    A = (0:N-1) * double (ANGLE) / max (double (N) - 1, 1);
  endif

endfunction

%!test
%! [errmsg, A] = geom.__turns__ (4, 360);
%! assert_equal (errmsg, '');
%! assert_equal (A, [0, 90, 180, 270]);

%!test
%! [~, A] = geom.__turns__ (3, -90);
%! assert_equal (A, [0, -45, -90]);
%! [~, A] = geom.__turns__ (1, 90);
%! assert_equal (A, 0);

%!test
%! errmsg = geom.__turns__ (2.5, 90);
%! assert_equal (errmsg, "N must be a positive integer.");

%!test
%! errmsg = geom.__turns__ (2, 400);
%! assert_equal (errmsg, strcat ("ANGLE must be a nonzero real scalar", ...
%!                              " of at most 360 degrees."));

%!test
%! errmsg = geom.__turns__ (2, 0);
%! assert_equal (errmsg, strcat ("ANGLE must be a nonzero real scalar", ...
%!                              " of at most 360 degrees."));
