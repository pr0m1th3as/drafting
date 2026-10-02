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

classdef Region
  ## -*- texinfo -*-
  ## @deftp {drafting} geom.Region
  ##
  ## A closed area of a plane, an outline with holes in it.
  ##
  ## A @code{geom.Region} is what a solid is made from:
  ## @code{solid.extrude}, @code{solid.revolve}, @code{solid.sweep},
  ## @code{solid.loft} and @code{solid.helix} each take one.  It is the area
  ## inside one closed loop, the outline, less the areas inside any number of
  ## others, the holes.  Each loop is a closed @code{geom.Path} of straight
  ## segments, arcs and splines, so a hole may have any shape: a circle, a
  ## slot, a square or a smooth closed @code{geom.Spline}.  A hole goes right
  ## through whatever is made from the region; a recess of limited depth is a
  ## pocket, worked on the solid.
  ##
  ## A region is always valid: every outline closed, none crossing or touching
  ## itself or enclosing no area, every hole in the plane of the outline and
  ## strictly inside it, and no two holes overlapping or touching.  An island
  ## inside a hole is not a region; union a second solid made from it.  Arcs
  ## are followed to within 2 degrees, and splines as closely, when the loops
  ## are checked against one another.
  ##
  ## The outline and holes may be drawn either way round.  The region stores
  ## the outline anticlockwise and the holes clockwise, all in the
  ## @code{geom.UCS} of the outline, which is the UCS of the region.
  ## Assigning the region another UCS moves it there.
  ##
  ## A @code{geom.Region} is a value: every change makes a new one.
  ##
  ## @seealso{geom.Path, geom.Polyline, geom.Spline, geom.UCS, solid.extrude}
  ## @end deftp

  properties (SetAccess = private)

    ## -*- texinfo -*-
    ## @deftp {geom.Region} {property} Outline
    ##
    ## Outline of the region
    ##
    ## The outline, a closed @code{geom.Path} running anticlockwise in the
    ## plane of its UCS, which is the plane of the region.
    ##
    ## @end deftp
    Outline = [];

    ## -*- texinfo -*-
    ## @deftp {geom.Region} {property} Holes
    ##
    ## Holes in the region
    ##
    ## The holes, a row cell array of closed @code{geom.Path} objects running
    ## clockwise, in the UCS of the outline; empty when there are none.
    ##
    ## @end deftp
    Holes = cell (1, 0);

  endproperties

  properties (Dependent)

    ## -*- texinfo -*-
    ## @deftp {geom.Region} {property} UCS
    ##
    ## Coordinate system of the region
    ##
    ## The @code{geom.UCS} the outline and holes are coordinates in.
    ## Assigning another moves the region onto it, its shape unchanged in its
    ## own coordinates, so a region drawn in the @math{xy} plane is laid on the
    ## face of a part by assigning it the face's UCS.
    ##
    ## @end deftp
    UCS

  endproperties

  methods (Hidden)

    function disp (this)

      printf ("  geom.Region: an outline of %d segments, %d holes\n", ...
              rows (this.Outline.Vertices), numel (this.Holes));

    endfunction

    ## The region with the outline O and the holes in the cell H, N-by-2
    ## vertices of straight segments in the xy plane, O anticlockwise and the
    ## holes clockwise, already known to be valid, as a cut through a mesh
    ## is: they are taken without the checks, which take time quadratic in the
    ## number of vertices
    function this = __trusted__ (this, O, H)

      this.Outline = geom.Path (O, 'Closed', true);
      this.Holes = cellfun (@(h) geom.Path (h, 'Closed', true), H, ...
                            'UniformOutput', false);

    endfunction

    ## The region scaled by the factor F about the origin of its UCS
    function this = __scaled__ (this, F)

      this.Outline = __scaled__ (this.Outline, F);
      this.Holes = cellfun (@(h) __scaled__ (h, F), this.Holes, ...
                            'UniformOutput', false);

    endfunction

  endmethods

  methods (Access = public)

    ## -*- texinfo -*-
    ## @deftypefn  {geom.Region} {@var{R} =} geom.Region (@var{OUTLINE})
    ## @deftypefnx {geom.Region} {@var{R} =} geom.Region (@var{OUTLINE}, @var{HOLES})
    ##
    ## Make a region.
    ##
    ## @code{@var{R} = geom.Region (@var{OUTLINE})} makes the area inside
    ## @var{OUTLINE}, a closed @code{geom.Polyline}, @code{geom.Path} or
    ## @code{geom.Spline} lying in the plane of its UCS.
    ##
    ## @code{@var{R} = geom.Region (@var{OUTLINE}, @var{HOLES})} cuts out of
    ## it the areas inside the closed polylines, paths and splines in the cell
    ## array @var{HOLES}.  A hole given in another frame of the same plane is
    ## carried into the frame of the outline.  The region keeps each as a
    ## @code{geom.Path}.
    ##
    ## @var{OUTLINE} and each hole may also be given as the matrix of vertices
    ## a @code{geom.Polyline} is made from, @code{[@var{x}, @var{y},
    ## @var{bulge}]} rows or @code{[@var{x}, @var{y}]} rows for straight
    ## segments.  An outline given so lies in the @math{xy} plane, and a hole
    ## given so lies in the plane of the outline:
    ##
    ## @example
    ## @group
    ## ## A plate 60 by 40 with a bore of diameter 20 and two square holes
    ## R = geom.Region ([0, 0; 60, 0; 60, 40; 0, 40], ...
    ##                  @{[20, 20, 1; 40, 20, 1], ...
    ##                   [4, 4; 10, 4; 10, 10; 4, 10], ...
    ##                   [50, 30; 56, 30; 56, 36; 50, 36]@});
    ## @end group
    ## @end example
    ##
    ## A hole with a smooth outline is a closed spline:
    ##
    ## @example
    ## @group
    ## H = geom.Spline ([20, 15; 35, 12; 40, 25; 28, 35; 18, 28], ...
    ##                  'Closed', true);
    ## R = geom.Region ([0, 0; 80, 0; 80, 50; 0, 50], @{H@});
    ## @end group
    ## @end example
    ##
    ## An invalid region is refused with an error naming the outline or hole at
    ## fault.
    ##
    ## @end deftypefn
    function U = get.UCS (this)

      U = this.Outline.UCS;

    endfunction

    function this = set.UCS (this, U)

      if (! isa (U, 'geom.UCS') || ! isscalar (U))
        error ("geom.Region: UCS must be a geom.UCS object.");
      endif
      this.Outline.UCS = U;
      for k = 1:numel (this.Holes)
        this.Holes{k}.UCS = U;
      endfor

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {geom.Region} {@var{R} =} fillet (@var{R}, @var{RADIUS})
    ##
    ## Round the corners of a region.
    ##
    ## @code{@var{R} = fillet (@var{R}, @var{RADIUS})} rounds every corner of
    ## the outline and of every hole where two straight segments meet, with an
    ## arc of radius @var{RADIUS} millimetres tangent to both, as
    ## @code{geom.Path.fillet} does: the outline's corners and the inside
    ## corners of its holes alike.  This is the rounded outline of a plate or a
    ## pocket, drawn before it is extruded, which is simpler and more exact
    ## than rounding the edges of the solid afterwards.  Corners next to an arc
    ## or a spline are left as they are.  To round only some corners, round the
    ## outline or a hole as a path and make the region again.
    ##
    ## @example
    ## @group
    ## ## A plate 60 by 40 with corners of radius 5 and a slot with sharp
    ## ## corners rounded to 1
    ## R = geom.Region ([0, 0; 60, 0; 60, 40; 0, 40], ...
    ##                  @{[20, 15; 40, 15; 40, 25; 20, 25]@});
    ## S = solid.extrude (fillet (R, 1), 6);
    ## @end group
    ## @end example
    ##
    ## @seealso{geom.Path.fillet}
    ## @end deftypefn
    function this = fillet (this, RADIUS)

      ## Input validation
      if (nargin != 2)
        error ("geom.Region.fillet: invalid number of input arguments.");
      endif

      try
        O = fillet (this.Outline, RADIUS);
      catch err
        error ("geom.Region.fillet: OUTLINE: %s", ...
               regexprep (err.message, '^geom\.Path\.fillet: ', ''));
      end_try_catch
      H = this.Holes;
      for k = 1:numel (H)
        try
          H{k} = fillet (H{k}, RADIUS);
        catch err
          error ("geom.Region.fillet: HOLES{%d}: %s", k, ...
                 regexprep (err.message, '^geom\.Path\.fillet: ', ''));
        end_try_catch
      endfor
      this = geom.Region (O, H);

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {geom.Region} {@var{R} =} chamfer (@var{R}, @var{D})
    ## @deftypefnx {geom.Region} {@var{R} =} chamfer (@var{R}, [@var{D1}, @var{D2}])
    ## @deftypefnx {geom.Region} {@var{R} =} chamfer (@var{R}, @var{D}, @qcode{'Angle'}, @var{A})
    ##
    ## Cut the corners of a region.
    ##
    ## @code{@var{R} = chamfer (@var{R}, @var{D})} cuts every corner of the
    ## outline and of every hole where two straight segments meet, @var{D}
    ## millimetres back along both segments, as @code{geom.Path.chamfer}
    ## does.  Two distances or a distance and an angle are taken as there,
    ## before and after each corner in the order the region stores its
    ## vertices: anticlockwise round the outline, clockwise round the holes.
    ## To cut only some corners, cut the outline or a hole as a path and make
    ## the region again.
    ##
    ## @seealso{geom.Path.chamfer, geom.Region.fillet}
    ## @end deftypefn
    function this = chamfer (this, varargin)

      ## Input validation
      if (nargin < 2)
        error ("geom.Region.chamfer: invalid number of input arguments.");
      endif

      try
        O = chamfer (this.Outline, varargin{:});
      catch err
        error ("geom.Region.chamfer: OUTLINE: %s", ...
               regexprep (err.message, '^geom\.Path\.chamfer: ', ''));
      end_try_catch
      H = this.Holes;
      for k = 1:numel (H)
        try
          H{k} = chamfer (H{k}, varargin{:});
        catch err
          error ("geom.Region.chamfer: HOLES{%d}: %s", k, ...
                 regexprep (err.message, '^geom\.Path\.chamfer: ', ''));
        end_try_catch
      endfor
      this = geom.Region (O, H);

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {geom.Region} {@var{R} =} fit (@var{R})
    ## @deftypefnx {geom.Region} {@var{R} =} fit (@var{R}, @var{MODE})
    ## @deftypefnx {geom.Region} {@var{R} =} fit (@dots{}, @var{Name}, @var{Value}, @dots{})
    ##
    ## Fit lines, arcs and splines to a faceted region.
    ##
    ## @code{@var{R} = fit (@var{R})} replaces the straight segments of the
    ## outline and the holes of @var{R} with as few lines and circular arcs as
    ## follow them within a tolerance, so that a region cut from a mesh, whose
    ## round bore is a polygon of facets and whose edges zigzag with the noise
    ## of a scan, becomes the outline it was drawn from: its edges straight,
    ## its bore a circle, its fillets arcs.  Where two pieces meet without a
    ## corner they meet tangentially.  Arcs and splines already in @var{R} are
    ## kept, and the straight segments between them fitted.
    ##
    ## @var{MODE} chooses what the fit may use: @qcode{'lines'}, lines only;
    ## @qcode{'arcs'}, lines and arcs, the default; or @qcode{'curves'},
    ## lines, arcs that turn at least 60 degrees, lines at least a fiftieth of
    ## the region's size, and smooth cubic splines for the stretches between
    ## them, the shape of a free-form part.
    ##
    ## Name/Value pairs:
    ##
    ## @table @asis
    ## @item @qcode{'AbsTol'}
    ## The furthest, in millimetres, the fit may stray from the segments it
    ## replaces, and they from it.
    ##
    ## @item @qcode{'RelTol'}
    ## The same as a fraction of the region's size, the diagonal of the box
    ## around its outline.  Given alone, either tolerance holds alone; given
    ## both, the stricter.  The default is a @qcode{'RelTol'} of 1e-3.  To
    ## turn a faceted bore into a circle the tolerance must be larger than its
    ## facets stray from the circle.
    ##
    ## @item @qcode{'Corner'}
    ## The turn, in degrees, at which the outline has a corner, 20 by
    ## default.  The turn is measured on a sliding window: between the mean
    ## direction of the outline over a stretch behind a point and over a
    ## stretch ahead of it, so that noise and a small fillet saved as a few
    ## facets do not make corners of their own.  A corner is kept only where
    ## the outline lies within the tolerance of the sharp corner its two
    ## sides make, which then sits where the sides meet; a larger fillet is
    ## fitted as an arc.
    ##
    ## @item @qcode{'Window'}
    ## The length of each stretch, in millimetres, ten tolerances by default.
    ## @end table
    ##
    ## The fitted region is checked as any region is.  Should a fit make a loop
    ## cross or touch another, as when two lie closer than the tolerance, the
    ## region is fitted again at half the tolerance, up to four times, and
    ## returned as it was when it never passes.
    ##
    ## @example
    ## @group
    ## ## A slice of a scanned part, its bore a circle again
    ## M = stl.read ('part.stl');
    ## R = stl.section (M, geom.UCS ([0, 0, 1], [0, 0, 5]));
    ## R = fit (R@{1@}, 'arcs', 'AbsTol', 0.01);
    ## @end group
    ## @end example
    ##
    ## @seealso{stl.section, geom.Region.fillet, geom.Spline}
    ## @end deftypefn
    function this = fit (this, MODE = 'arcs', varargin)

      ## Input validation
      if (! ischar (MODE) || ! any (strcmp (MODE, {'lines', 'arcs', 'curves'})))
        error ("geom.Region.fit: MODE must be 'lines', 'arcs' or 'curves'.");
      endif
      if (mod (numel (varargin), 2) != 0)
        error ("geom.Region.fit: Name/Value arguments must come in pairs.");
      endif
      opt = struct ('RelTol', [], 'AbsTol', [], 'Corner', 20, 'Window', []);
      for k = 1:2:numel (varargin)
        name = varargin{k};
        if (! ischar (name) || ! isrow (name) ...
            || ! any (strcmp (name, fieldnames (opt))))
          error ("geom.Region.fit: unknown parameter.");
        endif
        opt.(name) = varargin{k+1};
      endfor
      pos = @(x) isnumeric (x) && isreal (x) && isscalar (x) ...
                 && isfinite (x) && x > 0;
      for name = {'RelTol', 'AbsTol', 'Window'}
        x = opt.(name{1});
        if (! isempty (x) && ! pos (x))
          error (strcat ("geom.Region.fit: %s must be a positive and", ...
                         " finite real scalar."), name{1});
        endif
      endfor
      A = opt.Corner;
      if (! isnumeric (A) || ! isreal (A) || ! isscalar (A) || ! (A > 0) ...
          || ! (A < 180))
        error (strcat ("geom.Region.fit: Corner must be an angle in the", ...
                       " range (0, 180) degrees."));
      endif

      Q = __sample__ (this.Outline);
      size = norm (max (Q(:,1:2), [], 1) - min (Q(:,1:2), [], 1));
      tol = [];
      if (! isempty (opt.RelTol))
        tol = opt.RelTol * size;
      endif
      if (! isempty (opt.AbsTol))
        tol = min ([tol, opt.AbsTol]);
      endif
      if (isempty (tol))
        tol = 1e-3 * size;
      endif
      mode = find (strcmp (MODE, {'lines', 'arcs', 'curves'}));
      loops = [{this.Outline}, this.Holes];
      for attempt = 0:4
        T = tol / 2 ^ attempt;
        W = opt.Window;
        if (isempty (W))
          W = 10 * T;
        endif
        L = cellfun (@(P) fitloop (P, mode, T, A * pi / 180, W), loops, ...
                     'UniformOutput', false);
        try
          R = geom.Region (L{1}, L(2:end));
        catch
          continue;
        end_try_catch
        R.UCS = this.UCS;
        this = R;
        return;
      endfor

    endfunction

    function this = Region (OUTLINE, HOLES = {})

      ## Input validation
      if (nargin < 1 || nargin > 2)
        error ("geom.Region: invalid number of input arguments.");
      endif
      [errmsg, O] = toloop (OUTLINE, 'OUTLINE', []);
      if (! isempty (errmsg))
        error ("geom.Region: %s", errmsg);
      endif
      if (! iscell (HOLES) || ! (isvector (HOLES) || isempty (HOLES)))
        error ("geom.Region: HOLES must be a cell array of holes.");
      endif
      H = cell (1, numel (HOLES));
      for k = 1:numel (HOLES)
        [errmsg, H{k}] = toloop (HOLES{k}, sprintf ("HOLES{%d}", k), O);
        if (! isempty (errmsg))
          error ("geom.Region: %s", errmsg);
        endif
      endfor

      ## Each loop on its own, sampled along its arcs and splines
      names = [{'OUTLINE'}, arrayfun(@(k) sprintf ("HOLES{%d}", k), ...
                                     1:numel (H), 'UniformOutput', false)];
      all_ = [{O}, H];
      S = cell (size (all_));
      A = zeros (size (all_));
      for k = 1:numel (all_)
        S{k} = __sample__ (all_{k})(:,1:2);
        if (rows (S{k}) > 2 && geom.selfintersects (S{k}, true))
          error ("geom.Region: %s must not cross or touch itself.", names{k});
        endif
        A(k) = __area__ (all_{k});
        if (abs (A(k)) <= 1e-12 * max (range (S{k})) ^ 2)
          error ("geom.Region: %s must enclose a nonzero area.", names{k});
        endif
      endfor

      ## The holes against the outline and against one another
      for k = 2:numel (S)
        [in, on] = inpolygon (S{k}(:,1), S{k}(:,2), S{1}(:,1), S{1}(:,2));
        if (! all (in & ! on) || meets (S{k}, S{1}))
          error ("geom.Region: %s must lie strictly inside OUTLINE.", ...
                 names{k});
        endif
      endfor
      for j = 2:numel (S)
        for k = j+1:numel (S)
          jink = inpolygon (S{j}(:,1), S{j}(:,2), S{k}(:,1), S{k}(:,2));
          kinj = inpolygon (S{k}(:,1), S{k}(:,2), S{j}(:,1), S{j}(:,2));
          if (meets (S{j}, S{k}) || any (jink) || any (kinj))
            error ("geom.Region: %s and %s must not overlap or touch.", ...
                   names{j}, names{k});
          endif
        endfor
      endfor

      ## The outline anticlockwise and the holes clockwise
      if (A(1) < 0)
        O = __reversed__ (O);
      endif
      for k = 1:numel (H)
        if (A(k+1) > 0)
          H{k} = __reversed__ (H{k});
        endif
      endfor
      this.Outline = O;
      this.Holes = H;

    endfunction

  endmethods

endclassdef

## A closed loop from ARG, named NAME in errors: a closed geom.Polyline,
## geom.Path or geom.Spline, or a matrix of polyline vertices in the plane of
## the loop IN, or the xy plane when IN is empty, as a geom.Path.  A loop in
## another frame of the same plane is carried into the frame of IN.  Returns
## an error message body, empty when it is valid.
function [errmsg, P] = toloop (ARG, NAME, IN)

  errmsg = '';
  P = [];
  if (isnumeric (ARG))
    if (isempty (IN))
      args = {};
    else
      args = {'UCS', IN.UCS};
    endif
    try
      P = geom.Path (geom.Polyline (ARG, 'Closed', true, args{:}));
    catch err
      errmsg = sprintf ("%s: %s", NAME, regexprep (err.message, ...
                                                   '^geom\.Polyline: ', ''));
    end_try_catch
    return;
  endif
  if (! isscalar (ARG) || ! (isa (ARG, 'geom.Polyline') ...
                             || isa (ARG, 'geom.Path') ...
                             || isa (ARG, 'geom.Spline')))
    errmsg = sprintf (strcat ("%s must be a closed geom.Polyline,", ...
                              " geom.Path or geom.Spline, or a matrix of", ...
                              " vertices."), NAME);
    return;
  endif
  if (! ARG.Closed)
    errmsg = sprintf ("%s must be closed.", NAME);
    return;
  endif
  if (isa (ARG, 'geom.Path'))
    P = ARG;
  else
    P = geom.Path (ARG);
  endif
  if (isempty (IN))
    if (! flat (P))
      errmsg = sprintf ("%s must lie in the plane of its UCS.", NAME);
    endif
    return;
  endif

  ## Into the UCS of IN, which must be on the same plane
  P = __into__ (P, IN.UCS);
  if (! flat (P))
    errmsg = sprintf ("%s must lie in the plane of OUTLINE.", NAME);
  endif

endfunction

## The closed path P fitted in MODE, 1 lines, 2 arcs, 3 curves, within TOL,
## corners at the angle CORNER on windows of length W: the whole of it when it
## is all straight segments, else each run of straight segments between the
## arcs and splines it keeps
function Q = fitloop (P, mode, tol, corner, W)

  V = P.Vertices(:,1:2);
  n = rows (V);
  straight = isnan (P.Midpoints(:,1)) & cellfun (@isempty, P.Splines);
  if (all (straight))
    Q = topath (__mesh__ ('fit', 'geom.Region.fit', V, true, mode, tol, ...
                          corner, W));
    return;
  endif
  parts = {};
  first = find (! straight, 1);
  run = V(mod (first, n) + 1,:);
  for j = first + (1:n)
    k = mod (j - 1, n) + 1;
    nxt = V(mod (k, n) + 1,:);
    if (straight(k))
      run(end+1,:) = nxt;
      continue;
    endif
    if (rows (run) > 1)
      parts{end+1} = topath (__mesh__ ('fit', 'geom.Region.fit', run, ...
                                       false, mode, tol, corner, W));
    endif
    if (isempty (P.Splines{k}))
      parts{end+1} = geom.Path.arc ([V(k,:), 0], P.Midpoints(k,:), [nxt, 0]);
    else
      parts{end+1} = geom.Path (P.Splines{k});
    endif
    run = nxt;
  endfor
  Q = join (parts{:}, 'Tangent', false);

endfunction

## The path of the fitted PIECES in turn, lines that follow one another as one
## polyline; closed when it ends where it starts
function Q = topath (pieces)

  parts = {};
  lines = zeros (0, 2);
  for i = 1:numel (pieces)
    p = pieces{i};
    if (strcmp (p.type, 'line'))
      if (isempty (lines))
        lines = p.points;
      else
        lines(end+1,:) = p.points(2,:);
      endif
      continue;
    endif
    if (! isempty (lines))
      parts{end+1} = geom.Path (lines);
      lines = zeros (0, 2);
    endif
    if (strcmp (p.type, 'arc'))
      parts{end+1} = geom.Path.arc ([p.points(1,:), 0], [p.points(2,:), 0], ...
                                    [p.points(3,:), 0]);
    else
      parts{end+1} = geom.Spline.nurbs (p.points, p.knots);
    endif
  endfor
  if (! isempty (lines))
    parts{end+1} = geom.Path (lines);
  endif
  if (numel (parts) > 1)
    Q = join (parts{:}, 'Tangent', false);
  elseif (isa (parts{1}, 'geom.Spline'))
    Q = geom.Path (parts{1});
  elseif (isequal (lines(1,:), lines(end,:)))
    Q = geom.Path (lines(1:end-1,:), 'Closed', true);
  else
    Q = parts{1};
  endif

endfunction

## True when every point of the path P, and every direction it is given, lies
## in the plane of its UCS
function TF = flat (P)

  V = P.Vertices;
  M = P.Midpoints;
  z = [V(:,3); M(! isnan (M(:,1)),3)];
  d = [];
  for i = find (! cellfun (@isempty, P.Splines))'
    SP = P.Splines{i};
    z = [z; SP.ControlPoints(:,3); SP.FitPoints(:,3)];
    if (! isempty (SP.Tangents))
      d = [d; SP.Tangents(! isnan (SP.Tangents(:,1)),3)];
    endif
  endfor
  scale = max ([1; abs(V(:)); abs(P.UCS.Origin(:))]);
  TF = all (abs (z) <= 1e-9 * scale) && all (abs (d) <= 1e-9);

endfunction

## True when any segment of the closed polygon A meets any of the closed
## polygon B, crossing or touching
function TF = meets (A, B)

  a1 = A;
  a2 = A([2:end, 1],:);
  b1 = B;
  b2 = B([2:end, 1],:);
  tol = 1e-12 * max ([range(A(:)), range(B(:)), 1]) ^ 2;
  orient = @(p, q, r) (q(:,1) - p(:,1)) .* (r(:,2)' - p(:,2)) ...
                      - (q(:,2) - p(:,2)) .* (r(:,1)' - p(:,1));
  o1 = orient (a1, a2, b1);
  o2 = orient (a1, a2, b2);
  o3 = orient (b1, b2, a1)';
  o4 = orient (b1, b2, a2)';
  o1(abs (o1) < tol) = 0;
  o2(abs (o2) < tol) = 0;
  o3(abs (o3) < tol) = 0;
  o4(abs (o4) < tol) = 0;
  hit = (o1 .* o2 <= 0) & (o3 .* o4 <= 0);
  ## Collinear segments meet only where their extents overlap
  col = (o1 == 0) & (o2 == 0);
  if (any (col(:)))
    lo = @(u, v) min (u, v);
    hi = @(u, v) max (u, v);
    ox = hi (lo (a1(:,1), a2(:,1)), lo (b1(:,1), b2(:,1))') ...
         <= lo (hi (a1(:,1), a2(:,1)), hi (b1(:,1), b2(:,1))');
    oy = hi (lo (a1(:,2), a2(:,2)), lo (b1(:,2), b2(:,2))') ...
         <= lo (hi (a1(:,2), a2(:,2)), hi (b1(:,2), b2(:,2))');
    hit(col) = ox(col) & oy(col);
  endif
  TF = any (hit(:));

endfunction

%!test
%! R = geom.Region ([0, 0; 60, 0; 60, 40; 0, 40]);
%! assert_equal (R.Outline.Vertices, [0, 0, 0; 60, 0, 0; 60, 40, 0; 0, 40, 0]);
%! assert_equal (R.Holes, cell (1, 0));

%!test  # a clockwise outline turned anticlockwise, from the same vertex
%! R = geom.Region ([0, 0, 0; 0, 40, 0; 60, 40, 1; 60, 0, 0]);
%! assert_equal (R.Outline.Vertices, [0, 0, 0; 60, 0, 0; 60, 40, 0; 0, 40, 0]);
%! assert_equal (R.Outline.Midpoints(2,:), [40, 20, 0], 1e-12);
%! assert_equal (__area__ (R.Outline), 2400 - 200 * pi, 1e-9);

%!test  # holes of any shape, stored clockwise
%! R = geom.Region ([0, 0; 60, 0; 60, 40; 0, 40], ...
%!                  {[20, 20, 1; 40, 20, 1], [4, 4; 10, 4; 10, 10; 4, 10]});
%! assert_equal (R.Holes{1}.Vertices, [20, 20, 0; 40, 20, 0]);
%! assert_equal (R.Holes{1}.Midpoints, [30, 30, 0; 30, 10, 0], 1e-12);
%! assert_equal (R.Holes{2}.Vertices, [4, 4, 0; 4, 10, 0; 10, 10, 0; 10, 4, 0]);

%!test  # an outline on a sloping plane, its holes in the same plane
%! U = geom.UCS ([0, -3, 4], [0, 0, 10]);
%! O = geom.Polyline ([0, 0; 50, 0; 50, 30; 0, 30], 'Closed', true, 'UCS', U);
%! R = geom.Region (O, {[10, 10; 20, 10; 20, 20; 10, 20]});
%! assert_equal (R.UCS, U);
%! assert_equal (R.Holes{1}.UCS, U);

%!test  # a hole drawn in another frame of the same plane is carried over
%! O = geom.Polyline ([0, 0; 60, 0; 60, 40; 0, 40], 'Closed', true);
%! H = geom.Polyline ([0, 0, 1; 10, 0, 1], 'Closed', true, ...
%!                    'UCS', geom.UCS ([0, 0, -1], [30, 20, 0]));
%! R = geom.Region (O, {H});
%! assert_equal (R.Holes{1}.Vertices, [30, 20, 0; 20, 20, 0], 1e-12);
%! assert_equal (__area__ (R.Holes{1}), -25 * pi, 1e-9);
%! assert_equal (R.Holes{1}.UCS, geom.UCS ());

%!test  # assigning a UCS moves the region, holes and all
%! R = geom.Region ([0, 0; 60, 0; 60, 40; 0, 40], {[20, 20, 1; 40, 20, 1]});
%! U = geom.UCS ([0, -3, 4], [0, 0, 10]);
%! R.UCS = U;
%! assert_equal (R.UCS, U);
%! assert_equal (R.Holes{1}.UCS, U);
%! assert_equal (R.Outline.Vertices, [0, 0, 0; 60, 0, 0; 60, 40, 0; 0, 40, 0]);
%! assert_equal (R.Holes{1}.Vertices, [20, 20, 0; 40, 20, 0]);

%!test  # every corner of the outline and of a hole rounded
%! R = geom.Region ([0, 0; 60, 0; 60, 40; 0, 40], ...
%!                  {[20, 15; 40, 15; 40, 25; 20, 25]});
%! Q = fillet (R, 1);
%! assert_equal (rows (Q.Outline.Vertices), 8);
%! assert_equal (rows (Q.Holes{1}.Vertices), 8);
%! assert_equal (all (! isnan (Q.Holes{1}.Midpoints(1:2:end,1))), true);
%! assert_equal (__area__ (Q.Holes{1}), -(200 - (4 - pi)), 1e-9);
%! assert_equal (Q.UCS, R.UCS);

%!test  # every corner of the outline and of a hole cut
%! R = geom.Region ([0, 0; 60, 0; 60, 40; 0, 40], ...
%!                  {[20, 15; 40, 15; 40, 25; 20, 25]});
%! Q = chamfer (R, 1);
%! assert_equal (rows (Q.Outline.Vertices), 8);
%! assert_equal (rows (Q.Holes{1}.Vertices), 8);
%! ## The outline loses four corners, the hole gives four back
%! A = @(P) polyarea (P(:,1), P(:,2));
%! assert_equal (A (Q.Outline.Vertices) - A (Q.Holes{1}.Vertices), 2200, 1e-9);

%!test  # a smooth hole, a closed spline
%! H = geom.Spline ([20, 15; 35, 12; 40, 25; 28, 35; 18, 28], ...
%!                  'Closed', true);
%! R = geom.Region ([0, 0; 80, 0; 80, 50; 0, 50], {H});
%! assert_equal (class (R.Holes{1}), 'geom.Path');
%! assert_equal (__area__ (R.Holes{1}) < 0, true);
%! assert_equal (-__area__ (R.Holes{1}), abs (__area__ (geom.Path (H))), 1e-9);

%!test  # an outline of a straight edge and a spline, from a path
%! P = join (geom.Path ([0, 0; 40, 0]), ...
%!           geom.Spline ([40, 0; 45, 20; 20, 30; 0, 0]));
%! R = geom.Region (P, {geom.Polyline([10, 8, 1; 16, 8, 1], 'Closed', true)});
%! assert_equal (R.Outline.Closed, true);
%! assert_equal (numel (R.Holes), 1);
%! assert_equal (isempty (R.Outline.Splines{2}), false);

%!test  # a closed spline as the outline, given in a UCS of its own
%! U = geom.UCS ([0, 0, 1], [5, 5, 5]);
%! O = geom.Spline ([0, 0; 30, -5; 45, 15; 25, 30; 5, 20], 'Closed', true, ...
%!                  'UCS', U);
%! R = geom.Region (O, {[20, 10; 25, 10; 25, 15]});
%! assert_equal (R.UCS, U);
%! assert_equal (__area__ (R.Outline) > 0, true);

%!test  # chamfer and fillet leave the corners next to a spline
%! P = join (geom.Path ([0, 0; 40, 0; 40, 10]), ...
%!           geom.Spline ([40, 10; 20, 25; 0, 10]), geom.Path ([0, 10; 0, 0]));
%! R = geom.Region (P);
%! assert_equal (rows (fillet (R, 1).Outline.Vertices), 6);
%! assert_equal (rows (chamfer (R, 1).Outline.Vertices), 6);

%!error<geom.Region: HOLES\{1\} must lie strictly inside OUTLINE.> ...
%! geom.Region ([0, 0; 30, 0; 30, 30; 0, 30], ...
%!              {geom.Spline([20, 10; 35, 15; 20, 20], 'Closed', true)})
%!error<geom.Region: OUTLINE must not cross or touch itself.> ...
%! geom.Region (geom.Spline ([0, 0; 10, 10; 20, 0; 20, 10; 10, 0; 0, 10], ...
%!                           'Closed', true))
%!error<geom.Region: OUTLINE must be closed.> ...
%! geom.Region (geom.Spline ([0, 0; 10, 10; 20, 0]))
%!error<geom.Region: OUTLINE must lie in the plane of its UCS.> ...
%! geom.Region (geom.Path ([0, 0, 0; 10, 0, 0; 10, 10, 1], 'Closed', true))
%!error<geom.Region: HOLES\{1\} must lie in the plane of OUTLINE.> ...
%! geom.Region ([0, 0; 30, 0; 30, 30; 0, 30], ...
%!              {geom.Spline([10, 10, 0; 20, 10, 0; 15, 20, 1], ...
%!                           'Closed', true)})
%!test  # a hole of a rational spline, its area exact
%! w = sqrt (2) / 2;
%! C = [1, 0; 1, 1; 0, 1; -1, 1; -1, 0; -1, -1; 0, -1; 1, -1; 1, 0];
%! H = geom.Spline.nurbs (5 * C + [20, 10], ...
%!                        [0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 4], ...
%!                        [1, w, 1, w, 1, w, 1, w, 1]);
%! R = geom.Region ([0, 0; 40, 0; 40, 20; 0, 20], {H});
%! assert_equal (__area__ (R.Holes{1}), -25 * pi, 1e-12);

## The furthest any point of A lies from the closed polygon B, for the tests
%!function d = gap (A, B)
%!  E = B([2:end, 1],:) - B;
%!  L2 = sum (E .^ 2, 2)';
%!  d = 0;
%!  for k = 1:500:rows (A)
%!    P = A(k:min (k + 499, rows (A)),:);
%!    t = ((P(:,1) - B(:,1)') .* E(:,1)' ...
%!         + (P(:,2) - B(:,2)') .* E(:,2)') ./ L2;
%!    t = min (max (t, 0), 1);
%!    dx = P(:,1) - (B(:,1)' + t .* E(:,1)');
%!    dy = P(:,2) - (B(:,2)' + t .* E(:,2)');
%!    d = max (d, max (min (sqrt (dx .^ 2 + dy .^ 2), [], 2)));
%!  endfor
%!endfunction
## A 60 by 40 rectangle whose corners are fillets of radius R, each N facets
%!function P = rounded (R, N)
%!  c = [60 - R, R; 60 - R, 40 - R; R, 40 - R; R, R];
%!  a = [-90; 0; 90; 180];
%!  f = @(k) c(k,:) + R * [cosd(a(k) + (0:N)' * 90 / N), ...
%!                         sind(a(k) + (0:N)' * 90 / N)];
%!  P = cell2mat (arrayfun (f, (1:4)', 'UniformOutput', false));
%!endfunction

%!test  # a faceted bore: two half circles, or kept below its facet error
%! a = (0:63)' * 2 * pi / 64;
%! R = geom.Region ([0, 0; 40, 0; 40, 30; 0, 30], ...
%!                  {[20 + 5 * cos(a), 15 + 5 * sin(a)]});
%! F = fit (R);
%! assert_equal (rows (F.Outline.Vertices), 4);
%! assert_equal (rows (F.Holes{1}.Vertices), 2);
%! assert_equal (all (! isnan (F.Holes{1}.Midpoints(:,1))), true);
%! assert_equal (__area__ (F.Holes{1}), -25 * pi, 1e-9);
%! F = fit (R, 'arcs', 'AbsTol', 1e-3);
%! assert_equal (rows (F.Holes{1}.Vertices), 64);
%! ## Both tolerances: the stricter holds
%! F = fit (R, 'arcs', 'RelTol', 1e-3, 'AbsTol', 1e-3);
%! assert_equal (rows (F.Holes{1}.Vertices), 64);
%! F = fit (R, 'arcs', 'AbsTol', 0.05);
%! assert_equal (rows (F.Holes{1}.Vertices), 2);

%!test  # a noisy rectangle: four lines, its corners where its sides meet
%! s = (0:199)' / 200;
%! P = [60 * s, 0 * s; 60 + 0 * s, 40 * s; 60 - 60 * s, 40 + 0 * s; ...
%!      0 * s, 40 - 40 * s];
%! P += 1e-3 * [sin(1:800)', cos(3 * (1:800))'];
%! F = fit (geom.Region (P), 'arcs', 'AbsTol', 0.01);
%! V = sortrows (round (F.Outline.Vertices(:,1:2)));
%! assert_equal (V, [0, 0; 0, 40; 60, 0; 60, 40]);
%! E = F.Outline.Vertices(:,1:2) - round (F.Outline.Vertices(:,1:2));
%! assert_equal (max (abs (E(:))) < 3e-3, true);

%!test  # fillets of radius 1 in eight facets: lines and arcs, tangent
%! F = fit (geom.Region (rounded (1, 8)), 'arcs', 'AbsTol', 0.005);
%! M = F.Outline.Midpoints;
%! assert_equal (rows (M), 8);
%! assert_equal (nnz (! isnan (M(:,1))), 4);
%! assert_equal (__area__ (F.Outline), 2400 - (4 - pi), 1e-6);
%! [tin, tout] = __tangents__ (F.Outline);
%! assert_equal (sum (tout .* tin([2:end, 1],:), 2), ones (8, 1), 1e-9);

%!test  # fillets smaller than the tolerance allows are sharp corners
%! F = fit (geom.Region (rounded (0.002, 8)), 'arcs', 'AbsTol', 0.01);
%! assert_equal (sortrows (F.Outline.Vertices(:,1:2)), ...
%!               [0, 0; 0, 40; 60, 0; 60, 40], 1e-9);

%!test  # lines only, within the tolerance
%! a = (0:63)' * 2 * pi / 64;
%! P = [5 * cos(a), 5 * sin(a)];
%! F = fit (geom.Region (P), 'lines', 'AbsTol', 0.05);
%! assert_equal (rows (F.Outline.Vertices) < 64, true);
%! assert_equal (all (isnan (F.Outline.Midpoints(:))), true);
%! assert_equal (gap (P, F.Outline.Vertices(:,1:2)) <= 0.05, true);

%!test  # curves: splines within the tolerance both ways, smooth throughout
%! t = linspace (0, 2 * pi, 2001)';
%! t(end) = [];
%! r = 30 + 6 * cos (5 * t);
%! P = [r .* cos(t), r .* sin(t)];
%! F = fit (geom.Region (P), 'curves', 'AbsTol', 0.01);
%! assert_equal (any (! cellfun (@isempty, F.Outline.Splines)), true);
%! S = __sample__ (F.Outline)(:,1:2);
%! assert_equal (gap (S, P) <= 0.01, true);
%! assert_equal (gap (P, S) <= 0.01, true);
%! [tin, tout] = __tangents__ (F.Outline);
%! assert_equal (sum (tout .* tin([2:end, 1],:), 2), ...
%!               ones (rows (tin), 1), 1e-9);

%!test  # an arc already in the outline is kept, the straight run fitted
%! s = (1:99)' / 100;
%! P = geom.Path ([0, -6; 40 * s, -6 + 1e-3 * sin(1:99)'; 40, -6]);
%! O = join (geom.Path ([0, 6; 0, -6]), P, ...
%!           geom.Path.arc ([40, -6, 0], [46, 0, 0], [40, 6, 0]), ...
%!           geom.Path ([40, 6; 0, 6]));
%! F = fit (geom.Region (O), 'arcs', 'AbsTol', 0.01);
%! assert_equal (rows (F.Outline.Vertices), 4);
%! M = F.Outline.Midpoints;
%! assert_equal (M(! isnan (M(:,1)),:), [46, 0, 0], 1e-12);

%!test  # in the region's own UCS
%! a = (0:63)' * 2 * pi / 64;
%! U = geom.UCS ([0, 1, 1], [1, 2, 3]);
%! R = geom.Region ([5 * cos(a), 5 * sin(a)]);
%! R.UCS = U;
%! F = fit (R);
%! assert_equal (F.UCS, U);
%! assert_equal (__area__ (F.Outline), 25 * pi, 1e-9);

%!error<geom.Region.fit: MODE must be 'lines', 'arcs' or 'curves'.> ...
%! fit (geom.Region ([0, 0; 1, 0; 1, 1]), 'splines')
%!error<geom.Region.fit: Name/Value arguments must come in pairs.> ...
%! fit (geom.Region ([0, 0; 1, 0; 1, 1]), 'arcs', 'AbsTol')
%!error<geom.Region.fit: unknown parameter.> ...
%! fit (geom.Region ([0, 0; 1, 0; 1, 1]), 'arcs', 'Tol', 1)
%!error<geom.Region.fit: AbsTol must be a positive and finite real scalar.> ...
%! fit (geom.Region ([0, 0; 1, 0; 1, 1]), 'arcs', 'AbsTol', 0)
%!error<geom.Region.fit: RelTol must be a positive and finite real scalar.> ...
%! fit (geom.Region ([0, 0; 1, 0; 1, 1]), 'arcs', 'RelTol', Inf)
%!error<geom.Region.fit: Window must be a positive and finite real scalar.> ...
%! fit (geom.Region ([0, 0; 1, 0; 1, 1]), 'arcs', 'Window', -1)
%!error<geom.Region.fit: Corner must be an angle in the range \(0, 180\) degrees.> ...
%! fit (geom.Region ([0, 0; 1, 0; 1, 1]), 'arcs', 'Corner', 180)

%!error<geom.Region.chamfer: invalid number of input arguments.> ...
%! chamfer (geom.Region ([0, 0; 1, 0; 1, 1]))
%!error<geom.Region.chamfer: OUTLINE: D must be one positive finite distance, or two.> ...
%! chamfer (geom.Region ([0, 0; 1, 0; 1, 1]), 0)
%!error<geom.Region.chamfer: HOLES\{1\}: the chamfer at vertex 1 does not fit its segments.> ...
%! chamfer (geom.Region ([0, 0; 60, 0; 60, 40; 0, 40], ...
%!                      {[20, 15; 24, 15; 24, 25; 20, 25]}), 3)

%!error<geom.Region.fillet: invalid number of input arguments.> ...
%! fillet (geom.Region ([0, 0; 1, 0; 1, 1]))
%!error<geom.Region.fillet: OUTLINE: RADIUS must be a positive and finite real scalar.> ...
%! fillet (geom.Region ([0, 0; 1, 0; 1, 1]), -1)
%!error<geom.Region.fillet: HOLES\{1\}: the round at vertex 1 does not fit its segments.> ...
%! fillet (geom.Region ([0, 0; 60, 0; 60, 40; 0, 40], ...
%!                      {[20, 15; 24, 15; 24, 25; 20, 25]}), 3)

%!error<geom.Region: invalid number of input arguments.> geom.Region ()
%!error<geom.Region: UCS must be a geom.UCS object.>
%! R = geom.Region ([0, 0; 1, 0; 1, 1]);
%! R.UCS = 1;
%!error<geom.Region: OUTLINE must be a closed geom.Polyline, geom.Path or geom.Spline, or a matrix of vertices.> ...
%! geom.Region ({[0, 0; 1, 0; 1, 1]})
%!error<geom.Region: OUTLINE: P must be an N-by-2 or N-by-3 real matrix of finite values with at least two rows.> ...
%! geom.Region ([0, 0])
%!error<geom.Region: OUTLINE must be closed.> ...
%! geom.Region (geom.Polyline ([0, 0; 1, 0; 1, 1]))
%!error<geom.Region: HOLES must be a cell array of holes.> ...
%! geom.Region ([0, 0; 10, 0; 10, 10], [1, 1; 2, 1; 2, 2])
%!error<geom.Region: HOLES\{1\} must be a closed geom.Polyline, geom.Path or geom.Spline, or a matrix of vertices.> ...
%! geom.Region ([0, 0; 10, 0; 10, 10], {'abc'})
%!error<geom.Region: HOLES\{2\}: P must not repeat a vertex consecutively.> ...
%! geom.Region ([0, 0; 10, 0; 10, 10], {[6, 2; 7, 2; 7, 3], [8, 2; 8, 2; 9, 3]})
%!error<geom.Region: HOLES\{1\} must be closed.> ...
%! geom.Region ([0, 0; 10, 0; 10, 10], {geom.Polyline([6, 2; 7, 2; 7, 3])})
%!error<geom.Region: HOLES\{1\} must lie in the plane of OUTLINE.> ...
%! geom.Region ([0, 0; 10, 0; 10, 10], ...
%!              {geom.Polyline([6, 2; 7, 2; 7, 3], 'Closed', true, ...
%!                             'UCS', geom.UCS ([0, 0, 1], [0, 0, 1]))})
%!error<geom.Region: HOLES\{1\} must lie in the plane of OUTLINE.> ...
%! geom.Region ([0, 0; 10, 0; 10, 10], ...
%!              {geom.Polyline([6, 2; 7, 2; 7, 3], 'Closed', true, ...
%!                             'UCS', geom.UCS ([0, 1, 1], [0, 0, 0]))})
%!error<geom.Region: OUTLINE must not cross or touch itself.> ...
%! geom.Region ([0, 0; 10, 10; 10, 0; 0, 10])
%!error<geom.Region: HOLES\{1\} must not cross or touch itself.> ...
%! geom.Region ([0, 0; 20, 0; 20, 20; 0, 20], {[5, 5; 15, 15; 15, 5; 5, 15]})
%!error<geom.Region: OUTLINE must enclose a nonzero area.> ...
%! geom.Region ([0, 0; 5, 0; 10, 0])
%!error<geom.Region: HOLES\{1\} must lie strictly inside OUTLINE.> ...
%! geom.Region ([0, 0; 20, 0; 20, 20; 0, 20], {[30, 5; 35, 5; 35, 10]})
%!error<geom.Region: HOLES\{1\} must lie strictly inside OUTLINE.> ...
%! geom.Region ([0, 0; 20, 0; 20, 20; 0, 20], {[15, 5; 25, 5; 25, 10]})
%!error<geom.Region: HOLES\{1\} must lie strictly inside OUTLINE.> ...
%! geom.Region ([0, 0; 20, 0; 20, 20; 0, 20], {[0, 5; 5, 5; 5, 10]})
%!error<geom.Region: HOLES\{1\} must lie strictly inside OUTLINE.> ...
%! geom.Region ([0, 0; 20, 0; 20, 15; 0, 15], {[2, 7.5, 1; 18, 7.5, 1]})
%!error<geom.Region: HOLES\{1\} and HOLES\{2\} must not overlap or touch.> ...
%! geom.Region ([0, 0; 30, 0; 30, 20; 0, 20], ...
%!              {[2, 2; 12, 2; 12, 12; 2, 12], [8, 8; 18, 8; 18, 18; 8, 18]})
%!error<geom.Region: HOLES\{1\} and HOLES\{2\} must not overlap or touch.> ...
%! geom.Region ([0, 0; 30, 0; 30, 20; 0, 20], ...
%!              {[2, 2; 12, 2; 12, 12; 2, 12], [12, 2; 20, 2; 20, 12]})
%!error<geom.Region: HOLES\{1\} and HOLES\{2\} must not overlap or touch.> ...
%! geom.Region ([0, 0; 30, 0; 30, 20; 0, 20], ...
%!              {[2, 2; 18, 2; 18, 18; 2, 18], [5, 5; 8, 5; 8, 8; 5, 8]})
