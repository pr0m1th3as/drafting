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
## @deftypefnx {drafting} {@var{D} =} draw.titleblock (@dots{}, @qcode{'Orientation'}, @var{ORIENT})
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
## The ISO A series from A4 to A0, by name, in landscape unless the option
## @qcode{'Orientation'} is @qcode{'portrait'}, which stands the sheet
## upright, as A4 usually is; or any sheet as a row @code{[@var{W},
## @var{H}]} in millimetres, used as given, with room for the frame and the
## title block, at least 210 by 76 mm.  The border is inset 10 mm from the
## trimmed edge except at the left, where it is inset 20 mm to leave a filing
## margin, which is what ISO 5457 asks for and what a drawing loses if it is
## punched without.  The title block stands in the bottom right corner of the
## frame either way.
##
## The four centring marks of ISO 5457 position the sheet when it is
## reproduced: one at each end of the sheet's two axes of symmetry, from the
## trimmed edge to 5 mm inside the frame, at the weight of the frame.  A mark
## that would run into the title block stops at the frame.
##
## @subheading Fields
##
## @var{FIELDS} is a struct whose fields fill the block.  Any of @code{title},
## @code{drawing}, @code{material}, @code{scale}, @code{units},
## @code{tolerance}, @code{date}, @code{drawnby} and @code{revision} is used;
## anything else is ignored, and anything absent is left blank rather than
## invented.
##
## The field @code{tolerance} is the general tolerance, the one every
## dimension without its own takes, such as @qcode{'ISO 2768-mK'}.  It stands
## beside the units, since both say how every dimension on the sheet is
## read, in a cell with room for about fifteen characters.
##
## The values are text and are written as given.  A scale of @qcode{'1:2'} is
## a claim about the drawing it frames, and nothing here checks it: the frame
## does not know what it was merged with.
##
## @subheading Layers
##
## The sheet is drawn on three layers of its own, defined with the line
## weights of ISO 5457 and ISO 128, so it prints correctly as it is:
##
## @table @asis
## @item @qcode{'FRAME'}
## The border and the outline of the title block, 0.7 mm, the weight ISO
## 5457 asks of a border.
## @item @qcode{'TITLE'}
## The rules and the text inside the title block, 0.25 mm.
## @item @qcode{'SHEET'}
## The trimmed edge of the paper, shown on screen and not printed, since on
## paper it is the edge itself.
## @end table
##
## Merged first, as a sheet is built, the frame keeps these definitions: a
## layer several drawings have keeps the properties of the first.  Change
## them afterwards with @code{draw.Drawing.layer}, or drop the three layers
## before sending the geometry to a machine that has no use for them.
##
## @seealso{draw.Drawing, draw.coordtable, draw.Drawing.merge}
## @end deftypefn

function D = titleblock (varargin)

  T = {'A4', 297, 210; 'A3', 420, 297; 'A2', 594, 420; ...
       'A1', 841, 594; 'A0', 1189, 841};

  if (numel (varargin) == 0)
    D = T(:,1)';
    return;
  endif

  SIZE = varargin{1};
  F = struct ();
  opts = varargin(2:end);
  if (! isempty (opts) && ! ischar (opts{1}))
    F = opts{1};
    opts = opts(2:end);
    if (! isstruct (F) || ! isscalar (F))
      error ("draw.titleblock: FIELDS must be a scalar struct.");
    endif
  endif
  if (mod (numel (opts), 2) != 0)
    error ("draw.titleblock: Name/Value arguments must come in pairs.");
  endif
  ORIENT = '';
  for ii = 1:2:numel (opts)
    name = opts{ii};
    if (! ischar (name) || ! isrow (name))
      error ("draw.titleblock: option names must be character vectors.");
    endif
    switch (lower (name))
      case 'orientation'
        ORIENT = opts{ii+1};
        if (! (ischar (ORIENT) && isrow (ORIENT)
               && any (strcmpi (ORIENT, {'landscape', 'portrait'}))))
          error (strcat ("draw.titleblock: Orientation must be", ...
                         " 'landscape' or 'portrait'."));
        endif
        ORIENT = lower (ORIENT);
      otherwise
        error ("draw.titleblock: unknown option '%s'.", name);
    endswitch
  endfor

  if (ischar (SIZE) && isrow (SIZE))
    k = find (strcmpi (SIZE, T(:,1)), 1);
    if (isempty (k))
      error (strcat ("draw.titleblock: '%s' is not a known sheet size;", ...
                     " use draw.titleblock () for the list."), SIZE);
    endif
    W = T{k,2};
    H = T{k,3};
    if (strcmp (ORIENT, 'portrait'))
      [W, H] = deal (H, W);
    endif
    sname = T{k,1};
  elseif (isnumeric (SIZE) && isreal (SIZE) && isequal (size (SIZE), [1, 2])
          && all (isfinite (SIZE)) && all (SIZE > 0))
    if (! isempty (ORIENT))
      error (strcat ("draw.titleblock: Orientation is for a named size;", ...
                     " a sheet [W, H] is used as given."));
    endif
    W = double (SIZE(1));
    H = double (SIZE(2));
    if (W < 210 || H < 76)
      error (strcat ("draw.titleblock: SIZE must leave room for the", ...
                     " frame and the title block, at least 210 by 76 mm."));
    endif
    sname = sprintf ('%g x %g', W, H);
  else
    error (strcat ("draw.titleblock: SIZE must be a sheet name or a row", ...
                   " [W, H] in millimetres."));
  endif

  D = draw.Drawing (sprintf ('%s sheet', sname));
  D = D.layer ('SHEET', 'Plot', false);
  D = D.layer ('FRAME', 'LineWeight', 0.7);
  D = D.layer ('TITLE', 'LineWeight', 0.25);

  ## Trimmed edge, then the border inset for filing
  D.Layer = 'SHEET';
  D = D.polyline (geom.Polyline ([0, 0; W, 0; W, H; 0, H], 'Closed', true));
  D.Layer = 'FRAME';
  PL = geom.Polyline ([20, 10; W - 10, 10; W - 10, H - 10; 20, H - 10], ...
                      'Closed', true);
  D = D.polyline (PL);

  ## The block itself, bottom right, inside the border
  bw = 180;
  bh = 56;
  x0 = W - 10 - bw;
  y0 = 10;

  ## The centring marks, at the ends of the sheet's axes of symmetry, from
  ## the trimmed edge to 5 mm inside the frame, short of the title block
  reach = [15, 15, 25, 15];
  if (W / 2 > x0)
    reach(1) = 10;
  endif
  if (H / 2 < y0 + bh)
    reach(4) = 10;
  endif
  D = D.line ([W / 2, 0], [W / 2, reach(1)]);
  D = D.line ([W / 2, H], [W / 2, H - reach(2)]);
  D = D.line ([0, H / 2], [reach(3), H / 2]);
  D = D.line ([W, H / 2], [W - reach(4), H / 2]);
  PL = geom.Polyline ([x0, y0; x0 + bw, y0; x0 + bw, y0 + bh; x0, y0 + bh], ...
                      'Closed', true);
  D = D.polyline (PL);

  D.Layer = 'TITLE';
  rows_ = [0, 14, 28, 42];
  for r = rows_(2:end)
    D = D.line ([x0, y0 + r], [x0 + bw, y0 + r]);
  endfor
  D = D.line ([x0 + 110, y0], [x0 + 110, y0 + 42]);
  ## The units share their cell with the general tolerance
  D = D.line ([x0 + 135, y0 + 14], [x0 + 135, y0 + 28]);

  cells = {  4, 46, 'title',     '';
             4, 30, 'drawing',   'DRG No ';
             4, 16, 'material',  'MATL ';
             4,  4, 'drawnby',   'BY ';
           114, 30, 'scale',     'SCALE ';
           114, 16, 'units',     'UNITS ';
           139, 16, 'tolerance', 'TOL ';
           114,  4, 'date',      'DATE ';
           114, 46, 'revision',  'REV '};

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
    D = D.text ([x0 + cells{c,1}, y0 + cells{c,2}], [cells{c,4}, v], ...
                'Height', 3.5);
  endfor

endfunction

%!demo
%! ## A sheet frame with its title block, ready to merge with the drawing it
%! ## frames.  The border is drawn at 0.7 mm, the title block's rules at
%! ## 0.25 mm, and the trimmed edge only on screen.
%!
%! draw.titleblock ()
%!
%! F = struct ('title', 'BEARING BRACKET', 'drawing', 'BRK-014', ...
%!             'material', 'EN8', 'scale', '1:1', 'units', 'mm', ...
%!             'tolerance', 'ISO 2768-mK', 'date', '2026-08-17', ...
%!             'drawnby', 'AB', 'revision', 'B');
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
%! [~, W, H] = bbox (draw.titleblock ('A4'));
%! assert_equal (W > H, true);
%! [~, W, H] = bbox (draw.titleblock ('A3'));
%! assert_equal (W > H, true);
%! [~, W, H] = bbox (draw.titleblock ('A2'));
%! assert_equal (W > H, true);
%! [~, W, H] = bbox (draw.titleblock ('A1'));
%! assert_equal (W > H, true);
%! [~, W, H] = bbox (draw.titleblock ('A0'));
%! assert_equal (W > H, true);

%!test  # a portrait A4 stands upright
%! [~, W, H] = bbox (draw.titleblock ('A4', 'Orientation', 'portrait'));
%! assert_equal ([W, H], [210, 297], 1e-12);

%!test  # with the title block in the bottom right corner of its frame
%! D = draw.titleblock ('A4', struct ('title', 'X'), 'Orientation', 'Portrait');
%! E = entities (D);
%! P = E(strcmp ({E.type}, 'POLYLINE'));
%! assert_equal ([min(P(3).pts); max(P(3).pts)], [20, 10; 200, 66], 1e-12);

%!test  # a sheet of any size, used as given
%! D = draw.titleblock ([500, 350]);
%! [~, W, H] = bbox (D);
%! assert_equal ([W, H], [500, 350], 1e-12);
%! assert_equal (D.Name, '500 x 350 sheet');

%!test  # four centring marks, from the trimmed edge to 5 mm inside the frame
%! E = entities (draw.titleblock ('A3'));
%! L = E(strcmp ({E.type}, 'LINE') & strcmp ({E.layer}, 'FRAME'));
%! assert_equal (numel (L), 4);
%! assert_equal (L(1).pts, [210, 0; 210, 15], 1e-12);
%! assert_equal (L(2).pts, [210, 297; 210, 282], 1e-12);
%! assert_equal (L(3).pts, [0, 148.5; 25, 148.5], 1e-12);
%! assert_equal (L(4).pts, [420, 148.5; 405, 148.5], 1e-12);

%!test  # a centring mark over the title block stops at the frame
%! E = entities (draw.titleblock ('A4'));
%! L = E(strcmp ({E.type}, 'LINE') & strcmp ({E.layer}, 'FRAME'));
%! assert_equal (L(1).pts, [148.5, 0; 148.5, 10], 1e-12);

%!test  # the sheet is drawn on three layers of its own
%! D = draw.titleblock ('A4', struct ('title', 'BRACKET'));
%! assert_equal (D.layers (), {'0', 'FRAME', 'SHEET', 'TITLE'});

%!test  # the border is drawn at 0.7 mm and the rules at 0.25 mm
%! D = draw.titleblock ('A4');
%! k = strcmp ({D.Layers.name}, 'FRAME') | strcmp ({D.Layers.name}, 'TITLE');
%! assert_equal ([D.Layers(k).lineweight], [0.7, 0.25]);

%!test  # the trimmed edge is not printed
%! D = draw.titleblock ('A4');
%! assert_equal (D.Layers(strcmp ({D.Layers.name}, 'SHEET')).plot, false);

%!test  # a field given is written, with its caption
%! D = draw.titleblock ('A4', struct ('drawing', 'ABC-123'));
%! E = entities (D);
%! txt = {E(strcmp ({E.type}, 'TEXT')).text};
%! assert_equal (any (strcmp (txt, 'DRG No ABC-123')), true);

%!test  # the general tolerance stands beside the units, in a cell of its own
%! D = draw.titleblock ('A4', struct ('units', 'mm', ...
%!                                    'tolerance', 'ISO 2768-mK'));
%! E = entities (D);
%! T = E(strcmp ({E.type}, 'TEXT'));
%! assert_equal ({T.text}, {'UNITS mm', 'TOL ISO 2768-mK'});
%! assert_equal (T(2).pts(2), T(1).pts(2), 1e-12);
%! rule = E(strcmp ({E.type}, 'LINE'))(end).pts;
%! assert_equal (T(1).pts(1) < rule(1,1) && rule(1,1) < T(2).pts(1), true);
%! assert_equal (sort (rule(:,2))', T(1).pts(2) + [-2, 12], 1e-12);

%!test  # a field not given is left blank rather than invented
%! D = draw.titleblock ('A4', struct ('title', 'X'));
%! E = entities (D);
%! txt = {E(strcmp ({E.type}, 'TEXT')).text};
%! assert_equal (numel (txt), 1);

%!test  # an unknown field is ignored rather than refused
%! D = draw.titleblock ('A4', struct ('title', 'X', 'nonsense', 'Y'));
%! E = entities (D);
%! txt = {E(strcmp ({E.type}, 'TEXT')).text};
%! assert_equal (numel (txt), 1);

%!test  # the frame merges with the drawing it frames
%! part = draw.Drawing ().circle ([200, 150], 40);
%! frame = draw.titleblock ('A3', struct ('title', 'PLATE'));
%! sheet = frame.merge (part);
%! assert_equal (numel (sheet.layers ()) >= 2, true);

%!test  # the filing margin is wider than the other three
%! D = draw.titleblock ('A4');
%! E = entities (D);
%! B = E(2).pts;
%! assert_equal (min (B(:,1)), 20, 1e-12);
%! assert_equal (min (B(:,2)), 10, 1e-12);

%!error<draw.titleblock: Name/Value arguments must come in pairs.> ...
%! draw.titleblock ('A4', struct (), 1)
%!error<draw.titleblock: option names must be character vectors.> ...
%! draw.titleblock ('A4', struct (), 1, 2)
%!error<draw.titleblock: unknown option 'Scale'.> ...
%! draw.titleblock ('A4', 'Scale', 2)
%!error<draw.titleblock: Orientation must be 'landscape' or 'portrait'.> ...
%! draw.titleblock ('A4', 'Orientation', 'upright')
%!error<draw.titleblock: Orientation is for a named size; a sheet \[W, H\] is used as given.> ...
%! draw.titleblock ([500, 350], 'Orientation', 'portrait')
%!error<draw.titleblock: SIZE must leave room for the frame and the title block, at least 210 by 76 mm.> ...
%! draw.titleblock ([200, 300])
%!error<draw.titleblock: SIZE must leave room for the frame and the title block, at least 210 by 76 mm.> ...
%! draw.titleblock ([300, 70])
%!error<draw.titleblock: SIZE must be a sheet name or a row \[W, H\] in millimetres.> ...
%! draw.titleblock ([500; 350])
%!error<draw.titleblock: SIZE must be a sheet name or a row \[W, H\] in millimetres.> ...
%! draw.titleblock ([500, -350])
%!error<draw.titleblock: 'A9' is not a known sheet size; use draw.titleblock \(\) for the list.> ...
%! draw.titleblock ('A9')
%!error<draw.titleblock: FIELDS must be a scalar struct.> ...
%! draw.titleblock ('A4', 42)
%!error<draw.titleblock: field 'title' must be a character vector.> ...
%! draw.titleblock ('A4', struct ('title', 42))
