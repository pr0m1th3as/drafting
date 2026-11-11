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
## @deftypefnx {drafting} {@var{S} =} solid.box (@dots{}, 'Label', @var{L})
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
## The option @qcode{'Label'} names the faces of the block, so that a later
## step finds a face by its name with @code{solid.Shape.faces}, whatever was
## done to the block in between.  @var{L} is an identifier, a letter followed
## by letters, digits or underscores, and each face is named by it and the
## side of the block it is on: @var{L}@code{.xmin}, @var{L}@code{.xmax},
## @var{L}@code{.ymin}, @var{L}@code{.ymax}, @var{L}@code{.zmin} and
## @var{L}@code{.zmax}, along the axes of @var{U}, or of the world when
## @var{U} is left out.  A face keeps its name when it is moved or turned,
## so that @code{plate.xmin} is the same face after a rotation, wherever it
## then faces.
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
  if (nargin < 3 || nargin > 8)
    error ("solid.box: invalid number of input arguments.");
  endif
  if (! (isfloat (DX) && isreal (DX) && isscalar (DX) && isfinite (DX) &&
         DX > 0))
    error ("solid.box: DX must be a positive and finite real scalar.");
  endif
  if (! (isfloat (DY) && isreal (DY) && isscalar (DY) && isfinite (DY) &&
         DY > 0))
    error ("solid.box: DY must be a positive and finite real scalar.");
  endif
  if (! (isfloat (DZ) && isreal (DZ) && isscalar (DZ) && isfinite (DZ) &&
         DZ > 0))
    error ("solid.box: DZ must be a positive and finite real scalar.");
  endif
  D = double ([DX, DY, DZ]) / 2;
  [frame, errmsg, label] = solid.__place__ (varargin, {'corner', 'base', ...
                                            'centroid'}, ...
                                            [0, 0, 0; D(1:2), 0; D], true);
  if (! isempty (errmsg))
    error ("solid.box: %s", errmsg);
  endif

  S = __occt__ ('box', 'solid.box', double (DX), double (DY), double (DZ), ...
                label);
  S = solid.Shape (__occt__ ('place', 'solid.box', S, frame));

endfunction

%!test
%! S = solid.box (10, 20, 30);
%! assert_equal (volume (S), 6000, 1e-9);
%! assert_equal (bbox (S), [0, 0, 0, 10, 20, 30], 1e-9);
%! assert_equal (numfaces (S), 6);
%! assert_equal (isvalid (S), true);

%!test  # in a UCS turned onto the yz plane
%! U = geom.UCS ([1, 0, 0], [5, 0, 0], [5, 1, 0]);
%! S = solid.box (10, 20, 30, U);
%! assert_equal (bbox (S), [5, 0, 0, 35, 10, 20], 1e-9);

%!test  # standing on the centre of its base
%! U = geom.UCS ([0, 0, 1], [20, 10, 8]);
%! S = solid.box (6, 4, 3, U, 'Anchor', 'base');
%! assert_equal (bbox (S), [17, 8, 8, 23, 12, 11], 1e-9);

%!test  # centred on a tilted UCS
%! U = geom.UCS ([0, 1, 1], [1, 2, 3]);
%! S = solid.box (6, 4, 3, U, 'Anchor', 'centroid');
%! assert_equal (centroid (S), [1, 2, 3], 1e-9);
%! assert_equal (volume (S), 72, 1e-9);

%!test  # an anchor in the world axes
%! S = solid.box (6, 4, 2, 'Anchor', 'centroid');
%! assert_equal (bbox (S), [-3, -2, -1, 3, 2, 1], 1e-9);

%!test  # faces named by side
%! S = solid.box (10, 20, 30, 'Label', 'block');
%! assert_equal (faces (S, 'Label', 'block.xmin'), ...
%!               faces (S, 'Normal', [-1, 0, 0]));
%! assert_equal (faces (S, 'Label', 'block.ymax'), ...
%!               faces (S, 'Normal', [0, 1, 0]));
%! assert_equal (faces (S, 'Label', 'block.zmin'), ...
%!               faces (S, 'Normal', [0, 0, -1]));
%!test  # sides along the axes of the UCS
%! U = geom.UCS ([1, 0, 0], [5, 0, 0], [5, 1, 0]);
%! S = solid.box (10, 20, 30, U, 'Label', 'block');
%! assert_equal (faces (S, 'Label', 'block.zmax'), ...
%!               faces (S, 'Normal', [1, 0, 0]));
%! assert_equal (faces (S, 'Label', 'block.xmax'), ...
%!               faces (S, 'Normal', [0, 1, 0]));
%!test  # a label with an anchor, option names ignoring case
%! S = solid.box (6, 4, 2, 'label', 'block', 'Anchor', 'centroid');
%! assert_equal (bbox (S), [-3, -2, -1, 3, 2, 1], 1e-9);
%! assert_equal (numel (faces (S, 'Label', 'block')), 6);

%!error<solid.box: invalid number of input arguments.> solid.box (1, 2)
%!error<solid.box: invalid number of input arguments.> ...
%! solid.box (1, 2, 3, geom.UCS (), 'Anchor', 'base', 'Label', 'a', 4)
%!error<solid.box: DX must be a positive and finite real scalar.> ...
%! solid.box (0, 2, 3)
%!error<solid.box: DX must be a positive and finite real scalar.> ...
%! solid.box (int8 (10), 2.5, 3)
%!error<solid.box: DY must be a positive and finite real scalar.> ...
%! solid.box (1, -2, 3)
%!error<solid.box: DZ must be a positive and finite real scalar.> ...
%! solid.box (1, 2, Inf)
%!error<solid.box: DX must be a positive and finite real scalar.> ...
%! solid.box ([1, 2], 2, 3)
%!error<solid.box: U must be a geom.UCS object.> solid.box (1, 2, 3, [0, 0, 1])
%!error<solid.box: Name/Value arguments must come in pairs.> ...
%! solid.box (1, 2, 3, 'Anchor')
%!error<solid.box: unknown option 'Base'.> solid.box (1, 2, 3, 'Base', 'corner')
%!error<solid.box: option names must be character vectors.> ...
%! solid.box (1, 2, 3, geom.UCS (), 1, 'corner')
%!test  # option names ignore case
%! B = bbox (solid.box (2, 4, 6, 'anchor', 'centroid'));
%! assert_equal (B, [-1, -2, -3, 1, 2, 3], 1e-6);
%!error<solid.box: Anchor must be 'corner', 'base' or 'centroid'.> ...
%! solid.box (1, 2, 3, geom.UCS (), 'Anchor', 'top')
%!error<solid.box: Label must be an identifier: a letter followed by letters, digits or underscores.> ...
%! solid.box (1, 2, 3, 'Label', 'plate.top')
%!error<solid.box: Label must be an identifier: a letter followed by letters, digits or underscores.> ...
%! solid.box (1, 2, 3, 'Label', '2plate')
%!error<solid.box: Label must be an identifier: a letter followed by letters, digits or underscores.> ...
%! solid.box (1, 2, 3, 'Label', '')
%!error<solid.box: Label must be an identifier: a letter followed by letters, digits or underscores.> ...
%! solid.box (1, 2, 3, 'Label', 5)
