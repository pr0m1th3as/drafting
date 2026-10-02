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


## Internal helper.  Sample a closed outline along its arcs.
##
## V is an N-by-3 matrix of [x, y, bulge] rows, closed implicitly from the
## last vertex back to the first, every segment of nonzero length.  S is the
## closed polygon through its vertices with every arc sampled at least every 2
## degrees, as an M-by-2 matrix, for checks on where the outline lies.

function S = __sample__ (V)

  n = rows (V);
  S = cell (n, 1);
  for i = 1:n
    j = mod (i, n) + 1;
    S{i} = V(i,1:2);
    if (V(i,3) != 0)
      d = V(j,1:2) - V(i,1:2);
      c = norm (d);
      th = 4 * atan (V(i,3));
      ## The centre lies off the middle of the chord, to the left of the
      ## direction of travel for a positive bulge
      ctr = V(i,1:2) + d / 2 + [-d(2), d(1)] / 2 * cot (th / 2);
      r = c / (2 * abs (sin (th / 2)));
      m = ceil (abs (th) / (pi / 90));
      t = atan2 (V(i,2) - ctr(2), V(i,1) - ctr(1)) + th * (1:m-1)' / m;
      S{i} = [S{i}; ctr + r * [cos(t), sin(t)]];
    endif
  endfor
  S = vertcat (S{:});

endfunction

%!test  # straight segments are the vertices themselves
%! assert_equal (geom.__sample__ ([0, 0, 0; 1, 0, 0; 1, 1, 0]), ...
%!               [0, 0; 1, 0; 1, 1]);

%!test  # a circle of radius 5 from two vertices
%! S = geom.__sample__ ([0, 0, 1; 10, 0, 1]);
%! assert_equal (max (abs (hypot (S(:,1) - 5, S(:,2)) - 5)), 0, 1e-12);
%! assert_equal (rows (S), 180);

%!test  # a positive bulge dips below a chord running along x
%! S = geom.__sample__ ([0, 0, 1; 20, 0, 0; 20, 10, 0; 0, 10, 0]);
%! assert_equal (min (S(:,2)), -10, 1e-12);
