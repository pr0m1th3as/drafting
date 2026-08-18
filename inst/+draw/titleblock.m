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
## @deftypefn  {drafting} {@var{D} =} draw.titleblock (@var{SIZE}, @var{FIELDS})
## @deftypefnx {drafting} {@var{D} =} draw.titleblock (@var{SIZE})
## @deftypefnx {drafting} {@var{SIZES} =} draw.titleblock ()
##
## A sheet frame with a title block in its corner.
##
## @code{@var{D} = draw.titleblock (@var{SIZE}, @var{FIELDS})} returns a drawing
## holding the border of a sheet of the named size and the title block in its
## bottom right corner, filled in from @var{FIELDS}.  Merge it with the drawing
## it frames.
##
## @code{@var{SIZES} = draw.titleblock ()} lists the sheet sizes.
##
## @subheading Sheet sizes
##
## The ISO A series from A4 to A0, by name, in landscape.  Every one is in
## millimetres, and the border is inset 10 mm from the trimmed edge except at
## the left, where it is inset 20 mm to leave a filing margin --- which is what
## ISO 5457 asks for and what a drawing loses if it is punched without.
##
## @subheading Fields
##
## @var{FIELDS} is a struct whose fields fill the block.  Any of @code{title},
## @code{drawing}, @code{material}, @code{scale}, @code{units}, @code{date},
## @code{drawnby} and @code{revision} is used; anything else is ignored, and
## anything absent is left blank rather than invented.
##
## The values are text and are written as given.  A scale of @qcode{'1:2'} is
## a claim about the drawing it frames, and nothing here checks it: the frame
## does not know what it was merged with.
##
## @subheading Layers
##
## Everything is placed on layer @qcode{'FRAME'}, so a caller can turn the
## border off, restyle it, or drop it before sending the geometry to a machine
## that has no use for it.
##
## @seealso{draw.Drawing, draw.coordtable, merge}
## @end deftypefn

function D = titleblock (varargin)

  ## Input validation
  if (numel (varargin) > 2)
    error ("draw.titleblock: invalid number of input arguments.");
  endif

  T = {'A4', 297, 210; 'A3', 420, 297; 'A2', 594, 420; ...
       'A1', 841, 594; 'A0', 1189, 841};

  if (numel (varargin) == 0)
    D = T(:,1)';
    return;
  endif

  SIZE = varargin{1};
  if (! ischar (SIZE) || ! isrow (SIZE))
    error ("draw.titleblock: SIZE must be a character vector.");
  endif
  k = find (strcmpi (SIZE, T(:,1)), 1);
  if (isempty (k))
    error (strcat ("draw.titleblock: '%s' is not a known sheet size; use", ...
                   " draw.titleblock () for the list."), SIZE);
  endif

  F = struct ();
  if (numel (varargin) > 1)
    F = varargin{2};
    if (! isstruct (F) || ! isscalar (F))
      error ("draw.titleblock: FIELDS must be a scalar struct.");
    endif
  endif

  W = T{k,2};
  H = T{k,3};

  D = draw.Drawing (sprintf ('%s sheet', T{k,1}));
  D.Layer = 'FRAME';

  ## Trimmed edge, then the border inset for filing
  D = D.polyline ([0, 0; W, 0; W, H; 0, H], true);
  D = D.polyline ([20, 10; W - 10, 10; W - 10, H - 10; 20, H - 10], true);

  ## The block itself, bottom right, inside the border
  bw = 180;
  bh = 56;
  x0 = W - 10 - bw;
  y0 = 10;
  D = D.polyline ([x0, y0; x0 + bw, y0; x0 + bw, y0 + bh; x0, y0 + bh], true);

  rows_ = [0, 14, 28, 42];
  for r = rows_(2:end)
    D = D.line ([x0, y0 + r], [x0 + bw, y0 + r]);
  endfor
  D = D.line ([x0 + 110, y0], [x0 + 110, y0 + 42]);

  cells = {  4, 46, 'title',    '';
             4, 30, 'drawing',  'DRG No ';
             4, 16, 'material', 'MATL ';
             4,  4, 'drawnby',  'BY ';
           114, 30, 'scale',    'SCALE ';
           114, 16, 'units',    'UNITS ';
           114,  4, 'date',     'DATE ';
           114, 46, 'revision', 'REV '};

  for c = 1:rows (cells)
    name = cells{c,3};
    if (! isfield (F, name))
      continue;
    endif
    v = F.(name);
    if (! ischar (v))
      error (strcat ("draw.titleblock: field '%s' must be a character", ...
                     " vector."), name);
    endif
    D = D.text ([x0 + cells{c,1}, y0 + cells{c,2}], [cells{c,4}, v], 3.5);
  endfor

endfunction

%!demo
%! ## A sheet frame with its title block, ready to merge with the drawing it
%! ## frames.  Everything sits on layer FRAME, so it can be dropped before the
%! ## geometry goes to a machine that has no use for it.
%!
%! draw.titleblock ()
%!
%! F = struct ('title', 'BEARING BRACKET', 'drawing', 'BRK-014', ...
%!             'material', 'EN8', 'scale', '1:1', 'units', 'mm', ...
%!             'date', '2026-08-17', 'drawnby', 'AB', 'revision', 'B');
%! sheet = draw.titleblock ('A4', F);
%!
%! part = draw.Drawing ().circle ([0, 0], 30).circle ([0, 0], 12);
%! part.Linetype = 'CENTER';
%! part.Colour = 'red';
%! part = part.centremark ();
%! sheet = sheet.merge (part.transform ('translate', [120, 120]));
%!
%! plot (sheet, 'FontSize', 6);
%! title ('an A4 sheet with its frame, block and part');

%!test  # the sizes are the ISO A series
%! S = draw.titleblock ();
%! assert_equal (iscellstr (S), true);
%! assert_equal (any (strcmp ('A3', S)), true);
%! assert_equal (numel (S), 5);

%!test  # an A3 sheet is 420 by 297
%! D = draw.titleblock ('A3');
%! [B, W, H] = bbox (D);
%! assert_equal ([W, H], [420, 297], 1e-12);

%!test  # every size is landscape, wider than tall
%! for s = draw.titleblock ()
%!   [B, W, H] = bbox (draw.titleblock (s{1}));
%!   assert_equal (W > H, true);
%! endfor

%!test  # everything sits on the frame layer, so it can be dropped
%! D = draw.titleblock ('A4', struct ('title', 'BRACKET'));
%! assert_equal (D.layers (), {'FRAME'});

%!test  # a field given is written, with its caption
%! D = draw.titleblock ('A4', struct ('drawing', 'ABC-123'));
%! txt = {D.Entities(strcmp ({D.Entities.type}, 'text')).text};
%! assert_equal (any (strcmp (txt, 'DRG No ABC-123')), true);

%!test  # a field not given is left blank rather than invented
%! D = draw.titleblock ('A4', struct ('title', 'X'));
%! txt = {D.Entities(strcmp ({D.Entities.type}, 'text')).text};
%! assert_equal (numel (txt), 1);

%!test  # an unknown field is ignored rather than refused
%! D = draw.titleblock ('A4', struct ('title', 'X', 'nonsense', 'Y'));
%! txt = {D.Entities(strcmp ({D.Entities.type}, 'text')).text};
%! assert_equal (numel (txt), 1);

%!test  # the frame merges with the drawing it frames
%! part = draw.Drawing ().circle ([200, 150], 40);
%! frame = draw.titleblock ('A3', struct ('title', 'PLATE'));
%! sheet = frame.merge (part);
%! assert_equal (numel (sheet.layers ()) >= 2, true);

%!test  # the filing margin is wider than the other three
%! D = draw.titleblock ('A4');
%! B = D.Entities(2).pts;
%! assert_equal (min (B(:,1)), 20, 1e-12);
%! assert_equal (min (B(:,2)), 10, 1e-12);

%!error<draw.titleblock: invalid number of input arguments.> ...
%! draw.titleblock ('A4', struct (), 1)
%!error<draw.titleblock: 'A9' is not a known sheet size; use draw.titleblock \(\) for the list.> ...
%! draw.titleblock ('A9')
%!error<draw.titleblock: FIELDS must be a scalar struct.> ...
%! draw.titleblock ('A4', 42)
%!error<draw.titleblock: field 'title' must be a character vector.> ...
%! draw.titleblock ('A4', struct ('title', 42))
