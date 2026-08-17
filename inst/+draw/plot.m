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
## @deftypefn  {drafting} {} draw.plot (@var{D})
## @deftypefnx {drafting} {} draw.plot (@var{HAX}, @var{D})
## @deftypefnx {drafting} {} draw.plot (@dots{}, @var{Name}, @var{Value})
## @deftypefnx {drafting} {@var{H} =} draw.plot (@dots{})
##
## Draw a @code{draw.Drawing} into a figure, to look at it.
##
## @code{draw.plot (@var{D})} renders the drawing into the current axes at
## equal aspect ratio, honouring each entity's layer, line type and colour.
##
## @code{draw.plot (@var{HAX}, @var{D})} draws into the axes @var{HAX} instead
## of the current ones, as every plotting function in Octave accepts an axes
## handle ahead of its data.  The @qcode{'Axes'} pair below does the same thing
## and is equivalent.
##
## @code{@var{H} = draw.plot (@dots{})} returns a column of graphics handles,
## one per object created, so that a caller can restyle or delete them.
##
## @subheading Name/Value pairs
##
## @multitable @columnfractions 0.16 0.14 0.70
## @headitem Name @tab Default @tab Meaning
## @item @qcode{'Axes'} @tab @code{gca} @tab axes to draw into
## @item @qcode{'LineWidth'} @tab 0.5 @tab width of every line, in points
## @item @qcode{'FontSize'} @tab 8 @tab size of text, in points
## @item @qcode{'Layers'} @tab all @tab cell array of layer names to draw
## @item @qcode{'Arc'} @tab 64 @tab segments per full turn when sampling curves
## @item @qcode{'Hatch'} @tab @qcode{'lines'} @tab @qcode{'lines'} to fill a
## hatch, @qcode{'boundary'} for its outline alone
## @item @qcode{'Linetypes'} @tab @qcode{'true'} @tab @qcode{'true'} to draw the
## real dash patterns, @qcode{'approximate'} for the figure's own four styles
## @item @qcode{'LTScale'} @tab 1 @tab multiplies the dash lengths
## @end multitable
##
## @subheading What you see is what gets written
##
## The drawing is lowered through @code{draw.entities} --- the same conversion
## the DXF backend uses --- and the result of that is what is plotted.  A figure
## therefore shows the entities the file will contain, not a more flattering
## rendering of them.  In particular a hatch appears as its boundary alone,
## because that is what the file will carry; the second output of
## @code{draw.entities} says so explicitly.
##
## The alternative, rendering from the drawing model directly, would let the
## screen show something the recipient never receives.  For a package whose
## output is meant to be manufactured, that is the wrong way round.
##
## @subheading Line types are drawn properly, not approximated
##
## A figure offers four line styles and this package defines seven line types,
## so setting @code{linestyle} would collapse three of them onto their
## neighbours --- CENTER, DASHDOT and PHANTOM would all come out dash-dot, and a
## phantom line would be indistinguishable from a centre line.
##
## Instead each run of geometry is cut into its dashes and the pieces are drawn,
## so all seven patterns render as themselves.  Dash lengths are in the units of
## the drawing, multiplied by @qcode{'LTScale'}, which is the model-space
## convention CAD uses.  A drawing spanning tens of millimetres therefore needs
## no adjustment; one spanning metres wants an @qcode{'LTScale'} to match.
##
## The cost is one graphics object per dash.  Set @qcode{'Linetypes'} to
## @qcode{'approximate'} on a large drawing to fall back on the figure's four
## styles and one object per entity.
##
## @strong{Text is not to scale.}  A figure sets font size in points, which does
## not track the data units the drawing is in, so text cannot both sit at the
## right size and stay there when the axes are zoomed.  It is drawn at a fixed
## point size, positioned correctly.  For a rendering where text is to scale,
## use @code{draw.tikz}.
##
## @seealso{draw.Drawing, draw.entities, draw.tikz, dxf.write}
## @end deftypefn

function H = plot (varargin)

  ## Input validation
  if (numel (varargin) < 1)
    error ("draw.plot: invalid number of input arguments.");
  endif

  ## An axes handle may lead, as it may for every plotting function in Octave
  hax = [];
  if (! isa (varargin{1}, 'draw.Drawing') && isscalar (varargin{1}) ...
      && ishandle (varargin{1}))
    hax = varargin{1};
    varargin(1) = [];
  endif
  if (numel (varargin) < 1)
    error ("draw.plot: invalid number of input arguments.");
  endif
  D = varargin{1};
  varargin(1) = [];
  if (! isa (D, 'draw.Drawing'))
    error ("draw.plot: D must be a draw.Drawing object.");
  endif
  if (mod (numel (varargin), 2) != 0)
    error ("draw.plot: Name/Value arguments must come in pairs.");
  endif

  opt = struct ('Axes', hax, 'LineWidth', 0.5, 'FontSize', 8, ...
                'Layers', {{}}, 'Arc', 64, 'Hatch', 'lines', ...
                'Linetypes', 'true', 'LTScale', 1);
  known = fieldnames (opt);
  for k = 1:2:numel (varargin)
    name = varargin{k};
    if (! ischar (name) || ! isrow (name) || ! any (strcmp (name, known)))
      error ("draw.plot: unknown parameter.");
    endif
    opt.(name) = varargin{k+1};
  endfor
  if (! isempty (opt.Layers) && ! iscellstr (opt.Layers))
    error ("draw.plot: Layers must be a cell array of character vectors.");
  endif
  for f = {'Hatch', 'Linetypes'}
    if (! ischar (opt.(f{1})) || ! isrow (opt.(f{1})))
      error ("draw.plot: %s must be a character vector.", f{1});
    endif
  endfor
  if (! any (strcmpi (opt.Hatch, {'lines', 'boundary'})))
    error ("draw.plot: Hatch must be 'lines' or 'boundary'.");
  endif
  if (! any (strcmpi (opt.Linetypes, {'true', 'approximate'})))
    error ("draw.plot: Linetypes must be 'true' or 'approximate'.");
  endif
  for f = {'LineWidth', 'FontSize', 'Arc', 'LTScale'}
    v = opt.(f{1});
    if (! isnumeric (v) || ! isreal (v) || ! isscalar (v) || ! isfinite (v) ...
        || v <= 0)
      error ("draw.plot: %s must be a positive real finite scalar.", f{1});
    endif
  endfor

  if (isempty (opt.Axes))
    opt.Axes = gca ();
  elseif (! isscalar (opt.Axes) || ! ishandle (opt.Axes))
    error ("draw.plot: Axes must be a graphics handle.");
  endif

  ## The same lowering the file backends use, so the figure shows what the
  ## file will hold rather than a kinder version of it
  E = draw.entities (D, 'hatch', lower (opt.Hatch), 'bulges', 'flatten');
  if (! isempty (opt.Layers) && ! isempty (E))
    E = E(ismember ({E.layer}, opt.Layers));
  endif

  ax = opt.Axes;
  held = ishold (ax);
  hold (ax, 'on');
  H = [];

  unwind_protect
    for ii = 1:numel (E)
      e = E(ii);
      col = draw.colour (e.colour);

      switch (e.type)
        case {'LINE', 'POLYLINE', 'LWPOLYLINE'}
          P = e.pts;
          if (e.closed)
            P = [P; P(1,:)];
          endif
          H = [H; polydraw(ax, P, e.linetype, col, opt)];

        case {'CIRCLE', 'ARC'}
          if (strcmp (e.type, 'CIRCLE'))
            a = linspace (0, 360, opt.Arc + 1);
          else
            sweep = mod (e.angles(2) - e.angles(1), 360);
            if (sweep == 0)
              sweep = 360;
            endif
            n = max (2, ceil (opt.Arc * sweep / 360));
            a = linspace (e.angles(1), e.angles(1) + sweep, n + 1);
          endif
          P = [e.pts(1) + e.radius * cosd(a)', e.pts(2) + e.radius * sind(a)'];
          H = [H; polydraw(ax, P, e.linetype, col, opt)];

        case 'TEXT'
          H(end+1, 1) = text (e.pts(1), e.pts(2), e.text, 'parent', ax, ...
                              'color', col, 'fontsize', opt.FontSize, ...
                              'rotation', e.rotation, ...
                              'horizontalalignment', 'left', ...
                              'verticalalignment', 'baseline');

        case 'POINT'
          H(end+1, 1) = line (ax, e.pts(1), e.pts(2), 'color', col, ...
                              'marker', '+', 'linestyle', 'none');
      endswitch
    endfor

    axis (ax, 'equal');
  unwind_protect_cleanup
    if (! held)
      hold (ax, 'off');
    endif
  end_unwind_protect

  if (nargout == 0)
    clear H;
  endif

endfunction

## Draw one run of geometry in its line type.  With 'true' line types the run
## is cut into its dashes and each is a separate object, which is what lets all
## seven patterns render as themselves rather than collapsing onto the four
## styles a figure provides.
function H = polydraw (ax, P, lt, col, opt)

  H = [];
  if (rows (P) < 2)
    return;
  endif

  if (strcmpi (opt.Linetypes, 'approximate') || strcmpi (lt, 'CONTINUOUS'))
    H = line (ax, P(:,1), P(:,2), 'color', col, ...
              'linestyle', linestyle (lt), 'linewidth', opt.LineWidth);
    return;
  endif

  try
    pat = draw.linetype (lt) * opt.LTScale;
  catch
    pat = [];
  end_try_catch
  if (isempty (pat))
    H = line (ax, P(:,1), P(:,2), 'color', col, 'linestyle', '-', ...
              'linewidth', opt.LineWidth);
    return;
  endif

  for seg = dashes(P, pat)'
    d = seg{1};
    if (rows (d) == 1)
      H(end+1, 1) = line (ax, d(1,1), d(1,2), 'color', col, 'marker', '.', ...
                          'markersize', 2, 'linestyle', 'none');
    else
      H(end+1, 1) = line (ax, d(:,1), d(:,2), 'color', col, ...
                          'linestyle', '-', 'linewidth', opt.LineWidth);
    endif
  endfor

endfunction

## Cut a polyline into the drawn pieces of a dash pattern, walking it by arc
## length.  A zero-length element of the pattern is a dot, returned as a single
## point for the caller to mark.
function C = dashes (P, pat)

  seglen = sqrt (sum (diff (P, 1, 1) .^ 2, 2));
  total = sum (seglen);
  cum = [0; cumsum(seglen)];
  C = {};
  if (total <= 0)
    return;
  endif

  at = 0;
  k = 0;
  guard = 0;
  while (at < total && guard < 1e5)
    guard++;
    k = mod (k, numel (pat)) + 1;
    L = abs (pat(k));
    if (pat(k) < 0)
      at += max (L, eps);            # a gap
      continue;
    endif
    if (L == 0)
      C{end+1, 1} = interpat (P, cum, at);
      at += eps;                     # a dot has no length; the gap follows
      continue;
    endif
    stop = min (at + L, total);
    C{end+1, 1} = runbetween (P, cum, at, stop);
    at = stop;
  endwhile

endfunction

## The point at arc length T along the polyline
function q = interpat (P, cum, t)

  i = max (1, min (numel (cum) - 1, find (cum <= t, 1, 'last')));
  span = cum(i+1) - cum(i);
  if (span <= 0)
    q = P(i,:);
  else
    q = P(i,:) + (t - cum(i)) / span * (P(i+1,:) - P(i,:));
  endif

endfunction

## The piece of the polyline between two arc lengths, with any original
## vertices in between kept so that corners are not cut
function Q = runbetween (P, cum, t0, t1)

  Q = interpat (P, cum, t0);
  mid = find (cum > t0 & cum < t1);
  if (! isempty (mid))
    Q = [Q; P(mid,:)];
  endif
  Q = [Q; interpat(P, cum, t1)];

endfunction

## The nearest of the four line styles a figure offers, for 'approximate'.
function s = linestyle (lt)

  switch (upper (lt))
    case {'HIDDEN', 'DASHED'}
      s = '--';
    case 'DOT'
      s = ':';
    case {'CENTER', 'DASHDOT', 'PHANTOM'}
      s = '-.';
    otherwise
      s = '-';
  endswitch

endfunction

%!test  # a drawing renders one object per entity
%! f = figure ('visible', 'off');
%! unwind_protect
%!   D = draw.Drawing ().line ([0, 0], [1, 0]).circle ([0, 0], 2);
%!   H = draw.plot (D, 'Axes', axes ('parent', f));
%!   assert_equal (numel (H), 2);
%!   assert_equal (all (ishandle (H)), true);
%! unwind_protect_cleanup
%!   close (f);
%! end_unwind_protect

%!test  # the aspect ratio is equal, without which a drawing is a lie
%! f = figure ('visible', 'off');
%! unwind_protect
%!   ax = axes ('parent', f);
%!   draw.plot (draw.Drawing ().circle ([0, 0], 5), 'Axes', ax);
%!   r = get (ax, 'dataaspectratio');
%!   assert_equal (r(1), r(2), 1e-12);
%! unwind_protect_cleanup
%!   close (f);
%! end_unwind_protect

%!test  # colour reaches the plotted object
%! f = figure ('visible', 'off');
%! unwind_protect
%!   D = draw.Drawing ();
%!   D.Colour = 'red';
%!   H = draw.plot (D.line ([0, 0], [1, 1]), 'Axes', axes ('parent', f));
%!   assert_equal (get (H(1), 'color'), [1, 0, 0]);
%! unwind_protect_cleanup
%!   close (f);
%! end_unwind_protect

%!test  # approximate line types use the figure's own four styles
%! f = figure ('visible', 'off');
%! unwind_protect
%!   ax = axes ('parent', f);
%!   D = draw.Drawing ();
%!   D.Linetype = 'CENTER';
%!   D = D.line ([0, 0], [1, 0]);
%!   D.Linetype = 'HIDDEN';
%!   D = D.line ([0, 1], [1, 1]);
%!   H = draw.plot (D, 'Axes', ax, 'Linetypes', 'approximate');
%!   assert_equal (numel (H), 2);
%!   assert_equal (get (H(1), 'linestyle'), '-.');
%!   assert_equal (get (H(2), 'linestyle'), '--');
%! unwind_protect_cleanup
%!   close (f);
%! end_unwind_protect

%!test  # true line types cut the run into dashes, each drawn solid
%! f = figure ('visible', 'off');
%! unwind_protect
%!   D = draw.Drawing ();
%!   D.Linetype = 'DASHED';
%!   H = draw.plot (D.line ([0, 0], [20, 0]), 'Axes', axes ('parent', f));
%!   assert_equal (numel (H) > 1, true);
%!   assert_equal (all (strcmp (get (H, 'linestyle'), '-')), true);
%! unwind_protect_cleanup
%!   close (f);
%! end_unwind_protect

%!test  # the dashes cover the drawn fraction the pattern calls for
%! f = figure ('visible', 'off');
%! unwind_protect
%!   D = draw.Drawing ();
%!   D.Linetype = 'DASHED';
%!   H = draw.plot (D.line ([0, 0], [30, 0]), 'Axes', axes ('parent', f));
%!   L = 0;
%!   for h = H'
%!     x = get (h, 'xdata');
%!     L += abs (x(end) - x(1));
%!   endfor
%!   pat = draw.linetype ('DASHED');
%!   assert_equal (L / 30, sum (pat(pat > 0)) / sum (abs (pat)), 0.05);
%! unwind_protect_cleanup
%!   close (f);
%! end_unwind_protect

%!test  # patterns that collapse onto one style when approximated stay distinct
%! f = figure ('visible', 'off');
%! unwind_protect
%!   ax = axes ('parent', f);
%!   n = zeros (1, 3);
%!   k = 0;
%!   for lt = {'CENTER', 'DASHDOT', 'PHANTOM'}
%!     k++;
%!     D = draw.Drawing ();
%!     D.Linetype = lt{1};
%!     n(k) = numel (draw.plot (D.line ([0, 0], [40, 0]), 'Axes', ax));
%!   endfor
%!   assert_equal (numel (unique (n)) > 1, true);
%! unwind_protect_cleanup
%!   close (f);
%! end_unwind_protect

%!test  # LTScale stretches the pattern, so fewer dashes cover the same run
%! f = figure ('visible', 'off');
%! unwind_protect
%!   ax = axes ('parent', f);
%!   D = draw.Drawing ();
%!   D.Linetype = 'DASHED';
%!   L = D.line ([0, 0], [40, 0]);
%!   n1 = numel (draw.plot (L, 'Axes', ax, 'LTScale', 1));
%!   n4 = numel (draw.plot (L, 'Axes', ax, 'LTScale', 4));
%!   assert_equal (n4 < n1, true);
%! unwind_protect_cleanup
%!   close (f);
%! end_unwind_protect

%!test  # an axes handle may lead, as it may for any plotting function
%! f = figure ('visible', 'off');
%! unwind_protect
%!   ax = axes ('parent', f);
%!   H = draw.plot (ax, draw.Drawing ().line ([0, 0], [1, 1]));
%!   assert_equal (get (H(1), 'parent'), ax);
%! unwind_protect_cleanup
%!   close (f);
%! end_unwind_protect

%!test  # a leading handle and the Axes pair mean the same thing
%! f = figure ('visible', 'off');
%! unwind_protect
%!   ax = axes ('parent', f);
%!   D = draw.Drawing ().circle ([0, 0], 3);
%!   H1 = draw.plot (ax, D);
%!   H2 = draw.plot (D, 'Axes', ax);
%!   assert_equal (numel (H1), numel (H2));
%! unwind_protect_cleanup
%!   close (f);
%! end_unwind_protect

%!test  # a hatch is filled by default, and outlined when asked
%! f = figure ('visible', 'off');
%! unwind_protect
%!   ax = axes ('parent', f);
%!   D = draw.Drawing ().hatch ([0, 0; 20, 0; 20, 20; 0, 20]);
%!   nfill = numel (draw.plot (D, 'Axes', ax));
%!   nline = numel (draw.plot (D, 'Axes', ax, 'Hatch', 'boundary'));
%!   assert_equal (nline, 1);
%!   assert_equal (nfill > 1, true);
%! unwind_protect_cleanup
%!   close (f);
%! end_unwind_protect

%!test  # a closed polyline is closed on screen, not left open
%! f = figure ('visible', 'off');
%! unwind_protect
%!   P = [0, 0; 1, 0; 1, 1];
%!   H = draw.plot (draw.Drawing ().polyline (P, true), ...
%!                  'Axes', axes ('parent', f));
%!   assert_equal (numel (get (H(1), 'xdata')), 4);
%! unwind_protect_cleanup
%!   close (f);
%! end_unwind_protect

%!test  # the Layers filter draws only what was asked for
%! f = figure ('visible', 'off');
%! unwind_protect
%!   D = draw.Drawing ();
%!   D.Layer = 'A';  D = D.line ([0, 0], [1, 0]);
%!   D.Layer = 'B';  D = D.line ([0, 1], [1, 1]);
%!   H = draw.plot (D, 'Axes', axes ('parent', f), 'Layers', {'A'});
%!   assert_equal (numel (H), 1);
%! unwind_protect_cleanup
%!   close (f);
%! end_unwind_protect

%!test  # a dimension arrives already exploded, as the file will carry it
%! f = figure ('visible', 'off');
%! unwind_protect
%!   D = draw.Drawing ().dim ([0, 0], [100, 0], -20, 'horizontal');
%!   H = draw.plot (D, 'Axes', axes ('parent', f));
%!   assert_equal (numel (H) > 1, true);
%! unwind_protect_cleanup
%!   close (f);
%! end_unwind_protect

%!test  # an empty drawing plots nothing and does not raise
%! f = figure ('visible', 'off');
%! unwind_protect
%!   H = draw.plot (draw.Drawing (), 'Axes', axes ('parent', f));
%!   assert_equal (isempty (H), true);
%! unwind_protect_cleanup
%!   close (f);
%! end_unwind_protect

%!test  # an arc is sampled in proportion to its sweep
%! f = figure ('visible', 'off');
%! unwind_protect
%!   ax = axes ('parent', f);
%!   Dfull = draw.Drawing ().circle ([0, 0], 1);
%!   Hfull = draw.plot (Dfull, 'Axes', ax, 'Arc', 64);
%!   Hhalf = draw.plot (draw.Drawing ().arc ([0, 0], 1, 0, 180), 'Axes', ax, ...
%!                      'Arc', 64);
%!   assert_equal (numel (get (Hhalf(1), 'xdata')) ...
%!                 < numel (get (Hfull(1), 'xdata')), true);
%! unwind_protect_cleanup
%!   close (f);
%! end_unwind_protect

%!test  # hold state is left as it was found
%! f = figure ('visible', 'off');
%! unwind_protect
%!   ax = axes ('parent', f);
%!   draw.plot (draw.Drawing ().line ([0, 0], [1, 1]), 'Axes', ax);
%!   assert_equal (ishold (ax), false);
%! unwind_protect_cleanup
%!   close (f);
%! end_unwind_protect

%!error<draw.plot: invalid number of input arguments.> draw.plot ()
%!error<draw.plot: D must be a draw.Drawing object.> draw.plot (42)
%!error<draw.plot: Name/Value arguments must come in pairs.> ...
%! draw.plot (draw.Drawing (), 'Arc')
%!error<draw.plot: unknown parameter.> ...
%! draw.plot (draw.Drawing (), 'Colour', 1)
%!error<draw.plot: Arc must be a positive real finite scalar.> ...
%! draw.plot (draw.Drawing (), 'Arc', 0)
%!error<draw.plot: Layers must be a cell array of character vectors.> ...
%! draw.plot (draw.Drawing (), 'Layers', 'A')
%!error<draw.plot: Hatch must be 'lines' or 'boundary'.> ...
%! draw.plot (draw.Drawing (), 'Hatch', 'fill')
%!error<draw.plot: Linetypes must be 'true' or 'approximate'.> ...
%! draw.plot (draw.Drawing (), 'Linetypes', 'exact')
%!error<draw.plot: LTScale must be a positive real finite scalar.> ...
%! draw.plot (draw.Drawing (), 'LTScale', -1)
