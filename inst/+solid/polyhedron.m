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
## @deftypefn  {drafting} {@var{S} =} solid.polyhedron (@var{M})
## @deftypefnx {drafting} {@var{S} =} solid.polyhedron (@var{M}, 'Merge', @var{TF})
##
## A solid bounded by a closed triangle mesh.
##
## @code{@var{S} = solid.polyhedron (@var{M})} returns the
## @code{solid.Shape} enclosed by the triangles of the @code{polymesh.Mesh}
## @var{M}.  The solid takes part in booleans as any other, so a scanned or
## downloaded part can be cut, joined and measured.  This is OpenSCAD's
## @code{polyhedron}.  Vertices and faces in any other form, such as the
## struct @code{isosurface} returns, become a mesh first through the
## @code{polymesh.Mesh} constructor.
##
## The mesh must be closed, every edge shared by exactly two triangles, or it
## is an error that says how many edges are not.  Points that are equal are
## one vertex, and a triangle with no area is left out.  The triangles need
## not be turned the same way: each is turned to agree with its neighbours,
## and each closed piece of the mesh outwards.  A piece lying inside another
## and turned inwards, against it, is a void in it.  Pieces that overlap are
## united, as by @code{union}, and pieces apart are separate solids of one
## shape, counted by @code{solid.Shape.numsolids}.
##
## By default, triangles that lie in one plane and meet are merged into one
## face, so a box meshed with twelve triangles has six faces.  With
## @qcode{'Merge'} set to @code{false} every triangle stays a face.
##
## @example
## @group
## ## A tetrahedron with a corner cut away
## V = [0, 0, 0; 10, 0, 0; 0, 10, 0; 0, 0, 10];
## F = [1, 3, 2; 1, 2, 4; 2, 3, 4; 3, 1, 4];
## S = subtract (solid.polyhedron (polymesh.Mesh (V, F)), solid.sphere (3));
## @end group
## @end example
##
## @seealso{polymesh.Mesh, polymesh.read, solid.read, solid.Shape}
## @end deftypefn

function S = polyhedron (M, varargin)

  ## Input validation
  if (nargin < 1 || nargin > 3)
    error ("solid.polyhedron: invalid number of input arguments.");
  endif
  if (! isa (M, 'polymesh.Mesh') || ! isscalar (M))
    error ("solid.polyhedron: M must be a polymesh.Mesh object.");
  endif
  merge = true;
  if (! isempty (varargin))
    if (numel (varargin) != 2)
      error ("solid.polyhedron: Name/Value arguments must come in pairs.");
    endif
    if (! ischar (varargin{1}) || ! strcmp (varargin{1}, 'Merge'))
      error ("solid.polyhedron: unknown parameter.");
    endif
    merge = varargin{2};
    if (! (islogical (merge) || isnumeric (merge)) || ! isscalar (merge) ||
        ! any (merge == [0, 1]))
      error ("solid.polyhedron: Merge must be true or false.");
    endif
  endif
  errmsg = solid.__checkocct__ ();
  if (! isempty (errmsg))
    error ("solid.polyhedron: %s", errmsg);
  endif

  ## Points that are equal are one vertex
  [V, ~, j] = unique (M.Vertices, 'rows');
  F = reshape (j(M.Faces), size (M.Faces));
  S = solid.Shape (__occt__ ('polyhedron', 'solid.polyhedron', V, F, ...
                             logical (merge)));

endfunction

## A box from the origin to P meshed, its triangles turned outwards
%!function [V, F] = boxmesh (P)
%!  V = [0, 0, 0; 1, 0, 0; 1, 1, 0; 0, 1, 0; 0, 0, 1; 1, 0, 1; 1, 1, 1; ...
%!       0, 1, 1] .* P;
%!  F = [1, 3, 2; 1, 4, 3; 5, 6, 7; 5, 7, 8; 1, 2, 6; 1, 6, 5; ...
%!       2, 3, 7; 2, 7, 6; 3, 4, 8; 3, 8, 7; 4, 1, 5; 4, 5, 8];
%!endfunction
## A grid of N by M cells with its rows and columns wrapped round, a torus,
## or with each column flipped as it wraps, a Klein bottle
%!function [V, F] = wrapped (N, M, R, r, flip)
%!  [u, v] = ndgrid (2 * pi * (0:N-1) / N, 2 * pi * (0:M-1) / M);
%!  V = [(R + r * cos(v(:))) .* cos(u(:)), ...
%!       (R + r * cos(v(:))) .* sin(u(:)), r * sin(v(:))];
%!  id = @(i, j) mod (i, N) + N * mod (j, M) + 1;
%!  [i, j] = ndgrid (0:N-1, 0:M-1);
%!  last = flip & (i == N - 1);
%!  jj = j .* (1 - 2 * last);
%!  a = id (i, j);
%!  b = id (i + 1, jj);
%!  c = id (i + 1, jj + 1 - 2 * last);
%!  d = id (i, j + 1);
%!  F = [a(:), b(:), c(:); a(:), c(:), d(:)];
%!endfunction
## The volume a closed mesh turned outwards encloses
%!function vol = meshvolume (V, F)
%!  vol = sum (dot (V(F(:,1),:), cross (V(F(:,2),:), V(F(:,3),:), 2), 2)) / 6;
%!endfunction

%!testif ; exist ('__occt__') == 3  # a box, its coplanar triangles merged
%! [V, F] = boxmesh ([10, 20, 30]);
%! S = solid.polyhedron (polymesh.Mesh (V, F));
%! assert_equal (volume (S), 6000, -1e-12);
%! assert_equal (numfaces (S), 6);
%! assert_equal (isvalid (S), true);
%! S = solid.polyhedron (polymesh.Mesh (V, F), 'Merge', false);
%! assert_equal (numfaces (S), 12);
%! assert_equal (bbox (S), [0, 0, 0, 10, 20, 30], 1e-12);

%!testif ; exist ('__occt__') == 3  # triangles turned anyhow
%! [V, F] = boxmesh ([10, 10, 10]);
%! F([2, 5, 9],:) = F([2, 5, 9], [1, 3, 2]);
%! S = solid.polyhedron (polymesh.Mesh (V, F));
%! assert_equal (volume (S), 1000, -1e-12);
%! S = solid.polyhedron (polymesh.Mesh (V, F(:,[1, 3, 2])));
%! assert_equal (volume (S), 1000, -1e-12);

%!testif ; exist ('__occt__') == 3  # equal points welded, flat ones dropped
%! [V, F] = boxmesh ([1, 1, 1]);
%! W = V(F',:);
%! S = solid.polyhedron (polymesh.Mesh (W, [reshape(1:36, 3, [])'; 1, 1, 2]));
%! assert_equal (volume (S), 1, -1e-12);

%!testif ; exist ('__occt__') == 3  # a piece inside another turned in is a void
%! [V, F] = boxmesh ([10, 10, 10]);
%! S = solid.polyhedron (polymesh.Mesh ([V; V / 2 + 2.5], ...
%!                                    [F; F(:,[1, 3, 2]) + 8]));
%! assert_equal (volume (S), 875, -1e-12);
%! assert_equal (numsolids (S), 1);
%! S = solid.polyhedron (polymesh.Mesh ([V; V + 20], [F; F + 8]));
%! assert_equal (volume (S), 2000, -1e-12);
%! assert_equal (numsolids (S), 2);

%!testif ; exist ('__occt__') == 3  # pieces that overlap are united
%! [V, F] = boxmesh ([10, 10, 10]);
%! S = solid.polyhedron (polymesh.Mesh ([V; V + 5], [F; F + 8]));
%! assert_equal (volume (S), 1875, -1e-12);
%! assert_equal (numsolids (S), 1);
%! assert_equal (isvalid (S), true);
%! S = solid.polyhedron (polymesh.Mesh ([V; V + 5], [F; F + 8]), ...
%!                       'Merge', false);
%! assert_equal (volume (S), 1875, -1e-12);
%! S = solid.polyhedron (polymesh.Mesh ([V; V / 2 + 2.5], [F; F + 8]));
%! assert_equal (volume (S), 1000, -1e-12);
%! assert_equal (numsolids (S), 1);
%! assert_equal (numfaces (S), 6);

%!testif ; exist ('__occt__') == 3  # a torus, cut by a box
%! [V, F] = wrapped (48, 24, 20, 5, false);
%! S = solid.polyhedron (polymesh.Mesh (V, F));
%! assert_equal (volume (S), abs (meshvolume (V, F)), -1e-9);
%! assert_equal (numfaces (S), rows (F) / 2);  # each cell a flat quad
%! T = intersect (S, translate (solid.box (40, 40, 20), [0, 0, -10]));
%! assert_equal (isvalid (T), true);
%! assert_equal (volume (T), volume (S) / 4, -1e-9);

%!error<solid.polyhedron: invalid number of input arguments.> ...
%! solid.polyhedron ()
%!error<solid.polyhedron: invalid number of input arguments.> ...
%! solid.polyhedron (polymesh.Mesh (), 'Merge', true, 1)
%!error<solid.polyhedron: M must be a polymesh.Mesh object.> ...
%! solid.polyhedron (eye (3))
%!error<solid.polyhedron: M must be a polymesh.Mesh object.> ...
%! solid.polyhedron (struct ('vertices', eye (3), 'faces', [1, 2, 3]))
%!error<solid.polyhedron: Name/Value arguments must come in pairs.> ...
%! solid.polyhedron (polymesh.Mesh (eye (3), [1, 2, 3]), 'Merge')
%!error<solid.polyhedron: unknown parameter.> ...
%! solid.polyhedron (polymesh.Mesh (eye (3), [1, 2, 3]), 'Weld', true)
%!error<solid.polyhedron: Merge must be true or false.> ...
%! solid.polyhedron (polymesh.Mesh (eye (3), [1, 2, 3]), 'Merge', 2)
%!error<solid.polyhedron: the mesh has no triangles.> ...
%! solid.polyhedron (polymesh.Mesh ())
%!error<solid.polyhedron: the mesh is not closed: 3 edges belong to one triangle only.> ...
%! solid.polyhedron (polymesh.Mesh (eye (3), [1, 2, 3]))
%!error<solid.polyhedron: the mesh is not manifold: 1 edge belongs to more than two triangles.>
%! [V, F] = boxmesh ([10, 10, 10]);
%! solid.polyhedron (polymesh.Mesh ([V; 5, 5, 20], [F; 5, 6, 9; 6, 5, 9]));
%!error<solid.polyhedron: the mesh is one-sided, as a Klein bottle, and encloses no volume.>
%! [V, F] = wrapped (8, 6, 20, 5, true);
%! solid.polyhedron (polymesh.Mesh (V, F));
