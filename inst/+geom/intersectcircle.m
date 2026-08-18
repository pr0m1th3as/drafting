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
## @deftypefn  {drafting} {@var{P} =} geom.intersectcircle (@var{L}, @var{C}, @var{R})
## @deftypefnx {drafting} {[@var{P}, @var{T}] =} geom.intersectcircle (@dots{})
##
## Where a line meets a circle.
##
## @code{@var{P} = geom.intersectcircle (@var{L}, @var{C}, @var{R})} returns the
## points at which the line through @var{L} crosses the circle of radius
## @var{R} centred at @var{C}.  @var{L} is a 2-by-2 matrix of two points on the
## line, one per row.
##
## @var{P} has two rows where the line cuts the circle, one where it is
## tangent, and none where it misses.  The rows are ordered along the line, in
## the direction from @code{@var{L}(1,:)} to @code{@var{L}(2,:)}.
##
## @code{[@var{P}, @var{T}] = geom.intersectcircle (@dots{})} also returns where
## each crossing falls along the line, as a fraction of the distance from its
## first point to its second, so a caller wanting a @emph{segment} can keep the
## rows whose parameter lies between 0 and 1.
##
## The line is infinite, for the reasons given under
## @code{geom.intersectlines}.
##
## @subheading Tangency is decided, not stumbled upon
##
## A line grazing a circle gives a discriminant near zero, and rounding decides
## whether that reads as two crossings a nanometre apart or as none at all.
## Both are worse than the truth.  The discriminant is compared against a
## tolerance scaled by the radius, so a line within one part in @math{10^{12}}
## of tangent returns exactly one point, at the foot of the perpendicular.
##
## @seealso{geom.intersectlines, geom.intersectcircles, geom.tangentpoints}
## @end deftypefn

function [P, T] = intersectcircle (L, C, R)

  ## Input validation
  if (nargin != 3)
    error ("geom.intersectcircle: invalid number of input arguments.");
  endif
  if (! isnumeric (L) || ! isreal (L) || ! isequal (size (L), [2, 2]) ...
      || ! all (isfinite (L(:))))
    error (strcat ("geom.intersectcircle: L must be a 2-by-2 matrix of two", ...
                   " real finite points."));
  endif
  if (isequal (L(1,:), L(2,:)))
    error ("geom.intersectcircle: L must be two distinct points.");
  endif
  if (! isnumeric (C) || ! isreal (C) || ! isequal (size (C), [1, 2]) ...
      || ! all (isfinite (C)))
    error ("geom.intersectcircle: C must be a 1-by-2 real finite point.");
  endif
  if (! isnumeric (R) || ! isreal (R) || ! isscalar (R) || ! isfinite (R) ...
      || R <= 0)
    error ("geom.intersectcircle: R must be a positive real finite scalar.");
  endif

  d = L(2,:) - L(1,:);
  f = L(1,:) - C;

  a = d * d';
  b = 2 * (f * d');
  c = f * f' - R ^ 2;
  disc = b ^ 2 - 4 * a * c;

  ## Scale the tangency window with the geometry, so it means the same on a
  ## drawing in millimetres as on one in metres
  tol = 1e-12 * (4 * a * R ^ 2);

  if (disc < -tol)
    P = zeros (0, 2);
    T = zeros (0, 1);
  elseif (disc <= tol)
    T = -b / (2 * a);
    P = L(1,:) + T * d;
  else
    T = sort ([(-b - sqrt(disc)) / (2 * a); (-b + sqrt(disc)) / (2 * a)]);
    P = [L(1,:) + T(1) * d; L(1,:) + T(2) * d];
  endif

endfunction

%!demo
%! ## Where a line cuts a circle, in the order it meets them.  A tangent gives
%! ## exactly one point rather than two nearly equal ones.
%!
%! C = [0, 0];
%! R = 30;
%! D = draw.Drawing ().circle (C, R);
%! D.Colour = 'red';
%! for y = [0, 18, 30, 40]
%!   L = [-45, y; 45, y];
%!   P = geom.intersectcircle (L, C, R);
%!   printf ('y = %2d: %d point(s)\n', y, rows (P));
%!   D.Colour = 'byLayer';
%!   D = D.line (L(1,:), L(2,:));
%!   D.Colour = 'red';
%!   for k = 1:rows (P)
%!     D = D.circle (P(k,:), 1.5);
%!   endfor
%! endfor
%! plot (D);
%! title ('two points, two points, one at tangency, then none');

%!test  # a line through the centre cuts twice, at the ends of a diameter
%! P = geom.intersectcircle ([-10, 0; 10, 0], [0, 0], 5);
%! assert_equal (P, [-5, 0; 5, 0], 1e-12);

%!test  # the rows come back in the direction the line was given
%! P = geom.intersectcircle ([10, 0; -10, 0], [0, 0], 5);
%! assert_equal (P, [5, 0; -5, 0], 1e-12);

%!test  # a tangent line gives exactly one point, not two nearly equal ones
%! P = geom.intersectcircle ([-10, 5; 10, 5], [0, 0], 5);
%! assert_equal (rows (P), 1);
%! assert_equal (P, [0, 5], 1e-9);

%!test  # a line that misses gives nothing
%! P = geom.intersectcircle ([-10, 6; 10, 6], [0, 0], 5);
%! assert_equal (isempty (P), true);

%!test  # every returned point is on the circle
%! P = geom.intersectcircle ([-8, -3; 9, 4], [1, 1], 4);
%! n = rows (P);
%! assert_equal (sqrt (sum ((P - [1, 1]) .^ 2, 2)), 4 * ones (n, 1), 1e-12);

%!test  # the parameters place the points along the line
%! [P, T] = geom.intersectcircle ([0, 0; 20, 0], [10, 0], 5);
%! assert_equal (T, [0.25; 0.75], 1e-12);

%!test  # a segment is filtered by its parameters
%! [P, T] = geom.intersectcircle ([0, 0; 6, 0], [10, 0], 5);
%! assert_equal (rows (P), 2);
%! assert_equal (sum (T >= 0 & T <= 1), 1);

%!test  # an offset circle, checked against hand geometry
%! P = geom.intersectcircle ([0, 3; 1, 3], [0, 0], 5);
%! assert_equal (sort (P(:,1)), [-4; 4], 1e-12);

%!test  # tangency is found even when the line is given far from the contact
%! P = geom.intersectcircle ([1000, 5; 1001, 5], [0, 0], 5);
%! assert_equal (rows (P), 1);
%! assert_equal (P, [0, 5], 1e-6);

%!error<geom.intersectcircle: invalid number of input arguments.> ...
%! geom.intersectcircle ([0, 0; 1, 0], [0, 0])
%!error<geom.intersectcircle: R must be a positive real finite scalar.> ...
%! geom.intersectcircle ([0, 0; 1, 0], [0, 0], 0)
%!error<geom.intersectcircle: C must be a 1-by-2 real finite point.> ...
%! geom.intersectcircle ([0, 0; 1, 0], [0, 0, 0], 1)
%!error<geom.intersectcircle: L must be two distinct points.> ...
%! geom.intersectcircle ([2, 2; 2, 2], [0, 0], 1)
