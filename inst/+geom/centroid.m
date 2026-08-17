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
## @deftypefn {drafting} {@var{C} =} geom.centroid (@var{P})
##
## Area centroid of a simple polygon.
##
## @code{@var{C} = geom.centroid (@var{P})} returns the centroid of the polygon
## whose vertices are the rows of the @math{N}-by-2 matrix @var{P}, as the
## 1-by-2 row vector @code{[@var{x}, @var{y}]}.
##
## This is the @emph{area} centroid, not the mean of the vertices.  The two
## differ whenever the vertices are unevenly spaced around the outline: for the
## L-shaped polygon @code{[0, 0; 4, 0; 4, 2; 2, 2; 2, 4; 0, 4]} the area
## centroid is @code{[1.667, 1.667]} while the vertex mean is @code{[2, 2]}.
## The area centroid is the one that behaves as a balance point.
##
## The polygon is implicitly closed and its orientation is irrelevant, since the
## sign of the area cancels.
##
## A polygon of zero area has no defined centroid and raises an error.
##
## @seealso{geom.signedarea, geom.bbox}
## @end deftypefn

function C = centroid (P)

  ## Input validation
  if (nargin != 1)
    error ("geom.centroid: invalid number of input arguments.");
  endif
  [errmsg, P] = geom.__checkpoly__ (P);
  if (! isempty (errmsg))
    error ("geom.centroid: %s", errmsg);
  endif

  x = P(:,1);
  y = P(:,2);
  xNext = [x(2:end); x(1)];
  yNext = [y(2:end); y(1)];

  ## Cross-product term shared by the area and both centroid coordinates
  cross = x .* yNext - xNext .* y;
  A = sum (cross) / 2;

  ## A degenerate outline has no balance point.  Scale the threshold by the
  ## extent of P so the test means the same for an outline in mm and for a
  ## unit square.
  [~, W, H] = geom.bbox (P);
  if (abs (A) <= 1e-12 * max ([W, H, 1]) ^ 2)
    error ("geom.centroid: P has zero area, so its centroid is undefined.");
  endif

  C = [sum(( x + xNext) .* cross), sum((y + yNext) .* cross)] / (6 * A);

endfunction

%!demo
%! ## The centroid of the enclosed area, which for an L-shape lies well away
%! ## from the centre of its bounding box --- and outside the material for a
%! ## shape concave enough.
%!
%! L = [0, 0; 60, 0; 60, 15; 20, 15; 20, 50; 0, 50];
%! C = geom.centroid (L)
%!
%! D = draw.Drawing ().polyline (L, true);
%! D.Colour = 'red';
%! D.Linetype = 'CENTER';
%! D = D.centremark (C, 8);
%! draw.plot (D);
%! title ('the centroid of an L-shaped section');

%!test  # unit square
%! assert_equal (geom.centroid ([0, 0; 1, 0; 1, 1; 0, 1]), [0.5, 0.5], 1e-12);

%!test  # orientation does not matter
%! cw = geom.centroid ([0, 0; 0, 1; 1, 1; 1, 0]);
%! ccw = geom.centroid ([0, 0; 1, 0; 1, 1; 0, 1]);
%! assert_equal (cw, ccw, 1e-12);

%!test  # rectangle in millimetres
%! P = [0, 0; 1600, 0; 1600, 1800; 0, 1800];
%! assert_equal (geom.centroid (P), [800, 900], 1e-9);

%!test  # triangle centroid is the mean of its three vertices
%! assert_equal (geom.centroid ([0, 0; 6, 0; 0, 3]), [2, 1], 1e-12);

%!test  # area centroid differs from the vertex mean for an L shape
%! P = [0, 0; 4, 0; 4, 2; 2, 2; 2, 4; 0, 4];
%! assert_equal (geom.centroid (P), [5/3, 5/3], 1e-12);
%! assert_equal (mean (P), [2, 2], 1e-12);

%!test  # L shape agrees with a composite decomposition of the same figure
%! P = [0, 0; 4, 0; 4, 2; 2, 2; 2, 4; 0, 4];
%! whole = 16 * [2, 2];      # 4-by-4 square
%! notch = 4 * [3, 3];       # less the 2-by-2 corner removed from it
%! assert_equal (geom.centroid (P), (whole - notch) / 12, 1e-12);

%!test  # translating the polygon translates the centroid
%! P = [0, 0; 4, 0; 4, 3; 0, 3];
%! assert_equal (geom.centroid (P + 100), geom.centroid (P) + 100, 1e-9);

%!test  # an extra collinear vertex does not move the centroid
%! a = geom.centroid ([0, 0; 4, 0; 4, 4; 0, 4]);
%! b = geom.centroid ([0, 0; 2, 0; 4, 0; 4, 4; 0, 4]);
%! assert_equal (a, b, 1e-12);

%!error<geom.centroid: invalid number of input arguments.> geom.centroid ()
%!error<geom.centroid: P must be an N-by-2 matrix of point coordinates.> ...
%! geom.centroid ([1, 2, 3])
%!error<geom.centroid: P must be a polygon with at least 3 vertices.> ...
%! geom.centroid ([0, 0; 1, 1])
%!error<geom.centroid: P has zero area, so its centroid is undefined.> ...
%! geom.centroid ([0, 0; 1, 0; 2, 0])
