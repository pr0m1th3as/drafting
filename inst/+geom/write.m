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
## @deftypefn  {drafting} {} geom.write (@var{C}, @var{FILE})
## @deftypefnx {drafting} {} geom.write (@var{C}, @var{FILE}, @var{Name}, @var{Value}, @dots{})
##
## Write several geom objects to one DXF file.
##
## @code{geom.write (@var{C}, @var{FILE})} writes the geom objects of the
## cell array @var{C}, any mix of @code{geom.Polyline}, @code{geom.Spline},
## @code{geom.Path} and @code{geom.Region}, to @var{FILE}, which must end in
## @file{.dxf}, in one pass, as the @code{write} method of each class writes
## one: a polyline as an @code{LWPOLYLINE}, a spline as a @code{SPLINE}, a
## path as its pieces and a region as its loops, each of those bound by a
## group.  Every object keeps its @code{geom.UCS} in extended data, so
## @code{geom.read} gives back the objects that were written, in order.
##
## A DXF file is not appended to: adding to one rewrites its tables, its
## handles and its objects section, so a file is written whole, from every
## object it is to hold.  A drawing of several objects is a
## @code{draw.Drawing}, which @code{draw.Drawing.write} writes.
##
## Name/Value pairs:
##
## @table @asis
## @item @qcode{'Layer'}
## The layer, @qcode{'0'} by default: one name for every object, or a cell
## array with one name per object.
## @item @qcode{'Linetype'}
## One of the line types of @code{draw.linetype}, or any name the receiving
## program holds; @qcode{'CONTINUOUS'} by default.  One for every object, or
## a cell array of one per object.
## @item @qcode{'Colour'}
## An AutoCAD colour index from 1 to 256, 256 meaning the layer's colour,
## which is the default.  One for every object, or a cell array of one per
## object.  True colour came only with R2004.
## @item @qcode{'Fill'}
## @code{true} adds a solid @code{HATCH} over every region, written with
## its group so it reads back as part of the region; @code{false} by
## default.
## @item @qcode{'Version'}
## @qcode{'R2000'} (@code{AC1015}), the default, or @qcode{'R12'}
## (@code{AC1009}) for a program that reads nothing later.  R12 holds only
## lines and arcs, so only polylines may be written as R12; a spline, a path
## or a region is an error naming it.
## @item @qcode{'LTScale'}
## The drawing's line-type scale, 1 by default, written in the header so
## the dashes look the same wherever the file is opened.
## @end table
##
## The drawing units are millimetres.  Text is written with every character
## outside ASCII escaped as @code{\U+XXXX}, so the file reads the same
## whatever the reader's code page.
##
## @seealso{geom.read, geom.Polyline.write, geom.Spline.write,
## geom.Path.write, geom.Region.write, draw.Drawing.write}
## @end deftypefn

function write (C, FILE, varargin)

  if (nargin < 2)
    error ("geom.write: invalid number of input arguments.");
  endif
  __dxf__ ('write', FILE, C, varargin, 'geom.write');

endfunction

%!shared tmpf
%! tmpf = [tempname(), '.dxf'];

%!test  # options take one value per object
%! PL = geom.Polyline ([0, 0; 10, 0]);
%! unwind_protect
%!   geom.write ({PL, PL}, tmpf, 'Layer', {'A', 'B'}, 'Colour', {1, 3}, ...
%!               'Linetype', 'CENTER');
%!   txt = fileread (tmpf);
%!   assert_equal (numel (strfind (txt, sprintf ("\n  8\nA\n"))), 1);
%!   assert_equal (numel (strfind (txt, sprintf ("\n 62\n3\n"))), 1);
%!   assert_equal (numel (strfind (txt, sprintf ("\n  6\nCENTER\n"))), 2);
%! unwind_protect_cleanup
%!   unlink (tmpf);
%! end_unwind_protect

%!test  # a path and a region are each bound by a group
%! P = geom.Path ([0, 0; 10, 0; 10, 10]);
%! R = geom.Region (geom.Polyline ([0, 0; 6, 0; 6, 4], 'Closed', true));
%! unwind_protect
%!   geom.write ({P, R}, tmpf);
%!   assert_equal (numel (strfind (fileread (tmpf), "AcDbGroup")), 2);
%! unwind_protect_cleanup
%!   unlink (tmpf);
%! end_unwind_protect

%!test  # Fill hatches every region
%! R = geom.Region (geom.Polyline ([0, 0; 6, 0; 6, 4], 'Closed', true));
%! unwind_protect
%!   geom.write ({R, R}, tmpf, 'Fill', true);
%!   assert_equal (numel (strfind (fileread (tmpf), "AcDbHatch")), 2);
%! unwind_protect_cleanup
%!   unlink (tmpf);
%! end_unwind_protect

%!test  # an empty cell writes a readable file
%! unwind_protect
%!   geom.write ({}, tmpf);
%!   assert_equal (geom.read (tmpf), cell (1, 0));
%! unwind_protect_cleanup
%!   unlink (tmpf);
%! end_unwind_protect

%!test  # R12 for polylines
%! unwind_protect
%!   geom.write ({geom.Polyline([0, 0; 10, 0])}, tmpf, 'Version', 'R12');
%!   assert_equal (numel (strfind (fileread (tmpf), "AC1009")), 1);
%! unwind_protect_cleanup
%!   unlink (tmpf);
%! end_unwind_protect

%!error<geom.write: invalid number of input arguments.> geom.write ({})
%!error<geom.write: FILE must be a non-empty character vector.> ...
%! geom.write ({}, 1)
%!error<geom.write: FILE must end in .dxf.> geom.write ({}, 'a.txt')
%!error<geom.write: C must be a cell array of geom.Polyline, geom.Spline, geom.Path and geom.Region objects.> ...
%! geom.write (geom.Polyline ([0, 0; 1, 0]), 'a.dxf')
%!error<geom.write: C must be a cell array of geom.Polyline, geom.Spline, geom.Path and geom.Region objects.> ...
%! geom.write ({1}, 'a.dxf')
%!error<geom.write: Name/Value arguments must come in pairs.> ...
%! geom.write ({}, 'a.dxf', 'Layer')
%!error<geom.write: unknown parameter.> geom.write ({}, 'a.dxf', 'Size', 1)
%!error<geom.write: Layer must be a non-empty character vector or a cell array of one per object.> ...
%! geom.write ({geom.Polyline([0, 0; 1, 0])}, 'a.dxf', 'Layer', {'A', 'B'})
%!error<geom.write: Linetype must be a non-empty character vector or a cell array of one per object.> ...
%! geom.write ({geom.Polyline([0, 0; 1, 0])}, 'a.dxf', 'Linetype', 1)
%!error<geom.write: Colour must be an integer from 1 to 256 or a cell array of one per object.> ...
%! geom.write ({geom.Polyline([0, 0; 1, 0])}, 'a.dxf', 'Colour', 0)
%!error<geom.write: Fill must be a logical scalar.> ...
%! geom.write ({}, 'a.dxf', 'Fill', 2)
%!error<geom.write: Version must be 'R2000' or 'R12'.> ...
%! geom.write ({}, 'a.dxf', 'Version', 'R14')
%!error<geom.write: LTScale must be a positive finite scalar.> ...
%! geom.write ({}, 'a.dxf', 'LTScale', 0)
%!error<geom.write: R12 holds only lines and arcs, not a spline.> ...
%! geom.write ({geom.Spline([0, 0; 1, 1; 2, 0])}, 'a.dxf', 'Version', 'R12')
%!error<geom.write: R12 holds only lines and arcs, not a path.> ...
%! geom.write ({geom.Path([0, 0; 1, 0])}, 'a.dxf', 'Version', 'R12')
%!error<geom.write: R12 holds only lines and arcs, not a region.> ...
%! geom.write ({geom.Region(geom.Polyline([0, 0; 1, 0; 1, 1], 'Closed', ...
%!                                         true))}, 'a.dxf', 'Version', 'R12')
