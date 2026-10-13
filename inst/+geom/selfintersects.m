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
## curve.  A point repeating the one before it adds a segment of no length,
## which is passed over, so the segments either side of it count as
## consecutive.  A curve that touches itself without crossing, where two
## segments meet at a point that is an end of both, is reported, since for the
## purposes this test serves, touching and crossing are equally fatal.
## Touching means meeting: segments any distance apart, however small, do not
## touch, where a @code{geom.Region} counts curves within 1e-7 mm of one
## another as touching.
##
## This is the global companion to the local criterion in
## @code{geom.curveoffset}.  An offset curve can satisfy the curvature condition
## at every point and still pinch closed somewhere along its length; only a
## test like this one sees that.
##
## Only segments whose bounding boxes overlap are tested, found by sweeping
## along @math{x}, so a profile of half a million points takes a few
## hundredths of a second.
##
## @seealso{geom.curveoffset, geom.curvature, geom.signedarea}
## @end deftypefn

function [TF, IDX] = selfintersects (P, CLOSED = false)

  ## Input validation
  if (nargin < 1 || nargin > 2)
    error ("geom.selfintersects: invalid number of input arguments.");
  endif
  if (! islogical (CLOSED) || ! isscalar (CLOSED))
    error ("geom.selfintersects: CLOSED must be true or false.");
  endif
  CLOSED = logical (CLOSED);
  [errmsg, P] = geom.__checkcurve__ (P, CLOSED);
  if (! isempty (errmsg))
    error ("geom.selfintersects: %s", errmsg);
  endif

  ## A point repeating the one before it makes a segment of no length, whose
  ## neighbours would then meet as segments that are not adjacent.  It is
  ## passed over, and the segments found are numbered as in P.
  keep = [true; any(diff (P) != 0, 2)];
  if (CLOSED && rows (P) > 1 && isequal (P(end,:), P(1,:)))
    keep(end) = false;
  endif
  first = find (keep);
  IDX = zeros (0, 2);
  if (numel (first) >= 3 || (! CLOSED && numel (first) >= 2))
    ## Only segments whose boxes overlap are tested
    IDX = __mesh__ ('crossings', 'geom.selfintersects', P(keep,:), CLOSED);
    if (! isempty (IDX) && ! all (keep))
      ## Segment k of the points kept ends at the point kept next, and is
      ## the last segment of P before it; the closing one is P's last
      seg = [first(2:end) - 1; rows(P)];
      IDX = reshape (seg(IDX), size (IDX));
    endif
  endif
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
%! D = draw.Drawing ().polyline (geom.Polyline (bowtie, 'Closed', true));
%! plot (D);
%! title ('segments 1 and 3 cross');

%!demo
%! ## A simple outline crosses nothing, and reports so.
%!
%! t = linspace (0, 2*pi, 181)(1:180)';
%! P = (30 + 4 * cos (5 * t)) .* [cos(t), sin(t)];
%! geom.selfintersects (P, true)

%!test  # pieces of one straight edge, far apart in a fine sampling
%! t = linspace (0, 1, 101)';
%! P = [[2.0161 - 1.9 * t, 5 - 4.9786 * t]; 0.1, 0.02; 9, 0.02; 5.5, 10];
%! assert_equal (geom.selfintersects (P, true), false);

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

%!test  # segments in line within rounding, 1e-14 apart, overlap
%! [~, IDX] = geom.selfintersects ([0, 0; 10, 1e-14; 20, 0; 15, 0; 5, 0]);
%! assert_equal (IDX, [1, 4; 2, 4]);

%!test  # a repeated point is passed over
%! assert_equal (geom.selfintersects ([0, 0; 1, 0; 1, 0; 1, 1; 0, 1], true), ...
%!               false);

%!test  # and the segments found are numbered as in P
%! [~, IDX] = geom.selfintersects ([0, 0; 2, 2; 2, 2; 2, 0; 0, 2]);
%! assert_equal (IDX, [1, 4]);

%!error<geom.selfintersects: invalid number of input arguments.> ...
%! geom.selfintersects ()
%!error<geom.selfintersects: CLOSED must be true or false.> ...
%! geom.selfintersects ([0, 0; 1, 0; 1, 1], [true, false])
%!error<geom.selfintersects: CLOSED must be true or false.> ...
%! geom.selfintersects ([0, 0; 1, 0; 1, 1], 1)
%!error<geom.selfintersects: P must be a curve with at least 3 points.> ...
%! geom.selfintersects ([0, 0; 1, 1])
%!error<geom.selfintersects: P must not contain NaN or Inf values.> ...
%! geom.selfintersects ([0, 0; 1, 0; NaN, 1])
%!error<geom.selfintersects: P must be a real floating-point matrix.> ...
%! geom.selfintersects ({1, 2})
%!error<geom.selfintersects: P must be an N-by-2 matrix of point coordinates.> ...
%! geom.selfintersects (ones (3, 3))
%!error<geom.selfintersects: P must contain at least one point.> ...
%! geom.selfintersects (zeros (0, 2))
