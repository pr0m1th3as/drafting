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
## @deftypefn  {drafting} {@var{S} =} solid.wedge (@var{DX}, @var{DY}, @var{DZ}, @var{TX})
## @deftypefnx {drafting} {@var{S} =} solid.wedge (@var{DX}, @var{DY}, @var{DZ}, @var{TOP})
## @deftypefnx {drafting} {@var{S} =} solid.wedge (@dots{}, @var{U})
## @deftypefnx {drafting} {@var{S} =} solid.wedge (@dots{}, 'Anchor', @var{A})
##
## A wedge: a block whose top is smaller than its base.
##
## @code{@var{S} = solid.wedge (@var{DX}, @var{DY}, @var{DZ}, @var{TX})}
## returns a @code{solid.Shape} standing on a base @var{DX} by @var{DY}
## millimetres, with one corner at the origin, @var{DZ} high.  Its top face
## runs from @math{x = 0} to @math{x =} @var{TX} across the full depth
## @var{DY}, so the face opposite @math{x = 0} slopes: this is a ramp, a
## gusset or a stop.  A @var{TX} of zero makes a triangular prism.
##
## @code{@var{S} = solid.wedge (@var{DX}, @var{DY}, @var{DZ}, @var{TOP})}
## gives the top face as the rectangle @code{[@var{XMIN}, @var{YMIN},
## @var{XMAX}, @var{YMAX}]}, so faces can slope on any side, as for a
## dovetail, a frustum of a pyramid or a pyramid itself when the rectangle
## is a point.
##
## @code{@var{S} = solid.wedge (@dots{}, @var{U})} places the wedge in the
## @code{geom.UCS} @var{U}: @var{DX} runs along its @math{x} axis, @var{DY}
## along its @math{y} axis and @var{DZ} along its normal, with the corner on
## its origin.
##
## The option @qcode{'Anchor'} chooses the point of the wedge that lands on
## the origin, of @var{U} or of the world when @var{U} is left out:
## @qcode{'corner'}, the corner of the base at the least @math{x} and
## @math{y}, the default, or @qcode{'base'}, the centre of the base.
##
## @example
## @group
## ## A ramp 40 long, 20 wide and 10 high
## S = solid.wedge (40, 20, 10, 0);
## volume (S)
## @result{} 4000
## @end group
## @end example
##
## @seealso{solid.box, solid.Shape, geom.UCS}
## @end deftypefn

function S = wedge (DX, DY, DZ, TOP, varargin)

  ## Input validation
  if (nargin < 4 || nargin > 7)
    error ("solid.wedge: invalid number of input arguments.");
  endif
  errmsg = solid.__checkpos__ (DX, 'DX');
  if (isempty (errmsg))
    errmsg = solid.__checkpos__ (DY, 'DY');
  endif
  if (isempty (errmsg))
    errmsg = solid.__checkpos__ (DZ, 'DZ');
  endif
  if (! isempty (errmsg))
    error ("solid.wedge: %s", errmsg);
  endif
  if (! isnumeric (TOP) || ! isreal (TOP) || ! isvector (TOP) ...
      || ! any (numel (TOP) == [1, 4]) || ! all (isfinite (TOP)))
    error (strcat ("solid.wedge: TOP must be a length TX or a rectangle", ...
                   " [XMIN, YMIN, XMAX, YMAX] of finite values."));
  endif
  TOP = double (TOP(:)');
  if (isscalar (TOP))
    if (TOP < 0)
      error ("solid.wedge: TX must not be negative.");
    endif
    TOP = [0, 0, TOP, DY];
  elseif (TOP(1) > TOP(3) || TOP(2) > TOP(4))
    error ("solid.wedge: TOP must have XMIN <= XMAX and YMIN <= YMAX.");
  endif
  [frame, errmsg] = solid.__place__ (varargin, {'corner', 'base'}, ...
                                     [0, 0, 0; double([DX, DY]) / 2, 0]);
  if (isempty (errmsg))
    errmsg = solid.__checkocct__ ();
  endif
  if (! isempty (errmsg))
    error ("solid.wedge: %s", errmsg);
  endif

  S = __occt__ ('wedge', 'solid.wedge', double (DX), double (DY), ...
                double (DZ), TOP);
  S = solid.Shape (__occt__ ('place', 'solid.wedge', S, frame));

endfunction

%!testif ; exist ('__occt__') == 3  # a block cut back at the top
%! S = solid.wedge (10, 20, 8, 4);
%! assert_equal (volume (S), (10 + 4) / 2 * 8 * 20, 1e-9);
%! assert_equal (bbox (S), [0, 0, 0, 10, 20, 8], 1e-9);
%! assert_equal (numfaces (S), 6);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # a ramp, a triangular prism
%! S = solid.wedge (40, 20, 10, 0);
%! assert_equal (volume (S), 4000, 1e-9);
%! assert_equal (numfaces (S), 5);
%! assert_equal (numel (faces (S, 'Normal', [1, 0, 4])), 1);

%!testif ; exist ('__occt__') == 3  # a frustum of a pyramid, a pyramid
%! S = solid.wedge (10, 20, 8, [2, 3, 7, 5]);
%! assert_equal (volume (S), 720, 1e-9);
%! assert_equal (isvalid (S), true);
%! S = solid.wedge (10, 20, 8, [5, 5, 5, 5]);
%! assert_equal (volume (S), 10 * 20 * 8 / 3, 1e-9);

%!testif ; exist ('__occt__') == 3  # on the centre of its base in a UCS
%! U = geom.UCS ([0, 0, 1], [1, 2, 3], [1, 3, 3]);
%! S = solid.wedge (10, 20, 8, 4, U, 'Anchor', 'base');
%! assert_equal (bbox (S), [-9, -3, 3, 11, 7, 11], 1e-9);
%! assert_equal (numel (faces (S, 'Normal', [0, -1, 0])), 1);

%!error<solid.wedge: invalid number of input arguments.> solid.wedge (1, 2, 3)
%!error<solid.wedge: invalid number of input arguments.> ...
%! solid.wedge (1, 2, 3, 1, geom.UCS (), 'Anchor', 'base', 4)
%!error<solid.wedge: DX must be a positive and finite real scalar.> ...
%! solid.wedge (0, 2, 3, 1)
%!error<solid.wedge: DY must be a positive and finite real scalar.> ...
%! solid.wedge (1, -2, 3, 1)
%!error<solid.wedge: DZ must be a positive and finite real scalar.> ...
%! solid.wedge (1, 2, Inf, 1)
%!error<solid.wedge: TOP must be a length TX or a rectangle \[XMIN, YMIN, XMAX, YMAX\] of finite values.> ...
%! solid.wedge (1, 2, 3, [1, 2])
%!error<solid.wedge: TX must not be negative.> solid.wedge (1, 2, 3, -1)
%!error<solid.wedge: TOP must have XMIN <= XMAX and YMIN <= YMAX.> ...
%! solid.wedge (10, 20, 8, [5, 3, 2, 5])
%!error<solid.wedge: U must be a geom.UCS object.> solid.wedge (1, 2, 3, 1, 5)
%!error<solid.wedge: Name/Value arguments must come in pairs.> ...
%! solid.wedge (1, 2, 3, 1, 'Anchor')
%!error<solid.wedge: unknown parameter.> ...
%! solid.wedge (1, 2, 3, 1, geom.UCS (), 'Base', 'corner')
%!error<solid.wedge: Anchor must be 'corner' or 'base'.> ...
%! solid.wedge (1, 2, 3, 1, 'Anchor', 'centroid')
