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

## Internal helper.  Hand a geom.Path to Open CASCADE.
##
## D is the struct __occt__ reads for a path, all in world coordinates: its
## vertices, the midpoints of its arcs, NaN for a segment that is not an arc,
## a cell with, for each spline segment, the control points of its cubic
## pieces and the parameters where they meet, its ends set on the vertices so
## that the wire closes exactly, and whether the path is closed.

function D = __path__ (P)

  V = toworld (P.UCS, P.Vertices);
  M = P.Midpoints;
  arc = ! isnan (M(:,1));
  M(arc,:) = toworld (P.UCS, M(arc,:));
  n = rows (V);
  C = cell (n, 1);
  for i = find (! cellfun (@isempty, P.Splines))'
    [B, t] = __bezier__ (P.Splines{i});
    B = toworld (P.UCS, B);
    B([1, end],:) = V([i, mod(i, n) + 1],:);
    C{i} = struct ('poles', B, 'knots', t);
  endfor
  D = struct ('vertices', V, 'midpoints', M, 'splines', {C}, ...
              'closed', P.Closed);

endfunction

%!test
%! U = geom.UCS ([0, 0, 1], [0, 0, 5]);
%! D = solid.__path__ (geom.Path ([0, 0; 10, 0], 'UCS', U));
%! assert_equal (D.vertices, [0, 0, 5; 10, 0, 5]);
%! assert_equal (D.splines, cell (2, 1));
%! assert_equal (D.closed, false);

%!test  # a closed spline, its control points from the vertex round to it
%! SP = geom.Spline ([0, 0; 10, 0; 5, 8], 'Closed', true);
%! D = solid.__path__ (geom.Path (SP));
%! assert_equal (D.vertices, [0, 0, 0]);
%! assert_equal (rows (D.splines{1}.poles), 10);
%! assert_equal (D.splines{1}.poles([1, end],:), [0, 0, 0; 0, 0, 0]);
