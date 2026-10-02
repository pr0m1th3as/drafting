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

## Internal helper.  Validate and normalise a closed profile, the vertices P
## with the bulges B of the segments leaving them.
##
## Returns an error message BODY in ERRMSG, empty when the profile is valid;
## the caller emits the error under its own name.  PNAME and BNAME are the
## names of the arguments as the caller documents them.  P is returned with an
## explicitly repeated closing vertex removed and B as a column with one value
## per vertex, zero where none was given.  S samples the profile, its arcs
## included, as a closed polygon, for checks on where it lies.

function [errmsg, P, B, S] = __checkprofile__ (P, B, PNAME, BNAME)

  errmsg = '';
  S = [];

  if (! isnumeric (P) || ! isreal (P) || ! ismatrix (P) || columns (P) != 2 ...
      || rows (P) < 2 || ! all (isfinite (P(:))))
    errmsg = sprintf ("%s must be an N-by-2 real matrix of finite values.", ...
                      PNAME);
    return;
  endif
  P = double (P);
  if (isempty (B))
    B = zeros (rows (P), 1);
  elseif (! isnumeric (B) || ! isreal (B) || ! isvector (B) ...
          || numel (B) != rows (P) || ! all (isfinite (B)))
    errmsg = sprintf ("%s must hold one finite real value per row of %s.", ...
                      BNAME, PNAME);
    return;
  endif
  B = double (B(:));

  ## Accept an explicitly closed profile and drop the repeat
  if (rows (P) > 2 && isequal (P(1,:), P(end,:)))
    P(end,:) = [];
    B(end) = [];
  endif

  ## Every segment, the closing one included, must have a length
  D = P([2:end, 1],:) - P;
  c = hypot (D(:,1), D(:,2));
  if (any (c == 0))
    errmsg = sprintf ("%s must not repeat a vertex consecutively.", PNAME);
    return;
  endif

  ## The included angle and radius of each arc
  theta = 4 * atan (B);
  r = c ./ (2 * abs (sin (theta / 2)));

  ## Sample the arcs, about every 5 degrees, to find crossings
  S = cell (rows (P), 1);
  for i = 1:rows (P)
    if (B(i) == 0)
      S{i} = P(i,:);
    else
      ## The centre lies off the middle of the chord, to the left of the
      ## direction of travel for a positive bulge
      m = P(i,:) + D(i,:) / 2;
      n = [-D(i,2), D(i,1)] / c(i);
      ctr = m + n * c(i) / 2 * cot (theta(i) / 2);
      a0 = atan2 (P(i,2) - ctr(2), P(i,1) - ctr(1));
      t = a0 + theta(i) * (0:ceil (abs (theta(i)) / (pi / 36)) - 1)' ...
          / ceil (abs (theta(i)) / (pi / 36));
      S{i} = [P(i,:); ctr + r(i) * [cos(t(2:end)), sin(t(2:end))]];
    endif
  endfor
  S = vertcat (S{:});
  if (rows (S) > 2 && geom.selfintersects (S, true))
    errmsg = sprintf ("%s must not cross or touch itself.", PNAME);
    return;
  endif

  ## The enclosed area: the polygon's, plus the circular segment of each arc,
  ## which a positive bulge adds on an anticlockwise profile
  seg = r .^ 2 / 2 .* (abs (theta) - sin (abs (theta)));
  seg(B == 0) = 0;
  A = sum (P(:,1) .* P([2:end, 1],2) - P([2:end, 1],1) .* P(:,2)) / 2 ...
      + sum (sign (B) .* seg);
  if (abs (A) <= 1e-12 * max (c) ^ 2)
    errmsg = sprintf ("%s must enclose a nonzero area.", PNAME);
    return;
  endif

endfunction

%!test
%! [errmsg, P, B] = solid.__checkprofile__ ([0, 0; 1, 0; 1, 1; 0, 0], [], ...
%!                                         'P', 'BULGE');
%! assert_equal (errmsg, '');
%! assert_equal (P, [0, 0; 1, 0; 1, 1]);
%! assert_equal (B, [0; 0; 0]);

%!test  # a circle from two vertices
%! [errmsg, ~, ~, S] = solid.__checkprofile__ ([0, 0; 10, 0], [1, 1], ...
%!                                             'P', 'BULGE');
%! assert_equal (errmsg, '');
%! assert_equal (max (abs (hypot (S(:,1) - 5, S(:,2)) - 5)), 0, 1e-12);

%!test  # a positive bulge dips below a chord running along x
%! [~, ~, ~, S] = solid.__checkprofile__ ([0, 0; 20, 0; 20, 10; 0, 10], ...
%!                                        [1, 0, 0, 0], 'P', 'BULGE');
%! assert_equal (min (S(:,2)), -10, 1e-12);
