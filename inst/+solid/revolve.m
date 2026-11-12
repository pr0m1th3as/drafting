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
## @deftypefnx {drafting} {@var{S} =} solid.revolve (@var{R}, 'Angle', @var{ANGLE})
## @deftypefnx {drafting} {@var{S} =} solid.revolve (@dots{}, 'Label', @var{L})
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
## @var{R} may also be a cell array of regions, such as
## @code{geom.Region.union} returns: each is turned about the axis of its own
## plane and the solids are fused into one shape.  The cell must not be
## empty.
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
## The option @qcode{'Angle'} turns the region through @var{ANGLE} degrees
## only, anticlockwise seen from the tip of the axis, starting from the
## region's plane.  @var{ANGLE} is in the range @math{(0, 360]}, and 360 is
## the default.
##
## The option @qcode{'Label'} names the faces of the solid, so that a later step
## finds a face by its name with @code{solid.Shape.faces}.  @var{L} is a valid
## Octave identifier or keyword, and the faces are named @var{L}@code{.side},
## every face turned from the outline of the region, and @var{L}@code{.hole},
## every face turned from its holes.  A part turn has two flat ends besides,
## @var{L}@code{.start} in the region's plane and @var{L}@code{.end} at
## @var{ANGLE}; a whole turn has none.  Where the region runs along the axis it
## makes no face, and no name.  The solids of a cell array of regions are copies
## 1, 2 and so on of the label, chosen with @qcode{'Copy'}.
##
## Where the segments of the region are labelled, as @code{geom.Region}
## describes, each wall also takes the label of the segment it is turned from,
## one level below its role: @var{L}@code{.side.web} for a wall of the outline's
## segment labelled @code{web}, @var{L}@code{.hole.key_floor} for a wall of a
## hole's segment labelled @code{key_floor}.  @var{L}@code{.side} still names
## every wall of the outline, and a wall of a segment left unnamed is plain
## @var{L}@code{.side} or @var{L}@code{.hole}.  Without @qcode{'Label'} no face
## is named, whatever labels the region carries.
##
## @seealso{geom.Region, solid.extrude, solid.helix}
## @end deftypefn

function S = revolve (R, varargin)

  ## Input validation
  if (nargin < 1 || nargin > 5)
    error ("solid.revolve: invalid number of input arguments.");
  endif
  if (iscell (R))
    if (isempty (R))
      error ("solid.revolve: R must not be an empty cell array.");
    endif
    S = cellfun (@(r) solid.revolve (r, varargin{:}), R, ...
                 'UniformOutput', false);
    ## The solid of region K is copy K, for 'Copy' to choose it
    for k = 1:numel (S)
      S{k} = solid.Shape (__occt__ ('copyindex', 'solid.revolve', ...
                                    S{k}.Data, k));
    endfor
    S = union (S{:});
    return;
  endif
  ANGLE = 360;
  if (mod (numel (varargin), 2) != 0)
    error ("solid.revolve: Name/Value arguments must come in pairs.");
  endif
  label = '';
  for ii = 1:2:numel (varargin)
    name = varargin{ii};
    val = varargin{ii+1};
    if (! ischar (name) || ! isrow (name))
      error ("solid.revolve: option names must be character vectors.");
    endif
    switch (lower (name))
      case 'angle'
        ANGLE = val;
      case 'label'
        label = val;
        if (! (ischar (val) && isrow (val)
               && (isvarname (val) || iskeyword (val))))
          error (strcat ("solid.revolve: Label must be a valid Octave", ...
                         " identifier or keyword."));
        endif
      otherwise
        error ("solid.revolve: unknown option '%s'.", name);
    endswitch
  endfor
  [errmsg, D] = solid.__region__ (R, 'R');
  if (isempty (errmsg))
    Q = __sample__ (R.Outline);
    if (min (Q(:,1)) < -1e-9 * max (abs (Q(:))))
      errmsg = strcat ("R must lie on one side of its axis: no point of", ...
                       " it may have a negative x.");
    endif
  endif
  if (isempty (errmsg) && (! isfloat (ANGLE) || ! isreal (ANGLE)
                           || ! isscalar (ANGLE) || ! (ANGLE > 0)
                           || ! (ANGLE <= 360)))
    errmsg = "Angle must be a real scalar in the range (0, 360].";
  endif
  if (! isempty (errmsg))
    error ("solid.revolve: %s", errmsg);
  endif

  S = solid.Shape (__occt__ ('revolve', 'solid.revolve', D, double (ANGLE), ...
                             label));

endfunction

%!test  # a cylinder about the model's y axis
%! S = solid.revolve (geom.Region ([0, 0; 4, 0; 4, 12; 0, 12]));
%! assert_equal (volume (S), 192 * pi, 1e-9);
%! assert_equal (bbox (S), [-4, 0, -4, 4, 12, 4], 1e-9);
%! assert_equal (numfaces (S), 3);
%! assert_equal (isvalid (S), true);

%!test  # in the xz plane, about the z axis
%! R = geom.Region ([0, 0; 4, 0; 4, 12; 0, 12]);
%! R.UCS = geom.UCS ([0, -1, 0], [0, 0, 0]);
%! S = solid.revolve (R);
%! assert_equal (bbox (S), [-4, -4, 0, 4, 4, 12], 1e-9);

%!test  # a stepped shaft with a chamfer
%! R = geom.Region ([0, 0; 10, 0; 10, 30; 6, 30; 6, 49; 5, 50; 0, 50]);
%! S = solid.revolve (R);
%! assert_equal (volume (S), pi * (3000 + 36 * 19 + (36 + 30 + 25) / 3), 1e-9);
%! assert_equal (isvalid (S), true);

%!test  # a bush, clear of the axis
%! S = solid.revolve (geom.Region ([5, 0; 8, 0; 8, 10; 5, 10]));
%! assert_equal (volume (S), pi * (64 - 25) * 10, 1e-9);
%! assert_equal (numfaces (S), 4);

%!test  # a quarter turn, anticlockwise about y
%! S = solid.revolve (geom.Region ([0, 0; 4, 0; 4, 12; 0, 12]), 'Angle', 90);
%! assert_equal (volume (S), 48 * pi, 1e-9);
%! assert_equal (bbox (S), [0, 0, -4, 4, 12, 0], 1e-9);
%! assert_equal (isvalid (S), true);

%!test  # a sphere from a semicircle on the axis
%! S = solid.revolve (geom.Region ([0, -5, 1; 0, 5, 0]));
%! assert_equal (volume (S), 4 / 3 * pi * 125, 1e-9);
%! assert_equal (isvalid (S), true);

%!test  # a hollow ring, by Pappus
%! R = geom.Region ([8, -2; 12, -2; 12, 2; 8, 2], {[9, 0, 1; 11, 0, 1]});
%! S = solid.revolve (R);
%! assert_equal (volume (S), (16 - pi) * 2 * pi * 10, 1e-9);
%! assert_equal (isvalid (S), true);

%!test  # a closed spline, by Pappus
%! O = geom.Spline ([10, 0; 20, -5; 30, 5; 22, 15; 12, 10], 'Closed', true);
%! Q = points (O, 100001);
%! c = Q(1:end-1,1) .* Q(2:end,2) - Q(2:end,1) .* Q(1:end-1,2);
%! cx = sum ((Q(1:end-1,1) + Q(2:end,1)) .* c) / (3 * sum (c));
%! S = solid.revolve (geom.Region (O), 'Angle', 360);
%! assert_equal (volume (S), 2 * pi * cx * abs (sum (c)) / 2, -1e-8);
%! assert_equal (isvalid (S), true);

%!test  # each face named by the segment it is turned from
%! key = geom.Polyline ([18, 1; 22, 1; 22, 3; 18, 3], 'Closed', true, ...
%!                      'Label', {'key_floor', '', 'key_top', ''});
%! R = geom.Region ([0, 0; 40, 0; 40, 5; 5, 5; 5, 30; 0, 30], {key}, ...
%!                  'Label', {'base', '', '', 'inside', '', ''});
%! S = solid.revolve (R, 'Angle', 90, 'Label', 'ring');
%! assert_equal (faces (S, 'Label', 'ring.side.base'), ...
%!               faces (S, 'Within', [-40, 0, -40, 40, 0, 40]));
%! assert_equal (faces (S, 'Label', 'ring.side.inside'), ...
%!               faces (S, 'Type', 'cylinder', ...
%!                      'Within', [-5, 5, -5, 5, 30, 5]));
%! assert_equal (faces (S, 'Label', 'ring.hole.key_floor'), ...
%!               faces (S, 'Within', [-22, 1, -22, 22, 1, 22]));
%! assert_equal (numel (faces (S, 'Label', 'ring.side')), 5);

%!error<solid.revolve: invalid number of input arguments.> solid.revolve ()
%!test  # a cell of two regions, two rings fused into one shape
%! R = {geom.Region([5, 0; 10, 0; 10, 2; 5, 2]), ...
%!      geom.Region([5, 5; 10, 5; 10, 7; 5, 7])};
%! S = solid.revolve (R);
%! assert_equal (numsolids (S), 2);
%! assert_equal (volume (S), 300 * pi, 1e-9);

%!test  # a whole turn has walls only, named side
%! R = geom.Region ([0, 0; 10, 0; 10, 30; 6, 30; 6, 49; 5, 50; 0, 50]);
%! S = solid.revolve (R, 'Label', 'shaft');
%! assert_equal (numel (faces (S, 'Label', 'shaft.side')), numfaces (S));
%!test  # a part turn has a start in the region's plane and an end
%! S = solid.revolve (geom.Region ([0, 0; 4, 0; 4, 12; 0, 12]), 'Angle', 90, ...
%!                    'Label', 'segment');
%! assert_equal (faces (S, 'Label', 'segment.start'), ...
%!               faces (S, 'Normal', [0, 0, 1]));
%! assert_equal (faces (S, 'Label', 'segment.end'), ...
%!               faces (S, 'Normal', [-1, 0, 0]));
%!test  # the faces turned from a hole are named hole
%! R = geom.Region ([8, -2; 12, -2; 12, 2; 8, 2], {[9, 0, 1; 11, 0, 1]});
%! S = solid.revolve (R, 'Label', 'ring');
%! assert_equal (faces (S, 'Label', 'ring.hole'), faces (S, 'Type', 'torus'));
%! assert_equal (numel (faces (S, 'Label', 'ring.side')), 4);
%!test  # the solids of a cell of regions are copies of the label
%! R = {geom.Region([5, 0; 10, 0; 10, 2; 5, 2]), ...
%!      geom.Region([5, 5; 10, 5; 10, 7; 5, 7])};
%! S = solid.revolve (R, 'Label', 'washer');
%! assert_equal (numel (faces (S, 'Label', 'washer', 'Copy', 2)), 4);

%!error<solid.revolve: R must be a geom.Region object.> ...
%! solid.revolve ([0, 0; 1, 0; 1, 1])
%!error<solid.revolve: R must not be an empty cell array.> ...
%! solid.revolve (cell (1, 0))
%!error<solid.revolve: R must lie on one side of its axis: no point of it may have a negative x.> ...
%! solid.revolve ({geom.Region([1, 0; 2, 0; 2, 1]), ...
%!                 geom.Region([-1, 0; 1, 0; 1, 1; -1, 1])})
%!error<solid.revolve: R must lie on one side of its axis: no point of it may have a negative x.> ...
%! solid.revolve (geom.Region ([-1, 0; 1, 0; 1, 1; -1, 1]))
%!error<solid.revolve: R must lie on one side of its axis: no point of it may have a negative x.> ...
%! solid.revolve (geom.Region ([1, 0, -1; 1, 10, 0]))
%!error<solid.revolve: Angle must be a real scalar in the range \(0, 360\].> ...
%! solid.revolve (geom.Region ([0, 0; 1, 0; 1, 1]), 'Angle', 0)
%!error<solid.revolve: Angle must be a real scalar in the range \(0, 360\].> ...
%! solid.revolve (geom.Region ([0, 0; 1, 0; 1, 1]), 'Angle', 361)
%!error<solid.revolve: Angle must be a real scalar in the range \(0, 360\].> ...
%! solid.revolve (geom.Region ([0, 0; 1, 0; 1, 1]), 'Angle', NaN)
%!error<solid.revolve: Angle must be a real scalar in the range \(0, 360\].> ...
%! solid.revolve (geom.Region ([0, 0; 1, 0; 1, 1]), 'Angle', [90, 180])
%!error<solid.revolve: invalid number of input arguments.> ...
%! solid.revolve (geom.Region ([0, 0; 1, 0; 1, 1]), 'Angle', 90, 'Label', ...
%!                'a', 1)
%!error<solid.revolve: Name/Value arguments must come in pairs.> ...
%! solid.revolve (geom.Region ([0, 0; 1, 0; 1, 1]), 'Label')
%!error<solid.revolve: unknown option 'Degrees'.> ...
%! solid.revolve (geom.Region ([0, 0; 1, 0; 1, 1]), 'Degrees', 90)
%!error<solid.revolve: Name/Value arguments must come in pairs.> ...
%! solid.revolve (geom.Region ([0, 0; 1, 0; 1, 1]), 90)
%!error<solid.revolve: option names must be character vectors.> ...
%! solid.revolve (geom.Region ([0, 0; 1, 0; 1, 1]), 1, 2)
%!error<solid.revolve: Label must be a valid Octave identifier or keyword.> ...
%! solid.revolve (geom.Region ([0, 0; 1, 0; 1, 1]), 'Label', 'a.b')
