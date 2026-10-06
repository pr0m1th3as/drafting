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
## @deftypefn  {drafting} {@var{S} =} solid.loft (@var{REGIONS})
## @deftypefnx {drafting} {@var{S} =} solid.loft (@var{REGIONS}, @qcode{'Ruled'}, @var{TF})
##
## A solid passing through regions.
##
## @code{@var{S} = solid.loft (@var{REGIONS})} returns a @code{solid.Shape}
## that passes through every @code{geom.Region} in the cell array
## @var{REGIONS}, in order, with a smooth surface between them.  This is how a
## transition is modelled: a duct from a rectangle to a circle, a tapering
## arm, a handle that swells in the middle.
##
## Each region is a section and lies where its plane puts it, so the sections
## are placed by giving the regions' planes their origins and normals.  They
## need not be parallel: a duct can turn a corner as it changes shape.  The
## outlines need not have the same number of vertices.  Their first vertices
## are joined to one another, and so are the vertices that follow, so a loft
## twists when its sections do not start at corresponding points.
##
## Every region must have the same number of holes, and hole @var{k} of one
## section flows into hole @var{k} of the next, so a duct of uniform wall is a
## loft of regions with one hole each.
##
## @code{@var{S} = solid.loft (@dots{}, @qcode{'Ruled'}, @var{TF})} joins
## consecutive sections by straight lines when @var{TF} is @code{true}, so a
## loft between polygons has flat faces and a crease at every intermediate
## section.  It is @code{false} by default, which passes one smooth surface
## through every section.  With two sections both give the same solid.
##
## @example
## @group
## ## A square of 20 at the base becoming a circle of diameter 12 at 30
## base = geom.Region ([-10, -10; 10, -10; 10, 10; -10, 10]);
## top = geom.Region ([6, 0, 1; -6, 0, 1]);
## top.UCS = geom.UCS ([0, 0, 1], [0, 0, 30]);
## S = solid.loft (@{base, top@});
## @end group
## @end example
##
## @seealso{geom.Region, solid.extrude, solid.sweep}
## @end deftypefn

function S = loft (REGIONS, varargin)

  ## Input validation
  if (nargin < 1)
    error ("solid.loft: invalid number of input arguments.");
  endif
  if (! iscell (REGIONS) || ! isvector (REGIONS) || numel (REGIONS) < 2
      || ! all (cellfun (@(r) isa (r, 'geom.Region') && isscalar (r),
                         REGIONS)))
    error (strcat ("solid.loft: REGIONS must be a cell array of at least", ...
                   " two geom.Region objects."));
  endif
  if (numel (unique (cellfun (@(r) numel (r.Holes), REGIONS))) != 1)
    error ("solid.loft: every region must have the same number of holes.");
  endif
  if (mod (numel (varargin), 2) != 0)
    error ("solid.loft: Name/Value arguments must come in pairs.");
  endif
  opt = struct ('Ruled', false);
  for ii = 1:2:numel (varargin)
    name = varargin{ii};
    val = varargin{ii+1};
    if (! ischar (name) || ! isrow (name))
      error ("solid.loft: option names must be character vectors.");
    endif
    switch (lower (name))
      case 'ruled'
        opt.Ruled = val;
      otherwise
        error ("solid.loft: unknown option '%s'.", name);
    endswitch
  endfor
  if (! (islogical (opt.Ruled) || isnumeric (opt.Ruled))
      || ! isscalar (opt.Ruled) || ! any (opt.Ruled == [0, 1]))
    error ("solid.loft: Ruled must be a logical scalar.");
  endif

  D = cell (1, numel (REGIONS));
  for k = 1:numel (REGIONS)
    [~, D{k}] = solid.__region__ (REGIONS{k}, 'REGIONS');
  endfor
  S = solid.Shape (__occt__ ('loft', 'solid.loft', D, logical (opt.Ruled)));

endfunction

## A region of the outline P and the holes H lifted to the height Z, for the
## tests
%!function R = at (P, z, H = {})
%!  R = geom.Region (P, H);
%!  R.UCS = geom.UCS ([0, 0, 1], [0, 0, z]);
%!endfunction

%!test  # a frustum of a square pyramid
%! S = solid.loft ({at([0, 0; 10, 0; 10, 10; 0, 10], 0), ...
%!                  at([2.5, 2.5; 7.5, 2.5; 7.5, 7.5; 2.5, 7.5], 10)});
%! assert_equal (volume (S), 10 / 3 * (100 + 25 + 50), 1e-9);
%! assert_equal (bbox (S), [0, 0, 0, 10, 10, 10], 1e-6);
%! assert_equal (isvalid (S), true);

%!test  # ruled through three, two frustums
%! sq = @(a) [-a, -a; a, -a; a, a; -a, a];
%! S = solid.loft ({at(sq (5), 0), at(sq (3), 5), at(sq (5), 10)}, ...
%!                 'Ruled', true);
%! assert_equal (volume (S), 2 * 5 / 3 * (100 + 36 + 60), 1e-9);
%! assert_equal (numfaces (S), 10);
%! assert_equal (isvalid (S), true);

%!test  # smooth through three, bulging outwards
%! sq = @(a) [-a, -a; a, -a; a, a; -a, a];
%! S = solid.loft ({at(sq (3), 0), at(sq (5), 5), at(sq (3), 10)});
%! assert_equal (volume (S) > 2 * 5 / 3 * (36 + 100 + 60), true);
%! assert_equal (numfaces (S), 6);
%! assert_equal (isvalid (S), true);

%!test  # equal circles give a cylinder
%! c = [5, 0, 1; -5, 0, 1];
%! S = solid.loft ({at(c, 0), at(c, 10), at(c, 20)});
%! assert_equal (volume (S), 500 * pi, -1e-8);
%! assert_equal (bbox (S), [-5, -5, 0, 5, 5, 20], 1e-6);
%! assert_equal (isvalid (S), true);

%!test  # a square becoming a circle
%! S = solid.loft ({at([-10, -10; 10, -10; 10, 10; -10, 10], 0), ...
%!                  at([6, 0, 1; -6, 0, 1], 30)});
%! assert_equal (bbox (S), [-10, -10, 0, 10, 10, 30], 1e-6);
%! assert_equal (volume (S) > 30 / 3 * (400 + 36 * pi), true);
%! assert_equal (volume (S) < 30 * 400, true);
%! assert_equal (isvalid (S), true);

%!test  # a duct of uniform wall, its hole lofted
%! sq = @(a) [-a, -a; a, -a; a, a; -a, a];
%! S = solid.loft ({at(sq (5), 0, {sq(4)}), at(sq (5), 10, {sq(4)})});
%! assert_equal (volume (S), (100 - 64) * 10, 1e-9);
%! assert_equal (isvalid (S), true);

%!test  # sections that are not parallel
%! B = at ([-5, -5; 5, -5; 5, 5; -5, 5], 0);
%! T = geom.Region ([-5, -5; 5, -5; 5, 5; -5, 5]);
%! T.UCS = geom.UCS ([1, 0, 1], [0, 0, 20]);
%! S = solid.loft ({B, T});
%! assert_equal (isvalid (S), true);
%! assert_equal (volume (S) > 0, true);

%!test  # between two closed splines
%! P = [-3, -2; 3, -2; 4, 2; 0, 4; -4, 2];
%! R = geom.Region (geom.Spline (P, 'Closed', true));
%! S = solid.loft ({R, at(geom.Spline (P, 'Closed', true), 20)}, ...
%!                 'Ruled', true);
%! assert_equal (volume (S), 20 * __area__ (R.Outline), -1e-9);
%! assert_equal (isvalid (S), true);

%!error<solid.loft: invalid number of input arguments.> solid.loft ()
%!error<solid.loft: REGIONS must be a cell array of at least two geom.Region objects.> ...
%! solid.loft (geom.Region ([0, 0; 1, 0; 1, 1]))
%!error<solid.loft: REGIONS must be a cell array of at least two geom.Region objects.> ...
%! solid.loft ({geom.Region([0, 0; 1, 0; 1, 1])})
%!error<solid.loft: REGIONS must be a cell array of at least two geom.Region objects.> ...
%! solid.loft ({geom.Region([0, 0; 1, 0; 1, 1]), [0, 0; 1, 0; 1, 1]})
%!error<solid.loft: every region must have the same number of holes.> ...
%! solid.loft ({geom.Region([0, 0; 9, 0; 9, 9; 0, 9], {[1, 1; 2, 1; 2, 2]}), ...
%!              geom.Region([0, 0; 9, 0; 9, 9; 0, 9])})
%!error<solid.loft: Name/Value arguments must come in pairs.> ...
%! solid.loft ({geom.Region([0, 0; 1, 0; 1, 1]), ...
%!              geom.Region([0, 0; 1, 0; 1, 1])}, 'Ruled')
%!error<solid.loft: unknown option 'Smooth'.> ...
%! solid.loft ({geom.Region([0, 0; 1, 0; 1, 1]), ...
%!              geom.Region([0, 0; 1, 0; 1, 1])}, 'Smooth', 1)
%!error<solid.loft: option names must be character vectors.> ...
%! solid.loft ({geom.Region([0, 0; 1, 0; 1, 1]), ...
%!              geom.Region([0, 0; 1, 0; 1, 1])}, 1, 1)
%!test  # option names ignore case
%! T = geom.Region ([0, 0; 2, 0; 2, 2]);
%! T.UCS = geom.UCS ([0, 0, 1], [0, 0, 3]);
%! R = {geom.Region([0, 0; 1, 0; 1, 1]), T};
%! assert_equal (isequal (solid.loft (R, 'ruled', true), ...
%!                       solid.loft (R, 'Ruled', true)), true);
%!error<solid.loft: Ruled must be a logical scalar.> ...
%! solid.loft ({geom.Region([0, 0; 1, 0; 1, 1]), ...
%!              geom.Region([0, 0; 1, 0; 1, 1])}, 'Ruled', 2)
