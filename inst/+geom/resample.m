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
## @deftypefn  {drafting} {@var{Q} =} geom.resample (@var{P}, @var{N})
## @deftypefnx {drafting} {@var{Q} =} geom.resample (@var{P}, @qcode{'spacing'}, @var{D})
## @deftypefnx {drafting} {@var{Q} =} geom.resample (@dots{}, @var{CLOSED})
## @deftypefnx {drafting} {[@var{Q}, @var{S}] =} geom.resample (@dots{})
##
## Respace the points of a curve evenly along its length.
##
## @code{@var{Q} = geom.resample (@var{P}, @var{N})} returns @var{N} points
## spaced equally along the polyline @var{P}, the first at its start and the
## last at its end.
##
## @code{@var{Q} = geom.resample (@var{P}, @qcode{'spacing'}, @var{D})} spaces
## them @var{D} apart instead, taking as many as fit.  The last point lands at
## the end of the curve whatever the remainder, so the final gap may be shorter
## than @var{D}; a curve is not lengthened to make the arithmetic tidy.
##
## Adding @var{CLOSED} as a final true argument treats the curve as closed, in
## which case the returned points do not repeat the first.
##
## @code{[@var{Q}, @var{S}] = geom.resample (@dots{})} also returns the distance
## along the curve at which each point was taken.
##
## @subheading This is not @code{geom.curvesample}
##
## @code{geom.curvesample} samples a curve it can @emph{evaluate}, refining
## where the curvature demands it, and is the right tool when the curve is
## known as a function.  This one has only the points it is given, so it can
## interpolate between them but never recover what fell between two samples.
##
## Use it to give a curve evenly spaced points --- for a marker every so many
## millimetres, for a table of inspection coordinates, for feeding an algorithm
## that assumes uniform spacing --- not to improve one that was sampled too
## coarsely.  Resampling a coarse polyline finely produces a great many points
## on the same straight lines it already had.
##
## @subheading Corners are cut, and that is not a defect
##
## The returned points are new ones, placed at equal distances; the original
## vertices are not among them unless a sample happens to land on one.  Where
## two samples straddle a corner, the curve between them is the chord, and the
## corner is gone.  The result is therefore slightly shorter than the original
## and slightly inside it.
##
## That is inherent to spacing points evenly --- a corner is exactly the place
## where a curve cannot be walked at constant speed and still be reproduced ---
## but it means @strong{a polygon should not be resampled if its vertices
## matter}.  Feature lines, outlines to be cut, and anything with a defined
## corner want @code{geom.simplify}, which only ever removes points and so can
## never invent a chord across one.
##
## @seealso{geom.curvesample, geom.simplify, geom.arclength}
## @end deftypefn

function [Q, S] = resample (P, varargin)

  ## Input validation
  if (nargin < 2 || nargin > 4)
    error ("geom.resample: invalid number of input arguments.");
  endif

  ## resample (P, N), resample (P, N, CLOSED),
  ## resample (P, 'spacing', D), resample (P, 'spacing', D, CLOSED)
  args = varargin;
  bySpacing = ischar (args{1});
  if (bySpacing)
    if (! strcmpi (args{1}, 'spacing'))
      error ("geom.resample: the only named option is 'spacing'.");
    endif
    if (numel (args) < 2 || numel (args) > 3)
      error ("geom.resample: invalid number of input arguments.");
    endif
    val = args{2};
    args = args(3:end);
  else
    val = args{1};
    args = args(2:end);
  endif

  CLOSED = false;
  if (! isempty (args))
    CLOSED = args{1};
    if (! (islogical (CLOSED) || isnumeric (CLOSED)) || ! isscalar (CLOSED))
      error ("geom.resample: CLOSED must be a logical scalar.");
    endif
    CLOSED = logical (CLOSED);
  endif

  [errmsg, P] = geom.__checkpts__ (P);
  if (! isempty (errmsg))
    error ("geom.resample: %s", errmsg);
  endif
  if (rows (P) < 2)
    error ("geom.resample: P must contain at least two points.");
  endif
  if (! isnumeric (val) || ! isreal (val) || ! isscalar (val) ...
      || ! isfinite (val) || val <= 0)
    if (bySpacing)
      error ("geom.resample: D must be a positive real finite scalar.");
    else
      error ("geom.resample: N must be a positive integer.");
    endif
  endif
  if (! bySpacing && (val != fix (val) || val < 2))
    error ("geom.resample: N must be an integer of at least 2.");
  endif

  [L, cum] = geom.arclength (P, CLOSED);
  if (L <= 0)
    error ("geom.resample: P has no length to space points along.");
  endif
  if (CLOSED)
    P = [P; P(1,:)];
  endif

  ## On a ring the start is also the end, so N points means a step of L/N and
  ## no sample at L; on an open curve the ends are both wanted, so N points
  ## means a step of L/(N-1)
  if (bySpacing)
    if (CLOSED)
      S = (0:val:L - 1e-12 * L)';
    else
      S = (0:val:L)';
      if (S(end) < L - 1e-12 * L)
        S(end+1) = L;
      endif
    endif
  else
    if (CLOSED)
      S = linspace (0, L, val + 1)';
      S(end) = [];
    else
      S = linspace (0, L, val)';
    endif
  endif

  Q = zeros (numel (S), 2);
  for k = 1:numel (S)
    i = max (1, min (rows (P) - 1, find (cum <= S(k), 1, 'last')));
    span = cum(i+1) - cum(i);
    if (span <= 0)
      Q(k,:) = P(i,:);
    else
      Q(k,:) = P(i,:) + (S(k) - cum(i)) / span * (P(i+1,:) - P(i,:));
    endif
  endfor

endfunction

%!test  # N points along a straight line are evenly spaced
%! Q = geom.resample ([0, 0; 10, 0], 5);
%! assert_equal (Q, [0, 0; 2.5, 0; 5, 0; 7.5, 0; 10, 0], 1e-12);

%!test  # the first and last points are the ends of the curve
%! P = [0, 0; 3, 4; 10, 4];
%! Q = geom.resample (P, 7);
%! assert_equal (Q(1,:), P(1,:), 1e-12);
%! assert_equal (Q(end,:), P(end,:), 1e-12);

%!test  # the spacing is equal along the curve, which is what was asked for.
%!       # It is not equal in straight-line distance: two points straddling a
%!       # corner are closer to each other than their arc separation.
%! [Q, S] = geom.resample ([0, 0; 3, 4; 10, 4], 11);
%! assert_equal (max (diff (S)) - min (diff (S)) < 1e-9, true);
%! d = sqrt (sum (diff (Q, 1, 1) .^ 2, 2));
%! assert_equal (min (d) < max (d) - 1e-9, true);

%!test  # spacing mode takes as many as fit and still lands on the end
%! Q = geom.resample ([0, 0; 10, 0], 'spacing', 2.5);
%! assert_equal (Q, [0, 0; 2.5, 0; 5, 0; 7.5, 0; 10, 0], 1e-12);

%!test  # a remainder gives a shorter final gap, not a longer curve
%! Q = geom.resample ([0, 0; 10, 0], 'spacing', 3);
%! assert_equal (Q(end,:), [10, 0], 1e-12);
%! assert_equal (rows (Q), 5);

%!test  # every resampled point lies on the original curve
%! P = [0, 0; 3, 4; 10, 4];
%! Q = geom.resample (P, 20);
%! assert_equal (all (Q(:,2) <= 4 + 1e-12), true);

%!test  # a curve with no corners keeps its length exactly
%! assert_equal (geom.arclength (geom.resample ([0, 0; 10, 0], 7)), 10, 1e-12);

%!test  # a corner is cut, so the result is shorter, and less so as N grows
%! P = [0, 0; 3, 4; 10, 4];
%! L = geom.arclength (P);
%! L10 = geom.arclength (geom.resample (P, 10));
%! L200 = geom.arclength (geom.resample (P, 200));
%! assert_equal (L10 < L, true);
%! assert_equal (L200 < L, true);
%! assert_equal (L200 > L10, true);
%! assert_equal (L200, L, 1e-2);

%!test  # a closed curve does not repeat its first point
%! P = [0, 0; 10, 0; 10, 10; 0, 10];
%! Q = geom.resample (P, 8, true);
%! assert_equal (rows (Q), 8);
%! assert_equal (norm (Q(1,:) - Q(end,:)) > 1, true);

%!test  # and its points are evenly spaced right around the ring, closing gap
%!       # included
%! P = [0, 0; 10, 0; 10, 10; 0, 10];
%! [Q, S] = geom.resample (P, 8, true);
%! assert_equal (rows (Q), 8);
%! L = geom.arclength (P, true);
%! g = diff ([S; L]);
%! assert_equal (max (g) - min (g) < 1e-9, true);

%!test  # the distances along the curve come back too
%! [Q, S] = geom.resample ([0, 0; 10, 0], 5);
%! assert_equal (S, [0; 2.5; 5; 7.5; 10], 1e-12);

%!test  # a circle resampled stays on the circle
%! t = linspace (0, 2*pi, 721)(1:720)';
%! Q = geom.resample (10 * [cos(t), sin(t)], 36, true);
%! assert_equal (sqrt (sum (Q .^ 2, 2)), 10 * ones (36, 1), 1e-3);

%!error<geom.resample: invalid number of input arguments.> ...
%! geom.resample ([0, 0; 1, 0])
%!error<geom.resample: N must be an integer of at least 2.> ...
%! geom.resample ([0, 0; 1, 0], 1)
%!error<geom.resample: D must be a positive real finite scalar.> ...
%! geom.resample ([0, 0; 1, 0], 'spacing', 0)
%!error<geom.resample: the only named option is 'spacing'.> ...
%! geom.resample ([0, 0; 1, 0], 'every', 2)
%!error<geom.resample: P must contain at least two points.> ...
%! geom.resample ([3, 4], 5)
