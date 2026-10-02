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
## @deftypefn {drafting} {@var{S} =} solid.sweep (@var{R}, @var{PATH})
##
## A solid swept by a region along a path.
##
## @code{@var{S} = solid.sweep (@var{R}, @var{PATH})} returns a
## @code{solid.Shape} traced by the @code{geom.Region} @var{R} as it travels
## along the polyline @var{PATH}.  This is how a bent bar, a frame of welded
## sections or a pipe run is modelled; a hole in the region makes a tube.
##
## @var{PATH} is an @math{M}-by-3 matrix of points in model coordinates, with
## at least two rows.  At every intermediate point the path turns and the
## solid keeps a sharp corner, mitred as two sawn lengths are joined.  The path
## must not turn straight back on itself.
##
## The region is swept from where it lies.  Normally its plane passes through
## the first point of the path, square to the first segment; a region in the
## default @math{xy} plane is swept as drawn along a path that starts at the
## origin and runs up the @math{z} axis.  A region placed elsewhere is swept
## beside the path, keeping its distance, as a rail follows a centre line:
##
## @example
## @group
## ## A tube of 2 bore and 0.5 wall, bent twice, its section at the start
## ## of the path square to the first segment
## R = geom.Region ([1.5, 0, 1; -1.5, 0, 1], @{[1, 0, 1; -1, 0, 1]@});
## PATH = [0, 0, 0; 0, 0, 10; 10, 0, 20; 10, 0, 30];
## S = solid.sweep (R, PATH);
## @end group
## @end example
##
## A section centred on the path keeps its area through every mitred corner,
## so its volume is its area times the length of the path.  A section far off
## the path, or a corner too tight for it, makes a solid that intersects
## itself; check such a result with @code{solid.Shape.isvalid}.
##
## @seealso{geom.Region, solid.extrude, solid.helix}
## @end deftypefn

function S = sweep (R, PATH)

  ## Input validation
  if (nargin != 2)
    error ("solid.sweep: invalid number of input arguments.");
  endif
  [errmsg, D] = solid.__region__ (R, 'R');
  if (! isempty (errmsg))
    error ("solid.sweep: %s", errmsg);
  endif
  if (! isnumeric (PATH) || ! isreal (PATH) || ! ismatrix (PATH) ...
      || columns (PATH) != 3 || rows (PATH) < 2 || ! all (isfinite (PATH(:))))
    error (strcat ("solid.sweep: PATH must be an M-by-3 real matrix of", ...
                   " finite values with at least two rows."));
  endif
  PATH = double (PATH);
  V = diff (PATH);
  L = sqrt (sum (V .^ 2, 2));
  if (any (L == 0))
    error ("solid.sweep: PATH must not repeat a point consecutively.");
  endif
  U = V ./ L;
  if (any (sum (U(1:end-1,:) .* U(2:end,:), 2) <= -1 + 1e-12))
    error ("solid.sweep: PATH must not turn back on itself.");
  endif
  errmsg = solid.__checkocct__ ();
  if (! isempty (errmsg))
    error ("solid.sweep: %s", errmsg);
  endif

  S = solid.Shape (__occt__ ('sweep', 'solid.sweep', D, PATH));

endfunction

%!testif ; exist ('__occt__') == 3  # up the z axis, as extruded
%! R = geom.Region ([0, 0; 4, 0; 4, 2; 0, 2]);
%! S = solid.sweep (R, [0, 0, 0; 0, 0, 10]);
%! assert_equal (volume (S), 80, 1e-9);
%! assert_equal (bbox (S), [0, 0, 0, 4, 2, 10], 1e-9);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # along x, the region placed at the start
%! P = geom.Polyline ([-1, -1; 1, -1; 1, 1; -1, 1], 'Closed', true, ...
%!                    'Origin', [5, 5, 5], 'Normal', [1, 0, 0]);
%! S = solid.sweep (geom.Region (P), [5, 5, 5; 15, 5, 5]);
%! assert_equal (volume (S), 40, 1e-9);
%! assert_equal (bbox (S), [5, 4, 4, 15, 6, 6], 1e-9);

%!testif ; exist ('__occt__') == 3  # a mitred right angle
%! S = solid.sweep (geom.Region ([-1, -1; 1, -1; 1, 1; -1, 1]), ...
%!                  [0, 0, 0; 0, 0, 10; 10, 0, 10]);
%! assert_equal (volume (S), 80, 1e-9);
%! assert_equal (bbox (S), [-1, -1, 0, 10, 1, 11], 1e-9);
%! assert_equal (numfaces (S), 10);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # a round bar bent twice
%! S = solid.sweep (geom.Region ([1, 0, 1; -1, 0, 1]), ...
%!                  [0, 0, 0; 0, 0, 10; 10, 0, 20; 10, 0, 30]);
%! assert_equal (volume (S), pi * (20 + sqrt (200)), -1e-9);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # a tube bent twice, its bore carried
%! R = geom.Region ([1.5, 0, 1; -1.5, 0, 1], {[1, 0, 1; -1, 0, 1]});
%! S = solid.sweep (R, [0, 0, 0; 0, 0, 10; 10, 0, 20; 10, 0, 30]);
%! assert_equal (volume (S), (2.25 - 1) * pi * (20 + sqrt (200)), -1e-9);
%! assert_equal (isvalid (S), true);

%!error<solid.sweep: invalid number of input arguments.> ...
%! solid.sweep (geom.Region ([0, 0; 1, 0; 1, 1]))
%!error<solid.sweep: R must be a geom.Region object.> ...
%! solid.sweep ([0, 0; 1, 0; 1, 1], [0, 0, 0; 0, 0, 1])
%!error<solid.sweep: PATH must be an M-by-3 real matrix of finite values with at least two rows.> ...
%! solid.sweep (geom.Region ([0, 0; 1, 0; 1, 1]), [0, 0, 1])
%!error<solid.sweep: PATH must be an M-by-3 real matrix of finite values with at least two rows.> ...
%! solid.sweep (geom.Region ([0, 0; 1, 0; 1, 1]), [0, 0; 0, 1])
%!error<solid.sweep: PATH must be an M-by-3 real matrix of finite values with at least two rows.> ...
%! solid.sweep (geom.Region ([0, 0; 1, 0; 1, 1]), [0, 0, 0; 0, 0, NaN])
%!error<solid.sweep: PATH must not repeat a point consecutively.> ...
%! solid.sweep (geom.Region ([0, 0; 1, 0; 1, 1]), [0, 0, 0; 0, 0, 0; 0, 0, 1])
%!error<solid.sweep: PATH must not turn back on itself.> ...
%! solid.sweep (geom.Region ([0, 0; 1, 0; 1, 1]), [0, 0, 0; 0, 0, 5; 0, 0, 2])
