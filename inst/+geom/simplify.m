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
## @deftypefn  {drafting} {@var{Q} =} geom.simplify (@var{P}, @var{TOL})
## @deftypefnx {drafting} {[@var{Q}, @var{KEPT}] =} geom.simplify (@var{P}, @var{TOL})
##
## Remove the points of a curve that carry no shape, within a tolerance.
##
## @code{@var{Q} = geom.simplify (@var{P}, @var{TOL})} returns the polyline
## @var{P} with points dropped wherever doing so moves the curve by no more
## than @var{TOL}.  The first and last points are always kept.
##
## @code{[@var{Q}, @var{KEPT}] = geom.simplify (@dots{})} also returns the
## indices of the rows of @var{P} that survived, so a caller can carry along
## anything it had attached to those points.
##
## @subheading What the tolerance guarantees
##
## No point of the original curve ends up further than @var{TOL} from the
## simplified one.  That is a statement about the whole curve, not about the
## points removed, and it is what makes the tolerance safe to set from a
## manufacturing figure: simplifying a cut profile to a tenth of the machine's
## own tolerance cannot move the part outside it.
##
## The algorithm is Douglas and Peucker's: the segment from first point to last
## is taken, the original point furthest from it found, and if that distance
## exceeds @var{TOL} the curve is split there and each half treated the same
## way.  Points survive because they carry shape, not because of where they
## fall in the list.
##
## @subheading Simplifying, not resampling
##
## Every point of @var{Q} is a point of @var{P}; nothing is interpolated and no
## corner is cut, which is what distinguishes this from @code{geom.resample}.
## A polygon may be simplified without losing its vertices, since a corner is
## exactly the sort of point the algorithm keeps.
##
## The saving can be large.  A curve sampled to a chordal tolerance far finer
## than the drawing needs --- as a cycloidal profile at a micron is, for a part
## made to a hundredth --- carries points that no reader or machine can use, and
## every one of them reaches the file.
##
## @seealso{geom.resample, geom.arclength, geom.curvesample}
## @end deftypefn

function [Q, KEPT] = simplify (P, TOL)

  ## Input validation
  if (nargin != 2)
    error ("geom.simplify: invalid number of input arguments.");
  endif
  [errmsg, P] = geom.__checkpts__ (P);
  if (! isempty (errmsg))
    error ("geom.simplify: %s", errmsg);
  endif
  if (! isnumeric (TOL) || ! isreal (TOL) || ! isscalar (TOL) ...
      || ! isfinite (TOL) || TOL < 0)
    error ("geom.simplify: TOL must be a non-negative real finite scalar.");
  endif

  n = rows (P);
  if (n <= 2)
    Q = P;
    KEPT = (1:n)';
    return;
  endif

  keep = false (n, 1);
  keep([1, n]) = true;

  ## Iterative rather than recursive, so a curve of any length is safe
  stack = [1, n];
  while (! isempty (stack))
    i = stack(end, 1);
    j = stack(end, 2);
    stack(end,:) = [];
    if (j - i < 2)
      continue;
    endif

    [d, k] = furthest (P, i, j);
    if (d > TOL)
      keep(k) = true;
      stack = [stack; i, k; k, j];
    endif
  endwhile

  KEPT = find (keep);
  Q = P(KEPT,:);

endfunction

## The greatest distance from the segment i-j to the points between them, and
## which point that is
function [d, k] = furthest (P, i, j)

  A = P(i,:);
  B = P(j,:);
  idx = (i+1):(j-1);
  V = P(idx,:) - A;
  e = B - A;
  L = norm (e);

  if (L == 0)
    ## A degenerate segment: measure to the point itself
    dist = sqrt (sum (V .^ 2, 2));
  else
    ## Perpendicular distance to the infinite line is enough: the extremes of a
    ## Douglas-Peucker split are interior to the segment by construction
    dist = abs (V(:,1) * e(2) - V(:,2) * e(1)) / L;
  endif

  [d, m] = max (dist);
  k = idx(m);

endfunction

%!demo
%! ## Simplifying removes the points that carry no shape, guaranteeing that no
%! ## point of the original ends further than the tolerance from the result.
%! ## Every point kept is a point of the original: nothing is interpolated.
%!
%! t = linspace (0, 2*pi, 721)(1:720)';
%! P = (30 + 4 * cos (8 * t)) .* [cos(t), sin(t)];
%! Q = geom.simplify (P, 0.05);
%! printf ('%d points -> %d, within 0.05 mm\n', rows (P), rows (Q));
%!
%! D = draw.Drawing ().polyline (P, true);
%! D.Colour = 'red';
%! for k = 1:rows (Q)
%!   D = D.circle (Q(k,:), 0.7);
%! endfor
%! plot (D);
%! title ('the points that survive are the ones carrying shape');

%!demo
%! ## The saving matters: a profile sampled far finer than the drawing needs
%! ## carries points no reader or machine can use, and every one reaches the
%! ## file.
%!
%! t = linspace (0, 2*pi, 4001)(1:4000)';
%! P = (30 + 4 * cos (9 * t)) .* [cos(t), sin(t)];
%! for tol = [0.001, 0.01, 0.1]
%!   printf ('within %5.3f mm: %5d of %d points kept\n', tol, ...
%!           rows (geom.simplify (P, tol)), rows (P));
%! endfor

%!test  # collinear points in the middle are all dropped
%! Q = geom.simplify ([0, 0; 1, 0; 2, 0; 3, 0; 4, 0], 1e-9);
%! assert_equal (Q, [0, 0; 4, 0]);

%!test  # a corner is kept, because it carries shape
%! Q = geom.simplify ([0, 0; 1, 0; 2, 0; 2, 2; 2, 4], 1e-9);
%! assert_equal (Q, [0, 0; 2, 0; 2, 4]);

%!test  # the ends are always kept
%! Q = geom.simplify ([0, 0; 1, 0.001; 2, 0], 1);
%! assert_equal (Q, [0, 0; 2, 0]);

%!test  # every kept point is a point of the original, never an interpolation
%! t = linspace (0, 2*pi, 200)';
%! P = 10 * [cos(t), sin(t)];
%! Q = geom.simplify (P, 0.05);
%! assert_equal (all (ismember (Q, P, 'rows')), true);

%!test  # the tolerance is honoured: no original point is further than TOL
%! t = linspace (0, 2*pi, 400)';
%! P = 10 * [cos(t), sin(t)];
%! tol = 0.05;
%! Q = geom.simplify (P, tol);
%! worst = 0;
%! for k = 1:rows (P)
%!   d = inf;
%!   for j = 1:rows (Q) - 1
%!     A = Q(j,:);  B = Q(j+1,:);  e = B - A;  v = P(k,:) - A;
%!     s = max (0, min (1, dot (v, e) / dot (e, e)));
%!     d = min (d, norm (v - s * e));
%!   endfor
%!   worst = max (worst, d);
%! endfor
%! assert_equal (worst <= tol + 1e-9, true);

%!test  # a looser tolerance keeps fewer points
%! t = linspace (0, 2*pi, 400)';
%! P = 10 * [cos(t), sin(t)];
%! assert_equal (rows (geom.simplify (P, 0.5)) ...
%!               < rows (geom.simplify (P, 0.01)), true);

%!test  # a zero tolerance still removes exactly collinear points
%! Q = geom.simplify ([0, 0; 1, 0; 2, 0], 0);
%! assert_equal (Q, [0, 0; 2, 0]);

%!test  # the indices identify which rows survived
%! [Q, KEPT] = geom.simplify ([0, 0; 1, 0; 2, 0; 2, 4], 1e-9);
%! assert_equal (KEPT, [1; 3; 4]);
%! assert_equal (Q, [0, 0; 2, 0; 2, 4]);

%!test  # two points cannot be simplified further
%! assert_equal (geom.simplify ([0, 0; 1, 1], 5), [0, 0; 1, 1]);

%!test  # a real profile loses most of its points and little of its shape
%! t = linspace (0, 2*pi, 4000)';
%! P = (30 + 2 * cos (9 * t)) .* [cos(t), sin(t)];
%! Q = geom.simplify (P, 0.01);
%! assert_equal (rows (Q) < rows (P) / 4, true);
%! ratio = abs (geom.signedarea (Q)) / abs (geom.signedarea (P));
%! assert_equal (ratio, 1, 1e-3);

%!error<geom.simplify: invalid number of input arguments.> ...
%! geom.simplify ([0, 0; 1, 1])
%!error<geom.simplify: TOL must be a non-negative real finite scalar.> ...
%! geom.simplify ([0, 0; 1, 1], -1)
%!error<geom.simplify: P must be an N-by-2 matrix of point coordinates.> ...
%! geom.simplify ([1, 2, 3], 1)
%!error<geom.simplify: P must be a real numeric matrix.> ...
%! geom.simplify ({1, 2}, 0.1)
%!error<geom.simplify: P must contain at least one point.> ...
%! geom.simplify (zeros (0, 2), 0.1)
%!error<geom.simplify: P must not contain NaN or Inf values.> ...
%! geom.simplify ([0, 0; 1, 1; 2, 2; NaN, 3], 0.1)
