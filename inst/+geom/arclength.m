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
## @deftypefn  {drafting} {@var{L} =} geom.arclength (@var{P})
## @deftypefnx {drafting} {@var{L} =} geom.arclength (@var{P}, @var{CLOSED})
## @deftypefnx {drafting} {[@var{L}, @var{S}] =} geom.arclength (@dots{})
##
## Length along a sampled curve.
##
## @code{@var{L} = geom.arclength (@var{P})} returns the total length of the
## polyline whose points are the rows of the @math{N}-by-2 matrix @var{P}, in
## the units of @var{P}.
##
## @code{@var{L} = geom.arclength (@var{P}, @var{CLOSED})} adds the closing
## segment from the last point back to the first when @var{CLOSED} is true.
## @var{CLOSED} defaults to false.
##
## @code{[@var{L}, @var{S}] = geom.arclength (@dots{})} also returns the
## cumulative length at each point, starting at zero, which is what a caller
## needs to place something a given distance along the curve.
##
## The length is that of the @emph{polyline}, not of any smooth curve it may
## have been sampled from, and a polyline is always the shorter of the two.  How
## much shorter is governed by the sampling: at the chordal tolerance
## @code{geom.curvesample} works to, the shortfall is of the same order.
##
## @seealso{geom.resample, geom.simplify, geom.curvesample}
## @end deftypefn

function [L, S] = arclength (P, CLOSED = false)

  ## Input validation
  if (nargin < 1 || nargin > 2)
    error ("geom.arclength: invalid number of input arguments.");
  endif
  if (! (islogical (CLOSED) || isnumeric (CLOSED)) || ! isscalar (CLOSED))
    error ("geom.arclength: CLOSED must be a logical scalar.");
  endif
  CLOSED = logical (CLOSED);
  [errmsg, P] = geom.__checkpts__ (P);
  if (! isempty (errmsg))
    error ("geom.arclength: %s", errmsg);
  endif

  if (CLOSED)
    P = [P; P(1,:)];
  endif

  ## Difference down the rows explicitly: a bare diff on a single-point matrix
  ## treats it as a vector and subtracts y from x, which is a length of nothing
  ## reported as a length of something
  S = [0; cumsum(sqrt (sum (diff (P, 1, 1) .^ 2, 2)))];
  L = S(end);

endfunction

%!demo
%! ## The length along a curve, and the cumulative distance at each point --
%! ## which is what places something a given distance along it.
%!
%! P = [0, 0; 30, 0; 30, 40];
%! [L, S] = geom.arclength (P)
%!
%! ## Closing the ring adds the segment back to the start
%! geom.arclength (P, true)

%!demo
%! ## The length is that of the polyline, not of the smooth curve it was
%! ## sampled from, and a polyline is always the shorter of the two.
%!
%! for n = [8, 60, 400]
%!   t = linspace (0, 2*pi, n + 1)(1:n)';
%!   printf ('%3d-sided polygon: %8.4f  (circle is %8.4f)\n', n, ...
%!           geom.arclength (10 * [cos(t), sin(t)], true), 2 * pi * 10);
%! endfor

%!test  # a straight run is its own length
%! assert_equal (geom.arclength ([0, 0; 3, 4]), 5, 1e-12);

%!test  # the pieces of a polyline add up
%! assert_equal (geom.arclength ([0, 0; 3, 0; 3, 4]), 7, 1e-12);

%!test  # closing adds the segment back to the start
%! assert_equal (geom.arclength ([0, 0; 3, 0; 3, 4], true), 12, 1e-12);

%!test  # the perimeter of a square
%! assert_equal (geom.arclength ([0, 0; 5, 0; 5, 5; 0, 5], true), 20, 1e-12);

%!test  # the cumulative length starts at zero and ends at the total
%! [L, S] = geom.arclength ([0, 0; 3, 0; 3, 4]);
%! assert_equal (S(1), 0);
%! assert_equal (S(end), L, 1e-12);
%! assert_equal (S, [0; 3; 7], 1e-12);

%!test  # a polygon approaches its circle's circumference from below
%! t = linspace (0, 2*pi, 3601)(1:3600)';
%! L = geom.arclength (10 * [cos(t), sin(t)], true);
%! assert_equal (L < 2 * pi * 10, true);
%! assert_equal (L, 2 * pi * 10, 1e-3);

%!test  # a single point has no length
%! assert_equal (geom.arclength ([3, 4]), 0);

%!test  # repeated points contribute nothing
%! assert_equal (geom.arclength ([0, 0; 1, 0; 1, 0; 2, 0]), 2, 1e-12);

%!error<geom.arclength: invalid number of input arguments.> geom.arclength ()
%!error<geom.arclength: P must be an N-by-2 matrix of point coordinates.> ...
%! geom.arclength ([1, 2, 3])
%!error<geom.arclength: CLOSED must be a logical scalar.> ...
%! geom.arclength ([0, 0; 1, 1], [true, false])
%!error<geom.arclength: P must not contain NaN or Inf values.> ...
%! geom.arclength ([0, 0; Inf, 1])
