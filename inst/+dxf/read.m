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
## @deftypefn  {drafting} {@var{E} =} dxf.read (@var{FILE})
## @deftypefnx {drafting} {@var{E} =} dxf.read (@var{FILE}, @var{LAYER})
## @deftypefnx {drafting} {[@var{E}, @var{UNITS}, @var{SKIPPED}] =} dxf.read (@dots{})
## @deftypefnx {drafting} {[@var{E}, @var{UNITS}, @var{SKIPPED}, @var{BLOCKS}] =} dxf.read (@dots{})
##
## Read geometry from an ASCII DXF file.
##
## The format is R12 (@code{AC1009}), which is what @code{dxf.write} emits.  A
## file saved to a later version is read as well, the entity records this
## reader takes having kept the same group codes --- the suite reads a drawing
## another application saved as R14, 2000 and 2007 --- but nothing past R12 is
## promised.  A record this reader has no entity for is counted in
## @var{SKIPPED} rather than dropped in silence.
##
## @code{[@var{E}, @var{UNITS}, @var{SKIPPED}, @var{BLOCKS}] = dxf.read
## (@dots{})} additionally returns the block definitions, in the shape
## @code{dxf.write} takes back through its @qcode{'blocks'} pair.  Without it
## an @code{INSERT} is a reference to geometry the caller never receives.
##
## A @code{DIMENSION} is returned with its six definition points in
## @code{pts}, its DXF type in @code{angles} --- 0 rotated, 1 aligned, 2
## angular, 3 diameter, 4 radius --- the name of the block holding its picture
## in
## @code{block}, and its text in @code{text}, where @qcode{'<>'} means the
## dimension measures itself.
##
## @code{@var{E} = dxf.read (@var{FILE})} parses @var{FILE} and returns its
## drawing entities as a struct array with one element per entity and the
## fields below.  Coordinates are converted to millimetres.
##
## @multitable @columnfractions .15 .85
## @item @code{type} @tab entity type: @qcode{'LINE'}, @qcode{'LWPOLYLINE'},
## @qcode{'POLYLINE'}, @qcode{'CIRCLE'}, @qcode{'ARC'}, @qcode{'TEXT'} or
## @qcode{'POINT'}
## @item @code{layer} @tab layer name; @qcode{'0'} when the entity names none
## @item @code{pts} @tab @math{N}-by-2 coordinates in millimetres
## @item @code{closed} @tab true for a closed polyline, false otherwise
## @item @code{radius} @tab radius of a circle or arc, else empty
## @item @code{angles} @tab @code{[start, end]} of an arc in degrees, else empty
## @item @code{text} @tab string of a text entity, else empty
## @item @code{height} @tab height of a text entity, else empty
## @item @code{rotation} @tab rotation of a text entity in degrees,
## counter-clockwise; zero when the entity declares none, else empty
## @end multitable
##
## For a polyline @code{pts} holds the vertices; for a line, its two endpoints;
## for a circle, arc, text or point, the single centre or insertion point.  A
## closed polyline is @emph{not} given a repeated final vertex, matching the
## implicitly closed convention of the @code{geom} namespace.
##
## @code{@var{E} = dxf.read (@var{FILE}, @var{LAYER})} returns only the entities
## on the named layer.  Layer names are compared case-insensitively, as CAD
## applications treat them.
##
## @code{[@var{E}, @var{UNITS}, @var{SKIPPED}] = dxf.read (@dots{})} also
## reports the units the file declared and the entity types that were ignored.
##
## @var{UNITS} is one of @qcode{'mm'}, @qcode{'cm'}, @qcode{'m'},
## @qcode{'in'}, @qcode{'ft'} or @qcode{'unitless'}, taken from the
## @code{$INSUNITS} header variable, and coordinates are scaled to millimetres
## accordingly.  @strong{When the file declares no units, or declares itself
## unitless, coordinates are passed through unscaled} --- which amounts to
## assuming they were already millimetres.  That assumption is right for most
## architectural DXF but it is an assumption, so check @var{UNITS} rather than
## trusting it silently.
##
## @var{SKIPPED} is a cell array of the entity types present in the file but
## not understood, listed once each.  This reader deliberately covers the
## geometry needed to get an outline in, and reports the rest rather than
## growing into a general DXF importer.
##
## Only @strong{ASCII} DXF is supported.  Binary DXF and DWG must be converted
## first, for instance with the ODA File Converter.
##
## @seealso{dxf.write, geom.isrectilinear}
## @end deftypefn

function [E, UNITS, SKIPPED, BLOCKS] = read (FILE, LAYER = '')

  ## Input validation
  if (nargin < 1)
    error ("dxf.read: invalid number of input arguments.");
  endif
  if (! ischar (FILE) || ! isrow (FILE) || isempty (FILE))
    error ("dxf.read: FILE must be a non-empty character vector.");
  endif
  if (exist (FILE, 'file') != 2)
    error ("dxf.read: cannot find file '%s'.", FILE);
  endif
  if (! ischar (LAYER) || (! isempty (LAYER) && ! isrow (LAYER)))
    error ("dxf.read: LAYER must be a character vector.");
  endif

  ## Split into group-code / value pairs, one of each per line.  Consecutive
  ## delimiters must not be collapsed, which is what strsplit does by default:
  ## an empty value is legal and writers emit them -- $DIMBLK and $DIMPOST are
  ## empty in a file LibreCAD writes -- and swallowing the blank line shifts
  ## every pair after it by one.
  lines = strsplit (fileread (FILE), "\n", 'CollapseDelimiters', false);
  lines = regexprep (lines, "\r$", '');       # tolerate CRLF
  if (! isempty (lines) && isempty (lines{end}))
    lines(end) = [];                          # trailing newline is not a pair
  endif
  if (isempty (lines))
    error ("dxf.read: '%s' is empty.", FILE);
  endif
  if (mod (numel (lines), 2) != 0)
    error (strcat ("dxf.read: '%s' is malformed; group codes and values do", ...
                   " not pair up."), FILE);
  endif
  codes = str2double (strtrim (lines(1:2:end)));
  values = lines(2:2:end);
  bad = find (isnan (codes), 1);
  if (! isempty (bad))
    error ("dxf.read: '%s' is malformed; line %d is not a group code.", ...
           FILE, 2 * bad - 1);
  endif

  ## Walk the sections, picking up the units and the entity block
  UNITS = 'unitless';
  scale = 1;
  entities = [];
  blocks = [];
  starts = find (codes == 0 & strcmpi (values, 'SECTION'));
  stops = find (codes == 0 & strcmpi (values, 'ENDSEC'));
  for ii = 1:numel (starts)
    at = starts(ii);
    if (at + 1 > numel (codes) || codes(at+1) != 2)
      continue;                               # unnamed section, skip
    endif
    to = stops(find (stops > at, 1));
    if (isempty (to))
      to = numel (codes) + 1;
    endif
    body = (at+2):(to-1);
    switch (upper (strtrim (values{at+1})))
      case 'HEADER'
        [UNITS, scale] = headerunits (codes(body), values(body));
      case 'ENTITIES'
        entities = body;
      case 'BLOCKS'
        blocks = body;
    endswitch
  endfor

  [E, SKIPPED] = parseentities (codes(entities), values(entities), scale);
  [BLOCKS, bskip] = parseblocks (codes(blocks), values(blocks), scale);
  SKIPPED = addskipped (SKIPPED, bskip);

  ## Restrict to one layer if asked
  if (! isempty (LAYER) && ! isempty (E))
    E = E(strcmpi ({E.layer}, LAYER));
  endif

endfunction

## Read $INSUNITS out of the HEADER section and turn it into a scale to mm.
function [UNITS, scale] = headerunits (codes, values)

  UNITS = 'unitless';
  scale = 1;
  at = find (codes == 9 & strcmpi (strtrim (values), '$INSUNITS'), 1);
  if (isempty (at) || at + 1 > numel (codes))
    return;
  endif
  switch (str2double (values{at+1}))
    case 1
      UNITS = 'in';
      scale = 25.4;
    case 2
      UNITS = 'ft';
      scale = 304.8;
    case 4
      UNITS = 'mm';
      scale = 1;
    case 5
      UNITS = 'cm';
      scale = 10;
    case 6
      UNITS = 'm';
      scale = 1000;
  endswitch

endfunction

## Turn the BLOCKS section into a struct array of definitions, in the shape
## dxf.write takes back through its 'blocks' pair.  A block's own entities are
## parsed by exactly the same code as the drawing's, so anything readable in
## the drawing is readable inside a block -- and anything not readable is
## counted, since a type this reader has no entity for is no less absent for
## having been found inside a block than beside one.
function [B, SKIPPED] = parseblocks (codes, values, scale)

  B = struct ('name', {}, 'entities', {});
  SKIPPED = {};
  if (isempty (codes))
    return;
  endif
  marks = find (codes == 0);
  starts = marks(strcmpi (values(marks), 'BLOCK'));
  for ii = 1:numel (starts)
    at = starts(ii);
    ends = marks(marks > at);
    ends = ends(strcmpi (values(ends), 'ENDBLK'));
    if (isempty (ends))
      continue;
    endif
    to = ends(1);
    ## The name is the first group 2 of the block header
    hdr = (at+1):(to-1);
    nm = grouptext (codes(hdr), values(hdr), 2, '');
    if (isempty (nm))
      continue;
    endif
    ## Entities are everything from the second 0-marker inside the block
    inner = marks(marks > at & marks < to);
    if (isempty (inner))
      ents = struct ('type', {}, 'layer', {}, 'linetype', {}, 'colour', {}, ...
                     'pts', {}, 'closed', {}, 'radius', {}, 'angles', {}, ...
                     'text', {}, 'height', {}, 'rotation', {}, 'bulge', {}, ...
                     'block', {});
    else
      [ents, sk] = parseentities (codes(inner(1):(to-1)), ...
                                  values(inner(1):(to-1)), scale);
      SKIPPED = addskipped (SKIPPED, sk);
    endif
    B(end+1) = struct ('name', nm, 'entities', {ents});
  endfor

endfunction

## Turn the ENTITIES block into a struct array, folding the R12 POLYLINE /
## VERTEX / SEQEND triple into a single polyline entity.
function [E, SKIPPED] = parseentities (codes, values, scale)

  E = blankentity ();
  E(:) = [];
  SKIPPED = {};
  if (isempty (codes))
    return;
  endif

  known = {'LINE', 'LWPOLYLINE', 'POLYLINE', 'CIRCLE', 'ARC', 'TEXT', ...
           'POINT', 'INSERT', 'DIMENSION'};
  marks = find (codes == 0);
  built = {};
  ii = 1;
  while (ii <= numel (marks))
    at = marks(ii);
    to = numel (codes);
    if (ii < numel (marks))
      to = marks(ii+1) - 1;
    endif
    type = upper (strtrim (values{at}));
    body = (at+1):to;

    if (! any (strcmp (type, known)))
      if (! any (strcmp (type, {'SEQEND', 'VERTEX'})) ...
          && ! any (strcmp (type, SKIPPED)))
        SKIPPED{end+1} = type;
      endif
      ii++;
      continue;
    endif

    s = blankentity ();
    s.type = type;
    s.layer = grouptext (codes(body), values(body), 8, '0');
    s.linetype = grouptext (codes(body), values(body), 6, 'CONTINUOUS');
    s.colour = groupnum (codes(body), values(body), 62, 256);

    if (strcmp (type, 'POLYLINE'))
      ## Vertices live in the VERTEX entities that follow, up to the SEQEND
      s.closed = bitand (groupnum (codes(body), values(body), 70, 0), 1) != 0;
      pts = zeros (0, 2);
      jj = ii + 1;
      while (jj <= numel (marks))
        vAt = marks(jj);
        vTo = numel (codes);
        if (jj < numel (marks))
          vTo = marks(jj+1) - 1;
        endif
        vType = upper (strtrim (values{vAt}));
        if (strcmp (vType, 'SEQEND'))
          jj++;
          break;
        elseif (! strcmp (vType, 'VERTEX'))
          break;
        endif
        vBody = (vAt+1):vTo;
        pts(end+1,:) = [groupnum(codes(vBody), values(vBody), 10, 0), ...
                        groupnum(codes(vBody), values(vBody), 20, 0)];
        jj++;
      endwhile
      s.pts = pts * scale;
      built{end+1} = s;
      ii = jj;
      continue;
    endif

    switch (type)
      case 'LWPOLYLINE'
        s.closed = bitand (groupnum (codes(body), values(body), 70, 0), 1) != 0;
        x = groupall (codes(body), values(body), 10);
        y = groupall (codes(body), values(body), 20);
        n = min (numel (x), numel (y));
        s.pts = [x(1:n), y(1:n)] * scale;

      case 'LINE'
        s.pts = scale * [groupnum(codes(body), values(body), 10, 0), ...
                         groupnum(codes(body), values(body), 20, 0); ...
                         groupnum(codes(body), values(body), 11, 0), ...
                         groupnum(codes(body), values(body), 21, 0)];

      case {'CIRCLE', 'ARC'}
        s.pts = scale * [groupnum(codes(body), values(body), 10, 0), ...
                         groupnum(codes(body), values(body), 20, 0)];
        s.radius = scale * groupnum (codes(body), values(body), 40, 0);
        if (strcmp (type, 'ARC'))
          s.angles = [groupnum(codes(body), values(body), 50, 0), ...
                      groupnum(codes(body), values(body), 51, 0)];
        endif

      case 'TEXT'
        s.pts = scale * [groupnum(codes(body), values(body), 10, 0), ...
                         groupnum(codes(body), values(body), 20, 0)];
        s.height = scale * groupnum (codes(body), values(body), 40, 0);
        s.text = grouptext (codes(body), values(body), 1, '');
        ## Group 50 is an angle, so the drawing-unit scale must not touch it
        s.rotation = groupnum (codes(body), values(body), 50, 0);

      case 'DIMENSION'
        ## The six definition points are what a reader measures from, so they
        ## are what is returned; the picture lives in the block named by .block
        ## and is reached through the fourth output.
        pts = zeros (6, 2);
        gc = [10, 11, 13, 14, 15, 16];
        for pp = 1:6
          x = groupnum (codes(body), values(body), gc(pp), 0);
          y = groupnum (codes(body), values(body), gc(pp) + 10, 0);
          pts(pp,:) = scale * [x, y];
        endfor
        s.pts = pts;
        s.block = grouptext (codes(body), values(body), 2, '');
        s.text = grouptext (codes(body), values(body), 1, '<>');
        s.angles = mod (groupnum (codes(body), values(body), 70, 0), 32);
        s.rotation = groupnum (codes(body), values(body), 50, 0);

      case 'INSERT'
        ## The block name is carried in .block and the uniform scale in
        ## .radius, matching what dxf.write emits and draw.Drawing.entities
        ## produced
        s.pts = [groupnum(codes(body), values(body), 10, 0), ...
                 groupnum(codes(body), values(body), 20, 0)];
        s.block = grouptext (codes(body), values(body), 2, '');
        s.radius = groupnum (codes(body), values(body), 41, 1);
        s.rotation = groupnum (codes(body), values(body), 50, 0);

      case 'POINT'
        s.pts = scale * [groupnum(codes(body), values(body), 10, 0), ...
                         groupnum(codes(body), values(body), 20, 0)];
    endswitch

    built{end+1} = s;
    ii++;
  endwhile

  if (! isempty (built))
    E = [built{:}];
  endif

endfunction

## Merge a second list of unhandled types into the first, in the order they
## were met rather than in alphabetical order: which type appeared first is
## worth more to a reader than which sorts first.
function S = addskipped (S, more)

  for ii = 1:numel (more)
    if (! any (strcmp (more{ii}, S)))
      S{end+1} = more{ii};
    endif
  endfor

endfunction

## First value carrying the given group code, as a number
function v = groupnum (codes, values, code, dflt)
  at = find (codes == code, 1);
  if (isempty (at))
    v = dflt;
  else
    v = str2double (values{at});
    if (isnan (v))
      v = dflt;
    endif
  endif
endfunction

## Every value carrying the given group code, as a column of numbers
function v = groupall (codes, values, code)
  at = find (codes == code);
  v = str2double (values(at))(:);
endfunction

## First value carrying the given group code, as text
function v = grouptext (codes, values, code, dflt)
  at = find (codes == code, 1);
  if (isempty (at))
    v = dflt;
  else
    v = strtrim (values{at});
  endif
endfunction

## The full field set, so that entities of different types still concatenate
function s = blankentity ()
  s = struct ('type', '', 'layer', '0', 'linetype', 'CONTINUOUS', ...
              'colour', 256, 'pts', zeros (0, 2), ...
              'closed', false, 'radius', [], 'angles', [], ...
              'text', '', 'height', [], 'rotation', [], 'bulge', [], ...
              'block', '');
endfunction

%!demo
%! ## Reading a DXF gives one struct per entity, with the layer, line type and
%! ## colour it carried.  Anything the reader does not handle is counted rather
%! ## than silently dropped.
%!
%! D = draw.Drawing ().circle ([0, 0], 20).polyline ([0,0; 30,0; 30,20], true);
%! D.Linetype = 'HIDDEN';
%! D = D.line ([-25, 0], [25, 0]);
%!
%! fn = [tempname(), '.dxf'];
%! dxf.write (fn, entities (D));
%! [E, UNITS, SKIPPED] = dxf.read (fn);
%! printf ('%d entities, units "%s", %d skipped\n', numel (E), UNITS, SKIPPED);
%! for k = 1:numel (E)
%!   printf ('  %-9s %d point(s), %s\n', E(k).type, ...
%!           rows (E(k).pts), E(k).linetype);
%! endfor
%!
%! ## What was read can be drawn again
%! Q = draw.Drawing ();
%! for k = 1:numel (E)
%!   if (strcmp (E(k).type, 'CIRCLE'))
%!     Q = Q.circle (E(k).pts, E(k).radius);
%!   elseif (strcmp (E(k).type, 'POLYLINE'))
%!     Q = Q.polyline (E(k).pts, E(k).closed);
%!   else
%!     Q = Q.line (E(k).pts(1,:), E(k).pts(2,:));
%!   endif
%! endfor
%! plot (Q);
%! title ('read back from the file and drawn again');
%! unlink (fn);

%!shared tmpf
%! tmpf = [tempname() '.dxf'];

%!test  # a closed LWPOLYLINE on a named layer, declared in millimetres
%! txt = ["0\nSECTION\n2\nHEADER\n9\n$INSUNITS\n70\n4\n0\nENDSEC\n" ...
%!        "0\nSECTION\n2\nENTITIES\n" ...
%!        "0\nLWPOLYLINE\n8\nOUTLINE\n90\n4\n70\n1\n" ...
%!        "10\n0.0\n20\n0.0\n10\n1600.0\n20\n0.0\n" ...
%!        "10\n1600.0\n20\n1800.0\n10\n0.0\n20\n1800.0\n" ...
%!        "0\nENDSEC\n0\nEOF\n"];
%! fid = fopen (tmpf, 'w');  fputs (fid, txt);  fclose (fid);
%! unwind_protect
%!   [E, units] = dxf.read (tmpf);
%!   assert_equal (numel (E), 1);
%!   assert_equal (E.type, 'LWPOLYLINE');
%!   assert_equal (E.layer, 'OUTLINE');
%!   assert_equal (E.closed, true);
%!   assert_equal (E.pts, [0, 0; 1600, 0; 1600, 1800; 0, 1800]);
%!   assert_equal (units, 'mm');
%! unwind_protect_cleanup
%!   delete (tmpf);
%! end_unwind_protect

%!test  # metres are scaled to millimetres
%! txt = ["0\nSECTION\n2\nHEADER\n9\n$INSUNITS\n70\n6\n0\nENDSEC\n" ...
%!        "0\nSECTION\n2\nENTITIES\n" ...
%!        "0\nLWPOLYLINE\n8\n0\n70\n1\n" ...
%!        "10\n0\n20\n0\n10\n1.6\n20\n0\n10\n1.6\n20\n1.8\n" ...
%!        "0\nENDSEC\n0\nEOF\n"];
%! fid = fopen (tmpf, 'w');  fputs (fid, txt);  fclose (fid);
%! unwind_protect
%!   [E, units] = dxf.read (tmpf);
%!   assert_equal (E.pts, [0, 0; 1600, 0; 1600, 1800], 1e-9);
%!   assert_equal (units, 'm');
%! unwind_protect_cleanup
%!   delete (tmpf);
%! end_unwind_protect

%!test  # no $INSUNITS means unitless, and coordinates pass through unscaled
%! txt = ["0\nSECTION\n2\nENTITIES\n0\nLINE\n8\n0\n" ...
%!        "10\n1\n20\n2\n11\n3\n21\n4\n0\nENDSEC\n0\nEOF\n"];
%! fid = fopen (tmpf, 'w');  fputs (fid, txt);  fclose (fid);
%! unwind_protect
%!   [E, units] = dxf.read (tmpf);
%!   assert_equal (E.type, 'LINE');
%!   assert_equal (E.pts, [1, 2; 3, 4]);
%!   assert_equal (units, 'unitless');
%! unwind_protect_cleanup
%!   delete (tmpf);
%! end_unwind_protect

%!test  # the R12 POLYLINE / VERTEX / SEQEND triple folds into one entity
%! txt = ["0\nSECTION\n2\nENTITIES\n" ...
%!        "0\nPOLYLINE\n8\nWALL\n66\n1\n70\n1\n" ...
%!        "0\nVERTEX\n8\nWALL\n10\n0\n20\n0\n" ...
%!        "0\nVERTEX\n8\nWALL\n10\n10\n20\n0\n" ...
%!        "0\nVERTEX\n8\nWALL\n10\n10\n20\n5\n" ...
%!        "0\nSEQEND\n8\nWALL\n" ...
%!        "0\nLINE\n8\nWALL\n10\n0\n20\n0\n11\n1\n21\n1\n" ...
%!        "0\nENDSEC\n0\nEOF\n"];
%! fid = fopen (tmpf, 'w');  fputs (fid, txt);  fclose (fid);
%! unwind_protect
%!   E = dxf.read (tmpf);
%!   assert_equal (numel (E), 2);
%!   assert_equal (E(1).type, 'POLYLINE');
%!   assert_equal (E(1).closed, true);
%!   assert_equal (E(1).pts, [0, 0; 10, 0; 10, 5]);
%!   assert_equal (E(2).type, 'LINE');   # the entity after SEQEND survives
%! unwind_protect_cleanup
%!   delete (tmpf);
%! end_unwind_protect

%!test  # a TEXT carries its group 50 rotation, and an absent one reads as zero
%! txt = ["0\nSECTION\n2\nENTITIES\n" ...
%!        "0\nTEXT\n8\nT\n10\n0\n20\n0\n40\n2.5\n1\nUP\n50\n90\n" ...
%!        "0\nTEXT\n8\nT\n10\n0\n20\n0\n40\n2.5\n1\nFLAT\n" ...
%!        "0\nENDSEC\n0\nEOF\n"];
%! fid = fopen (tmpf, 'w');  fputs (fid, txt);  fclose (fid);
%! unwind_protect
%!   E = dxf.read (tmpf);
%!   assert_equal (E(1).rotation, 90);
%!   assert_equal (E(2).rotation, 0);
%! unwind_protect_cleanup
%!   delete (tmpf);
%! end_unwind_protect

%!test  # an ARC's group 50 is a start angle, not a rotation
%! txt = ["0\nSECTION\n2\nENTITIES\n" ...
%!        "0\nARC\n8\nC\n10\n0\n20\n0\n40\n3\n50\n30\n51\n120\n" ...
%!        "0\nENDSEC\n0\nEOF\n"];
%! fid = fopen (tmpf, 'w');  fputs (fid, txt);  fclose (fid);
%! unwind_protect
%!   E = dxf.read (tmpf);
%!   assert_equal (E(1).angles, [30, 120]);
%!   assert_equal (E(1).rotation, []);
%! unwind_protect_cleanup
%!   delete (tmpf);
%! end_unwind_protect

%!test  # circles, arcs and text
%! txt = ["0\nSECTION\n2\nENTITIES\n" ...
%!        "0\nCIRCLE\n8\nC\n10\n5\n20\n6\n40\n2.5\n" ...
%!        "0\nARC\n8\nC\n10\n1\n20\n2\n40\n3\n50\n30\n51\n120\n" ...
%!        "0\nTEXT\n8\nT\n10\n7\n20\n8\n40\n2.5\n1\nINNER\n" ...
%!        "0\nENDSEC\n0\nEOF\n"];
%! fid = fopen (tmpf, 'w');  fputs (fid, txt);  fclose (fid);
%! unwind_protect
%!   E = dxf.read (tmpf);
%!   assert_equal ({E.type}, {'CIRCLE', 'ARC', 'TEXT'});
%!   assert_equal (E(1).radius, 2.5);
%!   assert_equal (E(2).angles, [30, 120]);
%!   assert_equal (E(3).text, 'INNER');
%!   assert_equal (E(3).height, 2.5);
%! unwind_protect_cleanup
%!   delete (tmpf);
%! end_unwind_protect

%!test  # unknown entity types are skipped and reported once each
%! txt = ["0\nSECTION\n2\nENTITIES\n" ...
%!        "0\nSPLINE\n8\n0\n10\n0\n20\n0\n" ...
%!        "0\nSPLINE\n8\n0\n10\n1\n20\n1\n" ...
%!        "0\nHATCH\n8\n0\n10\n0\n20\n0\n" ...
%!        "0\nLINE\n8\n0\n10\n0\n20\n0\n11\n1\n21\n1\n" ...
%!        "0\nENDSEC\n0\nEOF\n"];
%! fid = fopen (tmpf, 'w');  fputs (fid, txt);  fclose (fid);
%! unwind_protect
%!   [E, ~, skipped] = dxf.read (tmpf);
%!   assert_equal (numel (E), 1);
%!   assert_equal (E.type, 'LINE');
%!   assert_equal (skipped, {'SPLINE', 'HATCH'});
%! unwind_protect_cleanup
%!   delete (tmpf);
%! end_unwind_protect

%!test  # LAYER selects, case-insensitively
%! txt = ["0\nSECTION\n2\nENTITIES\n" ...
%!        "0\nLINE\n8\nOUTLINE\n10\n0\n20\n0\n11\n1\n21\n1\n" ...
%!        "0\nLINE\n8\nDIMS\n10\n0\n20\n0\n11\n2\n21\n2\n" ...
%!        "0\nENDSEC\n0\nEOF\n"];
%! fid = fopen (tmpf, 'w');  fputs (fid, txt);  fclose (fid);
%! unwind_protect
%!   assert_equal (numel (dxf.read (tmpf)), 2);
%!   assert_equal (numel (dxf.read (tmpf, 'OUTLINE')), 1);
%!   assert_equal (numel (dxf.read (tmpf, 'outline')), 1);
%!   assert_equal (numel (dxf.read (tmpf, 'NOSUCH')), 0);
%! unwind_protect_cleanup
%!   delete (tmpf);
%! end_unwind_protect

%!test  # CRLF line endings are tolerated
%! txt = ["0\r\nSECTION\r\n2\r\nENTITIES\r\n" ...
%!        "0\r\nLINE\r\n8\r\n0\r\n10\r\n1\r\n20\r\n2\r\n" ...
%!        "11\r\n3\r\n21\r\n4\r\n0\r\nENDSEC\r\n0\r\nEOF\r\n"];
%! fid = fopen (tmpf, 'w');  fputs (fid, txt);  fclose (fid);
%! unwind_protect
%!   E = dxf.read (tmpf);
%!   assert_equal (E.pts, [1, 2; 3, 4]);
%! unwind_protect_cleanup
%!   delete (tmpf);
%! end_unwind_protect

%!test  # a file with no ENTITIES section yields nothing, not an error
%! txt = "0\nSECTION\n2\nHEADER\n0\nENDSEC\n0\nEOF\n";
%! fid = fopen (tmpf, 'w');  fputs (fid, txt);  fclose (fid);
%! unwind_protect
%!   E = dxf.read (tmpf);
%!   assert_equal (isempty (E), true);
%! unwind_protect_cleanup
%!   delete (tmpf);
%! end_unwind_protect

## The fixture below was drawn in LibreCAD and exported as R12, and it reaches
## what our own output cannot: an empty group value, the layout containers a
## real file defines, an entity type this reader has no equivalent for, and
## dimensions that arrive as anonymous blocks rather than as DIMENSION records.

%!test  # a file another application wrote reads, empty group values and all
%! fn = fullfile (fileparts (fileparts (which ('dxf.read'))), 'tests', ...
%!                'fixtures', 'foreign_dims_R12.dxf');
%! [E, ~, ~, B] = dxf.read (fn);
%! assert_equal (numel (E), 9);
%! assert_equal (numel (B), 9);

%!test  # and its geometry arrives as it was drawn
%! fn = fullfile (fileparts (fileparts (which ('dxf.read'))), 'tests', ...
%!                'fixtures', 'foreign_dims_R12.dxf');
%! E = dxf.read (fn);
%! P = E(strcmp ({E.type}, 'POLYLINE'));
%! assert_equal (P.pts, [0, 0; 100, 0; 100, 60; 0, 60], 1e-9);
%! assert_equal (logical (P.closed), true);
%! C = E(strcmp ({E.type}, 'CIRCLE'));
%! assert_equal ([C.pts, C.radius], [50, 30, 20], 1e-9);

%!test  # a type the reader has no entity for is counted, even inside a block
%! fn = fullfile (fileparts (fileparts (which ('dxf.read'))), 'tests', ...
%!                'fixtures', 'foreign_dims_R12.dxf');
%! [~, ~, SK] = dxf.read (fn);
%! assert_equal (strjoin (SK, ' '), 'SOLID');

%!test  # LibreCAD writes an R12 dimension as an anonymous block and an INSERT
%! fn = fullfile (fileparts (fileparts (which ('dxf.read'))), 'tests', ...
%!                'fixtures', 'foreign_dims_R12.dxf');
%! [E, ~, ~, B] = dxf.read (fn);
%! I = E(strcmp ({E.type}, 'INSERT'));
%! assert_equal (numel (I), 7);
%! assert_equal (strjoin (sort ({I.block}), ' '), ...
%!               '*D1 *D2 *D3 *D4 *D5 *D6 *D7');
%! assert_equal (any (strcmp ({B.name}, '$MODEL_SPACE')), true);

%!test  # a later version reads too, though the reader claims only R12
%! fn = fullfile (fileparts (fileparts (which ('dxf.read'))), 'tests', ...
%!                'fixtures', 'foreign_dims_2000.dxf');
%! [E, U, SK] = dxf.read (fn);
%! assert_equal (numel (E), 9);
%! assert_equal (sum (strcmp ({E.type}, 'DIMENSION')), 7);
%! assert_equal (U, 'mm');
%! assert_equal (strjoin (SK, ' '), 'SOLID MTEXT');

%!test  # R14 carries the dimensions but not yet a unit declaration
%! fn = fullfile (fileparts (fileparts (which ('dxf.read'))), 'tests', ...
%!                'fixtures', 'foreign_dims_R14.dxf');
%! [E, U] = dxf.read (fn);
%! assert_equal (U, 'unitless');
%! assert_equal (sum (strcmp ({E.type}, 'LWPOLYLINE')), 1);

%!test  # and a UTF-8 file, which is what R2007 onwards writes
%! fn = fullfile (fileparts (fileparts (which ('dxf.read'))), 'tests', ...
%!                'fixtures', 'foreign_dims_2007.dxf');
%! E = dxf.read (fn);
%! assert_equal (numel (E), 9);
%! assert_equal (sum (strcmp ({E.type}, 'DIMENSION')), 7);

%!error<dxf.read: invalid number of input arguments.> dxf.read ()
%!error<dxf.read: FILE must be a non-empty character vector.> dxf.read (42)
%!error<dxf.read: FILE must be a non-empty character vector.> dxf.read ('')
%!error<dxf.read: cannot find file 'no-such-file.dxf'.> ...
%! dxf.read ('no-such-file.dxf')

%!test  # a DIMENSION comes back with its type, block and definition points
%! D = draw.Drawing ().dim ([0, 0], [100, 0], -15, 'horizontal');
%! [E, ~, BL] = entities (D);
%! fn = [tempname() '.dxf'];
%! unwind_protect
%!   dxf.write (fn, E, 'blocks', BL);
%!   [R, ~, ~, B] = dxf.read (fn);
%!   d = R(strcmp ({R.type}, 'DIMENSION'));
%!   assert_equal (numel (d), 1);
%!   assert_equal (d.angles, 0);
%!   assert_equal (d.block, '*D1');
%!   assert_equal (d.pts(3,:), [0, 0], 1e-9);
%!   assert_equal (d.pts(4,:), [100, 0], 1e-9);
%!   assert_equal (numel (B), 1);
%! unwind_protect_cleanup
%!   unlink (fn);
%! end_unwind_protect

%!test  # each dimension family keeps its own DXF type across the round trip
%! D = draw.Drawing ().dim ([0, 0], [10, 0], -5, 'horizontal');
%! D = D.angdim ([0, 20], [10, 20], [8, 26], 5);
%! D = D.diam ([40, 0], 6, 45).radius ([60, 0], 4, 30);
%! [E, ~, BL] = entities (D);
%! fn = [tempname() '.dxf'];
%! unwind_protect
%!   dxf.write (fn, E, 'blocks', BL);
%!   R = dxf.read (fn);
%!   d = R(strcmp ({R.type}, 'DIMENSION'));
%!   assert_equal (sort ([d.angles]), [0, 2, 3, 4]);
%! unwind_protect_cleanup
%!   unlink (fn);
%! end_unwind_protect

%!test  # the BLOCKS section comes back with its names and its geometry
%! bore = draw.Drawing ().circle ([0, 0], 3).line ([-4, 0], [4, 0]);
%! D = draw.Drawing ().block ('BORE', bore).insert ('BORE', [10, 0]);
%! [E, ~, BL] = entities (D, 'blocks', 'reference');
%! fn = [tempname() '.dxf'];
%! unwind_protect
%!   dxf.write (fn, E, 'blocks', BL);
%!   [R, ~, ~, B] = dxf.read (fn);
%!   assert_equal (numel (B), 1);
%!   assert_equal (B.name, 'BORE');
%!   assert_equal (sort ({B.entities.type}), {'CIRCLE', 'LINE'});
%!   assert_equal (R(strcmp ({R.type}, 'INSERT')).block, 'BORE');
%! unwind_protect_cleanup
%!   unlink (fn);
%! end_unwind_protect

%!test  # a file with no BLOCKS section reads back an empty definition array
%! fn = [tempname() '.dxf'];
%! unwind_protect
%!   dxf.write (fn, struct ('type', 'LINE', 'pts', [0, 0; 1, 1]));
%!   [~, ~, ~, B] = dxf.read (fn);
%!   assert_equal (isempty (B), true);
%! unwind_protect_cleanup
%!   unlink (fn);
%! end_unwind_protect
