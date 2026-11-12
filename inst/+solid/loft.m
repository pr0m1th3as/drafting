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
## @deftypefnx {drafting} {@var{S} =} solid.loft (@dots{}, @qcode{'Label'}, @var{L})
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
## The option @qcode{'Label'} names the faces of the loft, so that a later step
## finds a face by its name with @code{solid.Shape.faces}.  @var{L} is a valid
## Octave identifier or keyword, and the faces are named @var{L}@code{.start},
## the first section, @var{L}@code{.end}, the last, @var{L}@code{.side}, every
## face of the walls swept by the outlines, and @var{L}@code{.hole}, every face
## of the walls swept by the holes.
##
## Where the segments of the sections are labelled, as @code{geom.Region}
## describes, each wall also takes the labels of the segments it is lofted from,
## one level below its role: @var{L}@code{.side.web} for a wall of the outlines'
## segments labelled @code{web}, @var{L}@code{.hole.key_floor} for a wall of the
## holes' segments labelled @code{key_floor}.  @var{L}@code{.side} still names
## every wall of the outlines, and a wall lofted only from segments left unnamed
## is plain @var{L}@code{.side} or @var{L}@code{.hole}.  Without @qcode{'Label'}
## no face is named, whatever labels the sections carry.
##
## The sections need not have the same number of segments, so a wall may come
## from a segment of one section and from part of a segment of another.  It then
## takes the label of each, one name for each: a wall lofted from a segment
## labelled @code{front} on one section and from one labelled @code{right} on
## the next is named both @var{L}@code{.side.front} and
## @var{L}@code{.side.right}, and @code{faces} finds it by either.  Which
## segments meet on a wall is decided by Open CASCADE as it pairs the edges of
## the sections, splitting some; a segment it splits names every wall it
## reaches.
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
  opt = struct ('Ruled', false, 'Label', '');
  for ii = 1:2:numel (varargin)
    name = varargin{ii};
    val = varargin{ii+1};
    if (! ischar (name) || ! isrow (name))
      error ("solid.loft: option names must be character vectors.");
    endif
    switch (lower (name))
      case 'ruled'
        opt.Ruled = val;
      case 'label'
        opt.Label = val;
        if (! (ischar (val) && isrow (val)
               && (isvarname (val) || iskeyword (val))))
          error (strcat ("solid.loft: Label must be a valid Octave", ...
                         " identifier or keyword."));
        endif
      otherwise
        error ("solid.loft: unknown option '%s'.", name);
    endswitch
  endfor
  if (! islogical (opt.Ruled) || ! isscalar (opt.Ruled))
    error ("solid.loft: Ruled must be true or false.");
  endif

  D = cell (1, numel (REGIONS));
  for k = 1:numel (REGIONS)
    [~, D{k}] = solid.__region__ (REGIONS{k}, 'REGIONS');
  endfor
  S = solid.Shape (__occt__ ('loft', 'solid.loft', D, logical (opt.Ruled), ...
                             opt.Label));

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

%!test  # faces named start, end, side and hole
%! base = geom.Region ([-10, -10; 10, -10; 10, 10; -10, 10], ...
%!                     {[3, 0, 1; -3, 0, 1]});
%! top = geom.Region ([6, 0, 1; -6, 0, 1], {[2, 0, 1; -2, 0, 1]});
%! top.UCS = geom.UCS ([0, 0, 1], [0, 0, 30]);
%! S = solid.loft ({base, top}, 'Label', 'duct');
%! assert_equal (faces (S, 'Label', 'duct.start'), ...
%!               faces (S, 'Normal', [0, 0, -1]));
%! assert_equal (faces (S, 'Label', 'duct.end'), ...
%!               faces (S, 'Normal', [0, 0, 1]));
%! assert_equal (numel (faces (S, 'Label', 'duct')), numfaces (S));
%! assert_equal (isempty (faces (S, 'Label', 'duct.hole')), false);
%! assert_equal (isempty (faces (S, 'Label', 'duct.side')), false);

%!test  # a wall named by the segments it is lofted from
%! base = geom.Region ([-10, -10; 10, -10; 10, 10; -10, 10], ...
%!                     'Label', {'front', '', '', ''});
%! top = geom.Region ([-5, -5; 5, -5; 5, 5; -5, 5], ...
%!                    'Label', {'front', '', '', ''});
%! top.UCS = geom.UCS ([0, 0, 1], [0, 0, 30]);
%! S = solid.loft ({base, top}, 'Label', 'hood');
%! assert_equal (faces (S, 'Label', 'hood.side.front'), ...
%!               faces (S, 'Within', [-10, -10, 0, 10, -5, 30]));
%!test  # a label on one section names the wall
%! base = geom.Region ([-10, -10; 10, -10; 10, 10; -10, 10], ...
%!                     'Label', {'front', '', '', ''});
%! top = geom.Region ([-5, -5; 5, -5; 5, 5; -5, 5]);
%! top.UCS = geom.UCS ([0, 0, 1], [0, 0, 30]);
%! S = solid.loft ({base, top}, 'Ruled', true, 'Label', 'hood');
%! assert_equal (faces (S, 'Label', 'hood.side.front'), ...
%!               faces (S, 'Within', [-10, -10, 0, 10, -5, 30]));
%!test  # a wall from segments of two labels takes both
%! base = geom.Region ([-10, -10; 10, -10; 10, 10; -10, 10], ...
%!                     'Label', {'front', 'right', '', ''});
%! top = geom.Region ([-6, -6; 6, -6; 0, 6], ...
%!                    'Label', {'front', 'slope', ''});
%! top.UCS = geom.UCS ([0, 0, 1], [0, 0, 30]);
%! S = solid.loft ({base, top}, 'Label', 'hood');
%! assert_equal (numel (intersect (faces (S, 'Label', 'hood.side.front'), ...
%!                                 faces (S, 'Label', 'hood.side.right'))), 1);

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
%!error<solid.loft: Ruled must be true or false.> ...
%! solid.loft ({geom.Region([0, 0; 1, 0; 1, 1]), ...
%!              geom.Region([0, 0; 1, 0; 1, 1])}, 'Ruled', 2)
%!error<solid.loft: Ruled must be true or false.> ...
%! solid.loft ({geom.Region([0, 0; 1, 0; 1, 1]), ...
%!              geom.Region([0, 0; 1, 0; 1, 1])}, 'Ruled', 1)
%!error<solid.loft: Label must be a valid Octave identifier or keyword.> ...
%! solid.loft ({geom.Region([0, 0; 1, 0; 1, 1]), ...
%!              geom.Region([0, 0; 1, 0; 1, 1])}, 'Label', '1a')
