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
## @deftypefn  {drafting} {@var{P} =} geom.curvesample (@var{FCN}, @var{TRANGE}, @var{TOL})
## @deftypefnx {drafting} {@var{P} =} geom.curvesample (@var{FCN}, @var{TRANGE}, @var{TOL}, @var{MAXPTS})
## @deftypefnx {drafting} {[@var{P}, @var{T}] =} geom.curvesample (@dots{})
##
## Sample a parametric curve to a stated chordal tolerance.
##
## @code{@var{P} = geom.curvesample (@var{FCN}, @var{TRANGE}, @var{TOL})}
## returns points on the curve @var{FCN} over the parameter interval
## @var{TRANGE}, placed so that the straight chord between consecutive points
## never departs from the true curve by more than @var{TOL}.
##
## @var{FCN} is a function handle taking a column vector of parameter values and
## returning an @math{N}-by-2 matrix, one row of coordinates per value.
## @var{TRANGE} is a two-element increasing vector @code{[@var{T0}, @var{T1}]}.
## @var{TOL} is a positive scalar in the units of the curve, so millimetres by
## package convention.
##
## @code{@var{P} = geom.curvesample (@dots{}, @var{MAXPTS})} caps the number of
## points; exceeding it raises an error rather than refining without end.
## @var{MAXPTS} defaults to 100000.
##
## @code{[@var{P}, @var{T}] = geom.curvesample (@dots{})} additionally returns
## the parameter values, in increasing order, at which the curve was evaluated.
##
## @strong{Why this rather than a uniform step.}  A tolerance is a statement
## about the part; a point count is not.  A cycloidal disc varies its radius of
## curvature by an order of magnitude between crest and root, so a uniform step
## fine enough for the root wastes points along the flanks, and one economical
## on the flanks cuts the root visibly flat.  Sampling to a tolerance lets the
## drawing carry a number the machinist can act on.
##
## Refinement is by bisection: an interval whose midpoint on the true curve lies
## further than @var{TOL} from its chord is split, and the test is repeated
## until every interval passes.  The interval is seeded uniformly, which keeps a
## symmetric curve from terminating early on a midpoint that happens to fall on
## its own chord.
##
## The curve is sampled, not closed.  A closed curve is obtained by giving a
## @var{TRANGE} spanning one full period; the first and last points then
## coincide, and callers that want an implicitly closed ring drop the last.
##
## @seealso{geom.curvature, geom.curveoffset, geom.selfintersects}
## @end deftypefn

function [P, T] = curvesample (FCN, TRANGE, TOL, MAXPTS = 100000)

  ## Input validation
  if (nargin < 3 || nargin > 4)
    error ("geom.curvesample: invalid number of input arguments.");
  endif
  if (! is_function_handle (FCN))
    error ("geom.curvesample: FCN must be a function handle.");
  endif
  if (! isnumeric (TRANGE) || ! isreal (TRANGE) || ! isvector (TRANGE) ...
      || numel (TRANGE) != 2 || ! all (isfinite (TRANGE)))
    error (strcat ("geom.curvesample: TRANGE must be a two-element real", ...
                   " finite vector."));
  endif
  if (TRANGE(2) <= TRANGE(1))
    error ("geom.curvesample: TRANGE must be increasing.");
  endif
  if (! isnumeric (TOL) || ! isreal (TOL) || ! isscalar (TOL) ...
      || ! isfinite (TOL) || TOL <= 0)
    error ("geom.curvesample: TOL must be a positive finite scalar.");
  endif
  if (! isnumeric (MAXPTS) || ! isreal (MAXPTS) || ! isscalar (MAXPTS) ...
      || MAXPTS < 3 || MAXPTS != fix (MAXPTS))
    error ("geom.curvesample: MAXPTS must be an integer of at least 3.");
  endif

  ## A uniform seed, so that a symmetric curve is not mistaken for a flat one
  SEED = 16;
  T = linspace (TRANGE(1), TRANGE(2), SEED + 1)';
  P = evaluate (FCN, T);

  do
    ## Midpoint of every interval, on the true curve
    tMid = (T(1:end-1) + T(2:end)) / 2;
    pMid = evaluate (FCN, tMid);

    ## Departure of the true midpoint from the chord it should have lain on
    A = P(1:end-1,:);
    B = P(2:end,:);
    chord = B - A;
    len = sqrt (sum (chord .^ 2, 2));
    v = pMid - A;
    dev = abs (v(:,1) .* chord(:,2) - v(:,2) .* chord(:,1)) ./ len;

    ## A chord of no length cannot be departed from; split it regardless
    dev(len == 0) = Inf;

    split = (dev > TOL);
    if (! any (split))
      break;
    endif

    if (rows (T) + sum (split) > MAXPTS)
      error (strcat ("geom.curvesample: more than %d points are needed to", ...
                     " hold TOL; the curve may be discontinuous or TOL too", ...
                     " small."), MAXPTS);
    endif

    [T, i] = sort ([T; tMid(split)]);
    P = [P; pMid(split,:)](i,:);
  until (false)

endfunction

## Evaluate the curve and check the shape of what came back
function P = evaluate (FCN, T)

  P = FCN (T);
  if (! isnumeric (P) || ! isreal (P) || ndims (P) != 2 ...
      || columns (P) != 2 || rows (P) != numel (T))
    error (strcat ("geom.curvesample: FCN must return a real N-by-2 matrix", ...
                   " with one row per parameter value."));
  endif
  if (! all (isfinite (P(:))))
    error ("geom.curvesample: FCN returned a non-finite coordinate.");
  endif

endfunction

%!test  # every sampled point of a circle is on the circle
%! P = geom.curvesample (@(t) [cos(t), sin(t)], [0, 2*pi], 1e-3);
%! assert_equal (sqrt (sum (P .^ 2, 2)), ones (rows (P), 1), 1e-12);

%!test  # the stated tolerance is actually met
%! R = 25;
%! P = geom.curvesample (@(t) R * [cos(t), sin(t)], [0, 2*pi], 0.01);
%! d = sqrt (sum ((P(2:end,:) - P(1:end-1,:)) .^ 2, 2));
%! sagitta = R - sqrt (R ^ 2 - (d / 2) .^ 2);
%! assert_equal (all (sagitta <= 0.01 + 1e-12), true);

%!test  # a tighter tolerance costs more points
%! n1 = rows (geom.curvesample (@(t) [cos(t), sin(t)], [0, 2*pi], 1e-2));
%! n2 = rows (geom.curvesample (@(t) [cos(t), sin(t)], [0, 2*pi], 1e-4));
%! assert_equal (n2 > n1, true);

%!test  # a straight line needs no refinement beyond the seed
%! [P, T] = geom.curvesample (@(t) [t, 2*t], [0, 10], 1e-6);
%! assert_equal (rows (P), 17);

%!test  # the parameter values come back sorted and spanning the range
%! [P, T] = geom.curvesample (@(t) [cos(t), sin(t)], [0, pi], 1e-3);
%! assert_equal (issorted (T), true);
%! assert_equal ([T(1), T(end)], [0, pi], 1e-12);

%!test  # a full period closes on itself
%! P = geom.curvesample (@(t) [cos(t), sin(t)], [0, 2*pi], 1e-3);
%! assert_equal (P(1,:), P(end,:), 1e-12);

%!test  # the polygon area approaches the true area from below
%! R = 10;
%! P = geom.curvesample (@(t) R * [cos(t), sin(t)], [0, 2*pi], 1e-4);
%! A = abs (geom.signedarea (P));
%! assert_equal (A < pi * R ^ 2, true);
%! assert_equal (A, pi * R ^ 2, 1e-2);

%!test  # curvature varying along the curve is sampled unevenly
%! [P, T] = geom.curvesample (@(t) [t, t .^ 3], [-2, 2], 1e-3);
%! d = diff (T);
%! assert_equal (max (d) >= 4 * min (d), true);

%!test  # refinement follows curvature, not parameter
%! [P, T] = geom.curvesample (@(t) [10*cos(t), sin(t)], [0, 2*pi], 1e-3);
%! d = diff (T);
%! tMid = (T(1:end-1) + T(2:end)) / 2;
%! sharp = mean (d(abs (tMid - pi) < 0.3));       # end of the major axis
%! blunt = mean (d(abs (tMid - pi/2) < 0.3));     # end of the minor axis
%! assert_equal (sharp < blunt, true);

%!error<geom.curvesample: invalid number of input arguments.> ...
%! geom.curvesample (@(t) [t, t], [0, 1])
%!error<geom.curvesample: FCN must be a function handle.> ...
%! geom.curvesample (42, [0, 1], 1e-3)
%!error<geom.curvesample: TRANGE must be a two-element real finite vector.> ...
%! geom.curvesample (@(t) [t, t], [0, 1, 2], 1e-3)
%!error<geom.curvesample: TRANGE must be increasing.> ...
%! geom.curvesample (@(t) [t, t], [1, 0], 1e-3)
%!error<geom.curvesample: TOL must be a positive finite scalar.> ...
%! geom.curvesample (@(t) [t, t], [0, 1], 0)
%!error<geom.curvesample: MAXPTS must be an integer of at least 3.> ...
%! geom.curvesample (@(t) [t, t], [0, 1], 1e-3, 2)
%!error<geom.curvesample: FCN must return a real N-by-2 matrix with one row per parameter value.> ...
%! geom.curvesample (@(t) [t, t, t], [0, 1], 1e-3)
%!error<geom.curvesample: FCN returned a non-finite coordinate.> ...
%! geom.curvesample (@(t) [t, 1 ./ (t - 0.5)], [0, 1], 1e-3)
