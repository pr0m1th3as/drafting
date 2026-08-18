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
## @deftypefn  {drafting} {@var{D} =} draw.fromentities (@var{E})
## @deftypefnx {drafting} {@var{D} =} draw.fromentities (@var{E}, @var{BLOCKS})
## @deftypefnx {drafting} {@var{D} =} draw.fromentities (@dots{}, @var{NAME}, @var{VALUE}, @dots{})
## @deftypefnx {drafting} {[@var{D}, @var{LOST}] =} draw.fromentities (@dots{})
##
## Build a drawing from an entity list, as read from a file.
##
## @code{@var{D} = draw.fromentities (@var{E})} raises the flat entity struct
## array @var{E} into a @code{draw.Drawing}, which is what makes a drawing read
## from a DXF file editable: it can then be transformed, merged into a sheet,
## dimensioned further and written out again.
##
## @code{@var{D} = draw.fromentities (@var{E}, @var{BLOCKS})} additionally
## defines the blocks that the @code{INSERT} entities of @var{E} refer to.
## @var{BLOCKS} is what the fourth output of @code{dxf.read} returns.  An
## @code{INSERT} naming a block that is not defined is reported rather than
## guessed at.
##
## This is the inverse of @code{draw.Drawing.entities}, and the pair is what
## makes a file a round trip rather than a one-way door.
##
## @subheading Name/Value pairs
##
## @multitable @columnfractions .16 .84
## @item @qcode{'Name'} @tab Name for the drawing.  Defaults to
## @qcode{'imported'}.
## @end multitable
##
## @code{[@var{D}, @var{LOST}] = draw.fromentities (@dots{})} returns what
## could not be raised, as a struct array with fields @code{index},
## @code{type} and @code{reason}, in the same shape
## @code{draw.Drawing.entities} reports its own losses.  Nothing is dropped
## silently.
##
## @subheading What comes back, and what cannot
##
## Geometry returns as itself: lines, polylines with their bulges, arcs,
## circles, text, points, and inserts of the blocks that came with them.  A
## @code{DIMENSION} returns as a dimension --- its definition points name what
## it measures, so a linear, angular, diameter or radius dimension is rebuilt
## as the method that would have made it, and it measures the geometry again
## rather than repeating a number.
##
## @strong{What was lowered on the way out does not come back.}  A hatch left
## as its boundary and fill lines, and an ellipse as a sampled polyline; a file
## records no memory of either having been anything else.  They return as the
## lines and polylines they became.  That is a property of the format, not of
## this function: R12 has no @code{HATCH} and no @code{ELLIPSE} to record.
##
## So a drawing written and read back is editable geometry, with its dimensions
## intact and its hatches and ellipses reduced to the marks they made.
##
## @seealso{draw.Drawing, dxf.read, dxf.write}
## @end deftypefn

function [D, LOST] = fromentities (E, varargin)

  ## Input validation
  if (nargin < 1)
    error ("draw.fromentities: invalid number of input arguments.");
  endif
  if (! isstruct (E))
    error ("draw.fromentities: E must be a struct array of entities.");
  endif

  BLOCKS = struct ('name', {}, 'entities', {});
  if (numel (varargin) > 0 && isstruct (varargin{1}))
    BLOCKS = varargin{1};
    varargin(1) = [];
    if (! isempty (BLOCKS) ...
        && (! isfield (BLOCKS, 'name') || ! isfield (BLOCKS, 'entities')))
      error (strcat ("draw.fromentities: BLOCKS must have 'name' and", ...
                     " 'entities' fields."));
    endif
  endif
  if (mod (numel (varargin), 2) != 0)
    error ("draw.fromentities: Name/Value arguments must come in pairs.");
  endif

  opt = struct ('Name', 'imported');
  known = fieldnames (opt);
  for k = 1:2:numel (varargin)
    name = varargin{k};
    if (! ischar (name) || ! isrow (name) || ! any (strcmp (name, known)))
      error ("draw.fromentities: unknown parameter.");
    endif
    opt.(name) = varargin{k+1};
  endfor
  if (! ischar (opt.Name) || ! isrow (opt.Name))
    error ("draw.fromentities: Name must be a character vector.");
  endif

  D = draw.Drawing (opt.Name);
  LOST = struct ('index', {}, 'type', {}, 'reason', {});

  ## Blocks first, so that an INSERT has something to refer to.  A name
  ## beginning with "*" is a block the writer generated rather than one the
  ## draughtsman defined -- the picture of a dimension, above all -- and the
  ## dimension itself is raised from its definition points, so keeping the
  ## picture as well would leave the drawing carrying it twice.
  keep = true (1, numel (BLOCKS));
  for ii = 1:numel (BLOCKS)
    keep(ii) = isempty (BLOCKS(ii).name) || BLOCKS(ii).name(1) != '*';
  endfor
  BLOCKS = BLOCKS(keep);

  for ii = 1:numel (BLOCKS)
    [B, bl] = draw.fromentities (BLOCKS(ii).entities, ...
                            'Name', BLOCKS(ii).name);
    for jj = 1:numel (bl)
      LOST(end+1) = struct ('index', 0, 'type', bl(jj).type, 'reason', ...
                            sprintf ('in block %s: %s', BLOCKS(ii).name, ...
                                     bl(jj).reason));
    endfor
    D = D.block (BLOCKS(ii).name, B);
  endfor
  defined = {BLOCKS.name};

  for ii = 1:numel (E)
    e = E(ii);

    ## Layer, line type and colour are properties of the drawing at the moment
    ## an entity is appended, not arguments to the append: the replay has to
    ## set them and then draw, exactly as a draughtsman does.
    D.Layer = getfield_or (e, 'layer', '0');
    D.Linetype = getfield_or (e, 'linetype', 'CONTINUOUS');
    D.Colour = getfield_or (e, 'colour', 256);

    switch (upper (getfield_or (e, 'type', '')))

      case 'LINE'
        D = D.line (e.pts(1,:), e.pts(2,:));

      case {'POLYLINE', 'LWPOLYLINE'}
        b = getfield_or (e, 'bulge', []);
        D = D.polyline (e.pts, logical (getfield_or (e, 'closed', false)), b);

      case 'CIRCLE'
        D = D.circle (e.pts(1,:), e.radius);

      case 'ARC'
        D = D.arc (e.pts(1,:), e.radius, e.angles(1), e.angles(2));

      case 'TEXT'
        h = getfield_or (e, 'height', 2.5);
        if (isempty (h))
          h = 2.5;
        endif
        D = D.text (e.pts(1,:), e.text, h, getfield_or (e, 'rotation', 0));

      case 'POINT'
        D = D.point (e.pts(1,:));

      case 'INSERT'
        nm = getfield_or (e, 'block', '');
        if (isempty (nm) || ! any (strcmp (defined, nm)))
          LOST(end+1) = struct ('index', ii, 'type', 'INSERT', 'reason', ...
                                sprintf ('block ''%s'' is not defined', nm));
          continue;
        endif
        sc = getfield_or (e, 'radius', 1);
        if (isempty (sc))
          sc = 1;
        endif
        D = D.insert (nm, e.pts(1,:), getfield_or (e, 'rotation', 0), sc);

      case 'DIMENSION'
        [D, why] = raisedim (D, e);
        if (! isempty (why))
          LOST(end+1) = struct ('index', ii, 'type', 'DIMENSION', ...
                                'reason', why);
        endif

      otherwise
        LOST(end+1) = struct ('index', ii, 'type', ...
                              getfield_or (e, 'type', '<none>'), 'reason', ...
                              'no drawing entity of this type');

    endswitch
  endfor

  ## Leave the drawing on its defaults rather than on whatever the last entity
  ## happened to carry, so that anything appended next starts from a known
  ## state instead of inheriting the tail of an imported file.
  D.Layer = '0';
  D.Linetype = 'CONTINUOUS';
  D.Colour = 256;

endfunction

## Rebuild the dimension its definition points describe.  Which method made it
## is recoverable from the DXF type alone, which is why the type is worth
## carrying: the six points mean different things for each.
function [D, why] = raisedim (D, e)

  why = '';
  if (rows (e.pts) < 6)
    why = 'six definition points are needed to rebuild a dimension';
    return;
  endif
  lbl = getfield_or (e, 'text', '<>');
  if (strcmp (lbl, '<>'))
    lbl = '';                  # measure it again rather than repeat a number
  endif

  L = e.pts(1,:);              # a point on the dimension line
  P1 = e.pts(3,:);
  P2 = e.pts(4,:);
  Q = e.pts(5,:);

  switch (getfield_or (e, 'angles', 0))

    case 0
      ## The offset is the signed distance from the measured points out to the
      ## dimension line, along the normal of the direction measured.
      rot = getfield_or (e, 'rotation', 0);
      U = [cosd(rot), sind(rot)];
      N = [-U(2), U(1)];
      off = dot (L - P1, N);
      if (abs (rot) < 1e-9)
        dir = 'horizontal';
      elseif (abs (abs (rot) - 90) < 1e-9)
        dir = 'vertical';
      else
        dir = 'aligned';
      endif
      D = D.dim (P1, P2, off, dir, lbl);

    case 2
      V = P1;
      D = D.angdim (V, P2, e.pts(6,:), norm (L - V), lbl);

    case 3
      C = (L + Q) / 2;
      R = norm (L - Q) / 2;
      a = atan2d (L(2) - C(2), L(1) - C(1));
      D = D.diam (C, R, a, lbl);

    case 4
      R = norm (L - Q);
      a = atan2d (L(2) - Q(2), L(1) - Q(1));
      D = D.radius (Q, R, a, lbl);

    otherwise
      why = sprintf ('dimension type %g is not one this package draws', ...
                     getfield_or (e, 'angles', 0));

  endswitch

endfunction

## A field if the struct carries one, the given default otherwise.  A file may
## have been written by anything, so nothing is assumed to be present.
function v = getfield_or (s, name, dflt)

  v = dflt;
  if (isfield (s, name) && ! isempty (s.(name)))
    v = s.(name);
  endif

endfunction

%!demo
%! ## A drawing written to a file and read back is a drawing again, not a heap
%! ## of lines: `draw.fromentities` is the inverse of `entities`.
%!
%! D = draw.Drawing ('plate');
%! D = D.polyline ([0, 0; 100, 0; 100, 60; 0, 60], true).circle ([50, 30], 18);
%! D = D.dim ([0, 0], [100, 0], -15, 'horizontal').diam ([50, 30], 18, 45);
%!
%! fn = fullfile (tempdir (), 'plate.dxf');
%! [E, ~, BL] = entities (D);
%! dxf.write (fn, E, 'blocks', BL);
%! [R, ~, ~, B] = dxf.read (fn);
%! back = draw.fromentities (R, B, 'Name', 'read back')
%! delete (fn);
%!
%! ## What returned are dimensions, not the lines they were drawn as, so the
%! ## drawing can go on being edited.
%! unique ({back.Entities.type})

%!demo
%! ## The imported drawing carries on being a drawing: transform it, add to it
%! ## and write it out again.
%!
%! D = draw.Drawing ().polyline ([0, 0; 60, 0; 60, 40; 0, 40], true);
%! fn = fullfile (tempdir (), 'part.dxf');
%! dxf.write (fn, entities (D));
%! back = draw.fromentities (dxf.read (fn));
%! delete (fn);
%!
%! sheet = back.merge (back.transform ('translate', [80, 0]));
%! sheet = sheet.dim ([0, 0], [140, 0], -12, 'horizontal');
%! plot (sheet);
%! title ('imported once, placed twice, then dimensioned');

%!test  # geometry comes back as itself
%! D = draw.Drawing ().line ([0, 0], [10, 5]).circle ([3, 3], 2);
%! D = D.arc ([0, 0], 4, 10, 80).point ([7, 7]).text ([1, 1], 'A', 3);
%! back = draw.fromentities (entities (D));
%! assert_equal (numentities (back), 5);
%! assert_equal (sort (unique ({back.Entities.type})), ...
%!               {'arc', 'circle', 'line', 'point', 'text'});

%!test  # a dimension returns as a dimension, not as the lines it was drawn as
%! D = draw.Drawing ().dim ([0, 0], [100, 0], -15, 'horizontal');
%! [E, ~, BL] = entities (D);
%! back = draw.fromentities (E, BL);
%! assert_equal (numentities (back), 1);
%! assert_equal (back.Entities(1).type, 'dim');
%! assert_equal (back.Entities(1).pts, [0, 0; 100, 0], 1e-9);
%! assert_equal (back.Entities(1).direction, 'horizontal');

%!test  # each family is rebuilt as the method that would have made it
%! D = draw.Drawing ().dim ([0, 0], [10, 0], -5, 'horizontal');
%! D = D.diam ([40, 0], 6, 45).radius ([60, 0], 4, 30);
%! D = D.angdim ([0, 20], [10, 20], [8, 26], 5);
%! [E, ~, BL] = entities (D);
%! back = draw.fromentities (E, BL);
%! assert_equal (sort (unique ({back.Entities.type})), ...
%!               {'angdim', 'diam', 'dim', 'radius'});

%!test  # an unlabelled dimension measures again rather than repeating a number
%! D = draw.Drawing ().dim ([0, 0], [70, 0], -10, 'horizontal');
%! back = draw.fromentities (entities (D));
%! assert_equal (isempty (back.Entities(1).text), true);

%!test  # a label the caller gave survives the round trip
%! D = draw.Drawing ().dim ([0, 0], [70, 0], -10, 'horizontal', 'MIN. 70');
%! back = draw.fromentities (entities (D));
%! assert_equal (back.Entities(1).text, 'MIN. 70');

%!test  # layer, line type and colour are replayed onto each entity
%! D = draw.Drawing ();
%! D.Layer = 'A'; D.Linetype = 'HIDDEN'; D.Colour = 1;
%! D = D.line ([0, 0], [1, 0]);
%! D.Layer = 'B'; D.Linetype = 'CENTER'; D.Colour = 3;
%! D = D.line ([0, 1], [1, 1]);
%! back = draw.fromentities (entities (D));
%! assert_equal ({back.Entities.layer}, {'A', 'B'});
%! assert_equal ({back.Entities.linetype}, {'HIDDEN', 'CENTER'});
%! assert_equal ([back.Entities.colour], [1, 3]);

%!test  # the drawing is left on its defaults, not on the last entity's state
%! D = draw.Drawing ();
%! D.Layer = 'Z'; D.Colour = 5;
%! D = D.line ([0, 0], [1, 0]);
%! back = draw.fromentities (entities (D));
%! assert_equal (back.Layer, '0');
%! assert_equal (back.Colour, 256);

%!test  # a block comes back defined, and its insert refers to it
%! bore = draw.Drawing ().circle ([0, 0], 3);
%! D = draw.Drawing ().block ('BORE', bore).insert ('BORE', [10, 0]);
%! [E, ~, BL] = entities (D, 'blocks', 'reference');
%! back = draw.fromentities (E, BL);
%! assert_equal (numel (back.Blocks), 1);
%! assert_equal (back.Blocks(1).name, 'BORE');
%! assert_equal (back.Entities(1).type, 'insert');

%!test  # a generated block is not kept: the dimension it drew is already back
%! D = draw.Drawing ().dim ([0, 0], [10, 0], -5, 'horizontal');
%! [E, ~, BL] = entities (D);
%! back = draw.fromentities (E, BL);
%! assert_equal (isempty (back.Blocks), true);

%!test  # an insert of a block that never arrived is reported, not guessed at
%! E = struct ('type', 'INSERT', 'layer', '0', 'pts', [0, 0], 'block', 'GONE');
%! [back, LOST] = draw.fromentities (E);
%! assert_equal (numentities (back), 0);
%! assert_equal (numel (LOST), 1);
%! assert_equal (LOST.type, 'INSERT');

%!test  # an entity type with no drawing equivalent is reported
%! E = struct ('type', 'SOLID', 'layer', '0', 'pts', [0, 0]);
%! [back, LOST] = draw.fromentities (E);
%! assert_equal (numentities (back), 0);
%! assert_equal (LOST.reason, 'no drawing entity of this type');

%!error<draw.fromentities: invalid number of input arguments.> ...
%! draw.fromentities ()
%!error<draw.fromentities: E must be a struct array of entities.> ...
%! draw.fromentities (42)
%!error<draw.fromentities: Name/Value arguments must come in pairs.> ...
%! draw.fromentities (struct ('type', 'POINT', 'pts', [0, 0]), 'Name')
%!error<draw.fromentities: unknown parameter.> ...
%! draw.fromentities (struct ('type', 'POINT', 'pts', [0, 0]), 'Nope', 1)
%!error<draw.fromentities: Name must be a character vector.> ...
%! draw.fromentities (struct ('type', 'POINT', 'pts', [0, 0]), 'Name', 7)
