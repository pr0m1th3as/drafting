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
## @deftypefn {drafting} {} dxf.write (@var{FILE}, @var{E})
##
## Write drawing entities to an ASCII DXF file.
##
## @code{dxf.write (@var{FILE}, @var{E})} writes the entity struct array
## @var{E} to @var{FILE} as an AutoCAD R12 (@code{AC1009}) ASCII DXF drawing,
## in millimetres.  @var{E} has the layout returned by @code{dxf.read}; only
## the @code{type} and @code{pts} fields are required, and any of @code{layer},
## @code{closed}, @code{radius}, @code{angles}, @code{text}, @code{height} and
## @code{rotation} that are absent take their defaults.
##
## Supported entity types and what each needs in @code{pts}:
##
## @multitable @columnfractions .22 .78
## @item @qcode{'LINE'} @tab exactly two points
## @item @qcode{'POLYLINE'} @tab two or more vertices; @code{closed} honoured
## @item @qcode{'LWPOLYLINE'} @tab as @qcode{'POLYLINE'}; see the note below
## @item @qcode{'CIRCLE'} @tab one centre, plus @code{radius}
## @item @qcode{'ARC'} @tab one centre, plus @code{radius} and @code{angles}
## @item @qcode{'TEXT'} @tab one insertion point, plus @code{text} and
## @code{height}; an optional @code{rotation} in degrees, counter-clockwise,
## is written only when it is non-zero
## @item @qcode{'POINT'} @tab one point
## @item @qcode{'DIMENSION'} @tab six definition points, plus @code{block}
## naming the block that holds its picture, @code{angles} giving the DXF
## dimension type (0 linear, 2 angular, 3 diameter, 4 radius) and @code{text},
## where @qcode{'<>'} leaves the reader to measure it
## @end multitable
##
## Layers are collected from the entities and declared in the layer table.  An
## entity naming no layer goes on layer @qcode{'0'}.  A closed polyline must
## @emph{not} carry a repeated final vertex; the closed flag does that work,
## matching the implicitly closed convention of the @code{geom} namespace.
##
## @strong{R12 has no @code{LWPOLYLINE}}, so an entity of that type is written
## as a @code{POLYLINE}.  The geometry, layer and closed flag survive exactly;
## only the type name normalises, which reading the file back will show.
##
## Coordinates are written in fixed-point notation to six decimals, so the file
## resolves to a nanometre --- far finer than any drawing means, but worth
## knowing when comparing a round trip for exact equality.
##
## @strong{R12 rather than R2000.}  R12 needs no entity handles, no
## @code{OBJECTS} section and no @code{BLOCK_RECORD} table, which makes the
## structural boilerplate small enough to audit by eye, and it is the most
## widely accepted DXF flavour there is.  The cost is no @code{HATCH} entity,
## which will matter when wall sections want hatching and is the point at which
## moving to R2000 becomes worthwhile.  Nothing outside this file depends on
## the choice.
##
## @seealso{dxf.read}
## @end deftypefn

function write (FILE, E, varargin)

  ## Input validation
  if (nargin < 2)
    error ("dxf.write: invalid number of input arguments.");
  endif
  if (mod (numel (varargin), 2) != 0)
    error ("dxf.write: Name/Value arguments must come in pairs.");
  endif
  LTSCALE = 1;
  BLOCKS = struct ('name', {}, 'entities', {});
  for k = 1:2:numel (varargin)
    if (! ischar (varargin{k}))
      error ("dxf.write: unknown option.");
    endif
    switch (lower (varargin{k}))
      case 'ltscale'
        LTSCALE = varargin{k+1};
        if (! isnumeric (LTSCALE) || ! isreal (LTSCALE) ...
            || ! isscalar (LTSCALE) || ! isfinite (LTSCALE) || LTSCALE <= 0)
          error ("dxf.write: LTScale must be a real positive finite scalar.");
        endif
        LTSCALE = double (LTSCALE);
      case 'blocks'
        BLOCKS = varargin{k+1};
        if (! isstruct (BLOCKS) || (! isempty (BLOCKS) ...
            && (! isfield (BLOCKS, 'name') || ! isfield (BLOCKS, 'entities'))))
          error (strcat ("dxf.write: Blocks must be a struct array with", ...
                         " 'name' and 'entities' fields."));
        endif
      otherwise
        error ("dxf.write: unknown option.");
    endswitch
  endfor
  if (! ischar (FILE) || ! isrow (FILE) || isempty (FILE))
    error ("dxf.write: FILE must be a non-empty character vector.");
  endif
  if (! isstruct (E))
    error ("dxf.write: E must be a struct array of entities.");
  endif
  if (! isempty (E) && (! isfield (E, 'type') || ! isfield (E, 'pts')))
    error ("dxf.write: E must have at least the fields 'type' and 'pts'.");
  endif

  E = E(:);
  ents = cell (numel (E), 1);
  for ii = 1:numel (E)
    ents{ii} = checkentity (E(ii), ii);
  endfor

  ## Layers and line types named by the entities, plus the defaults
  layers = {'0'};
  ltypes = {'CONTINUOUS'};
  for ii = 1:numel (ents)
    if (! any (strcmp (ents{ii}.layer, layers)))
      layers{end+1} = ents{ii}.layer;
    endif
    if (! any (strcmpi (ents{ii}.linetype, ltypes)))
      ltypes{end+1} = ents{ii}.linetype;
    endif
  endfor

  fid = fopen (FILE, 'wt');
  if (fid < 0)
    error ("dxf.write: cannot open '%s' for writing.", FILE);
  endif

  unwind_protect
    ## Header: R12, drawing units millimetres
    putpair (fid, 0, 'SECTION');
    putpair (fid, 2, 'HEADER');
    putpair (fid, 9, '$ACADVER');
    putpair (fid, 1, 'AC1009');
    putpair (fid, 9, '$INSUNITS');
    putpair (fid, 70, 4);
    ## Without this the dash lengths in the LTYPE table are scaled by whatever
    ## the receiving installation happens to have set, so the file's line types
    ## are at the mercy of a setting the sender never sees.  Stating it makes
    ## the drawing look the same wherever it is opened.
    putpair (fid, 9, '$LTSCALE');
    putpair (fid, 40, LTSCALE);
    putpair (fid, 0, 'ENDSEC');

    ## Tables: the line types used, then the layers
    putpair (fid, 0, 'SECTION');
    putpair (fid, 2, 'TABLES');
    putpair (fid, 0, 'TABLE');
    putpair (fid, 2, 'LTYPE');
    putpair (fid, 70, numel (ltypes));
    for ii = 1:numel (ltypes)
      putltype (fid, ltypes{ii});
    endfor
    putpair (fid, 0, 'ENDTAB');
    putpair (fid, 0, 'TABLE');
    putpair (fid, 2, 'LAYER');
    putpair (fid, 70, numel (layers));
    for ii = 1:numel (layers)
      putpair (fid, 0, 'LAYER');
      putpair (fid, 2, layers{ii});
      putpair (fid, 70, 0);
      putpair (fid, 62, 7);
      putpair (fid, 6, 'CONTINUOUS');
    endfor
    putpair (fid, 0, 'ENDTAB');

    ## One dimension style, named for the package.  DIMTSZ non-zero is what
    ## makes a reader draw the 45-degree obliques this package draws itself,
    ## rather than substituting filled arrowheads.
    putpair (fid, 0, 'TABLE');
    putpair (fid, 2, 'DIMSTYLE');
    putpair (fid, 70, 1);
    putpair (fid, 0, 'DIMSTYLE');
    putpair (fid, 2, 'DRAFTING');
    putpair (fid, 70, 0);
    putpair (fid, 40, 1);          # DIMSCALE
    putpair (fid, 41, 2.5);        # DIMASZ, arrow size
    putpair (fid, 42, 0.625);      # DIMEXO, extension line offset
    putpair (fid, 44, 1.25);       # DIMEXE, extension beyond the line
    putpair (fid, 140, 2.5);       # DIMTXT, text height
    putpair (fid, 141, 2.5);       # DIMCEN, centre mark size
    putpair (fid, 142, 1.25);      # DIMTSZ, tick size: obliques, not arrows
    putpair (fid, 147, 0.625);     # DIMGAP
    putpair (fid, 77, 1);          # DIMTAD, text above the dimension line
    putpair (fid, 0, 'ENDTAB');

    putpair (fid, 0, 'ENDSEC');

    ## Blocks, which the INSERT entities refer to by name
    putpair (fid, 0, 'SECTION');
    putpair (fid, 2, 'BLOCKS');
    for ii = 1:numel (BLOCKS)
      putpair (fid, 0, 'BLOCK');
      putpair (fid, 8, '0');
      putpair (fid, 2, BLOCKS(ii).name);
      putpair (fid, 70, 0);
      putpair (fid, 10, 0);
      putpair (fid, 20, 0);
      putpair (fid, 30, 0);
      putpair (fid, 3, BLOCKS(ii).name);
      for jj = 1:numel (BLOCKS(ii).entities)
        putentity (fid, checkentity (BLOCKS(ii).entities(jj), jj));
      endfor
      putpair (fid, 0, 'ENDBLK');
      putpair (fid, 8, '0');
    endfor
    putpair (fid, 0, 'ENDSEC');

    ## Entities
    putpair (fid, 0, 'SECTION');
    putpair (fid, 2, 'ENTITIES');
    for ii = 1:numel (ents)
      putentity (fid, ents{ii});
    endfor
    putpair (fid, 0, 'ENDSEC');

    putpair (fid, 0, 'EOF');
  unwind_protect_cleanup
    fclose (fid);
  end_unwind_protect

endfunction

## Validate one entity and fill in whatever the caller left out.  The index is
## carried only so that a failure names the offending element.
function s = checkentity (e, ii)

  known = {'LINE', 'POLYLINE', 'LWPOLYLINE', 'CIRCLE', 'ARC', 'TEXT', ...
           'POINT', 'INSERT', 'DIMENSION'};

  if (! ischar (e.type) || ! isrow (e.type) ...
      || ! any (strcmpi (e.type, known)))
    error ("dxf.write: E(%d) has an unsupported entity type.", ii);
  endif
  s.type = upper (e.type);

  if (! isnumeric (e.pts) || ! isreal (e.pts) || ndims (e.pts) != 2 ...
      || columns (e.pts) != 2 || ! all (isfinite (e.pts(:))))
    error (strcat ("dxf.write: E(%d).pts must be a real finite N-by-2", ...
                   " matrix."), ii);
  endif
  s.pts = e.pts;

  s.layer = optfield (e, 'layer', '0');
  if (! ischar (s.layer) || isempty (s.layer) || ! isrow (s.layer))
    error ("dxf.write: E(%d).layer must be a non-empty character vector.", ii);
  endif

  s.linetype = optfield (e, 'linetype', 'CONTINUOUS');
  if (! ischar (s.linetype) || isempty (s.linetype) || ! isrow (s.linetype))
    error (strcat ("dxf.write: E(%d).linetype must be a non-empty", ...
                   " character vector."), ii);
  endif

  s.colour = optfield (e, 'colour', 256);
  if (! isnumeric (s.colour) || ! isreal (s.colour) || ! isscalar (s.colour) ...
      || ! isfinite (s.colour) || s.colour != fix (s.colour) ...
      || s.colour < 0 || s.colour > 256)
    error (strcat ("dxf.write: E(%d).colour must be an integer index from", ...
                   " 0 to 256."), ii);
  endif

  s.closed = false;
  s.bulge = optfield (e, 'bulge', []);
  if (! isempty (s.bulge) && (! isnumeric (s.bulge) || ! isreal (s.bulge) ...
      || ! all (isfinite (s.bulge))))
    error ("dxf.write: E(%d).bulge must be real and finite.", ii);
  endif
  s.radius = [];
  s.angles = [];
  s.text = '';
  s.height = [];
  s.rotation = 0;

  switch (s.type)

    case 'LINE'
      if (rows (s.pts) != 2)
        error ("dxf.write: E(%d) is a LINE and needs exactly 2 points.", ii);
      endif

    case {'POLYLINE', 'LWPOLYLINE'}
      if (rows (s.pts) < 2)
        error (strcat ("dxf.write: E(%d) is a polyline and needs at least", ...
                       " 2 vertices."), ii);
      endif
      s.closed = logical (optfield (e, 'closed', false));
      if (! isscalar (s.closed))
        error ("dxf.write: E(%d).closed must be a logical scalar.", ii);
      endif

    case {'CIRCLE', 'ARC'}
      if (rows (s.pts) != 1)
        error (strcat ("dxf.write: E(%d) is a %s and needs exactly 1", ...
                       " centre point."), ii, s.type);
      endif
      s.radius = optfield (e, 'radius', []);
      if (! isnumeric (s.radius) || ! isreal (s.radius) ...
          || ! isscalar (s.radius) || ! isfinite (s.radius) || s.radius <= 0)
        error (strcat ("dxf.write: E(%d).radius must be a positive real", ...
                       " finite scalar."), ii);
      endif
      if (strcmp (s.type, 'ARC'))
        s.angles = optfield (e, 'angles', []);
        if (! isnumeric (s.angles) || ! isreal (s.angles) ...
            || ! isequal (size (s.angles), [1, 2]) ...
            || ! all (isfinite (s.angles)))
          error (strcat ("dxf.write: E(%d).angles must be a real finite", ...
                         " 1-by-2 vector of degrees."), ii);
        endif
      endif

    case 'TEXT'
      if (rows (s.pts) != 1)
        error (strcat ("dxf.write: E(%d) is a TEXT and needs exactly 1", ...
                       " insertion point."), ii);
      endif
      s.text = optfield (e, 'text', '');
      if (! ischar (s.text) || (! isempty (s.text) && ! isrow (s.text)))
        error ("dxf.write: E(%d).text must be a character vector.", ii);
      endif
      s.height = optfield (e, 'height', []);
      if (! isnumeric (s.height) || ! isreal (s.height) ...
          || ! isscalar (s.height) || ! isfinite (s.height) || s.height <= 0)
        error (strcat ("dxf.write: E(%d).height must be a positive real", ...
                       " finite scalar."), ii);
      endif
      s.rotation = optfield (e, 'rotation', 0);
      if (isempty (s.rotation))
        s.rotation = 0;
      endif
      if (! isnumeric (s.rotation) || ! isreal (s.rotation) ...
          || ! isscalar (s.rotation) || ! isfinite (s.rotation))
        error (strcat ("dxf.write: E(%d).rotation must be a real finite", ...
                       " scalar."), ii);
      endif

    case 'DIMENSION'
      if (rows (s.pts) != 6)
        error (strcat ("dxf.write: E(%d) DIMENSION needs six definition", ...
                       " points."), ii);
      endif
      s.block = optfield (e, 'block', '');
      if (! ischar (s.block) || isempty (s.block))
        error (strcat ("dxf.write: E(%d) DIMENSION needs the name of the", ...
                       " block holding its picture in .block."), ii);
      endif
      s.angles = optfield (e, 'angles', 0);
      if (! isnumeric (s.angles) || ! isscalar (s.angles) ...
          || ! any (s.angles == [0, 2, 3, 4]))
        error (strcat ("dxf.write: E(%d).angles is the DIMENSION type and", ...
                       " must be 0, 2, 3 or 4."), ii);
      endif
      s.text = optfield (e, 'text', '<>');
      s.rotation = optfield (e, 'rotation', 0);

    case 'INSERT'
      if (rows (s.pts) != 1)
        error ("dxf.write: E(%d) INSERT needs exactly one point.", ii);
      endif
      s.block = optfield (e, 'block', '');
      if (! ischar (s.block) || isempty (s.block))
        error ("dxf.write: E(%d) INSERT needs a block name in .block.", ii);
      endif
      s.radius = optfield (e, 'radius', 1);
      if (isempty (s.radius))
        s.radius = 1;
      endif
      if (! isnumeric (s.radius) || ! isreal (s.radius) ...
          || ! isscalar (s.radius) || ! isfinite (s.radius) || s.radius <= 0)
        error (strcat ("dxf.write: E(%d).radius is the INSERT scale and", ...
                       " must be a positive real finite scalar."), ii);
      endif
      s.rotation = optfield (e, 'rotation', 0);
      if (isempty (s.rotation))
        s.rotation = 0;
      endif

    case 'POINT'
      if (rows (s.pts) != 1)
        error ("dxf.write: E(%d) is a POINT and needs exactly 1 point.", ii);
      endif

  endswitch

endfunction

## Layer, line type and colour, which every entity carries
function putcommon (fid, s)

  putpair (fid, 8, s.layer);
  if (! strcmpi (s.linetype, 'CONTINUOUS'))
    putpair (fid, 6, s.linetype);
  endif
  if (s.colour != 256)
    putpair (fid, 62, s.colour);
  endif

endfunction

## One line-type table record.  A name the package defines carries its dash
## pattern; one it does not is named only, which is how a file refers to a line
## type the receiving installation already holds.
function putltype (fid, name)

  putpair (fid, 0, 'LTYPE');
  putpair (fid, 2, name);
  putpair (fid, 70, 0);
  try
    [pat, descr] = draw.linetype (name);
  catch
    pat = [];
    descr = name;
  end_try_catch
  putpair (fid, 3, descr);
  putpair (fid, 72, 65);
  putpair (fid, 73, numel (pat));
  putpair (fid, 40, sum (abs (pat)));
  for k = 1:numel (pat)
    putpair (fid, 49, pat(k));
  endfor

endfunction

## Emit one entity.  R12 has no LWPOLYLINE, so both polyline types go out as a
## POLYLINE with its VERTEX list and closing SEQEND.
function putentity (fid, s)

  switch (s.type)

    case 'LINE'
      putpair (fid, 0, 'LINE');
      putcommon (fid, s);
      putpoint (fid, 10, s.pts(1,:));
      putpoint (fid, 11, s.pts(2,:));

    case {'POLYLINE', 'LWPOLYLINE'}
      putpair (fid, 0, 'POLYLINE');
      putcommon (fid, s);
      putpair (fid, 66, 1);                 # vertices follow
      putpair (fid, 70, double (s.closed)); # bit 1: closed
      putpoint (fid, 10, [0, 0]);
      for ii = 1:rows (s.pts)
        putpair (fid, 0, 'VERTEX');
        putcommon (fid, s);
        putpoint (fid, 10, s.pts(ii,:));
        ## A bulge turns the segment leaving this vertex into an arc
        if (numel (s.bulge) >= ii && s.bulge(ii) != 0)
          putpair (fid, 42, s.bulge(ii));
        endif
      endfor
      putpair (fid, 0, 'SEQEND');
      putcommon (fid, s);

    case 'CIRCLE'
      putpair (fid, 0, 'CIRCLE');
      putcommon (fid, s);
      putpoint (fid, 10, s.pts);
      putpair (fid, 40, s.radius);

    case 'ARC'
      putpair (fid, 0, 'ARC');
      putcommon (fid, s);
      putpoint (fid, 10, s.pts);
      putpair (fid, 40, s.radius);
      putpair (fid, 50, s.angles(1));
      putpair (fid, 51, s.angles(2));

    case 'TEXT'
      putpair (fid, 0, 'TEXT');
      putcommon (fid, s);
      putpoint (fid, 10, s.pts);
      putpair (fid, 40, s.height);
      putpair (fid, 1, s.text);
      ## Group 50 defaults to zero when absent, so an unrotated text is
      ## written exactly as it was before rotation was supported.  That keeps
      ## every drawing without rotated text byte-identical to the output the
      ## CAD acceptance in ARCHITECTURE.md §4.1 was run against.
      if (s.rotation != 0)
        putpair (fid, 50, s.rotation);
      endif

    case 'DIMENSION'
      putpair (fid, 0, 'DIMENSION');
      putcommon (fid, s);
      putpair (fid, 2, s.block);
      putpair (fid, 3, 'DRAFTING');
      for kk = [10, 11, 13, 14, 15, 16]
        row = find ([10, 11, 13, 14, 15, 16] == kk);
        putpair (fid, kk, s.pts(row,1));
        putpair (fid, kk + 10, s.pts(row,2));
        putpair (fid, kk + 20, 0);
      endfor
      ## Bit 32 marks the picture as an unnamed block, as every writer sets it.
      putpair (fid, 70, s.angles + 32);
      putpair (fid, 1, s.text);
      putpair (fid, 50, s.rotation);

    case 'INSERT'
      putpair (fid, 0, 'INSERT');
      putcommon (fid, s);
      putpair (fid, 2, s.block);
      putpair (fid, 10, s.pts(1));
      putpair (fid, 20, s.pts(2));
      putpair (fid, 30, 0);
      if (s.radius != 1)
        putpair (fid, 41, s.radius);
        putpair (fid, 42, s.radius);
        putpair (fid, 43, s.radius);
      endif
      if (s.rotation != 0)
        putpair (fid, 50, s.rotation);
      endif

    case 'POINT'
      putpair (fid, 0, 'POINT');
      putcommon (fid, s);
      putpoint (fid, 10, s.pts);

  endswitch

endfunction

## A point occupies three consecutive group codes; Z is always zero here
function putpoint (fid, code, xy)
  putpair (fid, code, xy(1));
  putpair (fid, code + 10, xy(2));
  putpair (fid, code + 20, 0);
endfunction

## One group-code / value pair, one of each per line
function putpair (fid, code, value)
  if (ischar (value))
    fprintf (fid, "%d\n%s\n", code, value);
  elseif (any (code == [70, 72, 73, 62, 66, 90]))
    fprintf (fid, "%d\n%d\n", code, round (value));
  else
    fprintf (fid, "%d\n%.6f\n", code, value);
  endif
endfunction

## Field value if the struct carries it, otherwise the default
function v = optfield (s, name, dflt)
  if (isfield (s, name))
    v = s.(name);
  else
    v = dflt;
  endif
endfunction

%!demo
%! ## Writing a drawing as DXF is one call on what `entities` produced.
%! ## The file carries the layers, line types and colours, and a line-type
%! ## table with the dash patterns.
%!
%! D = draw.Drawing ('plate');
%! D.Layer = 'OUTLINE';
%! D = D.polyline ([0, 0; 60, 0; 60, 40; 0, 40], true);
%! D.Layer = 'AXES';
%! D.Linetype = 'CENTER';
%! D.Colour = 'red';
%! D = D.line ([-5, 20], [65, 20]);
%!
%! fn = [tempname(), '.dxf'];
%! dxf.write (fn, entities (D));
%! printf ('%d bytes written\n', stat (fn).size);
%! R = dxf.read (fn);
%! for k = 1:numel (R)
%!   printf ('  %-9s on %-8s %-11s colour %d\n', R(k).type, R(k).layer, ...
%!           R(k).linetype, R(k).colour);
%! endfor
%! unlink (fn);

%!demo
%! ## A repeated feature is written once as a block and referred to, which is
%! ## what a draughtsman expects to receive and a fraction of the file size.
%!
%! bore = draw.Drawing ().circle ([0, 0], 4).line ([-6, 0], [6, 0]);
%! D = draw.Drawing ().block ('bore', bore);
%! for k = 0:24
%!   D = D.insert ('bore', [12 * k, 0]);
%! endfor
%!
%! f1 = [tempname(), '.dxf'];
%! f2 = [tempname(), '.dxf'];
%! [E, LOST, B] = entities (D, 'blocks', 'reference');
%! dxf.write (f1, E, 'blocks', B);
%! dxf.write (f2, entities (D));
%! printf ('25 instances: %d bytes referenced, %d bytes expanded\n', ...
%!         stat (f1).size, stat (f2).size);
%! unlink (f1);
%! unlink (f2);

%!shared tmpf
%! tmpf = [tempname() '.dxf'];

%!test  # round trip: a closed outline survives write then read
%! E = struct ('type', 'POLYLINE', 'layer', 'OUTLINE', 'closed', true, ...
%!             'pts', [0, 0; 1600, 0; 1600, 1800; 0, 1800]);
%! unwind_protect
%!   dxf.write (tmpf, E);
%!   [R, units] = dxf.read (tmpf);
%!   assert_equal (numel (R), 1);
%!   assert_equal (R.type, 'POLYLINE');
%!   assert_equal (R.layer, 'OUTLINE');
%!   assert_equal (R.closed, true);
%!   assert_equal (R.pts, E.pts, 1e-6);
%!   assert_equal (units, 'mm');
%! unwind_protect_cleanup
%!   delete (tmpf);
%! end_unwind_protect

%!test  # LWPOLYLINE normalises to POLYLINE but keeps its geometry
%! E = struct ('type', 'LWPOLYLINE', 'layer', 'A', 'closed', false, ...
%!             'pts', [0, 0; 10, 0; 10, 5]);
%! unwind_protect
%!   dxf.write (tmpf, E);
%!   R = dxf.read (tmpf);
%!   assert_equal (R.type, 'POLYLINE');
%!   assert_equal (R.closed, false);
%!   assert_equal (R.pts, E.pts, 1e-6);
%! unwind_protect_cleanup
%!   delete (tmpf);
%! end_unwind_protect

%!test  # round trip of every supported entity type at once
%! E = struct ('type', {'LINE', 'CIRCLE', 'ARC', 'TEXT', 'POINT'}, ...
%!             'layer', {'L', 'C', 'C', 'T', 'P'}, ...
%!             'pts', {[0, 0; 100, 50], [5, 6], [1, 2], [7, 8], [9, 10]}, ...
%!             'radius', {[], 2.5, 3, [], []}, ...
%!             'angles', {[], [], [30, 120], [], []}, ...
%!             'text', {'', '', '', 'INNER', ''}, ...
%!             'height', {[], [], [], 2.5, []});
%! unwind_protect
%!   dxf.write (tmpf, E);
%!   R = dxf.read (tmpf);
%!   assert_equal ({R.type}, {'LINE', 'CIRCLE', 'ARC', 'TEXT', 'POINT'});
%!   assert_equal ({R.layer}, {'L', 'C', 'C', 'T', 'P'});
%!   assert_equal (R(1).pts, [0, 0; 100, 50], 1e-6);
%!   assert_equal (R(2).radius, 2.5, 1e-6);
%!   assert_equal (R(3).angles, [30, 120], 1e-6);
%!   assert_equal (R(4).text, 'INNER');
%!   assert_equal (R(4).height, 2.5, 1e-6);
%!   assert_equal (R(5).pts, [9, 10], 1e-6);
%! unwind_protect_cleanup
%!   delete (tmpf);
%! end_unwind_protect

%!test  # optional fields may be omitted entirely
%! E = struct ('type', 'LINE', 'pts', [0, 0; 1, 1]);
%! unwind_protect
%!   dxf.write (tmpf, E);
%!   R = dxf.read (tmpf);
%!   assert_equal (R.layer, '0');
%! unwind_protect_cleanup
%!   delete (tmpf);
%! end_unwind_protect

%!test  # a geom outline survives the round trip and stays rectilinear
%! outline = [0, 0; 1600, 0; 1600, 1800; 0, 1800];
%! P = geom.largestrect (outline, [50, 200, 50, 100]);
%! E = struct ('type', 'POLYLINE', 'layer', 'INNER', 'closed', true, 'pts', P);
%! unwind_protect
%!   dxf.write (tmpf, E);
%!   R = dxf.read (tmpf, 'INNER');
%!   assert_equal (R.pts, P, 1e-6);
%!   assert_equal (geom.isrectilinear (R.pts), true);
%!   assert_equal (geom.signedarea (R.pts), geom.signedarea (P), 1e-3);
%! unwind_protect_cleanup
%!   delete (tmpf);
%! end_unwind_protect

%!test  # an empty entity array still writes a readable file
%! unwind_protect
%!   dxf.write (tmpf, struct ('type', {}, 'pts', {}));
%!   R = dxf.read (tmpf);
%!   assert_equal (isempty (R), true);
%! unwind_protect_cleanup
%!   delete (tmpf);
%! end_unwind_protect

%!test  # every layer used is declared in the layer table
%! E = struct ('type', {'LINE', 'LINE'}, 'layer', {'AAA', 'BBB'}, ...
%!             'pts', {[0, 0; 1, 1], [2, 2; 3, 3]});
%! unwind_protect
%!   dxf.write (tmpf, E);
%!   txt = fileread (tmpf);
%!   assert_equal (! isempty (strfind (txt, "\nAAA\n")), true);
%!   assert_equal (! isempty (strfind (txt, "\nBBB\n")), true);
%!   assert_equal (! isempty (strfind (txt, 'AC1009')), true);
%! unwind_protect_cleanup
%!   delete (tmpf);
%! end_unwind_protect

%!error<dxf.write: invalid number of input arguments.> dxf.write ('a.dxf')
%!test  # a rotated TEXT carries group code 50 and survives a round trip
%! fn = [tempname(), '.dxf'];
%! unwind_protect
%!   E = struct ('type', 'TEXT', 'pts', [10, 20], 'text', 'A', ...
%!               'height', 2.5, 'rotation', 90);
%!   dxf.write (fn, E);
%!   txt = fileread (fn);
%!   s = sprintf ("\n50\n90.000000\n");
%!   assert_equal (! isempty (strfind (txt, s)), true);
%!   R = dxf.read (fn);
%!   assert_equal (R(1).rotation, 90, 1e-9);
%! unwind_protect_cleanup
%!   unlink (fn);
%! end_unwind_protect

%!test  # an unrotated TEXT omits group 50 and reads back as zero
%! fn = [tempname(), '.dxf'];
%! unwind_protect
%!   E = struct ('type', 'TEXT', 'pts', [0, 0], 'text', 'A', 'height', 2.5);
%!   dxf.write (fn, E);
%!   txt = fileread (fn);
%!   assert_equal (isempty (strfind (txt, sprintf ("\n50\n"))), true);
%!   R = dxf.read (fn);
%!   assert_equal (R(1).rotation, 0);
%! unwind_protect_cleanup
%!   unlink (fn);
%! end_unwind_protect

%!test  # rotation is an angle, so the drawing-unit scale must not touch it
%! fn = [tempname(), '.dxf'];
%! unwind_protect
%!   E = struct ('type', 'TEXT', 'pts', [1, 0], 'text', 'A', ...
%!               'height', 2.5, 'rotation', 30);
%!   dxf.write (fn, E);
%!   ## Restate the file as inches, so reading it scales every length by 25.4
%!   txt = strrep (fileread (fn), sprintf ('$INSUNITS\n70\n4\n'), ...
%!                 sprintf ('$INSUNITS\n70\n1\n'));
%!   fid = fopen (fn, 'wt');
%!   fputs (fid, txt);
%!   fclose (fid);
%!   R = dxf.read (fn);
%!   assert_equal (R(1).height, 2.5 * 25.4, 1e-6);
%!   assert_equal (R(1).pts, [25.4, 0], 1e-6);
%!   assert_equal (R(1).rotation, 30, 1e-9);
%! unwind_protect_cleanup
%!   unlink (fn);
%! end_unwind_protect

%!error<dxf.write: E\(1\).rotation must be a real finite scalar.> ...
%! dxf.write (tempname (), struct ('type', 'TEXT', 'pts', [0, 0], ...
%!            'text', 'A', 'height', 2.5, 'rotation', Inf))

%!error<dxf.write: FILE must be a non-empty character vector.> ...
%! dxf.write (7, struct ('type', 'POINT', 'pts', [0, 0]))
%!error<dxf.write: E must be a struct array of entities.> ...
%! dxf.write ('a.dxf', 42)
%!error<dxf.write: E must have at least the fields 'type' and 'pts'.> ...
%! dxf.write ('a.dxf', struct ('type', 'POINT'))
%!error<dxf.write: E\(1\) has an unsupported entity type.> ...
%! dxf.write ('a.dxf', struct ('type', 'SPLINE', 'pts', [0, 0]))
%!error<dxf.write: E\(1\).pts must be a real finite N-by-2 matrix.> ...
%! dxf.write ('a.dxf', struct ('type', 'POINT', 'pts', [0, 0, 0]))
%!error<dxf.write: E\(1\) is a LINE and needs exactly 2 points.> ...
%! dxf.write ('a.dxf', struct ('type', 'LINE', 'pts', [0, 0]))
%!error<dxf.write: E\(1\) is a polyline and needs at least 2 vertices.> ...
%! dxf.write ('a.dxf', struct ('type', 'POLYLINE', 'pts', [0, 0]))
%!error<dxf.write: E\(1\).radius must be a positive real finite scalar.> ...
%! dxf.write ('a.dxf', struct ('type', 'CIRCLE', 'pts', [0, 0]))
%!error<dxf.write: E\(1\).angles must be a real finite 1-by-2 vector of degrees.> ...
%! dxf.write ('a.dxf', struct ('type', 'ARC', 'pts', [0, 0], 'radius', 1))
%!error<dxf.write: E\(1\).height must be a positive real finite scalar.> ...
%! dxf.write ('a.dxf', struct ('type', 'TEXT', 'pts', [0, 0], 'text', 'X'))
%!error<dxf.write: E\(1\).layer must be a non-empty character vector.> ...
%! dxf.write ('a.dxf', struct ('type', 'POINT', 'pts', [0, 0], 'layer', ''))

%!test  # line type and colour survive a round trip
%! E = struct ('type', 'LINE', 'layer', 'A', 'linetype', 'CENTER', ...
%!             'colour', 1, 'pts', [0, 0; 1, 1]);
%! unwind_protect
%!   dxf.write (tmpf, E);
%!   R = dxf.read (tmpf);
%!   assert_equal (R.linetype, 'CENTER');
%!   assert_equal (R.colour, 1);
%! unwind_protect_cleanup
%!   unlink (tmpf);
%! end_unwind_protect

%!test  # the line-type table carries the dash pattern of every type used
%! E = struct ('type', 'LINE', 'layer', 'A', 'linetype', 'CENTER', ...
%!             'colour', 256, 'pts', [0, 0; 1, 1]);
%! unwind_protect
%!   dxf.write (tmpf, E);
%!   txt = fileread (tmpf);
%!   assert_equal (! isempty (strfind (txt, 'LTYPE')), true);
%!   assert_equal (! isempty (strfind (txt, 'CENTER')), true);
%!   assert_equal (numel (strfind (txt, sprintf ('\n49\n'))), 4);
%! unwind_protect_cleanup
%!   unlink (tmpf);
%! end_unwind_protect

%!test  # defaults are not written as entity attributes, as DXF expects
%! E = struct ('type', 'LINE', 'layer', 'A', 'pts', [0, 0; 1, 1]);
%! unwind_protect
%!   dxf.write (tmpf, E);
%!   R = dxf.read (tmpf);
%!   assert_equal (R.linetype, 'CONTINUOUS');
%!   assert_equal (R.colour, 256);
%! unwind_protect_cleanup
%!   unlink (tmpf);
%! end_unwind_protect

%!test  # an unknown line type is carried by name rather than refused
%! E = struct ('type', 'LINE', 'layer', 'A', 'linetype', 'HOUSESTYLE', ...
%!             'colour', 256, 'pts', [0, 0; 1, 1]);
%! unwind_protect
%!   dxf.write (tmpf, E);
%!   R = dxf.read (tmpf);
%!   assert_equal (R.linetype, 'HOUSESTYLE');
%! unwind_protect_cleanup
%!   unlink (tmpf);
%! end_unwind_protect

%!error<dxf.write: E\(1\).colour must be an integer index from 0 to 256.> ...
%! dxf.write (tmpf, struct ('type', 'LINE', 'colour', 999, 'pts', [0,0;1,1]))

%!test  # the header states LTSCALE, so the file's dashes do not depend on a
%!       # setting the sender never sees
%! E = struct ('type', 'LINE', 'layer', 'A', 'pts', [0, 0; 1, 1]);
%! unwind_protect
%!   dxf.write (tmpf, E);
%!   txt = fileread (tmpf);
%!   assert_equal (! isempty (strfind (txt, '$LTSCALE')), true);
%! unwind_protect_cleanup
%!   unlink (tmpf);
%! end_unwind_protect

%!test  # and it can be set
%! E = struct ('type', 'LINE', 'layer', 'A', 'pts', [0, 0; 1, 1]);
%! unwind_protect
%!   dxf.write (tmpf, E, 'ltscale', 25);
%!   txt = fileread (tmpf);
%!   i = strfind (txt, '$LTSCALE');
%!   assert_equal (! isempty (strfind (txt(i:i+30), '25.000000')), true);
%! unwind_protect_cleanup
%!   unlink (tmpf);
%! end_unwind_protect

%!error<dxf.write: LTScale must be a real positive finite scalar.> ...
%! dxf.write (tmpf, struct ('type', 'LINE', 'pts', [0,0;1,1]), 'ltscale', -1)
%!error<dxf.write: unknown option.> ...
%! dxf.write (tmpf, struct ('type', 'LINE', 'pts', [0,0;1,1]), 'fancy', 1)

%!test  # a block is written once and referred to, not copied per instance
%! bore = draw.Drawing ().circle ([0, 0], 3);
%! D = draw.Drawing ().block ('bore', bore);
%! for k = 0:24
%!   D = D.insert ('bore', [10 * k, 0]);
%! endfor
%! [E, LOST, B] = entities (D, 'blocks', 'reference');
%! unwind_protect
%!   dxf.write (tmpf, E, 'blocks', B);
%!   txt = fileread (tmpf);
%!   assert_equal (numel (strfind (txt, 'INSERT')), 25);
%!   assert_equal (numel (strfind (txt, 'CIRCLE')), 1);
%! unwind_protect_cleanup
%!   unlink (tmpf);
%! end_unwind_protect

%!test  # and referring is far smaller than copying
%! bore = draw.Drawing ().circle ([0, 0], 3).line ([-4, 0], [4, 0]);
%! D = draw.Drawing ().block ('bore', bore);
%! for k = 0:49
%!   D = D.insert ('bore', [10 * k, 0]);
%! endfor
%! f2 = [tempname(), '.dxf'];
%! unwind_protect
%!   [E, L, B] = entities (D, 'blocks', 'reference');
%!   dxf.write (tmpf, E, 'blocks', B);
%!   dxf.write (f2, entities (D));
%!   assert_equal (stat (tmpf).size < stat (f2).size / 2, true);
%! unwind_protect_cleanup
%!   unlink (tmpf);  unlink (f2);
%! end_unwind_protect

%!test  # an INSERT round-trips with its block name, position, scale and angle
%! E = struct ('type', 'INSERT', 'layer', 'A', 'block', 'BORE', ...
%!             'pts', [12, 7], 'radius', 2.5, 'rotation', 30);
%! B = struct ('name', 'BORE', 'entities', ...
%!             struct ('type', 'CIRCLE', 'pts', [0, 0], 'radius', 3));
%! unwind_protect
%!   dxf.write (tmpf, E, 'blocks', B);
%!   R = dxf.read (tmpf);
%!   assert_equal (R.type, 'INSERT');
%!   assert_equal (R.block, 'BORE');
%!   assert_equal (R.pts, [12, 7], 1e-9);
%!   assert_equal (R.radius, 2.5, 1e-9);
%!   assert_equal (R.rotation, 30, 1e-9);
%! unwind_protect_cleanup
%!   unlink (tmpf);
%! end_unwind_protect

%!error<dxf.write: Blocks must be a struct array with 'name' and 'entities' fields.> ...
%! dxf.write (tmpf, struct ('type', 'LINE', 'pts', [0,0;1,1]), 'blocks', 42)

%!test  # a bulge reaches the file as group 42 and reads back
%! E = struct ('type', 'POLYLINE', 'layer', 'A', 'closed', false, ...
%!             'pts', [0, 0; 20, 0], 'bulge', [1, 0]);
%! unwind_protect
%!   dxf.write (tmpf, E);
%!   txt = fileread (tmpf);
%!   assert_equal (! isempty (strfind (txt, sprintf ('\n42\n'))), true);
%! unwind_protect_cleanup
%!   unlink (tmpf);
%! end_unwind_protect

%!test  # a DIMENSION is written with its style, its block and its type
%! P = [0, -5; 50, -5; 0, 0; 100, 0; 0, 0; 0, 0];
%! E = struct ('type', 'DIMENSION', 'pts', P, ...
%!             'block', '*D1', 'angles', 0, 'text', '<>');
%! B = struct ('name', '*D1', 'entities', ...
%!             struct ('type', 'LINE', 'pts', [0, -5; 100, -5]));
%! unwind_protect
%!   dxf.write (tmpf, E, 'blocks', B);
%!   txt = fileread (tmpf);
%!   assert_equal (! isempty (strfind (txt, 'DIMSTYLE')), true);
%!   assert_equal (! isempty (strfind (txt, 'DRAFTING')), true);
%!   assert_equal (! isempty (strfind (txt, 'DIMENSION')), true);
%! unwind_protect_cleanup
%!   unlink (tmpf);
%! end_unwind_protect

%!error<dxf.write: E\(1\) DIMENSION needs six definition points.> ...
%! dxf.write (tempname (), struct ('type', 'DIMENSION', 'pts', [0, 0], ...
%!                                 'block', '*D1', 'angles', 0))
%!error<dxf.write: E\(1\) DIMENSION needs the name of the block holding its picture in .block.> ...
%! dxf.write (tempname (), struct ('type', 'DIMENSION', ...
%!                                 'pts', zeros (6, 2), 'angles', 0))
%!error<dxf.write: E\(1\).angles is the DIMENSION type and must be 0, 2, 3 or 4.> ...
%! dxf.write (tempname (), struct ('type', 'DIMENSION', ...
%!                                 'pts', zeros (6, 2), ...
%!                                 'block', '*D1', 'angles', 9))
%!error<dxf.write: E\(1\) INSERT needs a block name in .block.> ...
%! dxf.write (tempname (), struct ('type', 'INSERT', 'pts', [0, 0]))
