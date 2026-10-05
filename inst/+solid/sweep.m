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
## @deftypefn {drafting} {@var{S} =} solid.sweep (@var{R}, @var{P})
##
## A solid swept by a region along a path.
##
## @code{@var{S} = solid.sweep (@var{R}, @var{P})} returns a
## @code{solid.Shape} traced by the @code{geom.Region} @var{R} as it travels
## along the @code{geom.Path} @var{P}.  This is how a bent bar, a frame of
## welded sections or a pipe run is modelled; a hole in the region makes a
## tube.
##
## Along an arc or a spline of the path the solid bends smoothly.  Where two
## segments meet at an angle the solid keeps a sharp corner, mitred as two
## sawn lengths are joined; round such a corner with @code{geom.Path.fillet}
## for a bend.  A spline joined into a path meets its neighbours smoothly
## unless told not to, see @code{geom.Path.join}.  The path must not turn
## straight back on itself.  A closed path makes a ring.
##
## The region is swept from where it lies.  Normally its plane passes through
## the first point of the path, square to the path there; a region in the
## default @math{xy} plane is swept as drawn along a path that starts at the
## origin and runs up the @math{z} axis.  A region placed elsewhere is swept
## beside the path, keeping its distance, as a rail follows a centre line:
##
## @example
## @group
## ## A tube of 2 bore and 0.5 wall, bent twice with bends of radius 5
## R = geom.Region ([1.5, 0, 1; -1.5, 0, 1], @{[1, 0, 1; -1, 0, 1]@});
## P = geom.Path ([0, 0, 0; 0, 0, 20; 20, 0, 20; 20, 20, 20]);
## S = solid.sweep (R, fillet (P, 5));
## @end group
## @end example
##
## A section centred on the path keeps its area through every bend and every
## mitred corner, so its volume is its area times the length of the path.  A
## section far off the path, or a bend or corner too tight for it, makes a
## solid that intersects itself; check such a result with
## @code{solid.Shape.isvalid}.
##
## @seealso{geom.Path, geom.Spline, geom.Region, solid.extrude, solid.helix}
## @end deftypefn

function S = sweep (R, P)

  ## Input validation
  if (nargin != 2)
    error ("solid.sweep: invalid number of input arguments.");
  endif
  [errmsg, D] = solid.__region__ (R, 'R');
  if (! isempty (errmsg))
    error ("solid.sweep: %s", errmsg);
  endif
  if (! isa (P, 'geom.Path') || ! isscalar (P))
    error ("solid.sweep: P must be a geom.Path object.");
  endif
  [tin, tout] = __tangents__ (P);
  if (P.Closed)
    t = sum (tout .* tin([2:end, 1],:), 2);
  else
    t = sum (tout(1:end-1,:) .* tin(2:end,:), 2);
  endif
  if (any (t <= -1 + 1e-12))
    error ("solid.sweep: P must not turn back on itself.");
  endif


  S = solid.Shape (__occt__ ('sweep', 'solid.sweep', D, solid.__path__ (P)));

endfunction

%!test  # up the z axis, as extruded
%! R = geom.Region ([0, 0; 4, 0; 4, 2; 0, 2]);
%! S = solid.sweep (R, geom.Path ([0, 0, 0; 0, 0, 10]));
%! assert_equal (volume (S), 80, 1e-9);
%! assert_equal (bbox (S), [0, 0, 0, 4, 2, 10], 1e-9);
%! assert_equal (isvalid (S), true);

%!test  # along x, the region placed at the start
%! R = geom.Region ([-1, -1; 1, -1; 1, 1; -1, 1]);
%! R.UCS = geom.UCS ([1, 0, 0], [5, 5, 5]);
%! S = solid.sweep (R, geom.Path ([5, 5, 5; 15, 5, 5]));
%! assert_equal (volume (S), 40, 1e-9);
%! assert_equal (bbox (S), [5, 4, 4, 15, 6, 6], 1e-9);

%!test  # a path laid by its UCS
%! R = geom.Region ([-1, -1; 1, -1; 1, 1; -1, 1]);
%! R.UCS = geom.UCS ([1, 0, 0], [5, 5, 5]);
%! P = geom.Path ([0, 0, 0; 0, 0, 10], 'UCS', R.UCS);
%! S = solid.sweep (R, P);
%! assert_equal (bbox (S), [5, 4, 4, 15, 6, 6], 1e-9);

%!test  # a mitred right angle
%! S = solid.sweep (geom.Region ([-1, -1; 1, -1; 1, 1; -1, 1]), ...
%!                  geom.Path ([0, 0, 0; 0, 0, 10; 10, 0, 10]));
%! assert_equal (volume (S), 80, 1e-9);
%! assert_equal (bbox (S), [-1, -1, 0, 10, 1, 11], 1e-9);
%! assert_equal (numfaces (S), 10);
%! assert_equal (isvalid (S), true);

%!test  # a round bar bent twice
%! S = solid.sweep (geom.Region ([1, 0, 1; -1, 0, 1]), ...
%!                  geom.Path ([0, 0, 0; 0, 0, 10; 10, 0, 20; 10, 0, 30]));
%! assert_equal (volume (S), pi * (20 + sqrt (200)), -1e-9);
%! assert_equal (isvalid (S), true);

%!test  # a tube bent twice, its bore carried
%! R = geom.Region ([1.5, 0, 1; -1.5, 0, 1], {[1, 0, 1; -1, 0, 1]});
%! S = solid.sweep (R, geom.Path ([0, 0, 0; 0, 0, 10; 10, 0, 20; 10, 0, 30]));
%! assert_equal (volume (S), (2.25 - 1) * pi * (20 + sqrt (200)), -1e-9);
%! assert_equal (isvalid (S), true);

%!test  # a round bar with two bends
%! P = fillet (geom.Path ([0, 0, 0; 0, 0, 20; 20, 0, 20; 20, 20, 20]), 5);
%! S = solid.sweep (geom.Region ([1, 0, 1; -1, 0, 1]), P);
%! assert_equal (volume (S), pi * length (P), -1e-6);
%! assert_equal (numfaces (S), 12);
%! assert_equal (isvalid (S), true);

%!test  # a hairpin from a path joined of pieces
%! P = join (geom.Path ([0, 0, 0; 0, 0, 50]), ...
%!           geom.Path.arc ([0, 0, 50], [10, 0, 60], [20, 0, 50]), ...
%!           geom.Path ([20, 0, 50; 20, 0, 0]));
%! S = solid.sweep (geom.Region ([2, 0, 1; -2, 0, 1]), P);
%! assert_equal (volume (S), 4 * pi * (100 + 10 * pi), -1e-6);
%! assert_equal (bbox (S), [-2, -2, 0, 22, 2, 62], 1e-6);

%!test  # a ring round a rounded rectangle
%! P = fillet (geom.Path ([0, 0, 0; 40, 0, 0; 40, 20, 0; 0, 20, 0], ...
%!                        'Closed', true), 5);
%! R = geom.Region ([1, 0, 1; -1, 0, 1]);
%! R.UCS = geom.UCS ([0, -1, 0], P.Vertices(1,:));
%! S = solid.sweep (R, P);
%! assert_equal (volume (S), pi * length (P), -1e-6);
%! assert_equal (isvalid (S), true);

%!test  # along a spline joined smoothly to lines
%! P = join (geom.Path ([0, 0, 0; 0, 0, 10]), ...
%!           geom.Spline ([0, 0, 10; 5, 3, 20; 15, 0, 25; 25, 0, 25]), ...
%!           geom.Path ([25, 0, 25; 40, 0, 25]));
%! S = solid.sweep (geom.Region ([1, 0, 1; -1, 0, 1]), P);
%! assert_equal (volume (S), pi * length (P), -1e-4);
%! assert_equal (isvalid (S), true);
%! assert_equal (bbox (S)([3, 4]), [0, 40], 1e-6);

%!test  # a spline in a UCS of its own
%! SP = geom.Spline ([0, 0; 10, 10; 20, 0; 30, 10], ...
%!                   'Tangents', [0, 1, 0; 0, 1, 0]);
%! SP.UCS = geom.UCS ([0, -1, 0], [5, 0, 0]);
%! R = geom.Region ([1, 0, 1; -1, 0, 1]);
%! R.UCS = geom.UCS ([0, 0, 1], [5, 0, 0]);
%! S = solid.sweep (R, geom.Path (SP));
%! assert_equal (volume (S), pi * length (SP), -1e-4);
%! assert_equal (isvalid (S), true);

%!test  # a polyline's arc, swept from its start
%! U = geom.UCS ([0, -1, 0], [0, 0, 0]);
%! P = geom.Path (geom.Polyline ([0, 0, -tand(22.5); 10, 10, 0], 'UCS', U));
%! S = solid.sweep (geom.Region ([1, 0, 1; -1, 0, 1]), P);
%! assert_equal (volume (S), pi * 5 * pi, -1e-6);

%!test  # a section of a closed spline
%! R = geom.Region (geom.Spline ([-3, -2; 3, -2; 4, 2; 0, 4; -4, 2], ...
%!                               'Closed', true));
%! P = fillet (geom.Path ([0, 0, 0; 0, 0, 30; 30, 0, 30]), 10);
%! S = solid.sweep (R, P);
%! assert_equal (volume (S), __area__ (R.Outline) * length (P), -1e-9);
%! assert_equal (isvalid (S), true);

%!test  # round a closed spline path, a ring
%! P = geom.Path (geom.Spline ([0, 0; 40, -5; 50, 20; 20, 30; -5, 15], ...
%!                             'Closed', true));
%! tin = __tangents__ (P);
%! R = geom.Region ([1, 0, 1; -1, 0, 1]);
%! R.UCS = geom.UCS (tin(1,:), [0, 0, 0], [0, 0, 1]);
%! S = solid.sweep (R, P);
%! assert_equal (volume (S), pi * length (P), -1e-6);
%! assert_equal (isvalid (S), true);

%!test  # round a rational circle, a torus
%! w = sqrt (2) / 2;
%! C = [1, 0; 1, 1; 0, 1; -1, 1; -1, 0; -1, -1; 0, -1; 1, -1; 1, 0];
%! SP = geom.Spline.nurbs (10 * C, [0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 4], ...
%!                         [1, w, 1, w, 1, w, 1, w, 1]);
%! R = geom.Region ([1, 0, 1; -1, 0, 1]);
%! R.UCS = geom.UCS ([0, 1, 0], [10, 0, 0], [11, 0, 0]);
%! S = solid.sweep (R, geom.Path (SP));
%! assert_equal (volume (S), 2 * pi ^ 2 * 10, -1e-6);
%! assert_equal (isvalid (S), true);

%!error<solid.sweep: invalid number of input arguments.> ...
%! solid.sweep (geom.Region ([0, 0; 1, 0; 1, 1]))
%!error<solid.sweep: R must be a geom.Region object.> ...
%! solid.sweep ([0, 0; 1, 0; 1, 1], geom.Path ([0, 0, 0; 0, 0, 1]))
%!error<solid.sweep: P must be a geom.Path object.> ...
%! solid.sweep (geom.Region ([0, 0; 1, 0; 1, 1]), [0, 0, 0; 0, 0, 1])
%!error<solid.sweep: P must not turn back on itself.> ...
%! solid.sweep (geom.Region ([0, 0; 1, 0; 1, 1]), ...
%!              geom.Path ([0, 0, 0; 0, 0, 5; 0, 0, 2]))
%!error<solid.sweep: P must not turn back on itself.> ...
%! solid.sweep (geom.Region ([0, 0; 1, 0; 1, 1]), ...
%!              join (geom.Path.arc ([0, 0, 0], [5, 0, 5], [10, 0, 0]), ...
%!                    geom.Path ([10, 0, 0; 10, 0, 5])))
