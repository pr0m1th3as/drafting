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
## @deftypefn  {drafting} {@var{S} =} solid.sweep (@var{P}, @var{PATH})
## @deftypefnx {drafting} {@var{S} =} solid.sweep (@var{P}, @var{PATH}, @var{BULGE})
##
## A solid swept by a profile along a path.
##
## @code{@var{S} = solid.sweep (@var{P}, @var{PATH})} returns a
## @code{solid.Shape} traced by the closed profile @var{P} as it travels
## along the polyline @var{PATH}, keeping square to it.  This is how a bent
## bar, a frame of welded sections or a pipe run is modelled.
##
## @var{PATH} is an @math{M}-by-3 matrix of vertices in millimetres, with at
## least two rows.  At every intermediate vertex the path turns and the solid
## keeps a sharp corner, mitred as two sawn lengths are joined.  The path
## must not turn straight back on itself.
##
## @var{P} is an @math{N}-by-2 matrix of vertices in millimetres, drawn in
## the @math{xy} plane and closed implicitly from the last vertex back to the
## first; a repeated first vertex at the end is accepted and dropped.  It must
## enclose an area and must not cross or touch itself.  The profile is
## carried to the first vertex of the path, its origin landing there, and
## turned by the smallest rotation that takes the @math{z} axis onto the
## first segment.  A path that starts up the @math{z} axis therefore sweeps
## the profile as drawn, as @code{solid.extrude} does.
##
## @var{BULGE} gives one value per vertex of @var{P}, turning the segment
## that leaves that vertex into a circular arc, as in
## @code{draw.Drawing.polyline}: the tangent of a quarter of the arc's
## included angle, zero for a straight segment and 1 for a semicircle,
## positive for an arc that runs anticlockwise.
##
## A section centred on the path keeps its area through every mitred corner,
## so its volume is its area times the length of the path.  A section far off
## the path, or a corner too tight for it, makes a solid that intersects
## itself; check such a result with @code{solid.Shape.isvalid}.
##
## @example
## @group
## ## A round bar of diameter 2, bent twice
## P = [1, 0; -1, 0];
## PATH = [0, 0, 0; 0, 0, 10; 10, 0, 20; 10, 0, 30];
## S = solid.sweep (P, PATH, [1, 1]);
## volume (S)
## @result{} 107.26
## @end group
## @end example
##
## @seealso{solid.extrude, solid.helix, draw.Drawing.polyline}
## @end deftypefn

function S = sweep (P, PATH, BULGE = [])

  ## Input validation
  if (nargin < 2 || nargin > 3)
    error ("solid.sweep: invalid number of input arguments.");
  endif
  [errmsg, P, BULGE] = solid.__checkprofile__ (P, BULGE, 'P', 'BULGE');
  if (! isempty (errmsg))
    error ("solid.sweep: %s", errmsg);
  endif
  if (! isnumeric (PATH) || ! isreal (PATH) || ! ismatrix (PATH) ...
      || columns (PATH) != 3 || rows (PATH) < 2 || ! all (isfinite (PATH(:))))
    error (strcat ("solid.sweep: PATH must be an M-by-3 real matrix of", ...
                   " finite values with at least two rows."));
  endif
  PATH = double (PATH);
  D = diff (PATH);
  L = sqrt (sum (D .^ 2, 2));
  if (any (L == 0))
    error ("solid.sweep: PATH must not repeat a vertex consecutively.");
  endif
  U = D ./ L;
  if (any (sum (U(1:end-1,:) .* U(2:end,:), 2) <= -1 + 1e-12))
    error ("solid.sweep: PATH must not turn back on itself.");
  endif
  errmsg = solid.__checkocct__ ();
  if (! isempty (errmsg))
    error ("solid.sweep: %s", errmsg);
  endif

  S = solid.Shape (__occt__ ('sweep', 'solid.sweep', P, BULGE, PATH));

endfunction

%!testif ; exist ('__occt__') == 3  # up the z axis, as extruded
%! S = solid.sweep ([0, 0; 4, 0; 4, 2; 0, 2], [0, 0, 0; 0, 0, 10]);
%! assert_equal (volume (S), 80, 1e-9);
%! assert_equal (bbox (S), [0, 0, 0, 4, 2, 10], 1e-9);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # down the z axis, turned about x
%! S = solid.sweep ([0, 0; 4, 0; 4, 2; 0, 2], [0, 0, 0; 0, 0, -10]);
%! assert_equal (volume (S), 80, 1e-9);
%! assert_equal (bbox (S), [0, -2, -10, 4, 0, 0], 1e-9);

%!testif ; exist ('__occt__') == 3  # along x, from a point off the origin
%! S = solid.sweep ([-1, -1; 1, -1; 1, 1; -1, 1], [5, 5, 5; 15, 5, 5]);
%! assert_equal (volume (S), 40, 1e-9);
%! assert_equal (bbox (S), [5, 4, 4, 15, 6, 6], 1e-9);

%!testif ; exist ('__occt__') == 3  # a mitred right angle
%! S = solid.sweep ([-1, -1; 1, -1; 1, 1; -1, 1], ...
%!                  [0, 0, 0; 0, 0, 10; 10, 0, 10]);
%! assert_equal (volume (S), 80, 1e-9);
%! assert_equal (bbox (S), [-1, -1, 0, 10, 1, 11], 1e-9);
%! assert_equal (numfaces (S), 10);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # a round bar bent twice
%! S = solid.sweep ([1, 0; -1, 0], ...
%!                  [0, 0, 0; 0, 0, 10; 10, 0, 20; 10, 0, 30], [1, 1]);
%! assert_equal (volume (S), pi * (20 + sqrt (200)), -1e-9);
%! assert_equal (isvalid (S), true);

%!error<solid.sweep: invalid number of input arguments.> ...
%! solid.sweep ([0, 0; 1, 0; 1, 1])
%!error<solid.sweep: P must enclose a nonzero area.> ...
%! solid.sweep ([0, 0; 1, 0; 2, 0], [0, 0, 0; 0, 0, 1])
%!error<solid.sweep: PATH must be an M-by-3 real matrix of finite values with at least two rows.> ...
%! solid.sweep ([0, 0; 1, 0; 1, 1], [0, 0, 1])
%!error<solid.sweep: PATH must be an M-by-3 real matrix of finite values with at least two rows.> ...
%! solid.sweep ([0, 0; 1, 0; 1, 1], [0, 0; 0, 1])
%!error<solid.sweep: PATH must be an M-by-3 real matrix of finite values with at least two rows.> ...
%! solid.sweep ([0, 0; 1, 0; 1, 1], [0, 0, 0; 0, 0, NaN])
%!error<solid.sweep: PATH must not repeat a vertex consecutively.> ...
%! solid.sweep ([0, 0; 1, 0; 1, 1], [0, 0, 0; 0, 0, 0; 0, 0, 1])
%!error<solid.sweep: PATH must not turn back on itself.> ...
%! solid.sweep ([0, 0; 1, 0; 1, 1], [0, 0, 0; 0, 0, 5; 0, 0, 2])
