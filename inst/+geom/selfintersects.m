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
## @deftypefn  {drafting} {@var{TF} =} geom.selfintersects (@var{P})
## @deftypefnx {drafting} {@var{TF} =} geom.selfintersects (@var{P}, @var{CLOSED})
## @deftypefnx {drafting} {[@var{TF}, @var{IDX}] =} geom.selfintersects (@dots{})
##
## Test whether a sampled curve crosses itself.
##
## @code{@var{TF} = geom.selfintersects (@var{P})} returns true when any two
## non-adjacent segments of the curve @var{P} intersect, and false otherwise.
## @var{P} is an @math{N}-by-2 matrix of points.
##
## @code{@var{TF} = geom.selfintersects (@var{P}, @var{CLOSED})} treats the
## curve as closed when @var{CLOSED} is true, adding the segment from the last
## point back to the first.  @var{CLOSED} defaults to false.
##
## @code{[@var{TF}, @var{IDX}] = geom.selfintersects (@dots{})} additionally
## returns the offending segment pairs as an @math{M}-by-2 matrix of segment
## indices, one row per crossing pair, empty when there is none.  Segment
## @math{k} runs from point @math{k} to point @math{k+1}.
##
## Segments that merely share an end point are not crossings, so consecutive
## segments are never reported, nor are the first and last segments of a closed
## curve.  A curve that touches itself without crossing --- two segments meeting
## at a point that is an end of both --- is reported, since for the purposes
## this test serves, touching and crossing are equally fatal.
##
## This is the global companion to the local criterion in
## @code{geom.curveoffset}.  An offset curve can satisfy the curvature condition
## at every point and still pinch closed somewhere along its length; only a
## test like this one sees that.
##
## The test is exhaustive over segment pairs, so its cost grows as the square of
## the number of points.  On a profile of a few thousand points that is a
## fraction of a second, but it is not something to call inside a loop over
## candidate designs.
##
## @seealso{geom.curveoffset, geom.curvature, geom.signedarea}
## @end deftypefn

function [TF, IDX] = selfintersects (P, CLOSED = false)

  ## Input validation
  if (nargin < 1 || nargin > 2)
    error ("geom.selfintersects: invalid number of input arguments.");
  endif
  if (! (islogical (CLOSED) || isnumeric (CLOSED)) || ! isscalar (CLOSED))
    error ("geom.selfintersects: CLOSED must be a logical scalar.");
  endif
  CLOSED = logical (CLOSED);
  [errmsg, P] = geom.__checkcurve__ (P, CLOSED);
  if (! isempty (errmsg))
    error ("geom.selfintersects: %s", errmsg);
  endif

  n = rows (P);

  ## Segment k runs from A(k,:) to B(k,:)
  if (CLOSED)
    A = P;
    B = P([2:n, 1],:);
  else
    A = P(1:n-1,:);
    B = P(2:n,:);
  endif
  m = rows (A);

  IDX = zeros (0, 2);

  ## Each segment against every later one, vectorised over the later segments.
  ## Adjacency is skipped by construction: segment i never meets i+1, and on a
  ## closed curve segment 1 never meets segment m.
  for i = 1:m-2
    if (CLOSED && i == 1)
      j = (i+2):(m-1);
    else
      j = (i+2):m;
    endif
    if (isempty (j))
      continue;
    endif

    p = A(i,:);
    r = B(i,:) - A(i,:);
    q = A(j,:);
    s = B(j,:) - A(j,:);

    ## Standard parametric crossing test: p + t r meets q + u s
    rxs = r(1) * s(:,2) - r(2) * s(:,1);
    qp = q - p;
    qpxr = qp(:,1) * r(2) - qp(:,2) * r(1);
    qpxs = qp(:,1) .* s(:,2) - qp(:,2) .* s(:,1);

    hit = false (numel (j), 1);

    ## Non-parallel segments cross when both parameters lie in [0, 1]
    np = (rxs != 0);
    if (any (np))
      t = qpxs(np) ./ rxs(np);
      u = qpxr(np) ./ rxs(np);
      hit(np) = (t >= 0 & t <= 1 & u >= 0 & u <= 1);
    endif

    ## Collinear segments cross when their parameter ranges overlap
    col = (rxs == 0 & qpxr == 0);
    if (any (col))
      rr = dot (r, r);
      if (rr > 0)
        t0 = (qp(col,1) * r(1) + qp(col,2) * r(2)) / rr;
        t1 = t0 + (s(col,1) * r(1) + s(col,2) * r(2)) / rr;
        lo = min (t0, t1);
        hi = max (t0, t1);
        hit(col) = (hi >= 0 & lo <= 1);
      endif
    endif

    if (any (hit))
      IDX = [IDX; repmat(i, sum (hit), 1), j(hit)'];
    endif
  endfor

  TF = ! isempty (IDX);

endfunction

%!demo
%! ## The global companion to the local fold test in `geom.curveoffset`.  A
%! ## curve can satisfy the curvature condition everywhere and still pinch
%! ## closed somewhere along its length; only a crossing test sees that.
%!
%! bowtie = [0, 0; 40, 40; 40, 0; 0, 40];
%! [TF, IDX] = geom.selfintersects (bowtie, true)
%!
%! D = draw.Drawing ().polyline (bowtie, true);
%! plot (D);
%! title ('segments 1 and 3 cross');

%!demo
%! ## A simple outline crosses nothing, and reports so.
%!
%! t = linspace (0, 2*pi, 181)(1:180)';
%! P = (30 + 4 * cos (5 * t)) .* [cos(t), sin(t)];
%! geom.selfintersects (P, true)

%!test  # a convex polygon does not cross itself
%! assert_equal (geom.selfintersects ([0, 0; 4, 0; 4, 3; 0, 3], true), false);

%!test  # a bow tie does
%! assert_equal (geom.selfintersects ([0, 0; 4, 4; 4, 0; 0, 4], true), true);

%!test  # a circle is clean at fine sampling
%! t = linspace (0, 2*pi, 361)(1:360)';
%! assert_equal (geom.selfintersects ([cos(t), sin(t)], true), false);

%!test  # the crossing pair is reported
%! [TF, IDX] = geom.selfintersects ([0, 0; 4, 4; 4, 0; 0, 4], true);
%! assert_equal (TF, true);
%! assert_equal (IDX, [1, 3]);

%!test  # a clean curve reports no pairs
%! [TF, IDX] = geom.selfintersects ([0, 0; 4, 0; 4, 3; 0, 3], true);
%! assert_equal (TF, false);
%! assert_equal (isempty (IDX), true);

%!test  # an open curve is not closed behind your back
%! assert_equal (geom.selfintersects ([0, 0; 4, 0; 4, 3; 0, 3]), false);

%!test  # an open curve that doubles back over itself is caught
%! assert_equal (geom.selfintersects ([0, 0; 4, 0; 2, 0; 2, 4]), true);

%!test  # an L that only touches at shared ends is clean
%! assert_equal (geom.selfintersects ([0, 0; 2, 0; 2, 2], false), false);

%!test  # a closed curve whose first and last segments meet is clean
%! assert_equal (geom.selfintersects ([0, 0; 1, 0; 1, 1; 0, 1], true), false);

%!test  # a curve returning to an earlier point is reported
%! assert_equal (geom.selfintersects ([0, 0; 2, 0; 2, 2; 0, 2; 1, 0]), true);

%!error<geom.selfintersects: invalid number of input arguments.> ...
%! geom.selfintersects ()
%!error<geom.selfintersects: CLOSED must be a logical scalar.> ...
%! geom.selfintersects ([0, 0; 1, 0; 1, 1], [true, false])
%!error<geom.selfintersects: P must be a curve with at least 3 points.> ...
%! geom.selfintersects ([0, 0; 1, 1])
%!error<geom.selfintersects: P must not contain NaN or Inf values.> ...
%! geom.selfintersects ([0, 0; 1, 0; NaN, 1])
