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
## @deftypefn {drafting} {@var{D} =} draw.read (@var{FILE})
##
## Read a drawing from an ASCII DXF file.
##
## @code{@var{D} = draw.read (@var{FILE})} returns the drawing in @var{FILE}
## as a @code{draw.Drawing} named @qcode{'imported'}, which can then be
## transformed, merged into a sheet, dimensioned further and written out
## again.  Each entity is appended on its own layer, line type and colour,
## and the drawing is left on its defaults afterwards.  The file's layer
## table comes with it into @code{Layers}: each layer's colour, line type,
## line weight, whether it is switched off or frozen, which both read as not
## visible, and whether it is printed.  An entity that takes its colour, line
## type or line weight from its layer keeps doing so, so the drawing looks as
## it did and a layer changed later changes everything on it.
##
## Geometry returns as itself: lines, points, arcs, circles, ellipses,
## polylines with their bulges, splines, text, and inserts of the blocks the
## file defines, nested blocks included.  A @code{HATCH} returns as a hatch
## over the regions it fills, its pattern, angle and spacing kept; a pattern
## the package does not define is drawn as @qcode{'ANSI31'}.  A path or a
## region the package wrote, through @code{draw.Drawing.write}, returns as
## that path or region.  An @code{MTEXT} returns as one line of text, its
## formatting removed.
##
## A @code{DIMENSION} returns as a dimension: its definition points name what
## it measures, so a linear, aligned, angular, diameter, radius or ordinate
## dimension is rebuilt as the method that would have made it, and it
## measures the geometry again rather than repeating a number.  The picture
## of a dimension lives in a block nothing places, and that block is dropped,
## as are the layout blocks a file defines; a block that is placed is kept.
##
## A drawing lies in the plane @math{z = 0}.  An entity whose normal points
## down the @math{z} axis is mirrored into the plane facing up, as 2-D CAD
## programs treat it; heights are dropped.  An entity on any other plane, a
## mesh, a solid, an entity in paper space, an insert of a block the file
## does not define and an entity type the package does not draw are skipped,
## as is the width of a polyline, which the package does not draw; whatever
## is skipped is reported in one warning, counted by entity type.
##
## Coordinates are converted to millimetres from the units the file declares
## in @code{$INSUNITS}; a file declaring none is read as millimetres.  The
## reader takes ASCII DXF from R12 (@code{AC1009}) to R2018
## (@code{AC1032}); text before R2007 is decoded from the code page the
## header names, and from R2007 on as UTF-8.  A binary DXF is an error.
##
## @seealso{draw.Drawing, draw.Drawing.write, geom.read}
## @end deftypefn

function D = read (FILE)

  if (nargin != 1)
    error ("draw.read: invalid number of input arguments.");
  endif
  [D, labels, counts] = __dxf__ ('readdraw', FILE, 'draw.read');
  if (! isempty (labels))
    msg = sprintf ("%d %s, ", [num2cell(counts); labels]{:});
    warning ("draw.read: skipped %s.", msg(1:end-2));
  endif

endfunction

%!shared tmpf
%! tmpf = [tempname(), '.dxf'];

%!test  # a drawing comes back entity for entity
%! D = draw.Drawing ('t');
%! D = D.line ([0, 0], [10, 0]).circle ([5, 5], 2).arc ([0, 0], 3, 0, 90);
%! D = D.text ([0, -5], 'NOTE', 2.5, 30).point ([1, 1]);
%! unwind_protect
%!   write (D, tmpf);
%!   R = draw.read (tmpf);
%!   assert_equal ({R.Entities.type}, {'line', 'circle', 'arc', 'text', ...
%!                                     'point'});
%!   assert_equal (R.Entities(4).angle, 30, 1e-12);
%! unwind_protect_cleanup
%!   unlink (tmpf);
%! end_unwind_protect

%!test  # layer, line type and colour come back with each entity
%! D = draw.Drawing ();
%! D.Layer = 'AXES';
%! D.Linetype = 'CENTER';
%! D.Colour = 1;
%! D = D.line ([0, 0], [10, 0]);
%! unwind_protect
%!   write (D, tmpf);
%!   R = draw.read (tmpf);
%!   assert_equal ({R.Entities.layer, R.Entities.linetype}, ...
%!                 {'AXES', 'CENTER'});
%!   assert_equal (R.Entities.colour, 1);
%!   assert_equal ({R.Layer, R.Linetype, R.Colour, R.LineWeight}, ...
%!                 {'0', 'byLayer', 256, 'byLayer'});
%! unwind_protect_cleanup
%!   unlink (tmpf);
%! end_unwind_protect

%!test  # a polyline keeps its bulges
%! PL = geom.Polyline ([0, 0, 0; 40, 0, 1; 40, 20, 0; 0, 20, 0], ...
%!                     'Closed', true);
%! unwind_protect
%!   write (draw.Drawing ().polyline (PL), tmpf);
%!   R = draw.read (tmpf);
%!   assert_equal (R.Entities.pts, PL.Vertices(:,1:2), 1e-12);
%!   assert_equal (R.Entities.bulge, [0, 1, 0, 0], 1e-12);
%! unwind_protect_cleanup
%!   unlink (tmpf);
%! end_unwind_protect

%!test  # an ellipse comes back as an ellipse
%! unwind_protect
%!   write (draw.Drawing ().ellipse ([5, 5], 10, 4, 30), tmpf);
%!   R = draw.read (tmpf);
%!   assert_equal (R.Entities.type, 'ellipse');
%!   assert_equal (R.Entities.radius, [10, 4], 1e-12);
%!   assert_equal (R.Entities.angle, 30, 1e-12);
%! unwind_protect_cleanup
%!   unlink (tmpf);
%! end_unwind_protect

%!test  # a dimension comes back as the dimension it was
%! D = draw.Drawing ().dim ([0, 0], [100, 0], -15, 'horizontal');
%! unwind_protect
%!   write (D, tmpf);
%!   R = draw.read (tmpf);
%!   assert_equal (R.Entities.type, 'dim');
%!   assert_equal (R.Entities.pts, [0, 0; 100, 0], 1e-12);
%!   assert_equal (R.Entities.offset, -15, 1e-12);
%!   assert_equal (R.Entities.direction, 'horizontal');
%! unwind_protect_cleanup
%!   unlink (tmpf);
%! end_unwind_protect

%!test  # each dimension family returns through its own method
%! D = draw.Drawing ().diam ([40, 0], 6, 45).radius ([60, 0], 4, 30);
%! D = D.angdim ([0, 20], [10, 20], [8, 26], 5);
%! D = D.ordinate ([0, 0], [20, 15], 'x', [20, -10]);
%! unwind_protect
%!   write (D, tmpf);
%!   R = draw.read (tmpf);
%!   assert_equal ({R.Entities.type}, {'diam', 'radius', 'angdim', ...
%!                                     'ordinate'});
%! unwind_protect_cleanup
%!   unlink (tmpf);
%! end_unwind_protect

%!test  # a block and its inserts come back
%! B = draw.Drawing ().circle ([0, 0], 3).line ([-4, 0], [4, 0]);
%! D = draw.Drawing ().block ('BORE', B).insert ('BORE', [10, 0], 30, 2);
%! unwind_protect
%!   write (D, tmpf);
%!   R = draw.read (tmpf);
%!   assert_equal (R.Entities.type, 'insert');
%!   assert_equal ([R.Entities.angle, R.Entities.scale], [30, 2], 1e-12);
%!   assert_equal (numentities (R.expand ()), 2);
%! unwind_protect_cleanup
%!   unlink (tmpf);
%! end_unwind_protect

%!test  # a hatch, a region and a path come back as themselves
%! R0 = geom.Region (geom.Polyline ([0, 0; 60, 0; 60, 40; 0, 40], ...
%!                                  'Closed', true));
%! D = draw.Drawing ().hatch (R0, 'ANSI37', 15, 2).region (R0);
%! D = D.path (geom.Path ([0, 0; 10, 0; 10, 10]));
%! unwind_protect
%!   write (D, tmpf);
%!   R = draw.read (tmpf);
%!   assert_equal ({R.Entities.type}, {'hatch', 'region', 'path'});
%!   assert_equal ({R.Entities(1).pattern, R.Entities(1).angle, ...
%!                  R.Entities(1).spacing}, {'ANSI37', 15, 2}, 1e-12);
%! unwind_protect_cleanup
%!   unlink (tmpf);
%! end_unwind_protect

%!test  # Greek text survives the code page
%! unwind_protect
%!   write (draw.Drawing ().text ([0, 0], 'Κλίμακα 1:2'), tmpf);
%!   R = draw.read (tmpf);
%!   assert_equal (R.Entities.text, 'Κλίμακα 1:2');
%! unwind_protect_cleanup
%!   unlink (tmpf);
%! end_unwind_protect

%!test  # an ARC whose normal points down is mirrored into the plane facing up
%! txt = ["0\nSECTION\n2\nENTITIES\n0\nARC\n8\n0\n10\n5\n20\n0\n30\n0\n" ...
%!        "40\n10\n50\n0\n51\n90\n210\n0\n220\n0\n230\n-1\n" ...
%!        "0\nENDSEC\n0\nEOF\n"];
%! fid = fopen (tmpf, 'w');
%! fputs (fid, txt);
%! fclose (fid);
%! unwind_protect
%!   R = draw.read (tmpf);
%!   assert_equal (R.Entities.pts, [-5, 0], 1e-12);
%!   assert_equal (R.Entities.angles, [90, 180], 1e-12);
%! unwind_protect_cleanup
%!   unlink (tmpf);
%! end_unwind_protect

%!test  # the anonymous blocks a real file places are kept, and the layout
%!      # containers it defines are not
%! fn = fullfile (fileparts (fileparts (which ('draw.read'))), 'tests', ...
%!                'fixtures', 'foreign_dims_R12.dxf');
%! ws = warning ('off', 'all');
%! unwind_protect
%!   D = draw.read (fn);
%!   assert_equal (numentities (D), 9);
%!   assert_equal (strjoin (sort ({D.Blocks.name}), ' '), ...
%!                 '*D1 *D2 *D3 *D4 *D5 *D6 *D7');
%! unwind_protect_cleanup
%!   warning (ws);
%! end_unwind_protect

%!test  # every dimension a real file carries comes back as a dimension
%! fn = fullfile (fileparts (fileparts (which ('draw.read'))), 'tests', ...
%!                'fixtures', 'foreign_dims_2000.dxf');
%! D = draw.read (fn);
%! assert_equal (numentities (D), 9);
%! assert_equal (strjoin (sort (unique ({D.Entities.type})), ' '), ...
%!               'angdim circle diam dim polyline radius');

%!test  # an aligned dimension is DXF type 1, which the package never writes
%! fn = fullfile (fileparts (fileparts (which ('draw.read'))), 'tests', ...
%!                'fixtures', 'foreign_dims_2000.dxf');
%! D = draw.read (fn);
%! d = D.Entities(strcmp ({D.Entities.type}, 'dim'));
%! a = d(strcmp ({d.direction}, 'aligned'));
%! assert_equal (numel (a), 1);
%! assert_equal (norm (a.pts(2,:) - a.pts(1,:)), hypot (100, 60), 1e-9);

%!test  # the linear dimensions measure the rectangle they were drawn on
%! fn = fullfile (fileparts (fileparts (which ('draw.read'))), 'tests', ...
%!                'fixtures', 'foreign_dims_2000.dxf');
%! D = draw.read (fn);
%! d = D.Entities(strcmp ({D.Entities.type}, 'dim'));
%! L = cellfun (@(p) norm (p(2,:) - p(1,:)), {d.pts});
%! assert_equal (sort (L), [60, 100, 100, hypot(100, 60)], 1e-9);

%!test  # a real file's angle between two lines is measured where they meet
%! fn = fullfile (fileparts (fileparts (which ('draw.read'))), 'tests', ...
%!                'fixtures', 'foreign_dims_2000.dxf');
%! D = draw.read (fn);
%! a = D.Entities(strcmp ({D.Entities.type}, 'angdim'));
%! assert_equal (a.pts, [0, 0; 100, 0; 100, 60], 1e-9);
%! assert_equal (a.radius, hypot (32, 9), 1e-9);
%! assert_equal (a.text, '30.96%%d');

%!test  # R14 declares no units, and is read as millimetres
%! fn = fullfile (fileparts (fileparts (which ('draw.read'))), 'tests', ...
%!                'fixtures', 'foreign_dims_R14.dxf');
%! D = draw.read (fn);
%! p = D.Entities(strcmp ({D.Entities.type}, 'polyline'));
%! assert_equal (p.pts, [0, 0; 100, 0; 100, 60; 0, 60], 1e-9);

%!test  # and a UTF-8 file, which is what R2007 onwards writes
%! fn = fullfile (fileparts (fileparts (which ('draw.read'))), 'tests', ...
%!                'fixtures', 'foreign_dims_2007.dxf');
%! D = draw.read (fn);
%! assert_equal (numentities (D), 9);
%! assert_equal (sum (strcmp ({D.Entities.type}, 'dim')), 4);

%!test  # an angle by three points comes back as it was drawn
%! unwind_protect
%!   write (draw.Drawing ().angdim ([1, 2], [10, 2], [1, 12], 5), tmpf);
%!   R = draw.read (tmpf);
%!   assert_equal (R.Entities.pts, [1, 2; 10, 2; 1, 12], 1e-12);
%!   assert_equal (R.Entities.radius, 5, 1e-12);
%! unwind_protect_cleanup
%!   unlink (tmpf);
%! end_unwind_protect

%!test  # and its explement too, which its arc point tells apart
%! unwind_protect
%!   write (draw.Drawing ().angdim ([0, 0], [0, 10], [10, 0], 5), tmpf);
%!   R = draw.read (tmpf);
%!   assert_equal (R.Entities.text, '270%%d');
%! unwind_protect_cleanup
%!   unlink (tmpf);
%! end_unwind_protect

%!test  # an x ordinate comes back with its datum, feature and leader
%! unwind_protect
%!   write (draw.Drawing ().ordinate ([1, 2], [20, 15], 'x', [20, -10]), tmpf);
%!   R = draw.read (tmpf);
%!   assert_equal (R.Entities.direction, 'x');
%!   assert_equal (R.Entities.pts, [1, 2; 20, 15; 20, -10], 1e-12);
%! unwind_protect_cleanup
%!   unlink (tmpf);
%! end_unwind_protect

%!test  # and a y ordinate as one
%! unwind_protect
%!   write (draw.Drawing ().ordinate ([0, 0], [20, 15], 'y', [-10, 15]), tmpf);
%!   R = draw.read (tmpf);
%!   assert_equal (R.Entities.direction, 'y');
%! unwind_protect_cleanup
%!   unlink (tmpf);
%! end_unwind_protect

%!warning<draw.read: skipped 2 3DFACE.> ...
%! txt = ["0\nSECTION\n2\nENTITIES\n" ...
%!        "0\n3DFACE\n8\n0\n0\n3DFACE\n8\n0\n" ...
%!        "0\nLINE\n8\n0\n10\n0\n20\n0\n11\n1\n21\n1\n" ...
%!        "0\nENDSEC\n0\nEOF\n"];
%! fid = fopen (tmpf, 'w');
%! fputs (fid, txt);
%! fclose (fid);
%! unwind_protect
%!   R = draw.read (tmpf);
%!   assert_equal (numentities (R), 1);
%! unwind_protect_cleanup
%!   unlink (tmpf);
%! end_unwind_protect

## The drawing in a file whose layer table makes HIDDEN yellow and dashed
## and OFF red and switched off, its entities ENT
%!function D = readlayers (f, ent)
%!  fid = fopen (f, 'w');
%!  fputs (fid, ["0\nSECTION\n2\nTABLES\n0\nTABLE\n2\nLAYER\n70\n2\n" ...
%!               "0\nLAYER\n2\nHIDDEN\n70\n0\n62\n2\n6\nDASHED\n" ...
%!               "0\nLAYER\n2\nOFF\n70\n0\n62\n-1\n6\nCENTER\n" ...
%!               "0\nENDTAB\n0\nENDSEC\n0\nSECTION\n2\nENTITIES\n", ent, ...
%!               "0\nENDSEC\n0\nEOF\n"]);
%!  fclose (fid);
%!  unwind_protect
%!    D = draw.read (f);
%!  unwind_protect_cleanup
%!    unlink (f);
%!  end_unwind_protect
%!endfunction

%!test  # the layer table comes back with the drawing
%! D = readlayers (tmpf, "0\nLINE\n8\nHIDDEN\n10\n0\n20\n0\n11\n10\n21\n0\n");
%! L = D.Layers(strcmp ({D.Layers.name}, 'HIDDEN'));
%! assert_equal ({L.colour, L.linetype, L.visible}, {2, 'DASHED', true});

%!test  # an entity drawn by layer stays by layer
%! D = readlayers (tmpf, "0\nLINE\n8\nHIDDEN\n10\n0\n20\n0\n11\n10\n21\n0\n");
%! assert_equal ({D.Entities.linetype, D.Entities.colour}, {'byLayer', 256});

%!test  # and is drawn in its layer's colour and line type
%! D = readlayers (tmpf, "0\nLINE\n8\nHIDDEN\n10\n0\n20\n0\n11\n10\n21\n0\n");
%! E = entities (D);
%! assert_equal ({E.linetype, E.colour}, {'DASHED', 2});

%!test  # a layer is found whatever the case of its name
%! D = readlayers (tmpf, "0\nLINE\n8\nhidden\n10\n0\n20\n0\n11\n10\n21\n0\n");
%! E = entities (D);
%! assert_equal ({E.linetype, E.colour}, {'DASHED', 2});

%!test  # an entity's own colour and line type are kept
%! D = readlayers (tmpf, ["0\nLINE\n8\nHIDDEN\n6\nCONTINUOUS\n62\n5\n" ...
%!                        "10\n0\n20\n0\n11\n10\n21\n0\n"]);
%! assert_equal ({D.Entities.linetype, D.Entities.colour}, {'CONTINUOUS', 5});

%!test  # a layer switched off is kept, and nothing on it is drawn
%! D = readlayers (tmpf, "0\nLINE\n8\nOFF\n10\n0\n20\n0\n11\n10\n21\n0\n");
%! L = D.Layers(strcmp ({D.Layers.name}, 'OFF'));
%! assert_equal ({L.colour, L.visible, numentities(D)}, {1, false, 1});
%! assert_equal (isempty (entities (D)), true);

%!test  # a layer the table does not define is added with the defaults
%! D = readlayers (tmpf, "0\nLINE\n8\nOTHER\n10\n0\n20\n0\n11\n10\n21\n0\n");
%! E = entities (D);
%! assert_equal ({E.linetype, E.colour}, {'CONTINUOUS', 7});

%!warning<draw.read: skipped 1 LWPOLYLINE width.> ...
%! D = readlayers (tmpf, ["0\nLWPOLYLINE\n8\n0\n90\n2\n70\n0\n43\n0.5\n" ...
%!                        "10\n0\n20\n0\n10\n10\n20\n0\n"]);
%! assert_equal (numentities (D), 1);

%!error<draw.read: invalid number of input arguments.> draw.read ()
%!error<draw.read: FILE must be a non-empty character vector.> draw.read (1)
%!error<draw.read: cannot find file 'no-such-file.dxf'.> ...
%! draw.read ('no-such-file.dxf')
%!error<draw.read: '.*' is empty.> ...
%! fn = [tempname(), '.dxf'];
%! fclose (fopen (fn, 'w'));
%! unwind_protect
%!   draw.read (fn);
%! unwind_protect_cleanup
%!   unlink (fn);
%! end_unwind_protect
%!error<draw.read: '.*' is malformed; line 3 is not a group code.> ...
%! fn = [tempname(), '.dxf'];
%! fid = fopen (fn, 'w');
%! fputs (fid, "0\nSECTION\nX\nY\n");
%! fclose (fid);
%! unwind_protect
%!   draw.read (fn);
%! unwind_protect_cleanup
%!   unlink (fn);
%! end_unwind_protect
