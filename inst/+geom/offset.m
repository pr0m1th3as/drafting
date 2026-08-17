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
## @deftypefn {drafting} {@var{Q} =} geom.offset (@var{P}, @var{D})
##
## Offset a rectilinear polygon inward or outward.
##
## @code{@var{Q} = geom.offset (@var{P}, @var{D})} slides every edge of the
## polygon @var{P} a distance @var{D} along its own inward normal and returns
## the resulting outline @var{Q}, with one vertex per vertex of @var{P}.
##
## A positive @var{D} offsets @strong{inward}, shrinking the outline; a negative
## @var{D} offsets outward.  @var{D} is in the units of @var{P}, so millimetres
## by package convention.  @code{@var{D} = 0} returns @var{P} unchanged.
##
## The orientation of @var{P}, clockwise or counter-clockwise, is preserved in
## @var{Q}, and vertex @math{k} of @var{Q} corresponds to vertex @math{k} of
## @var{P}.
##
## @strong{Rectilinear input only.}  @var{P} must satisfy
## @code{geom.isrectilinear}; anything else raises an error.  This is a
## deliberate restriction rather than an oversight.  Offsetting a general
## polygon is a genuinely hard problem --- edges collapse, the outline
## self-intersects, and a correct implementation has to detect and resolve both
## --- while the outlines this is wanted for are rectangular in the great
## majority of cases and L-shaped in most of the rest.  The interface is general
## enough that support for arbitrary polygons can be added later without
## disturbing callers.
##
## An offset too large for the outline to absorb raises an error rather than
## returning a self-intersecting result.  This is detected by checking that the
## orientation survives and that no edge has reversed direction, which is exact
## for rectilinear outlines.
##
## @seealso{geom.isrectilinear, geom.largestrect, geom.signedarea}
## @end deftypefn

function Q = offset (P, D)

  ## Input validation
  if (nargin != 2)
    error ("geom.offset: invalid number of input arguments.");
  endif
  [errmsg, P] = geom.__checkpoly__ (P);
  if (! isempty (errmsg))
    error ("geom.offset: %s", errmsg);
  endif
  if (! isnumeric (D) || ! isreal (D) || ! isscalar (D) || ! isfinite (D))
    error ("geom.offset: D must be a real finite scalar.");
  endif
  if (! geom.isrectilinear (P))
    error (strcat ("geom.offset: P must be a rectilinear polygon;", ...
                   " offsetting a general polygon is not implemented."));
  endif

  if (D == 0)
    Q = P;
    return;
  endif

  ## Work counter-clockwise, so that the inward normal is the left normal, and
  ## restore the caller's orientation on the way out.
  A0 = geom.signedarea (P);
  if (A0 == 0)
    error ("geom.offset: P has zero area, so it has no inside to offset into.");
  endif
  isFlipped = A0 < 0;
  if (isFlipped)
    P = flipud (P);
  endif

  ## Edge vectors around the closed ring
  nVert = rows (P);
  Dir = [P(2:end,:); P(1,:)] - P;
  edgeLen = sqrt (sum (Dir .^ 2, 2));
  if (any (edgeLen == 0))
    error ("geom.offset: P contains a zero-length edge.");
  endif

  ## Unit inward normal of each edge, then slide the edge along it
  Nrm = [-Dir(:,2), Dir(:,1)] ./ edgeLen;
  Base = P + D * Nrm;

  ## Each new vertex is where the two slid edges meeting at it now cross
  Q = zeros (nVert, 2);
  for ii = 1:nVert
    jj = mod (ii - 2, nVert) + 1;
    Q(ii,:) = meet (Base(jj,:), Dir(jj,:), Base(ii,:), Dir(ii,:));
  endfor

  ## An offset the outline cannot absorb shows up as a lost orientation or a
  ## reversed edge.  For rectilinear input those two catch every failure.
  DirNew = [Q(2:end,:); Q(1,:)] - Q;
  if (sign (geom.signedarea (Q)) != 1 || any (sum (DirNew .* Dir, 2) <= 0))
    error (strcat ("geom.offset: D is too large for P; the offset outline", ...
                   " would be degenerate."));
  endif

  if (isFlipped)
    Q = flipud (Q);
  endif

endfunction

## Intersection of the lines through A1 along DIR1 and through A2 along DIR2.
## Single consumer, so it stays in the file.  Parallel lines mean two collinear
## edges slid by the same distance, which now coincide: A2 is then already the
## meeting point.
function X = meet (A1, DIR1, A2, DIR2)

  den = DIR1(1) * DIR2(2) - DIR1(2) * DIR2(1);
  if (abs (den) <= 8 * eps * max ([1, abs([DIR1, DIR2])]))
    X = A2;
    return;
  endif
  w = A2 - A1;
  t = (w(1) * DIR2(2) - w(2) * DIR2(1)) / den;
  X = A1 + t * DIR1;

endfunction

%!test  # inward offset of a counter-clockwise square
%! P = [0, 0; 10, 0; 10, 10; 0, 10];
%! assert_equal (geom.offset (P, 2), [2, 2; 8, 2; 8, 8; 2, 8], 1e-12);

%!test  # negative D offsets outward
%! P = [0, 0; 10, 0; 10, 10; 0, 10];
%! assert_equal (geom.offset (P, -2), [-2, -2; 12, -2; 12, 12; -2, 12], 1e-12);

%!test  # zero offset is the identity
%! P = [0, 0; 10, 0; 10, 10; 0, 10];
%! assert_equal (geom.offset (P, 0), P);

%!test  # clockwise input keeps its orientation and vertex correspondence
%! P = [0, 0; 0, 10; 10, 10; 10, 0];
%! Q = geom.offset (P, 2);
%! assert_equal (Q, [2, 2; 2, 8; 8, 8; 8, 2], 1e-12);
%! assert_equal (sign (geom.signedarea (Q)), sign (geom.signedarea (P)));

%!test  # a large rectangle loses 2*D in each dimension
%! P = [0, 0; 1600, 0; 1600, 1800; 0, 1800];
%! Q = geom.offset (P, 50);
%! [~, W, H] = geom.bbox (Q);
%! assert_equal ([W, H], [1500, 1700], 1e-9);

%!test  # offsetting an L shape moves the reflex corner outward, not inward
%! P = [0, 0; 10, 0; 10, 4; 4, 4; 4, 10; 0, 10];
%! Q = geom.offset (P, 1);
%! assert_equal (Q, [1, 1; 9, 1; 9, 3; 3, 3; 3, 9; 1, 9], 1e-12);

%!test  # area decreases monotonically with an inward offset
%! P = [0, 0; 10, 0; 10, 10; 0, 10];
%! a = arrayfun (@(d) geom.signedarea (geom.offset (P, d)), [0, 1, 2, 3, 4]);
%! assert_equal (all (diff (a) < 0), true);

%!test  # a double offset equals a single offset by the sum
%! P = [0, 0; 20, 0; 20, 8; 8, 8; 8, 20; 0, 20];
%! assert_equal (geom.offset (geom.offset (P, 1), 2), ...
%!               geom.offset (P, 3), 1e-9);

%!test  # offsetting out and back again recovers the original
%! P = [0, 0; 20, 0; 20, 8; 8, 8; 8, 20; 0, 20];
%! assert_equal (geom.offset (geom.offset (P, 2), -2), P, 1e-9);

%!test  # an L-shaped outline is limited by its arm width, not its extent
%! P = [0, 0; 20, 0; 20, 8; 8, 8; 8, 20; 0, 20];   # arms 8 wide
%! Q = geom.offset (P, 3.9);
%! assert_equal (Q(1,:), [3.9, 3.9], 1e-12);

%!test  # an offset that just fits still succeeds
%! P = [0, 0; 10, 0; 10, 10; 0, 10];
%! assert_equal (geom.offset (P, 4.999), ...
%!               [4.999, 4.999; 5.001, 4.999; 5.001, 5.001; 4.999, 5.001], ...
%!               1e-9);

%!test  # collinear vertices survive the offset
%! P = [0, 0; 5, 0; 10, 0; 10, 10; 0, 10];
%! Q = geom.offset (P, 1);
%! assert_equal (Q, [1, 1; 5, 1; 9, 1; 9, 9; 1, 9], 1e-12);

%!error<geom.offset: invalid number of input arguments.> ...
%! geom.offset ([0, 0; 1, 0; 1, 1])
%!error<geom.offset: P must be a polygon with at least 3 vertices.> ...
%! geom.offset ([0, 0; 1, 1], 1)
%!error<geom.offset: D must be a real finite scalar.> ...
%! geom.offset ([0, 0; 1, 0; 1, 1; 0, 1], [1, 2])
%!error<geom.offset: D must be a real finite scalar.> ...
%! geom.offset ([0, 0; 1, 0; 1, 1; 0, 1], Inf)
%!error<geom.offset: P must be a rectilinear polygon; offsetting a general polygon is not implemented.> ...
%! geom.offset ([0, 0; 10, 0; 0, 10], 1)
%!error<geom.offset: P has zero area, so it has no inside to offset into.> ...
%! geom.offset ([0, 0; 1, 0; 2, 0], 1)
%!error<geom.offset: D is too large for P; the offset outline would be degenerate.> ...
%! geom.offset ([0, 0; 10, 0; 10, 10; 0, 10], 5)
%!error<geom.offset: D is too large for P; the offset outline would be degenerate.> ...
%! geom.offset ([0, 0; 10, 0; 10, 10; 0, 10], 8)
%!error<geom.offset: D is too large for P; the offset outline would be degenerate.> ...
%! geom.offset ([0, 0; 20, 0; 20, 8; 8, 8; 8, 20; 0, 20], 4)
