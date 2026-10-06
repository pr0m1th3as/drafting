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
## @deftypefn  {drafting} {@var{C} =} geom.read (@var{FILE})
## @deftypefnx {drafting} {@var{C} =} geom.read (@var{FILE}, @qcode{'Layer'}, @var{LAYER})
## @deftypefnx {drafting} {@var{G} =} geom.read (@var{FILE}, @qcode{'Type'}, @var{TYPE})
## @deftypefnx {drafting} {@var{G} =} geom.read (@var{FILE}, @qcode{'Type'}, @var{TYPE}, @qcode{'Layer'}, @var{LAYER})
##
## Read geom objects from an ASCII DXF file.
##
## @code{@var{C} = geom.read (@var{FILE})} returns what is in @var{FILE}: a
## row cell array with one geom object per entity, in the order of the file,
## nothing joined and nothing reclassified.  @code{LINE}, @code{ARC},
## @code{CIRCLE}, @code{LWPOLYLINE} and a flat @code{POLYLINE} are
## @code{geom.Polyline} objects; @code{SPLINE} and @code{ELLIPSE} are
## @code{geom.Spline} objects, an ellipse as its exact rational spline; a
## @code{HATCH} gives the @code{geom.Region} objects it fills.  A
## @code{LINE} slanting in three dimensions and a 3-D @code{POLYLINE} are
## @code{geom.Path} objects, since no single plane holds them.  Text,
## dimensions, inserts, points, meshes and solids are skipped.  An empty
## file gives @code{cell (1, 0)}.
##
## A group the package wrote, through the @code{write} method of a
## @code{geom.Path} or @code{geom.Region} or through @code{geom.write}, is
## one element, the class its extended data names, so what was written is
## what is read: a closed path stays a path, the route @code{solid.sweep}
## turns into a ring, and a region keeps its holes.
##
## @strong{Frames.}  Every geom object carries a @code{geom.UCS}, which the
## package writes as extended data and reads back, for a flat object only
## where the stored axes still lie in the entity's plane.  A file without that
## data is read in any plane: an entity whose normal is the @math{z} axis in
## the world frame moved to its height, one whose normal points down the
## @math{z} axis mirrored into the plane facing up first, as 2-D CAD programs
## treat it, and any other in DXF's own frame for its plane.  Paths and
## splines are read in world coordinates.
##
## @code{@var{C} = geom.read (@var{FILE}, @qcode{'Layer'}, @var{LAYER})}
## returns only what lies on the layer @var{LAYER}, its name compared without
## regard to case, as CAD programs compare them.
##
## @code{@var{G} = geom.read (@var{FILE}, @qcode{'Type'}, @var{TYPE})}
## builds the class @var{TYPE} names and returns one object of it:
##
## @table @asis
## @item @qcode{'polyline'}
## A @code{geom.Polyline}, from one entity.
## @item @qcode{'spline'}
## A @code{geom.Spline}, from one entity.
## @item @qcode{'path'}
## A @code{geom.Path}, the entities chained end to end by
## @code{geom.Path.chain}.
## @item @qcode{'region'}
## A @code{geom.Region}, the entities chained into closed loops and the loops
## that share a plane nested by @code{geom.Region.nest}, an outline and its
## holes.
## @end table
##
## The package's own groups count as built.  Exactly one object must result.
## More than one is an error naming the layer, as is finding objects on
## several layers with no @qcode{'Layer'} given, and finding none: separate
## parts belong on separate layers, and @qcode{'Layer'} picks one.
##
## The width of a polyline is dropped, since a geom object has none.
## Whatever is skipped, the widths dropped, and with @qcode{'Type'} whatever
## is left over, are reported in one warning, counted by entity type.
##
## Coordinates are converted to millimetres from the units the file declares
## in @code{$INSUNITS}; a file declaring none is read as millimetres.  The
## reader takes ASCII DXF from R12 (@code{AC1009}) to R2018
## (@code{AC1032}).  Text before R2007 is decoded from the code page the
## header names, and from R2007 on as UTF-8.  A binary DXF is an error.
##
## @example
## @group
## R = geom.Region (geom.Polyline ([0, 0; 60, 0; 60, 40; 0, 40], ...
##                                 'Closed', true));
## f = [tempname(), '.dxf'];
## write (R, f);
## B = geom.read (f, 'Type', 'region');
## S = solid.extrude (B, 10);
## @end group
## @end example
##
## @seealso{geom.write, geom.Polyline.write, geom.Spline.write,
## geom.Path.write, geom.Region.write, draw.read}
## @end deftypefn

function C = read (FILE, varargin)

  ## Input validation
  if (nargin < 1)
    error ("geom.read: invalid number of input arguments.");
  endif
  if (! ischar (FILE) || ! isrow (FILE) || isempty (FILE))
    error ("geom.read: FILE must be a non-empty character vector.");
  endif
  if (mod (numel (varargin), 2) != 0)
    error ("geom.read: Name/Value arguments must come in pairs.");
  endif
  TYPE = '';
  LAYER = '';
  for k = 1:2:numel (varargin)
    name = varargin{k};
    if (! ischar (name) || ! isrow (name))
      error ("geom.read: unknown parameter.");
    endif
    switch (lower (name))
      case 'type'
        TYPE = varargin{k+1};
        if (! ischar (TYPE) || ! isrow (TYPE)
            || ! any (strcmpi (TYPE, {'path', 'polyline', 'region', 'spline'})))
          error (strcat ("geom.read: Type must be 'path', 'polyline',", ...
                         " 'region' or 'spline'."));
        endif
        TYPE = lower (TYPE);
      case 'layer'
        LAYER = varargin{k+1};
        if (! ischar (LAYER) || ! isrow (LAYER) || isempty (LAYER))
          error ("geom.read: Layer must be a non-empty character vector.");
        endif
      otherwise
        error ("geom.read: unknown parameter.");
    endswitch
  endfor

  [C, layers, types, labels, counts] = __dxf__ ('readgeom', FILE, ...
                                                'geom.read');

  ## Restrict to one layer
  if (! isempty (LAYER))
    on = strcmpi (layers, LAYER);
    C = C(on);
    layers = layers(on);
    types = types(on);
  endif

  if (isempty (TYPE))
    report (labels, counts);
    return;
  endif

  ## Build the class asked for, layer by layer
  keys = lower (layers);
  [names, first] = unique (keys, 'first');
  [~, order] = sort (first);
  names = names(order);
  spelt = layers(first(order));
  found = cell (1, numel (names));
  used = cell (1, numel (names));
  for ii = 1:numel (names)
    idx = find (strcmp (keys, names{ii}));
    [found{ii}, used{ii}] = build (C(idx), TYPE);
    used{ii} = idx(used{ii});
  endfor
  hit = find (! cellfun (@isempty, found));

  plural = struct ('path', 'paths', 'polyline', 'polylines', ...
                   'region', 'regions', 'spline', 'splines');
  if (isempty (hit))
    if (isempty (LAYER))
      error ("geom.read: no %s found.", TYPE);
    endif
    error ("geom.read: no %s found in layer: '%s'", TYPE, LAYER);
  endif
  if (numel (hit) > 1)
    names = sprintf ("'%s', ", spelt{hit});
    error (strcat ("geom.read: %s found in more than one layer; choose", ...
                   " one with 'Layer': %s."), plural.(TYPE), names(1:end-2));
  endif
  if (numel (found{hit}) > 1)
    error ("geom.read: more than one %s found in layer: '%s'", TYPE, ...
           spelt{hit});
  endif

  ## Whatever did not go into the object is reported with what was skipped
  left = true (1, numel (C));
  left(used{hit}) = false;
  for ii = find (left)
    k = find (strcmp (labels, types{ii}), 1);
    if (isempty (k))
      labels{end+1} = types{ii};
      counts(end+1) = 1;
    else
      counts(k) += 1;
    endif
  endfor
  report (labels, counts);
  C = found{hit}{1};

endfunction

## The objects of class TYPE that the objects C build, and which of C went
## into them
function [found, used] = build (C, TYPE)

  of = @(c) cellfun (@(o) isa (o, c), C);
  pieces = of ('geom.Polyline') | of ('geom.Spline') | of ('geom.Path');
  switch (TYPE)
    case 'polyline'
      used = find (of ('geom.Polyline'));
      found = C(used);
    case 'spline'
      used = find (of ('geom.Spline'));
      found = C(used);
    case 'path'
      used = find (pieces);
      found = {};
      if (! isempty (used))
        found = geom.Path.chain (C(used));
      endif
    case 'region'
      regions = find (of ('geom.Region'));
      closed = false (1, numel (C));
      closed(pieces) = cellfun (@(o) o.Closed, C(pieces));
      loops = C(closed);
      open = find (pieces & ! closed);
      used = [regions, find(closed)];
      if (! isempty (open))
        chains = geom.Path.chain (C(open));
        shut = cellfun (@(o) o.Closed, chains);
        loops = [loops, chains(shut)];
        if (all (shut))
          used = [used, open];
        endif
      endif
      found = C(regions);
      if (! isempty (loops))
        try
          found = [found, geom.Region.nest(loops)];
        catch err
          error ("geom.read: %s", regexprep (err.message, '^[^:]*: ', ''));
        end_try_catch
      endif
  endswitch
  used = sort (used);

endfunction

## One warning for whatever was not returned, counted by entity type
function report (labels, counts)

  if (isempty (labels))
    return;
  endif
  msg = sprintf ("%d %s, ", [num2cell(counts); labels]{:});
  warning ("geom.read: skipped %s.", msg(1:end-2));

endfunction

%!shared tmpf
%! tmpf = [tempname(), '.dxf'];

%!test  # a polyline comes back with its bulges and its frame
%! U = geom.UCS ([0, -1, 0], [5, 0, 3], [10, 0, 3]);
%! PL = geom.Polyline ([0, 0, 0; 10, 0, 1; 10, 5, 0], 'UCS', U);
%! unwind_protect
%!   write (PL, tmpf);
%!   C = geom.read (tmpf);
%!   assert_equal (numel (C), 1);
%!   assert_equal (C{1}.Vertices, PL.Vertices, 1e-12);
%!   assert_equal (C{1}.UCS.Origin, U.Origin, 1e-12);
%!   assert_equal (C{1}.UCS.XAxis, U.XAxis, 1e-12);
%! unwind_protect_cleanup
%!   [~] = unlink (tmpf);
%! end_unwind_protect

%!test  # several objects keep their classes and their order
%! PL = geom.Polyline ([0, 0; 10, 0]);
%! SP = geom.Spline ([0, 0; 10, 10; 20, 0; 30, 10]);
%! P = fillet (geom.Path ([0, 0, 0; 40, 0, 0; 40, 20, 10]), 5);
%! unwind_protect
%!   geom.write ({PL, SP, P}, tmpf);
%!   C = geom.read (tmpf);
%!   assert_equal (cellfun (@class, C, 'UniformOutput', false), ...
%!                 {'geom.Polyline', 'geom.Spline', 'geom.Path'});
%! unwind_protect_cleanup
%!   [~] = unlink (tmpf);
%! end_unwind_protect

%!test  # a closed path stays a path
%! P = fillet (geom.Path ([0, 0; 40, 0; 40, 20; 0, 20], 'Closed', true), 5);
%! unwind_protect
%!   write (P, tmpf);
%!   C = geom.read (tmpf);
%!   assert_equal (class (C{1}), 'geom.Path');
%!   assert_equal (C{1}.Closed, true);
%!   assert_equal (length (C{1}), length (P), 1e-9);
%! unwind_protect_cleanup
%!   [~] = unlink (tmpf);
%! end_unwind_protect

%!test  # a region keeps its hole
%! H = geom.Polyline ([20, 20, 1; 30, 20, 1], 'Closed', true);
%! R = geom.Region (geom.Polyline ([0, 0; 60, 0; 60, 40; 0, 40], ...
%!                                 'Closed', true), {H});
%! unwind_protect
%!   write (R, tmpf);
%!   C = geom.read (tmpf);
%!   assert_equal (numel (C), 1);
%!   assert_equal (numel (C{1}.Holes), 1);
%! unwind_protect_cleanup
%!   [~] = unlink (tmpf);
%! end_unwind_protect

%!test  # Layer selects, case-insensitively
%! PL = geom.Polyline ([0, 0; 10, 0]);
%! unwind_protect
%!   geom.write ({PL, PL, PL}, tmpf, 'Layer', {'A', 'B', 'A'});
%!   assert_equal (numel (geom.read (tmpf, 'Layer', 'a')), 2);
%! unwind_protect_cleanup
%!   [~] = unlink (tmpf);
%! end_unwind_protect

%!test  # Type 'region' chains and nests the loops of a layer
%! PL = {geom.Polyline([0, 0; 60, 0]), geom.Polyline([60, 0; 60, 40]), ...
%!       geom.Polyline([60, 40; 0, 40]), geom.Polyline([0, 40; 0, 0]), ...
%!       geom.Polyline([20, 20, 1; 30, 20, 1], 'Closed', true)};
%! unwind_protect
%!   geom.write (PL, tmpf);
%!   R = geom.read (tmpf, 'Type', 'region');
%!   assert_equal (class (R), 'geom.Region');
%!   assert_equal (numel (R.Holes), 1);
%! unwind_protect_cleanup
%!   [~] = unlink (tmpf);
%! end_unwind_protect

%!test  # Type 'path' chains reversed pieces
%! PL = {geom.Polyline([10, 0; 0, 0]), geom.Polyline([10, 0; 10, 5])};
%! unwind_protect
%!   geom.write (PL, tmpf);
%!   P = geom.read (tmpf, 'Type', 'path');
%!   assert_equal (class (P), 'geom.Path');
%!   assert_equal (length (P), 15, 1e-9);
%! unwind_protect_cleanup
%!   [~] = unlink (tmpf);
%! end_unwind_protect

%!test  # Type 'spline' takes the one spline of a layer
%! SP = geom.Spline ([0, 0; 10, 10; 20, 0]);
%! unwind_protect
%!   geom.write ({SP, geom.Polyline([0, 0; 1, 0])}, tmpf, ...
%!               'Layer', {'S', 'P'});
%!   S = geom.read (tmpf, 'Type', 'spline', 'Layer', 'S');
%!   assert_equal (S.FitPoints, SP.FitPoints, 1e-12);
%! unwind_protect_cleanup
%!   [~] = unlink (tmpf);
%! end_unwind_protect

%!warning<geom.read: skipped 1 LWPOLYLINE.> ...
%! unwind_protect
%!   geom.write ({geom.Polyline([0, 0; 1, 0]), ...
%!                geom.Spline([0, 0; 1, 1; 2, 0])}, tmpf);
%!   geom.read (tmpf, 'Type', 'spline');
%! unwind_protect_cleanup
%!   [~] = unlink (tmpf);
%! end_unwind_protect

%!test  # an ARC whose normal points down is mirrored into the plane facing up
%! txt = ["0\nSECTION\n2\nENTITIES\n0\nARC\n8\n0\n10\n0\n20\n0\n30\n0\n" ...
%!        "40\n10\n50\n0\n51\n90\n210\n0\n220\n0\n230\n-1\n" ...
%!        "0\nENDSEC\n0\nEOF\n"];
%! fid = fopen (tmpf, 'w');
%! fputs (fid, txt);
%! fclose (fid);
%! unwind_protect
%!   C = geom.read (tmpf);
%!   assert_equal (C{1}.UCS, geom.UCS ());
%!   assert_equal (C{1}.Vertices, [-10, 0, -tand(22.5); 0, 10, 0], 1e-12);
%! unwind_protect_cleanup
%!   [~] = unlink (tmpf);
%! end_unwind_protect

%!warning<geom.read: skipped 1 TEXT.> ...
%! txt = ["0\nSECTION\n2\nENTITIES\n" ...
%!        "0\nLINE\n8\n0\n10\n0\n20\n0\n30\n0\n11\n1\n21\n1\n31\n1\n" ...
%!        "0\nTEXT\n8\n0\n10\n0\n20\n0\n40\n2.5\n1\nA\n" ...
%!        "0\nENDSEC\n0\nEOF\n"];
%! fid = fopen (tmpf, 'w');
%! fputs (fid, txt);
%! fclose (fid);
%! unwind_protect
%!   C = geom.read (tmpf);
%!   assert_equal (class (C{1}), 'geom.Path');
%! unwind_protect_cleanup
%!   [~] = unlink (tmpf);
%! end_unwind_protect

%!test  # an inch file is read in millimetres
%! txt = ["0\nSECTION\n2\nHEADER\n9\n$INSUNITS\n70\n1\n0\nENDSEC\n" ...
%!        "0\nSECTION\n2\nENTITIES\n" ...
%!        "0\nLINE\n8\n0\n10\n0\n20\n0\n11\n1\n21\n0\n" ...
%!        "0\nENDSEC\n0\nEOF\n"];
%! fid = fopen (tmpf, 'w');
%! fputs (fid, txt);
%! fclose (fid);
%! unwind_protect
%!   C = geom.read (tmpf);
%!   assert_equal (C{1}.Vertices, [0, 0, 0; 25.4, 0, 0], 1e-12);
%! unwind_protect_cleanup
%!   [~] = unlink (tmpf);
%! end_unwind_protect

%!test  # a CIRCLE is a closed polyline of two half arcs
%! txt = ["0\nSECTION\n2\nENTITIES\n" ...
%!        "0\nCIRCLE\n8\n0\n10\n5\n20\n6\n30\n0\n40\n2\n" ...
%!        "0\nENDSEC\n0\nEOF\n"];
%! fid = fopen (tmpf, 'w');
%! fputs (fid, txt);
%! fclose (fid);
%! unwind_protect
%!   C = geom.read (tmpf);
%!   assert_equal (C{1}.Closed, true);
%!   assert_equal (C{1}.Vertices, [7, 6, 1; 3, 6, 1], 1e-12);
%! unwind_protect_cleanup
%!   [~] = unlink (tmpf);
%! end_unwind_protect

%!test  # a file another application wrote reads
%! fn = fullfile (fileparts (fileparts (which ('geom.read'))), 'tests', ...
%!                'fixtures', 'foreign_dims_2000.dxf');
%! ws = warning ('off', 'all');
%! unwind_protect
%!   C = geom.read (fn);
%!   assert_equal (cellfun (@class, C, 'UniformOutput', false), ...
%!                 {'geom.Polyline', 'geom.Polyline'});
%! unwind_protect_cleanup
%!   warning (ws);
%! end_unwind_protect

%!warning<geom.read: skipped 1 LWPOLYLINE width.> ...
%! fid = fopen (tmpf, 'w');
%! fputs (fid, ["0\nSECTION\n2\nENTITIES\n" ...
%!              "0\nLWPOLYLINE\n8\n0\n90\n2\n70\n0\n10\n0\n20\n0\n" ...
%!              "40\n0\n41\n1\n10\n10\n20\n0\n0\nENDSEC\n0\nEOF\n"]);
%! fclose (fid);
%! unwind_protect
%!   C = geom.read (tmpf);
%!   assert_equal (class (C{1}), 'geom.Polyline');
%! unwind_protect_cleanup
%!   [~] = unlink (tmpf);
%! end_unwind_protect

%!test  # an empty file section gives an empty row cell
%! fid = fopen (tmpf, 'w');
%! fputs (fid, "0\nSECTION\n2\nENTITIES\n0\nENDSEC\n0\nEOF\n");
%! fclose (fid);
%! unwind_protect
%!   assert_equal (geom.read (tmpf), cell (1, 0));
%! unwind_protect_cleanup
%!   [~] = unlink (tmpf);
%! end_unwind_protect

%!error<geom.read: invalid number of input arguments.> geom.read ()
%!error<geom.read: FILE must be a non-empty character vector.> geom.read (1)
%!error<geom.read: Name/Value arguments must come in pairs.> ...
%! geom.read ('a.dxf', 'Type')
%!error<geom.read: unknown parameter.> geom.read ('a.dxf', 'Colour', 1)
%!error<geom.read: Type must be 'path', 'polyline', 'region' or 'spline'.> ...
%! geom.read ('a.dxf', 'Type', 'circle')
%!error<geom.read: Layer must be a non-empty character vector.> ...
%! geom.read ('a.dxf', 'Layer', '')
%!error<geom.read: cannot find file 'no-such-file.dxf'.> ...
%! geom.read ('no-such-file.dxf')
%!error<geom.read: no region found.> ...
%! fn = [tempname(), '.dxf'];
%! geom.write ({geom.Polyline([0, 0; 1, 0])}, fn);
%! unwind_protect
%!   geom.read (fn, 'Type', 'region');
%! unwind_protect_cleanup
%!   [~] = unlink (fn);
%! end_unwind_protect
%!error<geom.read: no spline found in layer: 'X'> ...
%! fn = [tempname(), '.dxf'];
%! geom.write ({geom.Spline([0, 0; 1, 1; 2, 0])}, fn);
%! unwind_protect
%!   geom.read (fn, 'Type', 'spline', 'Layer', 'X');
%! unwind_protect_cleanup
%!   [~] = unlink (fn);
%! end_unwind_protect
%!error<geom.read: more than one polyline found in layer: 'PLATES'> ...
%! fn = [tempname(), '.dxf'];
%! PL = geom.Polyline ([0, 0; 1, 0]);
%! geom.write ({PL, PL}, fn, 'Layer', 'PLATES');
%! unwind_protect
%!   geom.read (fn, 'Type', 'polyline');
%! unwind_protect_cleanup
%!   [~] = unlink (fn);
%! end_unwind_protect
%!error<geom.read: polylines found in more than one layer; choose one with 'Layer': 'A', 'B'.> ...
%! fn = [tempname(), '.dxf'];
%! PL = geom.Polyline ([0, 0; 1, 0]);
%! geom.write ({PL, PL}, fn, 'Layer', {'A', 'B'});
%! unwind_protect
%!   geom.read (fn, 'Type', 'polyline');
%! unwind_protect_cleanup
%!   [~] = unlink (fn);
%! end_unwind_protect
%!error<geom.read: '.*' is a binary DXF; only ASCII DXF is read.> ...
%! fn = [tempname(), '.dxf'];
%! fid = fopen (fn, 'w');
%! fputs (fid, "AutoCAD Binary DXF\r\n");
%! fclose (fid);
%! unwind_protect
%!   geom.read (fn);
%! unwind_protect_cleanup
%!   [~] = unlink (fn);
%! end_unwind_protect
