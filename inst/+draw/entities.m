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
## @deftypefn  {drafting} {@var{E} =} draw.entities (@var{D})
## @deftypefnx {drafting} {@var{E} =} draw.entities (@var{D}, @var{NAME}, @var{VALUE}, @dots{})
## @deftypefnx {drafting} {[@var{E}, @var{LOST}] =} draw.entities (@dots{})
##
## Lower a drawing to the flat entity struct array that @code{dxf.write} takes.
##
## @code{@var{E} = draw.entities (@var{D})} converts the @code{draw.Drawing}
## object @var{D} into the entity vocabulary of the DXF layer: @code{LINE},
## @code{POLYLINE}, @code{ARC}, @code{CIRCLE} and @code{TEXT}, each on the
## layer it was drawn on.  The result is written with
## @code{dxf.write (@var{FILE}, @var{E})}.
##
## This is the adapter between the two representations and the only place that
## knows both.  @code{dxf} deals in a file format and knows nothing of
## dimensions or hatches; @code{draw} models the drawing and knows nothing of
## group codes.
##
## @subheading Dimensions are exploded here
##
## A @code{'dim'} entity carries only geometry --- two points, an offset and a
## direction.  It becomes six entities: two extension lines, the dimension
## line, two oblique ticks and the text.  Nothing associative is emitted: a
## true @code{DIMENSION} needs a @code{*D} block and a @code{DIMSTYLE} record,
## and plots identically.
##
## Ticks are the 45-degree architectural obliques rather than arrowheads.  R12
## draws a filled arrowhead only as a @code{SOLID}, and at drawing scale the
## tick is the conventional mark in any case.
##
## The text is placed @strong{horizontally whatever the dimension measures}
## --- unidirectional dimensioning, which ISO 129 permits and which keeps every
## label on the sheet readable from one side of it.
##
## The label always clears the dimension line, on the far side from the
## geometry being measured.  A dimension across the sheet carries its label
## above or below the line; one up the sheet carries it to the left or right,
## since a horizontal label beside a vertical dimension has to clear the line
## by its @emph{width}.  Which side is which follows the sign of the offset.
##
## Without a label a dimension is annotated with the distance it measures,
## computed at the moment of conversion, so a dimension cannot fall out of step
## with the geometry it spans.
##
## @subheading Ornament size
##
## Dimension ornament --- tick length, text height, the gap between a measured
## point and the start of its extension line --- is in millimetres of
## @emph{model space}, so its size on the sheet depends on the plot scale.
## Pass @qcode{'DimScale'} to set it: a drawing to be plotted at @math{1:50}
## wants @code{'DimScale', 50}, which makes a nominally @math{2.5} mm text
## @math{125} mm in the model and therefore @math{2.5} mm on paper.  The
## default is @math{1}.
##
## @subheading What the DXF vocabulary cannot carry
##
## One thing in the model has no R12 equivalent, and it is not dropped
## silently: a @code{'hatch'} becomes its boundary as a closed polyline, so the
## region is outlined but not filled, R12 having no @code{HATCH} entity.
##
## Text rotation used to be the second such case and no longer is.
## @code{dxf.write} emits group code 50, so a rotated @code{'text'} arrives in
## the CAD file at the angle it was drawn at.
##
## @code{[@var{E}, @var{LOST}] = draw.entities (@dots{})} returns the losses as
## a struct array with fields @code{index}, @code{type} and @code{reason},
## naming the entity of @var{D} that lost something.  Ask for @var{LOST} and
## nothing is printed; omit it and each distinct reason is warned about once,
## because a conversion that quietly discards part of a drawing is the one
## failure mode a CAD file will not show you.
##
## @seealso{dxf.write, draw.Drawing}
## @end deftypefn

function [E, LOST] = entities (D, varargin)

  ## Input validation
  if (nargin < 1)
    error ("draw.entities: invalid number of input arguments.");
  endif
  if (! isa (D, 'draw.Drawing'))
    error ("draw.entities: D must be a draw.Drawing object.");
  endif
  if (mod (numel (varargin), 2) != 0)
    error ("draw.entities: optional arguments must come in name-value pairs.");
  endif

  dimScale = 1;
  for ii = 1:2:numel (varargin)
    name = varargin{ii};
    if (! ischar (name) || ! isrow (name))
      error ("draw.entities: option names must be character vectors.");
    endif
    switch (lower (name))
      case 'dimscale'
        dimScale = varargin{ii+1};
        if (! isnumeric (dimScale) || ! isreal (dimScale) ...
            || ! isscalar (dimScale) || ! isfinite (dimScale) ...
            || dimScale <= 0)
          error (strcat ("draw.entities: DimScale must be a real positive", ...
                         " finite scalar."));
        endif
        dimScale = double (dimScale);
      otherwise
        error ("draw.entities: unknown option '%s'.", name);
    endswitch
  endfor

  E = emptyentity ();
  LOST = struct ('index', {}, 'type', {}, 'reason', {});

  src = D.Entities;
  for ii = 1:numel (src)

    e = src(ii);

    switch (e.type)

      case 'line'
        E(end+1) = mkent ('LINE', e, e.pts);

      case 'polyline'
        p = mkent ('POLYLINE', e, e.pts);
        p.closed = e.closed;
        E(end+1) = p;

      case 'arc'
        a = mkent ('ARC', e, e.pts);
        a.radius = e.radius;
        a.angles = e.angles;
        E(end+1) = a;

      case 'circle'
        c = mkent ('CIRCLE', e, e.pts);
        c.radius = e.radius;
        E(end+1) = c;

      case 'text'
        t = mkent ('TEXT', e, e.pts);
        t.text = e.text;
        t.height = e.height;
        t.rotation = e.angle;
        E(end+1) = t;

      case 'hatch'
        h = mkent ('POLYLINE', e, e.pts);
        h.closed = true;
        E(end+1) = h;
        LOST(end+1) = struct ('index', ii, 'type', 'hatch', 'reason', ...
                              strcat ('fill dropped: R12 has no HATCH,', ...
                                      ' boundary emitted'));

      case 'dim'
        parts = explodedim (e, dimScale);
        for jj = 1:numel (parts)
          E(end+1) = parts(jj);
        endfor

    endswitch

  endfor

  ## Warn only when the caller has not asked to be told properly.
  if (nargout < 2 && ! isempty (LOST))
    reasons = unique ({LOST.reason});
    for ii = 1:numel (reasons)
      n = sum (strcmp ({LOST.reason}, reasons{ii}));
      if (n == 1)
        warning ("draw.entities: 1 entity: %s.", reasons{ii});
      else
        warning ("draw.entities: %d entities: %s.", n, reasons{ii});
      endif
    endfor
  endif

endfunction

## The empty entity array, in dxf.write's vocabulary.  Field order is fixed so
## that the array grows by assignment.
function E = emptyentity ()

  E = struct ('type', {}, 'layer', {}, 'linetype', {}, 'colour', {}, ...
              'pts', {}, 'closed', {}, ...
              'radius', {}, 'angles', {}, 'text', {}, 'height', {}, ...
              'rotation', {});

endfunction

## One entity with the unused fields at their defaults.
## Build a DXF record from the drawing entity E it came from, so that layer,
## line type and colour travel with the geometry rather than being reapplied.
## Exploded parts of a dimension inherit them too: the rule is uniform, and a
## caller wanting continuous dimension lines sets the line type before
## dimensioning, which is the natural order anyway.
function s = mkent (type, e, pts)

  s = struct ('type', type, 'layer', e.layer, ...
              'linetype', optfield (e, 'linetype', 'CONTINUOUS'), ...
              'colour', optfield (e, 'colour', 256), ...
              'pts', pts, 'closed', false, ...
              'radius', [], 'angles', [], 'text', '', 'height', [], ...
              'rotation', 0);

endfunction

## A field if the entity carries one, the default otherwise
function v = optfield (e, name, dflt)

  if (isfield (e, name) && ! isempty (e.(name)))
    v = e.(name);
  else
    v = dflt;
  endif

endfunction

## Explode a semantic dimension into the six entities that draw it.
##
## The construction is the same for all three directions once the measuring
## direction U is chosen: N is U turned a quarter-turn counter-clockwise, and
## each measured point is carried onto the dimension line along N.  A
## horizontal dimension between points at different heights therefore gets
## extension lines of different lengths, which is exactly right.
function parts = explodedim (e, scale)

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

  ## Ornament, in model millimetres
  tick = 1.25 * scale;      # half-length of the oblique tick
  gap = 1.0 * scale;        # from the measured point to its extension line
  over = 1.25 * scale;      # how far the extension line runs past the dim line
  hgt = 2.5 * scale;        # text cap height
  tgap = 0.8 * scale;       # from the dimension line up to the text baseline

  ## Carry each measured point onto the dimension line along N
  A1 = P1 + e.offset * N;
  A2 = P2 + (e.offset - dot (d, N)) * N;

  ## Extension lines: start clear of the measured point, end past the dim line
  parts = mkent ('LINE', e, [P1 + gap * unitor(A1 - P1, N); ...
                                   A1 + over * unitor(A1 - P1, N)]);
  parts(end+1) = mkent ('LINE', e, [P2 + gap * unitor(A2 - P2, N); ...
                                          A2 + over * unitor(A2 - P2, N)]);

  ## The dimension line itself
  parts(end+1) = mkent ('LINE', e, [A1; A2]);

  ## Oblique ticks at 45 degrees to the dimension line, centred on each foot
  T = (U + N) / sqrt (2);
  parts(end+1) = mkent ('LINE', e, [A1 - tick * T; A1 + tick * T]);
  parts(end+1) = mkent ('LINE', e, [A2 - tick * T; A2 + tick * T]);

  ## The label, horizontal whatever the dimension measures
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

  ## Place the label clear of the dimension line, on the far side from the
  ## geometry being measured.
  ##
  ## A DXF TEXT is positioned by the left end of its baseline and grows right
  ## and up from there, so the insertion point is not where the label appears
  ## to sit.  Both consequences have to be undone by hand: pushing the text
  ## down by the gap alone would leave the glyphs growing back up through the
  ## dimension line, and a label centred on a vertical dimension would straddle
  ## it.  So the box is placed, and the insertion point derived from it.
  ##
  ## Centring needs the width, which needs font metrics we do not have.  Six
  ## tenths of the cap height per character is close for the stroke fonts a CAD
  ## application substitutes here, and being slightly out matters far less than
  ## a label sitting nowhere near the middle.
  mid = (A1 + A2) / 2;
  wid = 0.6 * hgt * numel (label);
  side = sign0 (e.offset) * N;

  if (abs (side(2)) >= abs (side(1)))
    ## Dimension line lies across the sheet: the label goes above or below it
    ix = mid(1) - wid / 2;
    if (side(2) >= 0)
      iy = mid(2) + tgap;
    else
      iy = mid(2) - tgap - hgt;
    endif
  else
    ## Dimension line lies up the sheet: the label goes beside it, and the
    ## text stays horizontal, so it is the width that must clear the line
    iy = mid(2) - hgt / 2;
    if (side(1) >= 0)
      ix = mid(1) + tgap;
    else
      ix = mid(1) - tgap - wid;
    endif
  endif

  t = mkent ('TEXT', e, [ix, iy]);
  t.text = label;
  t.height = hgt;
  parts(end+1) = t;

endfunction

## The unit vector along V, falling back to the direction FB when V vanishes.
## An extension line has zero length when its measured point already lies on
## the dimension line, which happens whenever the offset is zero.
function U = unitor (V, FB)

  n = norm (V);
  if (n > 0)
    U = V / n;
  else
    U = FB;
  endif

endfunction

## sign(), but never zero: a dimension line drawn through its measured points
## still has to put its text on one side.
function s = sign0 (x)

  s = sign (x);
  if (s == 0)
    s = 1;
  endif

endfunction

%!test  # a plain drawing lowers entity for entity
%! D = draw.Drawing ().line ([0, 0], [10, 0]).circle ([5, 5], 2);
%! E = draw.entities (D);
%! assert_equal (numel (E), 2);
%! assert_equal ({E.type}, {'LINE', 'CIRCLE'});
%! assert_equal (E(1).pts, [0, 0; 10, 0]);
%! assert_equal (E(2).radius, 2);

%!test  # the layer travels with the entity
%! D = draw.Drawing ();
%! D.Layer = 'outline';
%! D = D.polyline ([0, 0; 1, 0; 1, 1], true);
%! E = draw.entities (D);
%! assert_equal (E(1).type, 'POLYLINE');
%! assert_equal (E(1).layer, 'outline');
%! assert_equal (E(1).closed, true);

%!test  # the result has exactly the fields dxf.write expects
%! E = draw.entities (draw.Drawing ().line ([0, 0], [1, 1]));
%! assert_equal (fieldnames (E), {'type'; 'layer'; 'linetype'; 'colour'; ...
%!               'pts'; 'closed'; 'radius'; 'angles'; 'text'; 'height'; ...
%!               'rotation'});

%!test  # an empty drawing lowers to an empty entity array
%! E = draw.entities (draw.Drawing ());
%! assert_equal (isempty (E), true);
%! assert_equal (fieldnames (E), {'type'; 'layer'; 'linetype'; 'colour'; ...
%!               'pts'; 'closed'; 'radius'; 'angles'; 'text'; 'height'; ...
%!               'rotation'});

%!test  # an arc keeps its radius and both angles
%! E = draw.entities (draw.Drawing ().arc ([1, 2], 3, 30, 120));
%! assert_equal (E(1).type, 'ARC');
%! assert_equal (E(1).radius, 3);
%! assert_equal (E(1).angles, [30, 120]);

%!test  # a dimension explodes into six entities on its own layer
%! D = draw.Drawing ();
%! D.Layer = 'dims';
%! D = D.dim ([0, 0], [100, 0], -20, 'horizontal');
%! E = draw.entities (D);
%! assert_equal (numel (E), 6);
%! assert_equal ({E.type}, {'LINE', 'LINE', 'LINE', 'LINE', 'LINE', 'TEXT'});
%! assert_equal (unique ({E.layer}), {'dims'});

%!test  # the dimension line spans the measured points at the offset
%! D = draw.Drawing ().dim ([0, 0], [100, 0], -20, 'horizontal');
%! E = draw.entities (D);
%! assert_equal (E(3).pts, [0, -20; 100, -20], 1e-9);

%!test  # an unlabelled dimension is annotated with what it measures
%! D = draw.Drawing ().dim ([0, 0], [1600, 0], -50, 'horizontal');
%! E = draw.entities (D);
%! assert_equal (E(6).type, 'TEXT');
%! assert_equal (E(6).text, '1600');

%!test  # a label overrides the measurement
%! E = draw.entities (draw.Drawing ().dim ([0, 0], [1600, 0], -50, ...
%!                                         'horizontal', 'MIN. 1600'));
%! assert_equal (E(6).text, 'MIN. 1600');

%!test  # a horizontal dimension measures x alone, a vertical one y alone
%! Eh = draw.entities (draw.Drawing ().dim ([0, 0], [300, 400], 50, ...
%!                                          'horizontal'));
%! D = draw.Drawing ().dim ([0, 0], [300, 400], 50, 'vertical');
%! Ev = draw.entities (D);
%! Ea = draw.entities (draw.Drawing ().dim ([0, 0], [300, 400], 50, 'aligned'));
%! assert_equal (Eh(6).text, '300');
%! assert_equal (Ev(6).text, '400');
%! assert_equal (Ea(6).text, '500');

%!test  # both feet of a horizontal dimension land at the same height
%! E = draw.entities (draw.Drawing ().dim ([0, 0], [300, 400], -50, ...
%!                                         'horizontal'));
%! assert_equal (E(3).pts(1,2), E(3).pts(2,2), 1e-9);

%!test  # both feet of a vertical dimension land at the same x
%! D = draw.Drawing ().dim ([0, 0], [300, 400], -50, 'vertical');
%! E = draw.entities (D);
%! assert_equal (E(3).pts(1,1), E(3).pts(2,1), 1e-9);

%!test  # a non-integral measurement is given to one decimal
%! E = draw.entities (draw.Drawing ().dim ([0, 0], [10, 10], 5, 'aligned'));
%! assert_equal (E(6).text, '14.1');

%!test  # DimScale multiplies the ornament without moving the dimension line
%! D = draw.Drawing ().dim ([0, 0], [100, 0], -20, 'horizontal');
%! E1 = draw.entities (D);
%! E50 = draw.entities (D, 'DimScale', 50);
%! assert_equal (E1(3).pts, E50(3).pts, 1e-9);
%! assert_equal (E50(6).height, 50 * E1(6).height, 1e-9);

%!test  # the label clears a dimension line drawn below the geometry
%! E = draw.entities (draw.Drawing ().dim ([0, 0], [100, 0], -20, ...
%!                                         'horizontal'), 'DimScale', 10);
%! liney = E(3).pts(1,2);
%! assert_equal (E(6).pts(2) + E(6).height < liney, true);

%!test  # and one drawn above it
%! E = draw.entities (draw.Drawing ().dim ([0, 0], [100, 0], 20, ...
%!                                         'horizontal'), 'DimScale', 10);
%! liney = E(3).pts(1,2);
%! assert_equal (E(6).pts(2) > liney, true);

%!test  # a horizontal label beside a vertical dimension clears it by its width
%! D = draw.Drawing ().dim ([0, 0], [0, 100], 20, 'vertical');
%! E = draw.entities (D, ...
%!                    'DimScale', 10);
%! linex = E(3).pts(1,1);
%! wid = 0.6 * E(6).height * numel (E(6).text);
%! assert_equal (E(6).pts(1) + wid < linex, true);
%! assert_equal (abs (E(6).pts(2) + E(6).height / 2 - 50) < 1e-9, true);

%!test  # the label sits on the far side of the line from what it measures
%! Eu = draw.entities (draw.Drawing ().dim ([0, 0], [100, 0], 30, ...
%!                                          'horizontal'), 'DimScale', 10);
%! Ed = draw.entities (draw.Drawing ().dim ([0, 0], [100, 0], -30, ...
%!                                          'horizontal'), 'DimScale', 10);
%! assert_equal (Eu(6).pts(2) > Eu(3).pts(1,2), true);
%! assert_equal (Ed(6).pts(2) < Ed(3).pts(1,2), true);

%!test  # the label is centred along a dimension across the sheet
%! E = draw.entities (draw.Drawing ().dim ([0, 0], [1000, 0], -30, ...
%!                                         'horizontal'), 'DimScale', 10);
%! wid = 0.6 * E(6).height * numel (E(6).text);
%! assert_equal (abs (E(6).pts(1) + wid / 2 - 500) < 1e-9, true);

%!test  # a zero offset still produces a drawable dimension
%! E = draw.entities (draw.Drawing ().dim ([0, 0], [100, 0], 0, 'horizontal'));
%! assert_equal (numel (E), 6);
%! assert_equal (all (isfinite ([E(1).pts(:); E(2).pts(:)])), true);

%!test  # a hatch keeps its boundary and reports the fill it could not carry
%! D = draw.Drawing ().hatch ([0, 0; 10, 0; 10, 10]);
%! [E, LOST] = draw.entities (D);
%! assert_equal (numel (E), 1);
%! assert_equal (E(1).type, 'POLYLINE');
%! assert_equal (E(1).closed, true);
%! assert_equal (numel (LOST), 1);
%! assert_equal (LOST(1).type, 'hatch');
%! assert_equal (LOST(1).index, 1);

%!test  # a rotated text keeps its rotation and costs nothing
%! [E0, L0] = draw.entities (draw.Drawing ().text ([0, 0], 'A'));
%! [E9, L9] = draw.entities (draw.Drawing ().text ([0, 0], 'A', 2.5, 90));
%! assert_equal (E0(1).rotation, 0);
%! assert_equal (E9(1).rotation, 90);
%! assert_equal (isempty (L0), true);
%! assert_equal (isempty (L9), true);

%!test  # asking for LOST silences the warning, omitting it does not
%! D = draw.Drawing ().hatch ([0, 0; 10, 0; 10, 10]);
%! lastwarn ('');
%! [E, LOST] = draw.entities (D);
%! assert_equal (lastwarn (), '');
%! E = draw.entities (D);
%! assert_equal (isempty (lastwarn ()), false);

%!test  # a lowered drawing survives a DXF round trip
%! fn = [tempname(), '.dxf'];
%! unwind_protect
%!   D = draw.Drawing ('rt');
%!   D.Layer = 'outline';
%!   D = D.polyline ([0, 0; 1600, 0; 1600, 1800; 0, 1800], true);
%!   D.Layer = 'inner';
%!   D = D.line ([100, 100], [1500, 100]).circle ([800, 900], 50);
%!   dxf.write (fn, draw.entities (D));
%!   R = dxf.read (fn);
%!   assert_equal (numel (R), 3);
%!   assert_equal ({R.type}, {'POLYLINE', 'LINE', 'CIRCLE'});
%!   assert_equal (R(1).pts, [0, 0; 1600, 0; 1600, 1800; 0, 1800], 1e-6);
%!   assert_equal (R(1).closed, true);
%!   assert_equal (R(3).radius, 50, 1e-6);
%! unwind_protect_cleanup
%!   unlink (fn);
%! end_unwind_protect

%!error<draw.entities: invalid number of input arguments.> ...
%! draw.entities ()
%!error<draw.entities: D must be a draw.Drawing object.> ...
%! draw.entities (42)
%!error<draw.entities: optional arguments must come in name-value pairs.> ...
%! draw.entities (draw.Drawing (), 'DimScale')
%!error<draw.entities: option names must be character vectors.> ...
%! draw.entities (draw.Drawing (), 42, 1)
%!error<draw.entities: unknown option 'Colour'.> ...
%! draw.entities (draw.Drawing (), 'Colour', 'red')
%!error<draw.entities: DimScale must be a real positive finite scalar.> ...
%! draw.entities (draw.Drawing (), 'DimScale', 0)
%!error<draw.entities: DimScale must be a real positive finite scalar.> ...
%! draw.entities (draw.Drawing (), 'DimScale', [1, 2])

%!test  # line type and colour travel from the drawing to the DXF record
%! D = draw.Drawing ();
%! D.Linetype = 'CENTER';
%! D.Colour = 'red';
%! E = draw.entities (D.line ([0, 0], [1, 1]));
%! assert_equal (E(1).linetype, 'CENTER');
%! assert_equal (E(1).colour, 1);

%!test  # every exploded part of a dimension inherits them
%! D = draw.Drawing ();
%! D.Linetype = 'HIDDEN';
%! D.Colour = 5;
%! E = draw.entities (D.dim ([0, 0], [100, 0], -20, 'horizontal'));
%! assert_equal (all (strcmp ({E.linetype}, 'HIDDEN')), true);
%! assert_equal (all ([E.colour] == 5), true);

%!test  # the defaults survive translation untouched
%! E = draw.entities (draw.Drawing ().circle ([0, 0], 5));
%! assert_equal (E(1).linetype, 'CONTINUOUS');
%! assert_equal (E(1).colour, 256);
