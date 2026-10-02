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
## @deftypefn  {drafting} {@var{S} =} solid.box (@var{DX}, @var{DY}, @var{DZ})
## @deftypefnx {drafting} {@var{S} =} solid.box (@var{DX}, @var{DY}, @var{DZ}, @var{U})
## @deftypefnx {drafting} {@var{S} =} solid.box (@dots{}, 'Anchor', @var{A})
##
## A rectangular block.
##
## @code{@var{S} = solid.box (@var{DX}, @var{DY}, @var{DZ})} returns a
## @code{solid.Shape} measuring @var{DX} by @var{DY} by @var{DZ} millimetres,
## with one corner at the origin and the block extending along the positive
## @math{x}, @math{y} and @math{z} axes.
##
## @code{@var{S} = solid.box (@var{DX}, @var{DY}, @var{DZ}, @var{U})} places
## the block in the @code{geom.UCS} @var{U}: @var{DX} runs along its
## @math{x} axis, @var{DY} along its @math{y} axis and @var{DZ} along its
## normal, with the corner on its origin.
##
## The option @qcode{'Anchor'} chooses the point of the block that lands on
## the origin, of @var{U} or of the world when @var{U} is left out:
##
## @table @asis
## @item @qcode{'corner'}
## the corner at the least @math{x}, @math{y} and @math{z}, the default.
##
## @item @qcode{'base'}
## the centre of the bottom face.
##
## @item @qcode{'centroid'}
## the centre of the block, its centre of mass.
## @end table
##
## @example
## @group
## ## A block standing centred on the top of another
## U = geom.UCS ([0, 0, 1], [20, 10, 8]);
## S = solid.box (6, 4, 3, U, 'Anchor', 'base');
## bbox (S)
## @result{} 17   8   8   23   12   11
## @end group
## @end example
##
## @seealso{solid.Shape, solid.wedge, solid.cylinder, geom.UCS}
## @end deftypefn

function S = box (DX, DY, DZ, varargin)

  ## Input validation
  if (nargin < 3 || nargin > 6)
    error ("solid.box: invalid number of input arguments.");
  endif
  errmsg = solid.__checkpos__ (DX, 'DX');
  if (isempty (errmsg))
    errmsg = solid.__checkpos__ (DY, 'DY');
  endif
  if (isempty (errmsg))
    errmsg = solid.__checkpos__ (DZ, 'DZ');
  endif
  if (isempty (errmsg))
    D = double ([DX, DY, DZ]) / 2;
    [frame, errmsg] = solid.__place__ (varargin, {'corner', 'base', ...
                                       'centroid'}, [0, 0, 0; D(1:2), 0; D]);
  endif
  if (isempty (errmsg))
    errmsg = solid.__checkocct__ ();
  endif
  if (! isempty (errmsg))
    error ("solid.box: %s", errmsg);
  endif

  S = __occt__ ('box', 'solid.box', double (DX), double (DY), double (DZ));
  S = solid.Shape (__occt__ ('place', 'solid.box', S, frame));

endfunction

%!testif ; exist ('__occt__') == 3
%! S = solid.box (10, 20, 30);
%! assert_equal (volume (S), 6000, 1e-9);
%! assert_equal (bbox (S), [0, 0, 0, 10, 20, 30], 1e-9);
%! assert_equal (numfaces (S), 6);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # integer-valued input
%! assert_equal (volume (solid.box (int16 (2), 3, 4)), 24, 1e-9);

%!testif ; exist ('__occt__') == 3  # in a UCS turned onto the yz plane
%! U = geom.UCS ([1, 0, 0], [5, 0, 0], [5, 1, 0]);
%! S = solid.box (10, 20, 30, U);
%! assert_equal (bbox (S), [5, 0, 0, 35, 10, 20], 1e-9);

%!testif ; exist ('__occt__') == 3  # standing on the centre of its base
%! U = geom.UCS ([0, 0, 1], [20, 10, 8]);
%! S = solid.box (6, 4, 3, U, 'Anchor', 'base');
%! assert_equal (bbox (S), [17, 8, 8, 23, 12, 11], 1e-9);

%!testif ; exist ('__occt__') == 3  # centred on a tilted UCS
%! U = geom.UCS ([0, 1, 1], [1, 2, 3]);
%! S = solid.box (6, 4, 3, U, 'Anchor', 'centroid');
%! assert_equal (centroid (S), [1, 2, 3], 1e-9);
%! assert_equal (volume (S), 72, 1e-9);

%!testif ; exist ('__occt__') == 3  # an anchor in the world axes
%! S = solid.box (6, 4, 2, 'Anchor', 'centroid');
%! assert_equal (bbox (S), [-3, -2, -1, 3, 2, 1], 1e-9);

%!error<solid.box: invalid number of input arguments.> solid.box (1, 2)
%!error<solid.box: invalid number of input arguments.> ...
%! solid.box (1, 2, 3, geom.UCS (), 'Anchor', 'base', 4)
%!error<solid.box: DX must be a positive and finite real scalar.> ...
%! solid.box (0, 2, 3)
%!error<solid.box: DY must be a positive and finite real scalar.> ...
%! solid.box (1, -2, 3)
%!error<solid.box: DZ must be a positive and finite real scalar.> ...
%! solid.box (1, 2, Inf)
%!error<solid.box: DX must be a positive and finite real scalar.> ...
%! solid.box ([1, 2], 2, 3)
%!error<solid.box: U must be a geom.UCS object.> solid.box (1, 2, 3, [0, 0, 1])
%!error<solid.box: Name/Value arguments must come in pairs.> ...
%! solid.box (1, 2, 3, 'Anchor')
%!error<solid.box: unknown parameter.> solid.box (1, 2, 3, 'Base', 'corner')
%!error<solid.box: Anchor must be 'corner', 'base' or 'centroid'.> ...
%! solid.box (1, 2, 3, geom.UCS (), 'Anchor', 'top')
