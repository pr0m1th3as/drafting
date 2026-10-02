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
## @deftypefn  {drafting} {@var{S} =} solid.revolve (@var{R})
## @deftypefnx {drafting} {@var{S} =} solid.revolve (@var{R}, @var{ANGLE})
##
## A solid of revolution, turned from a region about its own axis.
##
## @code{@var{S} = solid.revolve (@var{R})} returns a @code{solid.Shape} swept
## by the @code{geom.Region} @var{R} turning once about the @math{y} axis of
## its plane, through the plane's origin.  The region is the half section of
## the part, its @math{x} coordinate the radius and its @math{y} coordinate the
## position along the axis, as a turned part is drawn.  This is how a shaft, a
## bush, a pulley or a knob is modelled.  A hole in the region becomes a
## closed ring-shaped cavity.
##
## A region in the default @math{xy} plane turns about the model's @math{y}
## axis.  For a part along @math{z}, draw the region in the @math{xz} plane,
## whose @math{y} axis is the model's @math{z} axis:
##
## @example
## @group
## ## A shaft of diameter 20 stepping down to 12, a 1 mm chamfer at its end
## R = geom.Region ([0, 0; 10, 0; 10, 30; 6, 30; 6, 49; 5, 50; 0, 50]);
## R.UCS = geom.UCS ([0, -1, 0], [0, 0, 0]);   # the xz plane: y is world z
## S = solid.revolve (R);
## volume (S)
## @result{} 1.1669e+04
## @end group
## @end example
##
## The region must lie on one side of its axis: no point of it, along its
## arcs too, at a negative @math{x}.  It may run along the axis, as the
## section of a solid shaft does.  Arcs turn into true tori and spheres, so a
## radiused shoulder or a ball end is exact.
##
## @code{@var{S} = solid.revolve (@var{R}, @var{ANGLE})} turns the region
## through @var{ANGLE} degrees only, anticlockwise seen from the tip of the
## axis, starting from the region's plane.  @var{ANGLE} is in the range
## @math{(0, 360]}, and 360 is the default.
##
## @seealso{geom.Region, solid.extrude, solid.helix}
## @end deftypefn

function S = revolve (R, ANGLE = 360)

  ## Input validation
  if (nargin < 1 || nargin > 2)
    error ("solid.revolve: invalid number of input arguments.");
  endif
  [errmsg, D] = solid.__region__ (R, 'R');
  if (isempty (errmsg))
    Q = geom.__sample__ (D.outline);
    if (min (Q(:,1)) < -1e-9 * max (abs (Q(:))))
      errmsg = strcat ("R must lie on one side of its axis: no point of", ...
                       " it may have a negative x.");
    endif
  endif
  if (isempty (errmsg) && (! isnumeric (ANGLE) || ! isreal (ANGLE) ...
                           || ! isscalar (ANGLE) || ! (ANGLE > 0) ...
                           || ! (ANGLE <= 360)))
    errmsg = "ANGLE must be a real scalar in the range (0, 360].";
  endif
  if (isempty (errmsg))
    errmsg = solid.__checkocct__ ();
  endif
  if (! isempty (errmsg))
    error ("solid.revolve: %s", errmsg);
  endif

  S = solid.Shape (__occt__ ('revolve', 'solid.revolve', D, double (ANGLE)));

endfunction

%!testif ; exist ('__occt__') == 3  # a cylinder about the model's y axis
%! S = solid.revolve (geom.Region ([0, 0; 4, 0; 4, 12; 0, 12]));
%! assert_equal (volume (S), 192 * pi, 1e-9);
%! assert_equal (bbox (S), [-4, 0, -4, 4, 12, 4], 1e-9);
%! assert_equal (numfaces (S), 3);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # in the xz plane, about the z axis
%! R = geom.Region ([0, 0; 4, 0; 4, 12; 0, 12]);
%! R.UCS = geom.UCS ([0, -1, 0], [0, 0, 0]);
%! S = solid.revolve (R);
%! assert_equal (bbox (S), [-4, -4, 0, 4, 4, 12], 1e-9);

%!testif ; exist ('__occt__') == 3  # a stepped shaft with a chamfer
%! R = geom.Region ([0, 0; 10, 0; 10, 30; 6, 30; 6, 49; 5, 50; 0, 50]);
%! S = solid.revolve (R);
%! assert_equal (volume (S), pi * (3000 + 36 * 19 + (36 + 30 + 25) / 3), 1e-9);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # a bush, clear of the axis
%! S = solid.revolve (geom.Region ([5, 0; 8, 0; 8, 10; 5, 10]));
%! assert_equal (volume (S), pi * (64 - 25) * 10, 1e-9);
%! assert_equal (numfaces (S), 4);

%!testif ; exist ('__occt__') == 3  # a quarter turn, anticlockwise about y
%! S = solid.revolve (geom.Region ([0, 0; 4, 0; 4, 12; 0, 12]), 90);
%! assert_equal (volume (S), 48 * pi, 1e-9);
%! assert_equal (bbox (S), [0, 0, -4, 4, 12, 0], 1e-9);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # a sphere from a semicircle on the axis
%! S = solid.revolve (geom.Region ([0, -5, 1; 0, 5, 0]));
%! assert_equal (volume (S), 4 / 3 * pi * 125, 1e-9);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # a hollow ring, by Pappus
%! R = geom.Region ([8, -2; 12, -2; 12, 2; 8, 2], {[9, 0, 1; 11, 0, 1]});
%! S = solid.revolve (R);
%! assert_equal (volume (S), (16 - pi) * 2 * pi * 10, 1e-9);
%! assert_equal (isvalid (S), true);

%!error<solid.revolve: invalid number of input arguments.> solid.revolve ()
%!error<solid.revolve: R must be a geom.Region object.> ...
%! solid.revolve ([0, 0; 1, 0; 1, 1])
%!error<solid.revolve: R must lie on one side of its axis: no point of it may have a negative x.> ...
%! solid.revolve (geom.Region ([-1, 0; 1, 0; 1, 1; -1, 1]))
%!error<solid.revolve: R must lie on one side of its axis: no point of it may have a negative x.> ...
%! solid.revolve (geom.Region ([1, 0, -1; 1, 10, 0]))
%!error<solid.revolve: ANGLE must be a real scalar in the range \(0, 360\].> ...
%! solid.revolve (geom.Region ([0, 0; 1, 0; 1, 1]), 0)
%!error<solid.revolve: ANGLE must be a real scalar in the range \(0, 360\].> ...
%! solid.revolve (geom.Region ([0, 0; 1, 0; 1, 1]), 361)
%!error<solid.revolve: ANGLE must be a real scalar in the range \(0, 360\].> ...
%! solid.revolve (geom.Region ([0, 0; 1, 0; 1, 1]), NaN)
%!error<solid.revolve: ANGLE must be a real scalar in the range \(0, 360\].> ...
%! solid.revolve (geom.Region ([0, 0; 1, 0; 1, 1]), [90, 180])
