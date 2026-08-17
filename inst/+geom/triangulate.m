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
## @deftypefn  {drafting} {@var{T} =} geom.triangulate (@var{P})
## @deftypefnx {drafting} {@var{T} =} geom.triangulate (@var{P}, @var{HOLES})
## @deftypefnx {drafting} {[@var{T}, @var{V}] =} geom.triangulate (@dots{})
## @deftypefnx {drafting} {[@var{T}, @var{V}, @var{COVERAGE}] =} geom.triangulate (@dots{})
##
## Triangulate a polygon, optionally one with holes.
##
## @code{@var{T} = geom.triangulate (@var{P})} returns an @math{M}-by-3 matrix
## of vertex indices, one row per triangle, covering the interior of the polygon
## @var{P}.
##
## @code{@var{T} = geom.triangulate (@var{P}, @var{HOLES})} excludes the
## interiors of the polygons in @var{HOLES}, a cell array of @math{N}-by-2
## vertex matrices.  Each hole must lie inside @var{P} and the holes must not
## overlap one another; neither is checked.
##
## @code{[@var{T}, @var{V}] = geom.triangulate (@dots{})} returns the vertex
## list the indices refer to: @var{P} followed by each hole in turn.
##
## @code{[@var{T}, @var{V}, @var{COVERAGE}] = geom.triangulate (@dots{})}
## returns the fraction of the true area the triangles actually cover.  Read it;
## see below.
##
## The intended use is generating end caps for an extruded solid, where the
## profile carries a central bore and a ring of holes.
##
## @strong{This is not a constrained triangulation, and the distinction
## matters.}  The triangles come from an unconstrained Delaunay triangulation of
## the vertices, filtered by testing whether each triangle's centroid lies
## inside @var{P} and outside every hole.  That construction cannot guarantee
## that the edges of @var{P} appear in the result, so at a strongly concave part
## of the boundary a sliver of the true area may go uncovered: a triangle
## bridging the concavity has its centroid outside and is discarded, and nothing
## replaces it.
##
## The consequence is that a triangulated region can be slightly smaller than
## the polygon, never larger.  Denser sampling of the boundary shrinks the
## shortfall, and @var{COVERAGE} measures it, so a caller that needs a guarantee
## can assert on a number rather than trust a description.  For a printed
## prototype the shortfall is invisible well before it is zero; for anything
## dimensionally critical, a constrained triangulation is the right tool and
## this is not it.
##
## @seealso{geom.signedarea, geom.selfintersects, geom.bbox}
## @end deftypefn

function [T, V, COVERAGE] = triangulate (P, HOLES = {})

  ## Input validation
  if (nargin < 1 || nargin > 2)
    error ("geom.triangulate: invalid number of input arguments.");
  endif
  [errmsg, P] = geom.__checkpoly__ (P);
  if (! isempty (errmsg))
    error ("geom.triangulate: %s", errmsg);
  endif
  if (! iscell (HOLES))
    error ("geom.triangulate: HOLES must be a cell array of vertex matrices.");
  endif
  for k = 1:numel (HOLES)
    [errmsg, HOLES{k}] = geom.__checkpoly__ (HOLES{k});
    if (! isempty (errmsg))
      error ("geom.triangulate: hole %d: %s", k, errmsg);
    endif
  endfor

  ## One vertex list: the outline, then each hole in turn
  V = P;
  for k = 1:numel (HOLES)
    V = [V; HOLES{k}];
  endfor

  tri = delaunay (V(:,1), V(:,2));
  if (isempty (tri))
    error ("geom.triangulate: the vertices admit no triangulation.");
  endif

  ## Keep a triangle when its centroid is inside the outline and in no hole
  cx = mean (reshape (V(tri,1), size (tri)), 2);
  cy = mean (reshape (V(tri,2), size (tri)), 2);
  keep = inpolygon (cx, cy, P(:,1), P(:,2));
  for k = 1:numel (HOLES)
    keep = keep & ! inpolygon (cx, cy, HOLES{k}(:,1), HOLES{k}(:,2));
  endfor
  T = tri(keep,:);

  if (nargout > 2)
    area = abs (geom.signedarea (P));
    for k = 1:numel (HOLES)
      area -= abs (geom.signedarea (HOLES{k}));
    endfor
    x = reshape (V(T,1), size (T));
    y = reshape (V(T,2), size (T));
    covered = sum (abs ((x(:,2) - x(:,1)) .* (y(:,3) - y(:,1)) ...
                        - (x(:,3) - x(:,1)) .* (y(:,2) - y(:,1))) / 2);
    COVERAGE = covered / area;
  endif

endfunction

%!demo
%! ## Triangulating a plate with a bore and a ring of holes --- the end cap of
%! ## an extruded solid.  COVERAGE reports how much of the true area the
%! ## triangles actually reach, so a caller can assert on a number rather than
%! ## trust a description.
%!
%! a = linspace (0, 2*pi, 65)(1:64)';
%! b = linspace (0, 2*pi, 33)(1:32)';
%! outer = 40 * [cos(a), sin(a)];
%! H = {10 * [cos(b), sin(b)]};
%! for k = 1:5
%!   c = 26 * [cos(2*pi*(k-1)/5), sin(2*pi*(k-1)/5)];
%!   H{end+1} = c + 5 * [cos(b), sin(b)];
%! endfor
%! [T, V, COVERAGE] = geom.triangulate (outer, H);
%! printf ('%d triangles covering %.4f of the area\n', rows (T), COVERAGE);
%!
%! D = draw.Drawing ();
%! for k = 1:rows (T)
%!   D = D.polyline (V(T(k,:),:), true);
%! endfor
%! draw.plot (D);
%! title ('an end cap triangulated around its bore and holes');

%!test  # a square becomes two triangles
%! T = geom.triangulate ([0, 0; 1, 0; 1, 1; 0, 1]);
%! assert_equal (rows (T), 2);
%! assert_equal (columns (T), 3);

%!test  # a convex polygon is covered exactly
%! t = linspace (0, 2*pi, 41)(1:40)';
%! [T, V, COVERAGE] = geom.triangulate (10 * [cos(t), sin(t)]);
%! assert_equal (COVERAGE, 1, 1e-12);

%!test  # the vertex list is the outline followed by the holes
%! a = linspace (0, 2*pi, 25)(1:24)';
%! b = linspace (0, 2*pi, 13)(1:12)';
%! P = 10 * [cos(a), sin(a)];
%! H = 2 * [cos(b), sin(b)];
%! [T, V] = geom.triangulate (P, {H});
%! assert_equal (rows (V), 36);
%! assert_equal (V(1:24,:), P);

%!test  # a hole is left empty
%! a = linspace (0, 2*pi, 49)(1:48)';
%! b = linspace (0, 2*pi, 25)(1:24)';
%! P = 10 * [cos(a), sin(a)];
%! H = 3 * [cos(b), sin(b)];
%! [T, V, COVERAGE] = geom.triangulate (P, {H});
%! x = reshape (V(T,1), size (T));
%! y = reshape (V(T,2), size (T));
%! cx = mean (x, 2); cy = mean (y, 2);
%! assert_equal (any (sqrt (cx .^ 2 + cy .^ 2) < 3), false);
%! assert_equal (COVERAGE, 1, 1e-3);

%!test  # several holes, as a cycloidal disc carries
%! a = linspace (0, 2*pi, 145)(1:144)';
%! P = 30 * [cos(a), sin(a)];
%! H = cell (1, 6);
%! for k = 1:6
%!   c = 18 * [cos(2*pi*(k-1)/6), sin(2*pi*(k-1)/6)];
%!   b = linspace (0, 2*pi, 25)(1:24)';
%!   H{k} = c + 3 * [cos(b), sin(b)];
%! endfor
%! [T, V, COVERAGE] = geom.triangulate (P, H);
%! assert_equal (COVERAGE, 1, 1e-2);

%!test  # a concave boundary is covered short, never over
%! P = [0, 0; 10, 0; 10, 10; 5, 3; 0, 10];
%! [T, V, COVERAGE] = geom.triangulate (P);
%! assert_equal (COVERAGE <= 1, true);

%!test  # a lobed outline, densely sampled, is covered to within a percent
%! t = linspace (0, 2*pi, 721)(1:720)';
%! P = (30 + 3 * cos (9 * t)) .* [cos(t), sin(t)];
%! [T, V, COVERAGE] = geom.triangulate (P);
%! assert_equal (COVERAGE > 0.99, true);
%! assert_equal (COVERAGE <= 1, true);

%!test  # an explicitly closed outline is accepted
%! T = geom.triangulate ([0, 0; 1, 0; 1, 1; 0, 1; 0, 0]);
%! assert_equal (rows (T), 2);

%!error<geom.triangulate: invalid number of input arguments.> geom.triangulate ()
%!error<geom.triangulate: P must be a polygon with at least 3 vertices.> ...
%! geom.triangulate ([0, 0; 1, 1])
%!error<geom.triangulate: HOLES must be a cell array of vertex matrices.> ...
%! geom.triangulate ([0, 0; 1, 0; 1, 1], [0, 0; 1, 1; 2, 2])
%!error<geom.triangulate: hole 1: P must be a polygon with at least 3 vertices.> ...
%! geom.triangulate ([0, 0; 4, 0; 4, 4; 0, 4], {[1, 1; 2, 2]})
