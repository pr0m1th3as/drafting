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
## @deftypefn  {drafting} {@var{R} =} polymesh.section (@var{M}, @var{U})
## @deftypefnx {drafting} {@var{R} =} polymesh.section (@var{M}, @var{U}, @qcode{'Tolerance'}, @var{T})
## @deftypefnx {drafting} {[@var{R}, @var{OPEN}] =} polymesh.section (@dots{})
##
## Cut a triangle mesh with a plane.
##
## @code{@var{R} = polymesh.section (@var{M}, @var{U})} cuts the mesh
## @var{M}, a struct with the fields @code{vertices} and @code{faces} as
## @code{polymesh.read} returns it, with the plane of the @code{geom.UCS}
## @var{U}, and returns the cut as @code{solid.Shape.section} returns the cut
## of a solid: a 1-by-@math{N} cell array of @code{geom.Region} objects in
## @var{U}, one for each separate piece, largest first, each an outline with
## the holes in it, or the empty @code{cell (1, 0)} when the cut has no area.
## A face of the mesh lying in the plane is part of the cut.
##
## The cut of a mesh is a polygon, and the regions are made of straight
## segments, exact for the mesh: a round hole in a mesh is a polygon of its
## facets.  The triangles may be turned either way, inwards or outwards,
## which many files get wrong; outlines and holes are told apart by how they
## nest.  @code{geom.Region.fit} turns the polygon back into lines, arcs and
## splines within a tolerance, so that a faceted bore is a circle again.
##
## @code{@var{R} = polymesh.section (@var{M}, @var{U}, @qcode{'Tolerance'},
## @var{T})} heals a mesh with gaps: where the cut through it breaks off, ends
## closer than @var{T} are joined, nearest first, and points of the cut
## closer than @var{T} are taken as one.  The default @var{T} is a millionth
## of the size of the mesh, which joins nothing but rounding.
##
## @code{[@var{R}, @var{OPEN}] = polymesh.section (@dots{})} returns in
## @var{OPEN} what could not be made into regions, as a cell array of
## @math{N}-by-2 polylines in the coordinates of @var{U}: chains that still
## break off, where the mesh has a hole wider than @var{T}, and loops that
## cross themselves or one another, where the mesh does.  A closed loop repeats its
## first point at its end.
##
## @example
## @group
## ## A slice half way up a part, healed where it was saved with gaps
## M = polymesh.read ('part.stl');
## [R, OPEN] = polymesh.section (M, geom.UCS ([0, 0, 1], [0, 0, 12]), ...
##                               'Tolerance', 0.01);
## @end group
## @end example
##
## @seealso{polymesh.read, solid.Shape.section, geom.Region, geom.Region.fit}
## @end deftypefn

function [R, OPEN] = section (M, U, varargin)

  ## Input validation
  if (nargin != 2 && nargin != 4)
    error ("polymesh.section: invalid number of input arguments.");
  endif
  if (! isstruct (M) || ! isscalar (M) || ! isfield (M, 'vertices') ...
      || ! isfield (M, 'faces') || ! ismesh (M.vertices, M.faces))
    error (strcat ("polymesh.section: M must be a mesh struct with", ...
                   " vertices, an N-by-3 matrix, and faces, a K-by-3", ...
                   " matrix of indices into them."));
  endif
  if (! isa (U, 'geom.UCS') || ! isscalar (U))
    error ("polymesh.section: U must be a geom.UCS object.");
  endif
  V = double (M.vertices);
  T = 1e-6 * norm (max (V, [], 1) - min (V, [], 1));
  if (nargin == 4)
    if (! ischar (varargin{1}) || ! strcmp (varargin{1}, 'Tolerance'))
      error ("polymesh.section: unknown parameter.");
    endif
    T = varargin{2};
    if (! isnumeric (T) || ! isreal (T) || ! isscalar (T) || ! isfinite (T) ...
        || T < 0)
      error (strcat ("polymesh.section: Tolerance must be a non-negative", ...
                     " finite real scalar."));
    endif
  endif

  R = cell (1, 0);
  OPEN = cell (1, 0);
  if (isempty (M.faces))
    return;
  endif
  L = (V - U.Origin) * [U.XAxis; U.YAxis; U.Normal]';
  [P, OPEN] = __mesh__ ('section', 'polymesh.section', L, double (M.faces), ...
                        double (T));
  R = cell (1, numel (P));
  for k = 1:numel (P)
    R{k} = __trusted__ (geom.Region ([0, 0; 1, 0; 0, 1]), P{k}.outline, ...
                        P{k}.holes);
    R{k}.UCS = U;
  endfor

endfunction

## True for N-by-3 finite real vertices and K-by-3 faces indexing them
function TF = ismesh (V, F)

  TF = isnumeric (V) && isreal (V) && ismatrix (V) && columns (V) == 3 ...
       && all (isfinite (V(:))) && isnumeric (F) && isreal (F) ...
       && ismatrix (F) && columns (F) == 3 && all (F(:) == fix (F(:))) ...
       && all (F(:) >= 1) && all (F(:) <= rows (V));

endfunction

## A prism over the anticlockwise polygon P, its caps the triangles T, from
## z = 0 to z = H, its triangles turned outwards, for the tests
%!function M = prism (P, T, H)
%!  n = rows (P);
%!  V = [P, zeros(n, 1); P, H * ones(n, 1)];
%!  i = (1:n)';
%!  j = [2:n, 1]';
%!  F = [T(:,[1, 3, 2]); T + n; i, j, j + n; i, j + n, i + n];
%!  M = struct ('vertices', V, 'faces', F);
%!endfunction
%!function M = torus (N, R, r)
%!  [u, v] = ndgrid ((0:N-1) / N * 2 * pi);
%!  V = [(R + r * cos(v(:))) .* cos(u(:)), (R + r * cos(v(:))) .* sin(u(:)), ...
%!       r * sin(v(:))];
%!  id = reshape (1:N*N, N, N);
%!  a = id;
%!  b = circshift (id, -1, 1);
%!  c = circshift (id, -1, 2);
%!  d = circshift (b, -1, 2);
%!  M = struct ('vertices', V, 'faces', [a(:), b(:), d(:); a(:), d(:), c(:)]);
%!endfunction

%!test  # a box cut through the middle
%! M = prism ([0, 0; 10, 0; 10, 20; 0, 20], [1, 2, 3; 1, 3, 4], 30);
%! U = geom.UCS ([0, 0, 1], [0, 0, 15]);
%! R = polymesh.section (M, U);
%! assert_equal (numel (R), 1);
%! assert_equal (R{1}.UCS, U);
%! assert_equal (__area__ (R{1}.Outline), 200, 1e-9);
%! assert_equal (rows (R{1}.Outline.Vertices), 4);

%!test  # a face in the plane is the cut, below the mesh or above it
%! M = prism ([0, 0; 10, 0; 10, 20; 0, 20], [1, 2, 3; 1, 3, 4], 30);
%! R = polymesh.section (M, geom.UCS ([0, 0, 1], [0, 0, 0]));
%! assert_equal (__area__ (R{1}.Outline), 200, 1e-9);
%! R = polymesh.section (M, geom.UCS ([0, 0, 1], [0, 0, 30]));
%! assert_equal (__area__ (R{1}.Outline), 200, 1e-9);

%!test  # a face in the plane and a cut, one piece
%! P = [0, 0; 30, 0; 30, 5; 5, 5; 5, 20; 0, 20];
%! M = prism (P, [1, 2, 3; 1, 3, 4; 1, 4, 6; 4, 5, 6], 10);
%! R = polymesh.section (M, geom.UCS ([0, 1, 0], [0, 5, 0]));
%! assert_equal (numel (R), 1);
%! assert_equal (__area__ (R{1}.Outline), 300, 1e-9);

%!test  # missed, or touched along an edge
%! M = prism ([0, 0; 10, 0; 10, 20; 0, 20], [1, 2, 3; 1, 3, 4], 30);
%! R = polymesh.section (M, geom.UCS ([0, 0, 1], [0, 0, 31]));
%! assert_equal (R, cell (1, 0));
%! R = polymesh.section (M, geom.UCS ([1, 1, 0], [0, 0, 0]));
%! assert_equal (R, cell (1, 0));

%!test  # a torus through a ring of its vertices: an outline and a hole
%! N = 48;
%! R = polymesh.section (torus (N, 10, 2), geom.UCS ([0, 0, 1], [0, 0, 0]));
%! assert_equal (numel (R), 1);
%! assert_equal (numel (R{1}.Holes), 1);
%! A = @(r) N / 2 * r ^ 2 * sin (2 * pi / N);
%! assert_equal (__area__ (R{1}.Outline), A (12), 1e-9);
%! assert_equal (__area__ (R{1}.Holes{1}), -A (8), 1e-9);

%!test  # separate pieces, largest first; triangles turned either way
%! P = [0, 0; 30, 0; 30, 20; 25, 20; 25, 5; 10, 5; 10, 20; 0, 20];
%! T = [1, 2, 5; 2, 3, 4; 2, 4, 5; 1, 5, 6; 1, 6, 7; 1, 7, 8];
%! M = prism (P, T, 10);
%! U = geom.UCS ([0, 1, 0], [0, 10, 0]);
%! R = polymesh.section (M, U);
%! A = cellfun (@(r) abs (__area__ (r.Outline)), R);
%! assert_equal (A, [100, 50], 1e-9);
%! M.faces(1:2:end,:) = fliplr (M.faces(1:2:end,:));
%! R = polymesh.section (M, U);
%! assert_equal (cellfun (@(r) abs (__area__ (r.Outline)), R), [100, 50], 1e-9);

%!test  # cracks, joined within a tolerance, or left open
%! M = prism ([0, 0; 10, 0; 10, 20; 0, 20], [1, 2, 3; 1, 3, 4], 30);
%! M.vertices(end+1,:) = M.vertices(7,:) + [1e-4, 0, 0];
%! k = find (any (M.faces == 7, 2) & any (M.faces == 3, 2), 1);
%! M.faces(k, M.faces(k,:) == 7) = 9;
%! U = geom.UCS ([0, 0, 1], [0, 0, 15]);
%! [R, OPEN] = polymesh.section (M, U, 'Tolerance', 0);
%! assert_equal (R, cell (1, 0));
%! assert_equal (numel (OPEN), 2);
%! [R, OPEN] = polymesh.section (M, U, 'Tolerance', 1e-3);
%! assert_equal (numel (R), 1);
%! assert_equal (OPEN, cell (1, 0));
%! assert_equal (__area__ (R{1}.Outline), 200, 2e-3);

%!test  # a cylinder of 64 facets cut, and fitted back into a circle
%! a = (0:63)' * 2 * pi / 64;
%! T = [ones(62, 1), (2:63)', (3:64)'];
%! M = prism ([10 * cos(a), 10 * sin(a)], T, 20);
%! R = polymesh.section (M, geom.UCS ([0, 0, 1], [0, 0, 7]));
%! assert_equal (rows (R{1}.Outline.Vertices), 64);
%! F = fit (R{1});
%! assert_equal (rows (F.Outline.Vertices), 2);
%! assert_equal (__area__ (F.Outline), 100 * pi, 1e-9);
%! assert_equal (F.UCS, R{1}.UCS);

%!error<polymesh.section: invalid number of input arguments.> polymesh.section (1)
%!error<polymesh.section: M must be a mesh struct with vertices, an N-by-3 matrix, and faces, a K-by-3 matrix of indices into them.> ...
%! polymesh.section (struct ('vertices', [0, 0, 0], 'faces', [1, 2, 3]), ...
%!                   geom.UCS ())
%!error<polymesh.section: M must be a mesh struct with vertices, an N-by-3 matrix, and faces, a K-by-3 matrix of indices into them.> ...
%! polymesh.section ([0, 0, 0], geom.UCS ())
%!error<polymesh.section: U must be a geom.UCS object.> ...
%! polymesh.section (struct ('vertices', zeros (0, 3), ...
%!                          'faces', zeros (0, 3)), 1)
%!error<polymesh.section: unknown parameter.> ...
%! polymesh.section (struct ('vertices', zeros (0, 3), ...
%!                          'faces', zeros (0, 3)), geom.UCS (), 'Heal', 1)
%!error<polymesh.section: Tolerance must be a non-negative finite real scalar.> ...
%! polymesh.section (struct ('vertices', zeros (0, 3), ...
%!                          'faces', zeros (0, 3)), ...
%!                   geom.UCS (), 'Tolerance', NaN)
