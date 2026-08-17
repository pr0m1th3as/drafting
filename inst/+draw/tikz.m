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
## @deftypefn  {drafting} {@var{S} =} draw.tikz (@var{D})
## @deftypefnx {drafting} {@var{S} =} draw.tikz (@var{D}, @var{NAME}, @var{VALUE}, @dots{})
##
## Render a drawing as a TikZ picture for inclusion in the LaTeX report.
##
## @code{@var{S} = draw.tikz (@var{D})} returns the TikZ code for the
## @code{draw.Drawing} object @var{D} as a character array, one line per row of
## the drawing, ready to be written to a @file{.tex} file and pulled into a
## document with @code{\input}.
##
## The picture is emitted at a stated plot scale, so it arrives on the page at
## the size a drawing is meant to be read at rather than at whatever size fits.
## Model coordinates are written unchanged, in millimetres, and the scale is
## carried by the @code{x} and @code{y} unit vectors of the
## @code{tikzpicture}: a wall at @math{x = 1600} appears in the output as
## @code{1600} whatever the scale, which is what makes the generated source
## readable against the drawing it came from.
##
## Radii, text sizes and dimension ornament cannot follow that convention,
## since they must come out at a fixed size on paper regardless of scale.
## Those are emitted in absolute millimetres and points, already divided by the
## scale.
##
## @subheading Options
##
## @multitable @columnfractions .16 .84
## @item @qcode{'Scale'} @tab Plot scale denominator: @math{50} means
## @math{1:50}, which is a common scale for a general-arrangement plan and the
## default.  A drawing at @math{1:1} wants @math{1}.
## @item @qcode{'File'} @tab Also write the result to this file.  The code is
## returned either way.
## @item @qcode{'Styles'} @tab Emit a @code{\tikzset} block defining one empty
## style per layer, so that the document can restyle a layer by redefining it.
## True by default; set it false when the styles are already defined and
## redefining them would undo that.
## @item @qcode{'LTScale'} @tab Multiplies line-type dash lengths.  Patterns
## are model lengths times this factor, exactly as in @code{draw.plot} and as
## CAD's own @code{LTSCALE} works.  Defaults to the drawing scale, which
## cancels the reduction so dashes reach the page at their nominal size --- a
## centre line reads as a centre line whether the view is at 1:1 or 1:50 ---
## while leaving the factor visible and adjustable.
## @end multitable
##
## @subheading Dimensions
##
## Dimensions are rendered here rather than reused from
## @code{draw.entities}, which is the point of storing them semantically.  A
## TikZ node anchors itself, so the label is positioned by naming the side it
## should sit on and letting TikZ measure the text --- where the DXF path has
## to estimate the width of a string from its character count.  The same
## drawing therefore gets properly centred labels on the report figure and
## approximately centred ones in the CAD file, from one model and without a
## flag anywhere.
##
## Labels are unidirectional, matching @code{draw.entities}, and ticks are the
## 45-degree architectural obliques.
##
## @subheading What the document needs
##
## A hatch is emitted as @code{\path[pattern=@dots{}]}, which requires
## @code{\usetikzlibrary@{patterns@}}.  Nothing else in the output needs a
## library beyond TikZ itself.
##
## Text is written through as UTF-8 and LaTeX's special characters are
## escaped.  Greek text needs a Unicode-aware engine --- @code{xelatex} or
## @code{lualatex} --- or @code{babel} configured for Greek; that is a property
## of the document, not of this output.
##
## @seealso{draw.Drawing, draw.entities}
## @end deftypefn

function S = tikz (D, varargin)

  ## Input validation
  if (nargin < 1)
    error ("draw.tikz: invalid number of input arguments.");
  endif
  if (! isa (D, 'draw.Drawing'))
    error ("draw.tikz: D must be a draw.Drawing object.");
  endif
  if (mod (numel (varargin), 2) != 0)
    error ("draw.tikz: optional arguments must come in name-value pairs.");
  endif

  scale = 50;
  fname = '';
  styles = true;
  ltscale = [];
  for ii = 1:2:numel (varargin)
    name = varargin{ii};
    val = varargin{ii+1};
    if (! ischar (name) || ! isrow (name))
      error ("draw.tikz: option names must be character vectors.");
    endif
    switch (lower (name))
      case 'scale'
        if (! isnumeric (val) || ! isreal (val) || ! isscalar (val) ...
            || ! isfinite (val) || val <= 0)
          error (strcat ("draw.tikz: Scale must be a real positive finite", ...
                         " scalar."));
        endif
        scale = double (val);
      case 'file'
        if (! ischar (val) || ! isrow (val) || isempty (val))
          error (strcat ("draw.tikz: File must be a non-empty character", ...
                         " vector."));
        endif
        fname = val;
      case 'styles'
        if (! (islogical (val) || isnumeric (val)) || ! isscalar (val))
          error ("draw.tikz: Styles must be a logical scalar.");
        endif
        styles = logical (val);
      case 'ltscale'
        if (! isnumeric (val) || ! isreal (val) || ! isscalar (val) ...
            || ! isfinite (val) || val <= 0)
          error (strcat ("draw.tikz: LTScale must be a real positive", ...
                         " finite scalar."));
        endif
        ltscale = double (val);
      otherwise
        error ("draw.tikz: unknown option '%s'.", name);
    endswitch
  endfor

  ## Line-type patterns are model lengths times LTScale, as in CAD and as in
  ## draw.plot.  Defaulting LTScale to the drawing scale cancels the reduction,
  ## so dashes arrive at their nominal size on the page -- which is what a
  ## report figure wants -- by an explicit factor rather than by a second rule.
  if (isempty (ltscale))
    ltscale = scale;
  endif

  ## One model millimetre, in millimetres on the page
  u = 1 / scale;

  ## Lowered through draw.entities, exactly as draw.plot is, so that the three
  ## backends agree and none of them can silently fail to know an entity type.
  ## That is not hypothetical: this one did, when the dimensioning entities
  ## arrived and only this backend still rendered from the drawing model.
  E = draw.entities (D, 'bulges', 'flatten');

  if (isempty (E))
    L = {};
  else
    L = unique ({E.layer});
  endif
  sty = stylenames (L);

  out = {};
  out{end+1} = '% Generated by the drafting package: draw.tikz';
  out{end+1} = sprintf ('%% Drawing: %s', D.Name);
  out{end+1} = sprintf (strcat ('%% Plot scale 1:%s. Coordinates are model', ...
                                ' millimetres.'), fmt (scale));
  if (styles && ! isempty (L))
    out{end+1} = '\tikzset{';
    for ii = 1:numel (L)
      out{end+1} = sprintf ('  %s/.style={}, %% layer ''%s''', sty{ii}, L{ii});
    endfor
    out{end+1} = '}';
  endif

  out{end+1} = sprintf (strcat ('\\begin{tikzpicture}[x=%smm, y=%smm,', ...
                                ' line width=0.18mm]'), fmt (u), fmt (u));

  for ii = 1:numel (L)
    idx = find (strcmp ({E.layer}, L{ii}));
    out{end+1} = sprintf ('  %% layer: %s', L{ii});
    out{end+1} = sprintf ('  \\begin{scope}[%s]', sty{ii});
    for jj = idx
      lines = render (E(jj), scale, ltscale);
      for kk = 1:numel (lines)
        out{end+1} = ['    ', lines{kk}];
      endfor
    endfor
    out{end+1} = '  \end{scope}';
  endfor

  out{end+1} = '\end{tikzpicture}';

  S = strjoin (out, "\n");

  if (! isempty (fname))
    fid = fopen (fname, 'wt');
    if (fid < 0)
      error ("draw.tikz: cannot open '%s' for writing.", fname);
    endif
    unwind_protect
      fprintf (fid, "%s\n", S);
    unwind_protect_cleanup
      fclose (fid);
    end_unwind_protect
  endif

endfunction

## A TikZ style name per layer.  Style names have to be alphabetic, and layer
## names do not, so anything else is dropped -- which can make two layers
## collide, and a collision would silently merge their styling.  Disambiguate
## with an index rather than hoping.
function sty = stylenames (L)

  sty = cell (size (L));
  for ii = 1:numel (L)
    keep = isletter (L{ii});
    sty{ii} = ['dr', L{ii}(keep)];
    if (numel (sty{ii}) == 2)
      sty{ii} = sprintf ('dr%d', ii);
    endif
  endfor

  ## Compare against the names as they were, not as they are being rewritten:
  ## renaming the first of a colliding pair would otherwise leave the second
  ## looking unique.  Sanitised names carry no digits, so an index can never
  ## collide with one.
  base = sty;
  for ii = 1:numel (sty)
    if (sum (strcmp (base, base{ii})) > 1)
      sty{ii} = sprintf ('%s%d', base{ii}, ii);
    endif
  endfor

endfunction

## Line type and colour as a TikZ option list, empty when both are default.
##
## Dash lengths are emitted at their nominal size on the page, not divided by
## the drawing scale.  A line type is a paper-space property: a centre line
## should read as a centre line whether the view is at 1:1 or 1:50, and scaling
## the pattern down with the geometry would make it vanish.
function o = dopts (e, ltscale, scale)

  parts = {};

  colours = {'', 'red', 'yellow', 'green', 'cyan', 'blue', 'magenta', ...
             'black', 'gray'};
  c = optfield (e, 'colour', 256);
  if (c >= 1 && c <= 8)
    parts{end+1} = colours{c + 1};
  endif

  lt = optfield (e, 'linetype', 'CONTINUOUS');
  if (! strcmpi (lt, 'CONTINUOUS'))
    try
      pat = draw.linetype (lt) * ltscale / scale;
    catch
      pat = [];
    end_try_catch
    if (! isempty (pat))
      d = '';
      for k = 1:numel (pat)
        if (pat(k) >= 0)
          d = sprintf ('%son %smm ', d, fmt (max (pat(k), 0.1)));
        else
          d = sprintf ('%soff %smm ', d, fmt (-pat(k)));
        endif
      endfor
      parts{end+1} = ['dash pattern=', strtrim(d)];
    endif
  endif

  if (isempty (parts))
    o = '';
  else
    o = ['[', strjoin(parts, ', '), ']'];
  endif

endfunction

## A field if present and non-empty, the default otherwise
function v = optfield (e, name, dflt)

  if (isfield (e, name) && ! isempty (e.(name)))
    v = e.(name);
  else
    v = dflt;
  endif

endfunction

## Render one entity as one or more lines of TikZ.
function lines = render (e, scale, ltscale)

  o = dopts (e, ltscale, scale);

  switch (e.type)

    case 'LINE'
      lines = {sprintf('\\draw%s %s -- %s;', o, pt (e.pts(1,:)), ...
                       pt (e.pts(2,:)))};

    case {'POLYLINE', 'LWPOLYLINE'}
      s = ['\draw', o, ' ', pt(e.pts(1,:))];
      for ii = 2:rows (e.pts)
        s = [s, ' -- ', pt(e.pts(ii,:))];
      endfor
      if (e.closed)
        s = [s, ' -- cycle'];
      endif
      lines = {[s, ';']};

    case 'CIRCLE'
      lines = {sprintf('\\draw%s %s circle[radius=%smm];', o, pt (e.pts), ...
                       fmt (e.radius / scale))};

    case 'ARC'
      ## TikZ draws an arc from the current point, counter-clockwise when the
      ## end angle exceeds the start, so the sweep is unrolled rather than
      ## passed as the two stored angles.
      sweep = mod (e.angles(2) - e.angles(1), 360);
      if (sweep == 0)
        sweep = 360;
      endif
      a1 = e.angles(1);
      start = e.pts + e.radius * [cosd(a1), sind(a1)];
      tmpl = strcat ('\\draw%s %s arc[start angle=%s, end angle=%s,', ...
                     ' radius=%smm];');
      lines = {sprintf(tmpl, o, pt (start), fmt (a1), ...
                       fmt (a1 + sweep), fmt (e.radius / scale))};

    case 'TEXT'
      opts = sprintf ('anchor=base west, inner sep=0pt, font=%s', ...
                      fontfor (e.height, scale));
      if (e.rotation != 0)
        opts = sprintf ('%s, rotate=%s', opts, fmt (e.rotation));
      endif
      lines = {sprintf('\\node[%s] at %s {%s};', opts, pt (e.pts), ...
                       texescape (e.text))};

    case 'POINT'
      lines = {sprintf('\\fill%s %s circle[radius=0.3mm];', o, ...
                       pt (e.pts))};

    otherwise
      lines = {};

  endswitch

endfunction

## Render a semantic dimension.  The construction of the dimension line is the
## same as in draw.entities -- it has to be, or the two outputs would disagree
## about where the dimension sits -- but the label is placed by anchoring a
## node, so nothing here estimates the width of a string.
function lines = renderdim (e, scale)

  P1 = e.pts(1,:);
  P2 = e.pts(2,:);
  d = P2 - P1;

  switch (e.direction)
    case 'horizontal'
      U = [1, 0];
    case 'vertical'
      U = [0, 1];
    otherwise
      U = d / norm (d);
  endswitch
  N = [-U(2), U(1)];

  A1 = P1 + e.offset * N;
  A2 = P2 + (e.offset - dot (d, N)) * N;

  ## Ornament in model units, so that it comes out at a fixed size on paper
  gap = 1.0 * scale;
  over = 1.25 * scale;
  tick = 1.25 * scale;

  E1 = unitor (A1 - P1, N);
  E2 = unitor (A2 - P2, N);

  lines = {};
  lines{end+1} = sprintf ('\\draw %s -- %s;', pt (P1 + gap * E1), ...
                          pt (A1 + over * E1));
  lines{end+1} = sprintf ('\\draw %s -- %s;', pt (P2 + gap * E2), ...
                          pt (A2 + over * E2));
  lines{end+1} = sprintf ('\\draw %s -- %s;', pt (A1), pt (A2));

  T = (U + N) / sqrt (2);
  lines{end+1} = sprintf ('\\draw %s -- %s;', pt (A1 - tick * T), ...
                          pt (A1 + tick * T));
  lines{end+1} = sprintf ('\\draw %s -- %s;', pt (A2 - tick * T), ...
                          pt (A2 + tick * T));

  if (isempty (e.text))
    m = abs (dot (d, U));
    if (abs (m - round (m)) < 1e-9)
      label = sprintf ('%d', round (m));
    else
      label = sprintf ('%.1f', m);
    endif
  else
    label = e.text;
  endif

  ## The node anchors itself against the side the dimension line was offset
  ## to, so TikZ does the centring and the measuring.
  side = sign0 (e.offset) * N;
  if (abs (side(2)) >= abs (side(1)))
    if (side(2) >= 0)
      anchor = 'south';
    else
      anchor = 'north';
    endif
  else
    if (side(1) >= 0)
      anchor = 'west';
    else
      anchor = 'east';
    endif
  endif

  mid = (A1 + A2) / 2;
  lines{end+1} = sprintf (strcat ('\\node[anchor=%s, inner sep=0.8mm,', ...
                                  ' font=%s] at %s {%s};'), anchor, ...
                          fontfor (2.5 * scale, scale), pt (mid), ...
                          texescape (label));

endfunction

## A coordinate, in model millimetres.
function s = pt (P)

  s = sprintf ('(%s,%s)', fmt (P(1)), fmt (P(2)));

endfunction

## A number, without the trailing noise a plain %f leaves behind.
function s = fmt (x)

  s = sprintf ('%.6g', x);

endfunction

## A LaTeX font selection giving a cap height of H model millimetres at the
## stated scale.  TeX points, not the printer's points a CAD application uses.
function s = fontfor (H, scale)

  pts = (H / scale) * 72.27 / 25.4;
  s = sprintf ('\\fontsize{%s}{%s}\\selectfont', fmt (pts), fmt (1.2 * pts));

endfunction

## Map a CAD hatch pattern onto a TikZ one.  Only the patterns an engineering
## drawing actually uses are worth naming; anything else falls back rather than
## Escape the characters LaTeX would otherwise act on.  The backslash has to go
## first, or the escapes introduced for everything else get escaped in turn.
function s = texescape (t)

  ## Drawing symbols first, before the escaping turns their per cent signs into
  ## literals.  The replacements need no package beyond what any document has.
  t = strrep (t, '%%%', "\x00PC\x00");
  t = strrep (t, '%%c', "\x00DIA\x00");
  t = strrep (t, '%%C', "\x00DIA\x00");
  t = strrep (t, '%%d', "\x00DEG\x00");
  t = strrep (t, '%%D', "\x00DEG\x00");
  t = strrep (t, '%%p', "\x00PM\x00");
  t = strrep (t, '%%P', "\x00PM\x00");

  s = strrep (t, '\', '\textbackslash');
  s = strrep (s, '{', '\{');
  s = strrep (s, '}', '\}');
  s = strrep (s, '\textbackslash', '\textbackslash{}');
  for c = {'&', '%', '$', '#', '_'}
    s = strrep (s, c{1}, ['\', c{1}]);
  endfor
  s = strrep (s, '~', '\textasciitilde{}');
  s = strrep (s, '^', '\textasciicircum{}');

  s = strrep (s, "\x00DIA\x00", '\O{}');
  s = strrep (s, "\x00DEG\x00", '$^\circ$');
  s = strrep (s, "\x00PM\x00", '$\pm$');
  s = strrep (s, "\x00PC\x00", '\%');

endfunction

## The unit vector along V, falling back to FB when V vanishes.
function U = unitor (V, FB)

  n = norm (V);
  if (n > 0)
    U = V / n;
  else
    U = FB;
  endif

endfunction

## sign(), but never zero.
function s = sign0 (x)

  s = sign (x);
  if (s == 0)
    s = 1;
  endif

endfunction

%!demo
%! ## The LaTeX backend, for a drawing that belongs in a report rather than in
%! ## a CAD program.  Each layer becomes a TikZ scope with a style of its own,
%! ## so the document can restyle a layer by redefining it.
%!
%! D = draw.Drawing ('bracket');
%! D.Layer = 'BODY';
%! D = D.polyline ([0, 0; 40, 0; 40, 25; 0, 25], true).circle ([20, 12.5], 6);
%! D.Layer = 'AXES';
%! D.Linetype = 'CENTER';
%! D.Colour = 'red';
%! D = D.centremark ();
%! S = draw.tikz (D, 'scale', 2);
%! disp (S);

%!demo
%! ## Dash lengths are model dimensions times a line-type scale, as CAD's
%! ## LTSCALE works.  Defaulting that factor to the drawing scale brings the
%! ## dashes to the page at nominal size whatever the view is drawn at.
%!
%! D = draw.Drawing ();
%! D.Linetype = 'DASHED';
%! D = D.line ([0, 0], [50, 0]);
%! for sc = [1, 20]
%!   S = draw.tikz (D, 'scale', sc);
%!   m = regexp (S, 'dash pattern=[^]]*', 'match');
%!   printf ('scale 1:%-3d %s\n', sc, m{1});
%! endfor

%!test  # the picture is opened and closed, and carries the drawing name
%! S = draw.tikz (draw.Drawing ('katopsi').line ([0, 0], [10, 0]));
%! assert_equal (! isempty (strfind (S, '\begin{tikzpicture}')), true);
%! assert_equal (! isempty (strfind (S, '\end{tikzpicture}')), true);
%! assert_equal (! isempty (strfind (S, 'Drawing: katopsi')), true);

%!test  # the scale reaches the unit vectors, not the coordinates
%! S = draw.tikz (draw.Drawing ().line ([0, 0], [1600, 0]), 'Scale', 50);
%! assert_equal (! isempty (strfind (S, 'x=0.02mm, y=0.02mm')), true);
%! assert_equal (! isempty (strfind (S, '\draw (0,0) -- (1600,0);')), true);

%!test  # a 1:1 drawing has unit vectors of one millimetre
%! S = draw.tikz (draw.Drawing ().line ([0, 0], [10, 0]), 'Scale', 1);
%! assert_equal (! isempty (strfind (S, 'x=1mm, y=1mm')), true);

%!test  # an open polyline is not cycled and a closed one is
%! So = draw.tikz (draw.Drawing ().polyline ([0, 0; 1, 0; 1, 1]));
%! Sc = draw.tikz (draw.Drawing ().polyline ([0, 0; 1, 0; 1, 1], true));
%! assert_equal (! isempty (strfind (So, '(0,0) -- (1,0) -- (1,1);')), true);
%! assert_equal (! isempty (strfind (Sc, '(1,1) -- cycle;')), true);

%!test  # a radius is absolute, already divided by the scale
%! S = draw.tikz (draw.Drawing ().circle ([0, 0], 500), 'Scale', 50);
%! assert_equal (! isempty (strfind (S, 'circle[radius=10mm]')), true);

%!test  # an arc is unrolled so that the end angle exceeds the start
%! S = draw.tikz (draw.Drawing ().arc ([0, 0], 100, 315, 45), 'Scale', 1);
%! t = 'start angle=315, end angle=405';
%! assert_equal (! isempty (strfind (S, t)), true);

%!test  # equal arc angles unroll to a full turn
%! S = draw.tikz (draw.Drawing ().arc ([0, 0], 100, 45, 45));
%! t = 'start angle=45, end angle=405';
%! assert_equal (! isempty (strfind (S, t)), true);

%!test  # text is anchored at the baseline, matching the DXF insertion point
%! S = draw.tikz (draw.Drawing ().text ([1, 2], 'NOTE'));
%! assert_equal (! isempty (strfind (S, 'anchor=base west')), true);
%! assert_equal (! isempty (strfind (S, 'at (1,2) {NOTE}')), true);

%!test  # a rotated text keeps its rotation, unlike the DXF path
%! S = draw.tikz (draw.Drawing ().text ([0, 0], 'A', 2.5, 90));
%! assert_equal (! isempty (strfind (S, 'rotate=90')), true);

%!test  # text height is emitted in points at the plotted size
%! S = draw.tikz (draw.Drawing ().text ([0, 0], 'A', 125), 'Scale', 50);
%! assert_equal (! isempty (strfind (S, '\fontsize{7.11319}')), true);

%!test  # LaTeX special characters are escaped
%! S = draw.tikz (draw.Drawing ().text ([0, 0], '50% #3_a & b'));
%! assert_equal (! isempty (strfind (S, '50\% \#3\_a \& b')), true);

%!test  # a backslash escapes without its own escape being re-escaped
%! S = draw.tikz (draw.Drawing ().text ([0, 0], 'a\b'));
%! assert_equal (! isempty (strfind (S, 'a\textbackslash{}b')), true);

%!test  # braces are escaped
%! S = draw.tikz (draw.Drawing ().text ([0, 0], 'a{b}c'));
%! assert_equal (! isempty (strfind (S, 'a\{b\}c')), true);

%!test  # Greek text passes through untouched
%! S = draw.tikz (draw.Drawing ().text ([0, 0], 'ΤΟΜΗ'));
%! assert_equal (! isempty (strfind (S, '{ΤΟΜΗ}')), true);

%!test  # each layer becomes a scope, and a style is defined for it
%! D = draw.Drawing ();
%! D.Layer = 'outline';
%! D = D.line ([0, 0], [1, 0]);
%! D.Layer = 'inner';
%! D = D.line ([0, 1], [1, 1]);
%! S = draw.tikz (D);
%! assert_equal (! isempty (strfind (S, 'drinner/.style={}')), true);
%! assert_equal (! isempty (strfind (S, 'droutline/.style={}')), true);
%! assert_equal (! isempty (strfind (S, '\begin{scope}[drinner]')), true);
%! assert_equal (! isempty (strfind (S, '% layer: outline')), true);

%!test  # Styles false drops the definitions but keeps the scopes
%! D = draw.Drawing ().line ([0, 0], [1, 0]);
%! S = draw.tikz (D, 'Styles', false);
%! assert_equal (isempty (strfind (S, '\tikzset{')), true);
%! assert_equal (! isempty (strfind (S, '\begin{scope}[')), true);

%!test  # layer names differing only in punctuation get distinct styles
%! D = draw.Drawing ();
%! D.Layer = 'a-b';
%! D = D.line ([0, 0], [1, 0]);
%! D.Layer = 'ab';
%! D = D.line ([0, 1], [1, 1]);
%! S = draw.tikz (D);
%! assert_equal (! isempty (strfind (S, 'drab1')), true);
%! assert_equal (! isempty (strfind (S, 'drab2')), true);

%!test  # a layer with no letters in its name still gets a usable style
%! S = draw.tikz (draw.Drawing ().line ([0, 0], [1, 0]));
%! assert_equal (! isempty (strfind (S, 'dr1/.style={}')), true);

%!test  # a hatch arrives as its boundary and the fill lines that draw.entities
%!       # generates, the same ones the DXF file carries.  The native TikZ
%!       # pattern this replaced stroked no boundary at all and ignored the
%!       # angle and spacing the hatch was given.
%! S = draw.tikz (draw.Drawing ().hatch ([0, 0; 10, 0; 10, 10]));
%! assert_equal (! isempty (strfind (S, '-- cycle;')), true);
%! assert_equal (numel (strfind (S, '\draw')) > 3, true);
%! assert_equal (isempty (strfind (S, 'pattern=')), true);

%!test  # a drawing without a hatch does not ask for the patterns library
%! S = draw.tikz (draw.Drawing ().line ([0, 0], [1, 0]));
%! assert_equal (isempty (strfind (S, 'usetikzlibrary')), true);

%!test  # a dimension renders as five strokes and one node
%! S = draw.tikz (draw.Drawing ().dim ([0, 0], [100, 0], -20, 'horizontal'));
%! assert_equal (numel (strfind (S, '\draw')), 5);
%! assert_equal (numel (strfind (S, '\node')), 1);

%!test  # the dimension line agrees with the one draw.entities emits
%! D = draw.Drawing ().dim ([0, 0], [300, 400], -50, 'horizontal');
%! E = draw.entities (D);
%! S = draw.tikz (D);
%! expect = sprintf ('\\draw (%g,%g) -- (%g,%g);', E(3).pts(1,1), ...
%!                   E(3).pts(1,2), E(3).pts(2,1), E(3).pts(2,2));
%! assert_equal (! isempty (strfind (S, expect)), true);

%!test  # an unlabelled dimension is annotated with what it measures
%! S = draw.tikz (draw.Drawing ().dim ([0, 0], [1600, 0], -50, 'horizontal'));
%! assert_equal (! isempty (strfind (S, '{1600}')), true);

%!test  # a label overrides the measurement and is escaped
%! S = draw.tikz (draw.Drawing ().dim ([0, 0], [1600, 0], -50, 'horizontal', ...
%!                                     'MIN. 100%'));
%! assert_equal (! isempty (strfind (S, '{MIN. 100\%}')), true);

%!test  # a dimension arrives already exploded, so the label is placed the same
%!       # way here as it is in the file
%! S = draw.tikz (draw.Drawing ().dim ([0, 0], [100, 0], 20, 'horizontal'));
%! assert_equal (! isempty (strfind (S, '\node')), true);
%! assert_equal (numel (strfind (S, '\draw')) >= 5, true);

%!test  # every entity type reaches the backend, including the ones added last
%! D = draw.Drawing ().diam ([0, 0], 10).radius ([40, 0], 5);
%! D = D.angdim ([80, 0], [90, 0], [80, 10], 6).centremark ([0, 0], 10);
%! D = D.leader ([10, 10; 20, 20; 30, 20], 'NOTE').ellipse ([120, 0], 20, 8);
%! S = draw.tikz (D);
%! assert_equal (numel (strfind (S, '\draw')) > 8, true);
%! assert_equal (numel (strfind (S, '\node')), 4);

%!test  # an empty drawing still yields a valid, empty picture
%! S = draw.tikz (draw.Drawing ());
%! assert_equal (! isempty (strfind (S, '\begin{tikzpicture}')), true);
%! assert_equal (isempty (strfind (S, '\begin{scope}')), true);

%!test  # File writes the same code that is returned
%! fn = [tempname(), '.tex'];
%! unwind_protect
%!   S = draw.tikz (draw.Drawing ('w').line ([0, 0], [10, 0]), 'File', fn);
%!   assert_equal (exist (fn, 'file') == 2, true);
%!   fid = fopen (fn, 'rt');
%!   txt = fread (fid, Inf, 'char=>char').';
%!   fclose (fid);
%!   assert_equal (strtrim (txt), strtrim (S));
%! unwind_protect_cleanup
%!   unlink (fn);
%! end_unwind_protect

%!error<draw.tikz: invalid number of input arguments.> ...
%! draw.tikz ()
%!error<draw.tikz: D must be a draw.Drawing object.> ...
%! draw.tikz ('plan')
%!error<draw.tikz: optional arguments must come in name-value pairs.> ...
%! draw.tikz (draw.Drawing (), 'Scale')
%!error<draw.tikz: option names must be character vectors.> ...
%! draw.tikz (draw.Drawing (), 42, 1)
%!error<draw.tikz: unknown option 'Colour'.> ...
%! draw.tikz (draw.Drawing (), 'Colour', 'red')
%!error<draw.tikz: Scale must be a real positive finite scalar.> ...
%! draw.tikz (draw.Drawing (), 'Scale', 0)
%!error<draw.tikz: Scale must be a real positive finite scalar.> ...
%! draw.tikz (draw.Drawing (), 'Scale', [1, 2])
%!error<draw.tikz: File must be a non-empty character vector.> ...
%! draw.tikz (draw.Drawing (), 'File', '')
%!error<draw.tikz: Styles must be a logical scalar.> ...
%! draw.tikz (draw.Drawing (), 'Styles', 'yes')

%!test  # a styled entity carries colour and dash pattern as draw options
%! D = draw.Drawing ();
%! D.Linetype = 'CENTER';
%! D.Colour = 'red';
%! S = draw.tikz (D.line ([0, 0], [1, 0]));
%! assert_equal (! isempty (strfind (S, '\draw[red, dash pattern=on')), true);

%!test  # a default entity carries no options at all
%! S = draw.tikz (draw.Drawing ().line ([0, 0], [1, 0]));
%! assert_equal (isempty (strfind (S, '\draw[')), true);
%! assert_equal (! isempty (strfind (S, '\draw ')), true);

%!test  # by default LTScale follows the drawing scale, so dashes reach the
%!       # page at nominal size whatever the view is drawn at
%! D = draw.Drawing ();
%! D.Linetype = 'DASHED';
%! L = D.line ([0, 0], [1, 0]);
%! S1 = draw.tikz (L, 'scale', 1);
%! S50 = draw.tikz (L, 'scale', 50);
%! assert_equal (! isempty (strfind (S1, 'on 0.5mm off 0.25mm')), true);
%! assert_equal (! isempty (strfind (S50, 'on 0.5mm off 0.25mm')), true);

%!test  # an explicit LTScale multiplies the pattern, as CAD's LTSCALE does
%! D = draw.Drawing ();
%! D.Linetype = 'DASHED';
%! S = draw.tikz (D.line ([0, 0], [1, 0]), 'scale', 50, 'ltscale', 100);
%! assert_equal (! isempty (strfind (S, 'on 1mm off 0.5mm')), true);

%!test  # the rule is one rule: pattern times LTScale over scale
%! D = draw.Drawing ();
%! D.Linetype = 'DASHED';
%! S = draw.tikz (D.line ([0, 0], [1, 0]), 'scale', 10, 'ltscale', 5);
%! assert_equal (! isempty (strfind (S, 'on 0.25mm off 0.125mm')), true);

%!error<draw.tikz: LTScale must be a real positive finite scalar.> ...
%! draw.tikz (draw.Drawing (), 'ltscale', 0)

%!test  # the spacing given to a hatch reaches the page, which the native
%!       # pattern it replaced could not carry
%! P = [0, 0; 40, 0; 40, 40; 0, 40];
%! Swide = draw.tikz (draw.Drawing ().hatch (P, 'ANSI31', 0, 8));
%! Sfine = draw.tikz (draw.Drawing ().hatch (P, 'ANSI31', 0, 2));
%! assert_equal (numel (strfind (Sfine, '\draw')) ...
%!               > numel (strfind (Swide, '\draw')), true);

%!test  # and a sectioned area is drawn with its outline
%! P = [0, 0; 40, 0; 40, 40; 0, 40];
%! S = draw.tikz (draw.Drawing ().hatch (P, 'ANSI31'));
%! assert_equal (! isempty (strfind (S, '-- cycle;')), true);
