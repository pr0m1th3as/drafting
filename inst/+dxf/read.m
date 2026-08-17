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
##
## Read geometry from an ASCII DXF file.
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

function [E, UNITS, SKIPPED] = read (FILE, LAYER = '')

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

  ## Split into group-code / value pairs, one of each per line
  lines = strsplit (fileread (FILE), "\n");
  lines = regexprep (lines, "\r$", '');       # tolerate CRLF
  while (! isempty (lines) && isempty (lines{end}))
    lines(end) = [];                          # trailing newline is not a pair
  endwhile
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
    endswitch
  endfor

  [E, SKIPPED] = parseentities (codes(entities), values(entities), scale);

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

## Turn the ENTITIES block into a struct array, folding the R12 POLYLINE /
## VERTEX / SEQEND triple into a single polyline entity.
function [E, SKIPPED] = parseentities (codes, values, scale)

  E = blankentity ();
  E(:) = [];
  SKIPPED = {};
  if (isempty (codes))
    return;
  endif

  known = {'LINE', 'LWPOLYLINE', 'POLYLINE', 'CIRCLE', 'ARC', 'TEXT', 'POINT'};
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
              'text', '', 'height', [], 'rotation', []);
endfunction

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

%!error<dxf.read: invalid number of input arguments.> dxf.read ()
%!error<dxf.read: FILE must be a non-empty character vector.> dxf.read (42)
%!error<dxf.read: FILE must be a non-empty character vector.> dxf.read ('')
%!error<dxf.read: cannot find file 'no-such-file.dxf'.> ...
%! dxf.read ('no-such-file.dxf')
