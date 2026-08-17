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
## @deftypefn  {drafting} {@var{Q} =} geom.curveoffset (@var{P}, @var{D})
## @deftypefnx {drafting} {@var{Q} =} geom.curveoffset (@var{P}, @var{D}, @var{CLOSED})
## @deftypefnx {drafting} {[@var{Q}, @var{MARGIN}] =} geom.curveoffset (@dots{})
##
## Equidistant offset of a smooth sampled curve.
##
## @code{@var{Q} = geom.curveoffset (@var{P}, @var{D})} moves every point of the
## curve @var{P} a distance @var{D} along the curve's own normal and returns the
## result @var{Q}, with one point per point of @var{P}.  @var{P} is an
## @math{N}-by-2 matrix of points and @var{D} is a real scalar in the units of
## @var{P}, so millimetres by package convention.
##
## @code{@var{Q} = geom.curveoffset (@var{P}, @var{D}, @var{CLOSED})} treats the
## curve as closed when @var{CLOSED} is true.  @var{CLOSED} defaults to false.
##
## A positive @var{D} offsets @strong{inward} on a closed curve, shrinking it,
## whichever way round its points run; on an open curve, which has no inside, a
## positive @var{D} offsets to the @strong{left} of the direction of travel.  A
## negative @var{D} reverses this, and @code{@var{D} = 0} returns @var{P}
## unchanged.
##
## @code{[@var{Q}, @var{MARGIN}] = geom.curveoffset (@dots{})} additionally
## returns how much further the curve could have been offset before the result
## degenerated.  @var{MARGIN} is the smallest radius of curvature on the side
## being offset towards, less @var{D}; it is @code{Inf} for a curve that never
## turns that way.  A design that must not approach the limit can test
## @var{MARGIN} rather than wait for the error.
##
## @strong{Validity is decided by a criterion, not detected afterwards.}
## Offsetting inward by more than the radius of curvature at a point folds the
## curve through its own centre of curvature, and the criterion is simply that
## @var{D} must not exceed @code{1 / @var{K}} wherever the curvature @var{K} is
## positive on the offset side.  This is the undercut condition of a cycloidal
## disc, and of any roller running in a groove.  Violating it raises an error
## rather than returning a folded curve.
##
## Offsetting @emph{exactly} to the centre of curvature is admitted: it yields a
## cusp, which touches rather than folds.  That boundary is tested to a relative
## tolerance of @math{10^{-9}} of the limiting radius, because a three-point
## curvature estimate loses precision as the sampling tightens and cannot
## resolve the boundary exactly.  The tolerance is far below any distance a
## manufactured part could care about, and a real violation exceeds it by orders
## of magnitude.
##
## @strong{Accuracy, and when not to use this.}  The normal is estimated from
## each point's two neighbours, weighted by the chord lengths so that the
## estimate stays second order even where the spacing changes abruptly, as it
## does at every refinement boundary of an adaptively sampled curve.  On points
## taken from a circle the offset is exact to rounding at any spacing.  On a
## curve whose curvature varies sharply the residual is a few microns at a
## chordal tolerance of @math{10^{-4}} mm and falls with the sampling.
##
## Where the offset curve has a closed form --- as a cycloidal disc profile does
## --- evaluate that instead and keep this function to check it.  A few microns
## is a fraction of a wire-EDM tolerance, not a comfortable margin inside it.
##
## @strong{The criterion is local.}  It guarantees that no neighbourhood folds
## on itself, which is what makes an offset well defined point by point.  It
## does not guarantee that two distant parts of the curve stay apart: a shape
## with a narrow neck can pinch closed under an offset that every point accepts.
## Where that is possible, check the result with @code{geom.selfintersects}.
##
## @seealso{geom.curvature, geom.selfintersects, geom.offset}
## @end deftypefn

function [Q, MARGIN] = curveoffset (P, D, CLOSED = false)

  ## Input validation
  if (nargin < 2 || nargin > 3)
    error ("geom.curveoffset: invalid number of input arguments.");
  endif
  if (! isnumeric (D) || ! isreal (D) || ! isscalar (D) || ! isfinite (D))
    error ("geom.curveoffset: D must be a real finite scalar.");
  endif
  if (! (islogical (CLOSED) || isnumeric (CLOSED)) || ! isscalar (CLOSED))
    error ("geom.curveoffset: CLOSED must be a logical scalar.");
  endif
  CLOSED = logical (CLOSED);
  [errmsg, P] = geom.__checkcurve__ (P, CLOSED);
  if (! isempty (errmsg))
    error ("geom.curveoffset: %s", errmsg);
  endif

  n = rows (P);

  ## On a closed curve "inward" is a property of the shape, not of the order its
  ## points happen to run in, so the orientation is measured and divided out
  if (CLOSED)
    s = sign (geom.signedarea (P));
    if (s == 0)
      error ("geom.curveoffset: P encloses no area, so it has no inside.");
    endif
  else
    s = 1;
  endif

  ## Central-difference tangent, one-sided at the ends of an open curve
  if (CLOSED)
    iPrev = [n, 1:n-1];
    iNext = [2:n, 1];
  else
    iPrev = [1, 1:n-1];
    iNext = [2:n, n];
  endif
  ## A plain central difference is only first-order accurate when the spacings
  ## either side of a point differ, and adaptive sampling makes them differ by a
  ## factor of two at every refinement boundary.  Weighting by the chord lengths
  ## restores second order, which is worth ten microns on a cycloidal profile.
  a = sqrt (sum ((P - P(iPrev,:)) .^ 2, 2));
  b = sqrt (sum ((P(iNext,:) - P) .^ 2, 2));
  T = P(iNext,:) - P(iPrev,:);
  w = (a > 0 & b > 0);
  T(w,:) = (-b(w) ./ (a(w) .* (a(w) + b(w)))) .* P(iPrev(w),:) ...
           + ((b(w) - a(w)) ./ (a(w) .* b(w))) .* P(w,:) ...
           + (a(w) ./ (b(w) .* (a(w) + b(w)))) .* P(iNext(w),:);

  L = sqrt (sum (T .^ 2, 2));
  if (any (L == 0))
    error ("geom.curveoffset: P has a point with no tangent direction.");
  endif
  T = T ./ L;

  ## Normal towards the offset side: the left normal, flipped for a clockwise
  ## closed curve so that a positive D is always inward
  N = s * [-T(:,2), T(:,1)];

  ## Curvature measured on that same side
  K = s * geom.curvature (P, CLOSED);
  turning = K(isfinite (K) & K > 0);
  if (isempty (turning))
    RLIM = Inf;
    tol = 0;
  else
    RLIM = 1 / max (turning);
    ## Offsetting exactly to the centre of curvature yields a cusp, which
    ## touches rather than folds and is admitted.  The boundary cannot be
    ## resolved exactly: a three-point curvature estimate loses precision as the
    ## sampling tightens, its error growing like eps*R/h^2 in the point spacing
    ## h, so a strict comparison rejects the exact case.  A relative tolerance
    ## of 1e-9 of the limiting radius sits far above that noise and far below
    ## any distance that could matter to a manufactured part.
    tol = 1e-9 * RLIM;
  endif
  MARGIN = RLIM - D;

  if (MARGIN < -tol)
    error (strcat ("geom.curveoffset: D exceeds the radius of curvature by", ...
                   " %g; the offset would fold through its own centre of", ...
                   " curvature."), -MARGIN);
  endif

  Q = P + D * N;

endfunction

%!demo
%! ## An equidistant offset moves every point along the curve's own normal.  On
%! ## a closed curve a positive distance goes inward, whichever way round the
%! ## points happen to run.
%!
%! t = linspace (0, 2*pi, 241)(1:240)';
%! P = (30 + 4 * cos (7 * t)) .* [cos(t), sin(t)];
%!
%! D = draw.Drawing ().polyline (P, true);
%! D.Colour = 'red';
%! D = D.polyline (geom.curveoffset (P, 4, true), true);
%! D.Colour = 'blue';
%! D = D.polyline (geom.curveoffset (P, -4, true), true);
%! draw.plot (D);
%! title ('a lobed profile offset 4 mm in (red) and out (blue)');

%!demo
%! ## The margin says how much further the curve could be offset before it
%! ## folds through its own centre of curvature.  Exceeding it raises rather
%! ## than returning a folded curve that looks plausible and cannot be cut.
%!
%! t = linspace (0, 2*pi, 241)(1:240)';
%! P = (30 + 4 * cos (7 * t)) .* [cos(t), sin(t)];
%! [Q, MARGIN] = geom.curveoffset (P, 4, true);
%! printf ('4 mm in, with %.2f mm still in hand\n', MARGIN);
%!
%! try
%!   geom.curveoffset (P, 4 + MARGIN + 1, true);
%! catch err
%!   disp (err.message);
%! end_try_catch

%!test  # a circle offsets to a concentric circle
%! t = linspace (0, 2*pi, 361)(1:360)';
%! Q = geom.curveoffset (25 * [cos(t), sin(t)], 5, true);
%! assert_equal (sqrt (sum (Q .^ 2, 2)), 20 * ones (360, 1), 1e-9);

%!test  # a negative offset grows the circle
%! t = linspace (0, 2*pi, 361)(1:360)';
%! Q = geom.curveoffset (25 * [cos(t), sin(t)], -5, true);
%! assert_equal (sqrt (sum (Q .^ 2, 2)), 30 * ones (360, 1), 1e-9);

%!test  # inward is inward whichever way the points run
%! t = linspace (0, 2*pi, 361)(1:360)';
%! Qccw = geom.curveoffset (25 * [cos(t), sin(t)], 5, true);
%! Qcw = geom.curveoffset (25 * [cos(-t), sin(-t)], 5, true);
%! assert_equal (max (sqrt (sum (Qcw .^ 2, 2))), 20, 1e-9);
%! assert_equal (max (sqrt (sum (Qccw .^ 2, 2))), 20, 1e-9);

%!test  # zero offset is the identity
%! t = linspace (0, 2*pi, 61)(1:60)';
%! P = 25 * [cos(t), sin(t)];
%! assert_equal (geom.curveoffset (P, 0, true), P, 1e-12);

%!test  # the margin is what remains of the radius of curvature
%! t = linspace (0, 2*pi, 361)(1:360)';
%! [Q, MARGIN] = geom.curveoffset (25 * [cos(t), sin(t)], 5, true);
%! assert_equal (MARGIN, 20, 1e-9);

%!test  # a curve that never turns towards the offset has an infinite margin
%! [Q, MARGIN] = geom.curveoffset ([0, 0; 1, 0; 2, 0; 3, 0], 1);
%! assert_equal (MARGIN, Inf);

%!test  # offsetting a straight open curve to the left of travel
%! Q = geom.curveoffset ([0, 0; 1, 0; 2, 0], 1);
%! assert_equal (Q, [0, 1; 1, 1; 2, 1], 1e-12);

%!test  # offset exactly to the centre of curvature is still admissible
%! t = linspace (0, 2*pi, 361)(1:360)';
%! Q = geom.curveoffset (25 * [cos(t), sin(t)], 25, true);
%! assert_equal (max (abs (Q(:))) < 1e-9, true);

%!test  # unevenly spaced points offset as accurately as evenly spaced ones
%! d = repmat ([0.05; 0.15], 40, 1);
%! t = cumsum (d) * 2*pi / sum (d);
%! Q = geom.curveoffset (25 * [cos(t), sin(t)], 5, true);
%! assert_equal (sqrt (sum (Q .^ 2, 2)), 20 * ones (80, 1), 1e-12);

%!test  # a smooth non-circular closed curve keeps its point count
%! t = linspace (0, 2*pi, 201)(1:200)';
%! P = [(30 + 4 * cos (5 * t)) .* cos(t), (30 + 4 * cos (5 * t)) .* sin(t)];
%! Q = geom.curveoffset (P, 1, true);
%! assert_equal (size (Q), [200, 2]);

%!error<geom.curveoffset: invalid number of input arguments.> ...
%! geom.curveoffset ([0, 0; 1, 0; 1, 1])
%!error<geom.curveoffset: D must be a real finite scalar.> ...
%! geom.curveoffset ([0, 0; 1, 0; 1, 1], Inf)
%!error<geom.curveoffset: CLOSED must be a logical scalar.> ...
%! geom.curveoffset ([0, 0; 1, 0; 1, 1], 1, [true, false])
%!error<geom.curveoffset: P must be a curve with at least 3 points.> ...
%! geom.curveoffset ([0, 0; 1, 1], 1)
%!error<geom.curveoffset: P encloses no area, so it has no inside.> ...
%! geom.curveoffset ([0, 0; 1, 0; 2, 0], 1, true)
%!error<geom.curveoffset: D exceeds the radius of curvature by 5; the offset would fold through its own centre of curvature.> ...
%! t = linspace (0, 2*pi, 361)(1:360)';
%! geom.curveoffset (25 * [cos(t), sin(t)], 30, true)
