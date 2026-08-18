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
## A block that nothing places is dropped if the writer generated it and kept
## if the draughtsman defined it.  The picture of a dimension lives in a block
## whose name begins with @qcode{'*'} and to which no @code{INSERT} refers, and
## the dimension is raised from its definition points, so keeping the picture
## as well would carry it twice; the layout containers @qcode{'$MODEL_SPACE'}
## and @qcode{'$PAPER_SPACE'}, which a file defines as bookkeeping, go the same
## way.  A generated block that @emph{is} placed --- a hatch, or an anonymous
## block --- is kept, since nothing else holds its geometry.
##
## A block may itself place another.  The definitions are raised in dependency
## order, so a nested @code{INSERT} resolves, and block names are matched
## without regard to case, as a DXF reader matches them.
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
    for ii = 1:numel (BLOCKS)
      if (! ischar (BLOCKS(ii).name) || ! isrow (BLOCKS(ii).name))
        error (strcat ("draw.fromentities: each block name must be a", ...
                       " non-empty character vector."));
      endif
    endfor
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

  ## Which blocks are placed, and by what.  What decides whether a definition
  ## may be dropped is referential, not lexical: the picture of a dimension
  ## lives in a block the DIMENSION entity names in its own record and to which
  ## no INSERT ever refers, and the dimension is raised from its definition
  ## points, so keeping the picture would carry it twice.  A hatch or an
  ## anonymous block is named the same way -- with a leading "*" -- but is
  ## placed by an INSERT, and dropping it takes geometry nothing else holds.
  placed = insertnames (E);
  for ii = 1:numel (BLOCKS)
    more = insertnames (BLOCKS(ii).entities);
    placed = [placed, more];
  endfor

  keep = true (1, numel (BLOCKS));
  for ii = 1:numel (BLOCKS)
    nm = BLOCKS(ii).name;
    if (any (strcmpi (placed, nm)))
      continue;                # something places it, so something needs it
    endif
    keep(ii) = ! (nm(1) == '*' || islayout (nm));
  endfor
  BLOCKS = BLOCKS(keep);
  names = {BLOCKS.name};

  ## A block may itself place another, so raise them in dependency order:
  ## repeatedly take whichever blocks have all their own dependencies raised.
  ## A cycle -- which DXF forbids but a file may still contain -- stalls the
  ## sweep, and the remainder is then taken in file order with whatever did
  ## resolve, so this cannot spin.
  order = [];
  pending = 1:numel (BLOCKS);
  while (! isempty (pending))
    ready = false (1, numel (pending));
    for kk = 1:numel (pending)
      ready(kk) = depsraised (BLOCKS(pending(kk)).entities, names, order);
    endfor
    if (! any (ready))
      order = [order, pending];
      break;
    endif
    order = [order, pending(ready)];
    pending = pending(! ready);
  endwhile

  drawings = cell (1, numel (BLOCKS));
  for ii = order
    B = draw.Drawing (names{ii});
    deps = unique (insertnames (BLOCKS(ii).entities));
    for jj = 1:numel (deps)
      kk = find (strcmpi (names, deps{jj}), 1);
      if (! isempty (kk) && ! isempty (drawings{kk}))
        B = B.block (names{kk}, drawings{kk});
      endif
    endfor
    [drawings{ii}, bl] = replay (B, BLOCKS(ii).entities);
    for jj = 1:numel (bl)
      LOST(end+1) = struct ('index', 0, 'type', bl(jj).type, 'reason', ...
                            sprintf ('in block %s: %s', names{ii}, ...
                                     bl(jj).reason));
    endfor
  endfor

  for ii = 1:numel (BLOCKS)
    D = D.block (names{ii}, drawings{ii});
  endfor

  [D, bl] = replay (D, E);
  for jj = 1:numel (bl)
    LOST(end+1) = bl(jj);
  endfor

endfunction

## Append an entity list to a drawing, which is what raising one amounts to.
## The drawing arrives with its block table already defined, since an INSERT
## can only be appended to a drawing that holds what it places.
function [D, LOST] = replay (D, E)

  LOST = struct ('index', {}, 'type', {}, 'reason', {});
  defined = {};
  if (! isempty (D.Blocks))
    defined = {D.Blocks.name};
  endif

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
        if (isempty (nm) || ! any (strcmpi (defined, nm)))
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

## The block names an entity list places, so that no definition is dropped out
## from under a reference.
function nms = insertnames (E)

  nms = {};
  for ii = 1:numel (E)
    if (strcmpi (getfield_or (E(ii), 'type', ''), 'INSERT'))
      nm = getfield_or (E(ii), 'block', '');
      if (! isempty (nm))
        nms{end+1} = nm;
      endif
    endif
  endfor

endfunction

## Whether every block this entity list places, and that the file also defines,
## has already been raised.  A name the file never defines cannot be waited for.
function tf = depsraised (E, names, order)

  tf = true;
  deps = insertnames (E);
  for ii = 1:numel (deps)
    kk = find (strcmpi (names, deps{ii}), 1);
    if (! isempty (kk) && ! any (order == kk))
      tf = false;
      return;
    endif
  endfor

endfunction

## The layout containers a file defines as a matter of bookkeeping, empty in
## R12 since their contents are the ENTITIES section itself.  The R13 spelling,
## "*Model_Space", needs no entry here, being a generated name already.
function tf = islayout (nm)

  tf = any (strcmpi (nm, {'$MODEL_SPACE', '$PAPER_SPACE'}));

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

    case 1
      ## An aligned dimension carries no rotation of its own: its dimension
      ## line runs parallel to the two points it measures, so the direction
      ## comes from them.  We write our own aligned dimensions as type 0 with a
      ## rotation, which is why no file of ours has ever held a type 1.
      U = P2 - P1;
      if (norm (U) < 1e-12)
        why = 'an aligned dimension needs two distinct measured points';
        return;
      endif
      U = U / norm (U);
      N = [-U(2), U(1)];
      D = D.dim (P1, P2, dot (L - P1, N), 'aligned', lbl);

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

%!test  # a generated block that is placed is kept: nothing else holds it
%! fill = draw.Drawing ().line ([0, 0], [5, 5]).line ([2, 0], [7, 5]);
%! D = draw.Drawing ().block ('*X1', fill).insert ('*X1', [1, 1]);
%! [E, ~, BL] = entities (D, 'blocks', 'reference');
%! [back, LOST] = draw.fromentities (E, BL);
%! assert_equal (numel (back.Blocks), 1);
%! assert_equal (back.Blocks(1).name, '*X1');
%! assert_equal (numel (LOST), 0);

%!test  # the layout containers a file defines are not drawing content
%! none = struct ('type', {}, 'layer', {}, 'pts', {});
%! BL = struct ('name', {'$MODEL_SPACE', '$PAPER_SPACE'}, ...
%!              'entities', {none, none});
%! back = draw.fromentities (struct ('type', 'POINT', 'pts', [0, 0]), BL);
%! assert_equal (isempty (back.Blocks), true);

%!test  # a nested INSERT resolves against the block table
%! cir = struct ('type', 'CIRCLE', 'layer', '0', 'pts', [0, 0], ...
%!               'radius', 2, 'block', '');
%! lin = struct ('type', 'LINE', 'layer', '0', 'pts', [0, 0; 10, 0], ...
%!               'radius', [], 'block', '');
%! ins = struct ('type', 'INSERT', 'layer', '0', 'pts', [5, 0], ...
%!               'radius', [], 'block', 'HOLE');
%! BL = struct ('name', {'HOLE', 'PLATE'}, 'entities', {cir, [lin, ins]});
%! top = struct ('type', 'INSERT', 'layer', '0', 'pts', [0, 0], ...
%!               'radius', [], 'block', 'PLATE');
%! [back, LOST] = draw.fromentities (top, BL);
%! assert_equal (numel (LOST), 0);
%! k = find (strcmp ({back.Blocks.name}, 'PLATE'), 1);
%! assert_equal (numentities (back.Blocks(k).drawing), 2);

%!test  # a block defined after the one that places it is still raised first
%! cir = struct ('type', 'CIRCLE', 'layer', '0', 'pts', [0, 0], ...
%!               'radius', 2, 'block', '');
%! ins = struct ('type', 'INSERT', 'layer', '0', 'pts', [5, 0], ...
%!               'radius', [], 'block', 'HOLE');
%! BL = struct ('name', {'PLATE', 'HOLE'}, 'entities', {ins, cir});
%! top = struct ('type', 'INSERT', 'layer', '0', 'pts', [0, 0], ...
%!               'radius', [], 'block', 'PLATE');
%! [back, LOST] = draw.fromentities (top, BL);
%! assert_equal (numel (LOST), 0);
%! k = find (strcmp ({back.Blocks.name}, 'PLATE'), 1);
%! assert_equal (numentities (back.Blocks(k).drawing), 1);

%!test  # a block placing itself is broken rather than followed
%! ins = struct ('type', 'INSERT', 'layer', '0', 'pts', [5, 0], ...
%!               'radius', [], 'block', 'LOOP');
%! BL = struct ('name', 'LOOP', 'entities', ins);
%! [back, LOST] = draw.fromentities (ins, BL);
%! assert_equal (numentities (back), 1);
%! assert_equal (numel (LOST), 1);
%! assert_equal (LOST(1).type, 'INSERT');

%!test  # DXF matches block names without regard to case, and so does this
%! bore = draw.Drawing ().circle ([0, 0], 3);
%! D = draw.Drawing ().block ('BORE', bore).insert ('bore', [5, 5]);
%! [E, ~, BL] = entities (D, 'blocks', 'reference');
%! [back, LOST] = draw.fromentities (E, BL);
%! assert_equal (numentities (back), 1);
%! assert_equal (numel (LOST), 0);

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

%!test  # the anonymous blocks a real file places are kept, and the layout
%!      # containers it defines are not
%! fn = fullfile (fileparts (fileparts (which ('dxf.read'))), 'tests', ...
%!                'fixtures', 'foreign_dims_R12.dxf');
%! [E, ~, ~, B] = dxf.read (fn);
%! [D, LOST] = draw.fromentities (E, B);
%! assert_equal (numentities (D), 9);
%! assert_equal (numel (LOST), 0);
%! assert_equal (strjoin (sort ({D.Blocks.name}), ' '), ...
%!               '*D1 *D2 *D3 *D4 *D5 *D6 *D7');

%!test  # every dimension a real file carries comes back as a dimension
%! fn = fullfile (fileparts (fileparts (which ('dxf.read'))), 'tests', ...
%!                'fixtures', 'foreign_dims_2000.dxf');
%! [E, ~, ~, B] = dxf.read (fn);
%! [D, LOST] = draw.fromentities (E, B);
%! assert_equal (numentities (D), 9);
%! assert_equal (numel (LOST), 0);
%! assert_equal (strjoin (sort (unique ({D.Entities.type})), ' '), ...
%!               'angdim circle diam dim polyline radius');

%!test  # an aligned dimension is DXF type 1, which we never write ourselves
%! fn = fullfile (fileparts (fileparts (which ('dxf.read'))), 'tests', ...
%!                'fixtures', 'foreign_dims_2000.dxf');
%! [E, ~, ~, B] = dxf.read (fn);
%! D = draw.fromentities (E, B);
%! d = D.Entities(strcmp ({D.Entities.type}, 'dim'));
%! a = d(strcmp ({d.direction}, 'aligned'));
%! assert_equal (numel (a), 1);
%! assert_equal (norm (a.pts(2,:) - a.pts(1,:)), hypot (100, 60), 1e-9);

%!test  # the linear dimensions measure the rectangle they were drawn on
%! fn = fullfile (fileparts (fileparts (which ('dxf.read'))), 'tests', ...
%!                'fixtures', 'foreign_dims_2000.dxf');
%! [E, ~, ~, B] = dxf.read (fn);
%! D = draw.fromentities (E, B);
%! d = D.Entities(strcmp ({D.Entities.type}, 'dim'));
%! L = cellfun (@(p) norm (p(2,:) - p(1,:)), {d.pts});
%! assert_equal (sort (L), [60, 100, 100, hypot(100, 60)], 1e-9);

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
%!error<draw.fromentities: each block name must be a non-empty character vector.> ...
%! draw.fromentities (struct ('type', 'POINT', 'pts', [0, 0]), ...
%!                    struct ('name', 42, 'entities', []))
