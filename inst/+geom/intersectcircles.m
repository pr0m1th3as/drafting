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
## @deftypefn {drafting} {@var{P} =} geom.intersectcircles (@var{C1}, @var{R1}, @var{C2}, @var{R2})
##
## Where two circles meet.
##
## @code{@var{P} = geom.intersectcircles (@var{C1}, @var{R1}, @var{C2},
## @var{R2})} returns the points common to the two circles: two rows where they
## cross, one where they touch, and none where they do not reach each other or
## one lies wholly inside the other.
##
## This is how a point is located from two distances --- the compass
## construction that predates coordinates, and still the way a bolt hole is
## placed from two datums or a linkage position solved.
##
## @subheading Touching is decided, not stumbled upon
##
## Circles that touch give a distance exactly equal to the sum or difference of
## the radii, and in floating point that equality is a coin toss between two
## points a nanometre apart and no points at all.  The comparison carries a
## tolerance scaled by the radii, so circles within one part in @math{10^{12}}
## of touching return exactly one point, on the line of centres.
##
## @subheading Identical circles raise
##
## Two circles with the same centre and radius share every point of their
## circumference.  Returning nothing would say they share none, and returning
## two would name an arbitrary pair; neither is true, so this raises instead.
## Concentric circles of @emph{different} radii genuinely share no point and
## return empty.
##
## @seealso{geom.intersectcircle, geom.intersectlines, geom.tangentpoints}
## @end deftypefn

function P = intersectcircles (C1, R1, C2, R2)

  ## Input validation
  if (nargin != 4)
    error ("geom.intersectcircles: invalid number of input arguments.");
  endif
  checkcentre (C1, 'C1');
  checkcentre (C2, 'C2');
  checkradius (R1, 'R1');
  checkradius (R2, 'R2');

  v = C2 - C1;
  d = norm (v);
  tol = 1e-12 * max ([R1, R2, d]);

  if (d <= tol)
    if (abs (R1 - R2) <= tol)
      error (strcat ("geom.intersectcircles: the circles are identical, so", ...
                     " they share every point of their circumference."));
    endif
    P = zeros (0, 2);                   # concentric, different radii
    return;
  endif

  if (d > R1 + R2 + tol || d < abs (R1 - R2) - tol)
    P = zeros (0, 2);                   # too far apart, or one inside the other
    return;
  endif

  ## Distance from C1 to the foot of the common chord, along the line of centres
  a = (d ^ 2 + R1 ^ 2 - R2 ^ 2) / (2 * d);
  h2 = R1 ^ 2 - a ^ 2;
  u = v / d;
  foot = C1 + a * u;

  if (h2 <= tol * max ([R1, R2]))
    P = foot;                           # touching
    return;
  endif

  h = sqrt (h2);
  n = [-u(2), u(1)];
  P = [foot + h * n; foot - h * n];

endfunction

function checkcentre (C, name)
  if (! isnumeric (C) || ! isreal (C) || ! isequal (size (C), [1, 2]) ...
      || ! all (isfinite (C)))
    error (strcat ("geom.intersectcircles: %s must be a 1-by-2 real", ...
                   " finite point."), name);
  endif
endfunction

function checkradius (R, name)
  if (! isnumeric (R) || ! isreal (R) || ! isscalar (R) || ! isfinite (R) ...
      || R <= 0)
    error (strcat ("geom.intersectcircles: %s must be a positive real", ...
                   " finite scalar."), name);
  endif
endfunction

%!test  # two unit circles two apart across the origin
%! P = geom.intersectcircles ([-1, 0], sqrt (2), [1, 0], sqrt (2));
%! assert_equal (sort (P(:,2)), [-1; 1], 1e-12);
%! assert_equal (P(:,1), [0; 0], 1e-12);

%!test  # every returned point is on both circles
%! P = geom.intersectcircles ([0, 0], 5, [6, 2], 4);
%! assert_equal (sqrt (sum (P .^ 2, 2)), 5 * ones (rows (P), 1), 1e-12);
%! n = rows (P);
%! assert_equal (sqrt (sum ((P - [6, 2]) .^ 2, 2)), 4 * ones (n, 1), 1e-12);

%!test  # circles touching from outside give one point on the line of centres
%! P = geom.intersectcircles ([0, 0], 3, [8, 0], 5);
%! assert_equal (rows (P), 1);
%! assert_equal (P, [3, 0], 1e-9);

%!test  # circles touching from inside give one point too
%! P = geom.intersectcircles ([0, 0], 10, [4, 0], 6);
%! assert_equal (rows (P), 1);
%! assert_equal (P, [10, 0], 1e-9);

%!test  # circles too far apart share nothing
%! assert_equal (isempty (geom.intersectcircles ([0, 0], 1, [10, 0], 2)), true);

%!test  # one wholly inside the other shares nothing
%! assert_equal (isempty (geom.intersectcircles ([0, 0], 10, [1, 0], 2)), true);

%!test  # concentric circles of different radii share nothing
%! assert_equal (isempty (geom.intersectcircles ([3, 3], 5, [3, 3], 2)), true);

%!test  # the answer does not depend on the order of the circles
%! P1 = geom.intersectcircles ([0, 0], 5, [6, 2], 4);
%! P2 = geom.intersectcircles ([6, 2], 4, [0, 0], 5);
%! assert_equal (sortrows (P1), sortrows (P2), 1e-12);

%!test  # the compass construction: a point at known distances from two datums
%! P = geom.intersectcircles ([0, 0], 30, [40, 0], 50);
%! assert_equal (any (all (abs (P - [0, 30]) < 1e-9, 2)), true);

%!error<geom.intersectcircles: invalid number of input arguments.> ...
%! geom.intersectcircles ([0, 0], 1, [1, 0])
%!error<geom.intersectcircles: the circles are identical, so they share every point of their circumference.> ...
%! geom.intersectcircles ([2, 2], 5, [2, 2], 5)
%!error<geom.intersectcircles: R2 must be a positive real finite scalar.> ...
%! geom.intersectcircles ([0, 0], 1, [1, 0], -1)
%!error<geom.intersectcircles: C1 must be a 1-by-2 real finite point.> ...
%! geom.intersectcircles ([0, 0, 0], 1, [1, 0], 1)
