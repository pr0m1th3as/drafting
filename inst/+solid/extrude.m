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
## @deftypefn  {drafting} {@var{S} =} solid.extrude (@var{R}, @var{H})
## @deftypefnx {drafting} {@var{S} =} solid.extrude (@var{R}, @var{H}, @var{Name}, @var{Value}, @dots{})
##
## A solid extruded from a region.
##
## @code{@var{S} = solid.extrude (@var{R}, @var{H})} returns a
## @code{solid.Shape} whose section is the @code{geom.Region} @var{R},
## extruded from the region's plane square to it.  This is how a plate of any
## outline, a bracket or a key is modelled: draw its outline, then give it a
## thickness.  The holes of the region go right through, and its arcs become
## true circular edges and cylindrical faces.
##
## @var{H} says how far, in millimetres, and which way:
##
## @table @asis
## @item a positive scalar
## along the normal of the region's @code{geom.UCS};
## @item a negative scalar
## against it, the same distance the other way;
## @item @code{[@var{H1}, @var{H2}]}, both positive
## to both sides of the plane, @var{H1} along the normal and @var{H2} against
## it, so @code{[5, 5]} is centred on the plane.
## @end table
##
## A region in the default @math{xy} plane rises along @math{+z}; a region on
## the plane of a sloping face rises square to the face.
##
## Name/Value pairs:
##
## @table @asis
## @item @qcode{'Taper'}
## The angle in degrees by which the walls lean inwards as they leave the
## region's plane, the draft of a casting or a moulding: one angle for every
## side, or @code{[@var{A1}, @var{A2}]} for the two sides of an extrusion to
## both sides, each in the range @math{(-90, 90)}.  A negative angle leans
## the walls outwards.  The holes lean with the walls, so they open up as the
## outline closes in.  Corners stay sharp and walls stay flat or conical, as a
## drafted wall is; a taper that closes a hole or the outline before the full
## height cannot be built.  The heights are true heights, square to the plane.
## A region with splines takes no taper: Open CASCADE cannot offset a spline
## faithfully.
##
## @item @qcode{'Twist'}
## The angle in degrees the region turns about the normal through its
## origin, anticlockwise, over the height of the extrusion.
##
## @item @qcode{'Scale'}
## The factor by which the region is scaled about its origin at the far end
## of the extrusion, changing evenly along the height.  It is 1 by default.
## @end table
##
## Twist and scale apply to an extrusion to one side and cannot be combined
## with a taper.  A scaled extrusion without twist is exact.  A twisted one
## passes exactly through the region turned every 10 degrees, with a smooth
## surface between.
##
## @example
## @group
## ## A flange 3 thick: rounded ends, a bore of 20 and two holes of 6
## R = geom.Region ([-20, -20, 0; 20, -20, 1; 20, 20, 0; -20, 20, 1], ...
##                  @{[10, 0, 1; -10, 0, 1], [-22, 0, 1; -28, 0, 1], ...
##                   [28, 0, 1; 22, 0, 1]@});
## S = solid.extrude (R, 3);
##
## ## A block 10 high centred on the plane, its walls drafted 3 degrees
## S = solid.extrude (geom.Region ([0, 0; 40, 0; 40, 20; 0, 20]), [5, 5], ...
##                    'Taper', 3);
## @end group
## @end example
##
## @seealso{geom.Region, solid.revolve, solid.loft, solid.sweep}
## @end deftypefn

function S = extrude (R, H, varargin)

  ## Input validation
  if (nargin < 2)
    error ("solid.extrude: invalid number of input arguments.");
  endif
  [errmsg, D, splines] = solid.__region__ (R, 'R');
  if (! isempty (errmsg))
    error ("solid.extrude: %s", errmsg);
  endif
  if (! isnumeric (H) || ! isreal (H) || ! isvector (H) || numel (H) > 2 ...
      || ! all (isfinite (H)) || any (H == 0) ...
      || (numel (H) == 2 && any (H < 0)))
    error (strcat ("solid.extrude: H must be a nonzero finite real", ...
                   " scalar, or two positive ones for both sides."));
  endif
  if (mod (numel (varargin), 2) != 0)
    error ("solid.extrude: Name/Value arguments must come in pairs.");
  endif
  opt = struct ('Taper', 0, 'Twist', 0, 'Scale', 1);
  for k = 1:2:numel (varargin)
    name = varargin{k};
    if (! ischar (name) || ! isrow (name) ...
        || ! any (strcmp (name, fieldnames (opt))))
      error ("solid.extrude: unknown parameter.");
    endif
    opt.(name) = varargin{k+1};
  endfor
  A = opt.Taper;
  if (! isnumeric (A) || ! isreal (A) || ! isvector (A) || numel (A) > 2 ...
      || ! all (abs (A) < 90))
    error (strcat ("solid.extrude: Taper must be one angle, or two for", ...
                   " both sides, each in the range (-90, 90) degrees."));
  endif
  if (numel (A) == 2 && numel (H) == 1)
    error (strcat ("solid.extrude: Taper takes two angles only for an", ...
                   " extrusion to both sides."));
  endif
  if (splines && any (A != 0))
    error ("solid.extrude: Taper cannot be applied to a region with splines.");
  endif
  if (! isnumeric (opt.Twist) || ! isreal (opt.Twist) ...
      || ! isscalar (opt.Twist) || ! isfinite (opt.Twist))
    error ("solid.extrude: Twist must be a finite real scalar.");
  endif
  errmsg = solid.__checkpos__ (opt.Scale, 'Scale');
  if (! isempty (errmsg))
    error ("solid.extrude: %s", errmsg);
  endif
  twisted = (opt.Twist != 0 || opt.Scale != 1);
  if (twisted && numel (H) == 2)
    error ("solid.extrude: Twist and Scale apply to an extrusion to one side.");
  endif
  if (twisted && any (A != 0))
    error ("solid.extrude: Taper cannot be combined with Twist or Scale.");
  endif
  errmsg = solid.__checkocct__ ();
  if (! isempty (errmsg))
    error ("solid.extrude: %s", errmsg);
  endif

  H = double (H);
  if (twisted)
    S = twist (R, H, double (opt.Twist), double (opt.Scale));
    return;
  endif
  if (isscalar (H))
    H = [max(H, 0), max(-H, 0)];
  endif
  A = double (A);
  if (isscalar (A))
    A = [A, A];
  endif
  S = solid.Shape (__occt__ ('extrude', 'solid.extrude', D, H(1), H(2), ...
                             A(1), A(2)));

endfunction

## An extrusion of R to the signed height H, turning by TW degrees and scaled
## to SC at its far end: a loft through the region turned and scaled every 10
## degrees, ruled and exact when it does not turn
function S = twist (R, H, TW, SC)

  U = R.UCS;
  n = max (4, ceil (abs (TW) / 10)) * (TW != 0) + (TW == 0);
  sections = cell (1, n + 1);
  for k = 0:n
    f = k / n;
    t = TW * f;
    X = U.XAxis * cosd (t) + U.YAxis * sind (t);
    o = U.Origin + H * f * U.Normal;
    Rk = __scaled__ (R, 1 + (SC - 1) * f);
    Rk.UCS = geom.UCS (U.Normal, o, o + X);
    sections{k+1} = Rk;
  endfor
  S = solid.loft (sections, 'Ruled', TW == 0);

endfunction

%!testif ; exist ('__occt__') == 3
%! S = solid.extrude (geom.Region ([0, 0; 10, 0; 10, 20; 0, 20]), 5);
%! assert_equal (volume (S), 1000, 1e-9);
%! assert_equal (bbox (S), [0, 0, 0, 10, 20, 5], 1e-9);
%! assert_equal (numfaces (S), 6);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # an L-shaped bracket
%! R = geom.Region ([0, 0; 30, 0; 30, 5; 5, 5; 5, 20; 0, 20]);
%! S = solid.extrude (R, 10);
%! assert_equal (volume (S), (150 + 75) * 10, 1e-9);
%! assert_equal (numfaces (S), 8);

%!testif ; exist ('__occt__') == 3  # a slot-ended link
%! R = geom.Region ([0, -6, 0; 40, -6, 1; 40, 6, 0; 0, 6, 1]);
%! S = solid.extrude (R, 5);
%! assert_equal (volume (S), (480 + 36 * pi) * 5, 1e-9);
%! assert_equal (bbox (S), [-6, -6, 0, 46, 6, 5], 1e-9);
%! assert_equal (numfaces (S), 6);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # a disc from two vertices
%! S = solid.extrude (geom.Region ([0, 0, 1; 10, 0, 1]), 2);
%! assert_equal (volume (S), 50 * pi, 1e-9);
%! assert_equal (area (S), 50 * pi + 20 * pi, 1e-9);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # a negative bulge rounds inwards
%! R = geom.Region ([0, 0, 0; 20, 0, 0; 20, 20, -1; 0, 20, 0]);
%! S = solid.extrude (R, 1);
%! assert_equal (volume (S), 400 - 50 * pi, 1e-9);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # a smooth hole, a closed spline
%! H = geom.Spline ([20, 15; 35, 12; 40, 25; 28, 35; 18, 28], 'Closed', true);
%! R = geom.Region ([0, 0; 80, 0; 80, 50; 0, 50], {H});
%! S = solid.extrude (R, 6);
%! assert_equal (volume (S), 6 * (4000 + __area__ (R.Holes{1})), -1e-9);
%! assert_equal (numfaces (S), 7);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # a spline region scaled along the height
%! R = geom.Region (geom.Spline ([-3, -2; 3, -2; 4, 2; 0, 4; -4, 2], ...
%!                               'Closed', true));
%! S = solid.extrude (R, 6, 'Scale', 0.5);
%! assert_equal (volume (S), 6 * __area__ (R.Outline) * 1.75 / 3, -1e-9);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # holes of any shape go right through
%! R = geom.Region ([0, 0; 60, 0; 60, 40; 0, 40], ...
%!                  {[20, 20, 1; 40, 20, 1], [4, 4; 10, 4; 10, 10; 4, 10]});
%! S = solid.extrude (R, 3);
%! assert_equal (volume (S), (2400 - 100 * pi - 36) * 3, 1e-9);
%! assert_equal (numfaces (S), 6 + 2 + 4);   # a bore of two arcs, two faces
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # square to a sloping plane
%! n = [0, -0.6, 0.8];
%! R = geom.Region ([0, 0; 10, 0; 10, 10; 0, 10]);
%! R.UCS = geom.UCS (n, [0, 0, 5]);
%! S = solid.extrude (R, 4);
%! assert_equal (volume (S), 400, 1e-9);
%! c = [0, 0, 5] + 5 * R.UCS.XAxis + 5 * R.UCS.YAxis + 2 * n;
%! assert_equal (centroid (S), c, 1e-9);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # a negative height runs the other way
%! S = solid.extrude (geom.Region ([0, 0; 10, 0; 10, 20; 0, 20]), -5);
%! assert_equal (bbox (S), [0, 0, -5, 10, 20, 0], 1e-9);
%! assert_equal (volume (S), 1000, 1e-9);

%!testif ; exist ('__occt__') == 3  # to both sides of the plane
%! S = solid.extrude (geom.Region ([0, 0; 10, 0; 10, 20; 0, 20]), [5, 3]);
%! assert_equal (bbox (S), [0, 0, -3, 10, 20, 5], 1e-9);
%! assert_equal (numfaces (S), 6);

%!testif ; exist ('__occt__') == 3  # tapered walls leave a frustum
%! S = solid.extrude (geom.Region ([0, 0; 10, 0; 10, 10; 0, 10]), 5, ...
%!                    'Taper', 10);
%! w = 10 - 10 * tand (10);
%! assert_equal (volume (S), 5 / 3 * (100 + w ^ 2 + 10 * w), 1e-9);
%! assert_equal (bbox (S), [0, 0, 0, 10, 10, 5], 1e-6);
%! assert_equal (numel (faces (S, 'Type', 'plane')), 6);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # an outward taper, and a hole opening up
%! R = geom.Region ([0, 0; 20, 0; 20, 20; 0, 20], {[4, 6, 1; 8, 6, 1]});
%! S = solid.extrude (R, 5, 'Taper', 10);
%! fr = @(a1, a2, h) h / 3 * (a1 + a2 + sqrt (a1 * a2));
%! d = 5 * tand (10);
%! cone = pi * 5 / 3 * (4 + (2 + d) ^ 2 + 2 * (2 + d));
%! assert_equal (volume (S), fr (400, (20 - 2 * d) ^ 2, 5) - cone, 1e-9);
%! assert_equal (numel (faces (S, 'Type', 'cone')), 1);
%! T = solid.extrude (geom.Region ([0, 0; 10, 0; 10, 10; 0, 10]), 5, ...
%!                    'Taper', -10);
%! w = 10 + 10 * tand (10);
%! assert_equal (volume (T), fr (100, w ^ 2, 5), 1e-9);

%!testif ; exist ('__occt__') == 3  # each side its own taper
%! S = solid.extrude (geom.Region ([0, 0; 10, 0; 10, 10; 0, 10]), [5, 3], ...
%!                    'Taper', [10, 20]);
%! fr = @(a1, a2, h) h / 3 * (a1 + a2 + sqrt (a1 * a2));
%! w1 = 10 - 10 * tand (10);
%! w2 = 10 - 6 * tand (20);
%! assert_equal (volume (S), fr (100, w1 ^ 2, 5) + fr (100, w2 ^ 2, 3), 1e-9);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # scaled at the far end, exactly
%! S = solid.extrude (geom.Region ([-5, -5; 5, -5; 5, 5; -5, 5]), -6, ...
%!                    'Scale', 0.5);
%! assert_equal (volume (S), 6 / 3 * (100 + 25 + 50), 1e-9);
%! assert_equal (bbox (S), [-5, -5, -6, 5, 5, 0], 1e-6);

%!testif ; exist ('__occt__') == 3  # twisted, the section kept
%! S = solid.extrude (geom.Region ([-5, -2; 5, -2; 5, 2; -5, 2]), 20, ...
%!                    'Twist', 90);
%! assert_equal (volume (S), 40 * 20, -1e-3);
%! assert_equal (bbox (S)([3, 6]), [0, 20], 1e-6);
%! assert_equal (isvalid (S), true);

%!error<solid.extrude: invalid number of input arguments.> ...
%! solid.extrude (geom.Region ([0, 0; 1, 0; 1, 1]))
%!error<solid.extrude: R must be a geom.Region object.> ...
%! solid.extrude ([0, 0; 1, 0; 1, 1], 1)
%!error<solid.extrude: R must be a geom.Region object.> ...
%! solid.extrude (geom.Polyline ([0, 0; 1, 0; 1, 1], 'Closed', true), 1)
%!error<solid.extrude: H must be a nonzero finite real scalar, or two positive ones for both sides.> ...
%! solid.extrude (geom.Region ([0, 0; 1, 0; 1, 1]), 0)
%!error<solid.extrude: H must be a nonzero finite real scalar, or two positive ones for both sides.> ...
%! solid.extrude (geom.Region ([0, 0; 1, 0; 1, 1]), [5, -3])
%!error<solid.extrude: H must be a nonzero finite real scalar, or two positive ones for both sides.> ...
%! solid.extrude (geom.Region ([0, 0; 1, 0; 1, 1]), [1, 2, 3])
%!error<solid.extrude: Name/Value arguments must come in pairs.> ...
%! solid.extrude (geom.Region ([0, 0; 1, 0; 1, 1]), 1, 'Taper')
%!error<solid.extrude: unknown parameter.> ...
%! solid.extrude (geom.Region ([0, 0; 1, 0; 1, 1]), 1, 'Draft', 3)
%!error<solid.extrude: Taper must be one angle, or two for both sides, each in the range \(-90, 90\) degrees.> ...
%! solid.extrude (geom.Region ([0, 0; 1, 0; 1, 1]), 1, 'Taper', 90)
%!error<solid.extrude: Taper must be one angle, or two for both sides, each in the range \(-90, 90\) degrees.> ...
%! solid.extrude (geom.Region ([0, 0; 1, 0; 1, 1]), 1, 'Taper', 'a')
%!error<solid.extrude: Taper takes two angles only for an extrusion to both sides.> ...
%! solid.extrude (geom.Region ([0, 0; 1, 0; 1, 1]), 1, 'Taper', [3, 5])
%!error<solid.extrude: Twist must be a finite real scalar.> ...
%! solid.extrude (geom.Region ([0, 0; 1, 0; 1, 1]), 1, 'Twist', Inf)
%!error<solid.extrude: Scale must be a positive and finite real scalar.> ...
%! solid.extrude (geom.Region ([0, 0; 1, 0; 1, 1]), 1, 'Scale', 0)
%!error<solid.extrude: Twist and Scale apply to an extrusion to one side.> ...
%! solid.extrude (geom.Region ([0, 0; 1, 0; 1, 1]), [1, 1], 'Twist', 30)
%!error<solid.extrude: Taper cannot be applied to a region with splines.> ...
%! solid.extrude (geom.Region (geom.Spline ([0, 0; 5, 0; 3, 4], ...
%!                                         'Closed', true)), 1, 'Taper', 2)
%!error<solid.extrude: Taper cannot be combined with Twist or Scale.> ...
%! solid.extrude (geom.Region ([0, 0; 1, 0; 1, 1]), 1, 'Taper', 3, 'Scale', 2)
