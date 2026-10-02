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

    ## The region as Open CASCADE takes it: the outline and a cell of the
    ## holes, each as geom.Path's __data__ makes it, and the frame of the
    ## region's plane, rows origin, x axis, y axis and normal
    function D = __data__ (this)

      U = this.UCS;
      D = struct ('outline', __data__ (this.Outline), ...
                  'holes', {cellfun(@__data__, this.Holes, ...
                                    'UniformOutput', false)}, ...
                  'frame', [U.Origin; U.XAxis; U.YAxis; U.Normal]);

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

    ## The region with every point p of its plane moved to p * M + B, in its
    ## UCS, for M a 2-by-2 matrix that is not singular; the loops are turned
    ## back to run as a region's do where M reflects
    function this = __affine__ (this, M, B)

      ## z = 0 throughout, so z takes the scale of the plane, which keeps a
      ## similarity of the plane one in space and its arcs arcs
      A = sqrt (abs (det (M))) * eye (3);
      A(1:2,1:2) = M;
      b = [B, 0];
      this.Outline = __affine__ (this.Outline, A, b);
      this.Holes = cellfun (@(h) __affine__ (h, A, b), this.Holes, ...
                            'UniformOutput', false);
      if (det (M) < 0)
        this.Outline = __reversed__ (this.Outline);
        this.Holes = cellfun (@__reversed__, this.Holes, ...
                              'UniformOutput', false);
      endif

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

    ## -*- texinfo -*-
    ## @deftypefn {geom.Region} {@var{R} =} union (@var{R1}, @var{R2}, @dots{})
    ##
    ## The area of any of several regions.
    ##
    ## @code{@var{R} = union (@var{R1}, @var{R2}, @dots{})} returns the area
    ## covered by any of the regions, as a 1-by-@math{N} cell array of
    ## @code{geom.Region} objects, one for each separate piece, largest first,
    ## in the @code{geom.UCS} of @var{R1}.  Each argument is a region or a cell
    ## array of them, such as another of these operations returns, so that they
    ## chain.  Every region must lie in the plane of the first.  Where two meet
    ## along an edge they become one, and the edges of the result are those of
    ## the regions, arcs and splines exact.  This is OpenSCAD's @code{union} of
    ## 2-D shapes, before the result is extruded or revolved.
    ##
    ## @example
    ## @group
    ## ## A plate and a tab, as one outline
    ## R = union (geom.Region ([0, 0; 60, 0; 60, 40; 0, 40]), ...
    ##            geom.Region ([50, 10; 80, 10; 80, 30; 50, 30]));
    ## S = solid.extrude (R@{1@}, 5);
    ## @end group
    ## @end example
    ##
    ## Open CASCADE computes it, so the package must be built with it.
    ##
    ## @seealso{geom.Region.subtract, geom.Region.intersect, geom.Region.offset}
    ## @end deftypefn
    function R = union (varargin)

      R = combine ('union', 'geom.Region.union', varargin);

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {geom.Region} {@var{R} =} subtract (@var{R1}, @var{R2}, @dots{})
    ##
    ## The area of a region outside several others.
    ##
    ## @code{@var{R} = subtract (@var{R1}, @var{R2}, @dots{})} returns the area
    ## of @var{R1} that lies in none of the regions after it, as
    ## @code{geom.Region.union} returns its result: a cell array of regions,
    ## largest first, in the @code{geom.UCS} of @var{R1}, empty when nothing is
    ## left.  This is OpenSCAD's @code{difference} of 2-D shapes.
    ##
    ## @seealso{geom.Region.union, geom.Region.intersect}
    ## @end deftypefn
    function R = subtract (varargin)

      R = combine ('subtract', 'geom.Region.subtract', varargin);

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {geom.Region} {@var{R} =} intersect (@var{R1}, @var{R2}, @dots{})
    ##
    ## The area common to several regions.
    ##
    ## @code{@var{R} = intersect (@var{R1}, @var{R2}, @dots{})} returns the
    ## area that lies in every one of the regions, as
    ## @code{geom.Region.union} returns its result, empty when they share
    ## none.  This is OpenSCAD's @code{intersection} of 2-D shapes.
    ##
    ## @seealso{geom.Region.union, geom.Region.subtract}
    ## @end deftypefn
    function R = intersect (varargin)

      R = combine ('intersect', 'geom.Region.intersect', varargin);

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {geom.Region} {@var{R} =} offset (@var{R}, @var{D})
    ## @deftypefnx {geom.Region} {@var{R} =} offset (@var{R}, @var{D}, @qcode{'Corners'}, @var{C})
    ##
    ## Grow or shrink a region by a distance.
    ##
    ## @code{@var{R} = offset (@var{R}, @var{D})} returns the points of the
    ## plane that lie within @var{D} millimetres of the region, for a
    ## positive @var{D}, or the points of the region at least @minus{}@var{D}
    ## inside its edges, for a negative one: the outline moves out by @var{D}
    ## and the holes close in by it, or the other way.  The corners that come
    ## out of the move are round by default, arcs of radius @var{D}, as
    ## OpenSCAD's @code{offset (r = @var{D})} makes them.  Shrinking can split a
    ## region into pieces or leave nothing, so the result is a cell array of
    ## regions as @code{geom.Region.union} returns it.
    ##
    ## With @qcode{'Corners'} set to @qcode{'sharp'} the edges are carried on
    ## to meet, as @code{offset (delta = @var{D})} makes them, and with
    ## @qcode{'chamfer'} each such corner between straight edges is cut off
    ## square to the corner, @var{D} from where it was, as
    ## @code{offset (delta = @var{D}, chamfer = true)} does.
    ##
    ## The edges of the result are those of the region moved, straight edges
    ## straight and arcs exact; a spline's offset is a spline that Open CASCADE
    ## fits to it, to about a part in ten million.  It computes the offset, so
    ## the package must be built with it.
    ##
    ## @example
    ## @group
    ## ## A band 2 wide round a flange, G@{1@}; G@{2@} is the band 2 wide
    ## ## inside its bore, which grows into it too
    ## F = geom.Region ([0, 0; 60, 0; 60, 40; 0, 40], ...
    ##                  @{[30, 20, 1; 40, 20, 1]@});
    ## G = subtract (offset (F, 2), F);
    ## @end group
    ## @end example
    ##
    ## @seealso{geom.Region.union, geom.Region.fillet, geom.offset}
    ## @end deftypefn
    function R = offset (this, D, varargin)

      ## Input validation
      if (nargin != 2 && nargin != 4)
        error ("geom.Region.offset: invalid number of input arguments.");
      endif
      if (! isnumeric (D) || ! isreal (D) || ! isscalar (D) || ! isfinite (D))
        error ("geom.Region.offset: D must be a finite real scalar.");
      endif
      C = 'round';
      if (nargin == 4)
        if (! ischar (varargin{1}) || ! strcmp (varargin{1}, 'Corners'))
          error ("geom.Region.offset: unknown parameter.");
        endif
        C = varargin{2};
        if (! ischar (C) || ! any (strcmp (C, {'round', 'sharp', 'chamfer'})))
          error (strcat ("geom.Region.offset: Corners must be 'round',", ...
                         " 'sharp' or 'chamfer'."));
        endif
      endif
      if (D == 0)
        R = {this};
        return;
      endif
      if (exist ('__occt__') != 3)
        error (strcat ("geom.Region.offset: Open CASCADE is not available:", ...
                       " the drafting package was built without it."));
      endif

      U = this.UCS;
      F = __occt__ ('offset2d', 'geom.Region.offset', __data__ (this), ...
                    double (D), find (strcmp (C, {'round', 'sharp', ...
                                                  'chamfer'})) - 1, ...
                    [U.Origin; U.XAxis; U.YAxis; U.Normal]);
      R = geom.Region.__faces__ (F, U);

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {geom.Region} {@var{R} =} hull (@var{R1}, @var{R2}, @dots{})
    ##
    ## The convex hull of regions and points.
    ##
    ## @code{@var{R} = hull (@var{R1}, @var{R2}, @dots{})} returns the
    ## smallest convex region that holds every region and point given, the
    ## shape a band stretched round them takes, as a @code{geom.Region} in the
    ## @code{geom.UCS} of @var{R1}.  Each argument after the first is a
    ## region, a cell array of regions, such as @code{geom.Region.union}
    ## returns, or an @math{N}-by-2 matrix of points in the coordinates of that
    ## UCS.  Every region must lie in the plane of the first; only outlines
    ## count, since a hole cannot reach the hull.
    ##
    ## The hull is exact where the regions are made of lines and arcs: where
    ## it passes from one to the next its edge is a straight line truly
    ## tangent to the arcs it leaves and meets, and where an arc reaches
    ## furthest the hull follows the arc.  This is OpenSCAD's @code{hull} of
    ## 2-D shapes, which there are polygons of facets: the outline of a lever
    ## from the circles at its ends, of a bracket from its bosses, or of a
    ## plate rounded from four circles.  A spline is taken as points along
    ## it, the curve turning a tenth of a degree from one to the next.
    ##
    ## @example
    ## @group
    ## ## A lever: bosses of radius 10 and 5, 40 apart, and its bores
    ## C = @@(x, r) geom.Region ([x - r, 0, 1; x + r, 0, 1]);
    ## L = hull (C (0, 10), C (40, 5));
    ## L = subtract (L, C (0, 5), C (40, 2.5));
    ## @end group
    ## @end example
    ##
    ## It is computed without Open CASCADE.
    ##
    ## @seealso{geom.Region.union, geom.Region.offset}
    ## @end deftypefn
    function R = hull (varargin)

      ## Input validation
      if (nargin < 1)
        error ("geom.Region.hull: invalid number of input arguments.");
      endif
      L = {};
      P = zeros (0, 2);
      for k = 1:nargin
        a = varargin{k};
        if (isa (a, 'geom.Region') && isscalar (a))
          L{end+1} = a;
        elseif (iscell (a) && all (cellfun (@(r) isa (r, 'geom.Region') ...
                                             && isscalar (r), a(:)')))
          L = [L, a(:)'];
        elseif (k > 1 && isnumeric (a) && isreal (a) && ismatrix (a) ...
                && columns (a) == 2 && all (isfinite (a(:))))
          P = [P; double(a)];
        else
          error (strcat ("geom.Region.hull: every argument must be a", ...
                         " geom.Region object, a cell array of them, or", ...
                         " after the first an N-by-2 matrix of points."));
        endif
      endfor
      U = L{1}.UCS;
      A = zeros (0, 5);
      for k = 1:numel (L)
        V = L{k}.UCS;
        scale = max ([1, abs(U.Origin), abs(V.Origin)]);
        if (abs (V.Normal * U.Normal') < 1 - 1e-9 ...
            || abs ((V.Origin - U.Origin) * U.Normal') > 1e-9 * scale)
          error (strcat ("geom.Region.hull: every region must lie in the", ...
                         " plane of the first."));
        endif
        [p, a] = parts (__into__ (L{k}.Outline, U));
        P = [P; p];
        A = [A; a];
      endfor

      ## Convex and anticlockwise by its making, so taken without the checks,
      ## which take time quadratic in its vertices
      R = geom.Region ([0, 0; 1, 0; 0, 1]);
      R.Outline = geom.Path.__loop__ (__mesh__ ('hull', 'geom.Region.hull', ...
                                                P, A));
      R.UCS = U;

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {geom.Region} {@var{R} =} resize (@var{R}, @var{SZ})
    ## @deftypefnx {geom.Region} {@var{R} =} resize (@var{R}, @var{SZ}, @qcode{'Uniform'}, @var{TF})
    ##
    ## Scale a region to a size.
    ##
    ## @code{@var{R} = resize (@var{R}, @var{SZ})} scales the region evenly so
    ## that the box round it is as large as it can be within the sizes
    ## @code{@var{SZ} = [@var{x}, @var{y}]}, in millimetres along the axes of
    ## its UCS; a size of 0 leaves that direction free.  @code{resize (@var{R},
    ## [30, 0])} makes the region 30 wide and keeps its proportions.  The
    ## corner of the box at the least @math{x} and @math{y} stays where it is,
    ## and arcs stay arcs.
    ##
    ## With @qcode{'Uniform'} set to @code{false} each direction given is
    ## scaled to its size on its own and a direction left at 0 keeps its
    ## size, as OpenSCAD's @code{resize} does.  An arc stretched so becomes
    ## part of an ellipse, kept exactly as a rational @code{geom.Spline}.
    ##
    ## @example
    ## @group
    ## ## A disc of diameter 10 stretched into an ellipse 40 by 20
    ## E = resize (geom.Region ([-5, 0, 1; 5, 0, 1]), [40, 20], ...
    ##             'Uniform', false);
    ## @end group
    ## @end example
    ##
    ## @seealso{geom.Region.mirror, solid.Shape.resize}
    ## @end deftypefn
    function this = resize (this, SZ, varargin)

      ## Input validation
      if (nargin != 2 && nargin != 4)
        error ("geom.Region.resize: invalid number of input arguments.");
      endif
      if (! isnumeric (SZ) || ! isreal (SZ) || numel (SZ) != 2 ...
          || ! all (isfinite (SZ)) || any (SZ < 0) || ! any (SZ > 0))
        error (strcat ("geom.Region.resize: SZ must be a 2-element vector", ...
                       " of nonnegative finite sizes, not all zero."));
      endif
      [errmsg, even] = flag (varargin, 'Uniform', true);
      if (! isempty (errmsg))
        error ("geom.Region.resize: %s", errmsg);
      endif

      B = __box__ (this.Outline)(:,1:2);
      f = double (SZ(:)') ./ diff (B);
      given = SZ(:)' > 0;
      if (even)
        f(:) = min (f(given));
      else
        f(! given) = 1;
      endif
      this = __affine__ (this, diag (f), B(1,:) .* (1 - f));

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {geom.Region} {@var{R} =} mirror (@var{R}, @var{N})
    ## @deftypefnx {geom.Region} {@var{R} =} mirror (@var{R}, @var{N}, @var{P})
    ##
    ## Reflect a region in a line of its plane.
    ##
    ## @code{@var{R} = mirror (@var{R}, @var{N}, @var{P})} reflects the region
    ## in the line through the point @var{P}, the origin of its UCS by default,
    ## square to the nonzero direction @var{N}, both 2-element vectors in its
    ## UCS.  @code{mirror (@var{R}, [1, 0])} reflects in the @math{y} axis.
    ## Only the reflection is returned; @code{union (@var{R}, mirror (@var{R},
    ## @dots{}))} keeps both, as a profile drawn for one side of a symmetric
    ## part is made whole.
    ##
    ## @seealso{geom.Region.union, solid.Shape.mirror}
    ## @end deftypefn
    function this = mirror (this, N, P = [0, 0])

      ## Input validation
      if (nargin < 2 || nargin > 3)
        error ("geom.Region.mirror: invalid number of input arguments.");
      endif
      if (! isnumeric (N) || ! isreal (N) || numel (N) != 2 ...
          || ! all (isfinite (N)) || ! any (N != 0))
        error (strcat ("geom.Region.mirror: N must be a nonzero real", ...
                       " 2-element vector."));
      endif
      errmsg = checkpoint (P, 'P');
      if (! isempty (errmsg))
        error ("geom.Region.mirror: %s", errmsg);
      endif

      n = double (N(:)') / norm (double (N));
      M = eye (2) - 2 * (n' * n);
      this = __affine__ (this, M, 2 * (double (P(:)') * n') * n);

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {geom.Region} {@var{C} =} copy (@var{R}, @var{D})
    ##
    ## Copies of a region, united.
    ##
    ## @code{@var{C} = copy (@var{R}, @var{D})} places a copy of the region
    ## moved by each row of @var{D}, an @math{N}-by-2 matrix of offsets in its
    ## UCS, and returns their union as @code{geom.Region.union} returns it, a
    ## cell array of regions, largest first.  The region itself is among them
    ## only where a row of @var{D} is zero.  Copies that overlap become one
    ## region.
    ##
    ## Open CASCADE unites the copies, so the package must be built with it.
    ##
    ## @seealso{geom.Region.rectarray, geom.Region.polararray, solid.Shape.copy}
    ## @end deftypefn
    function C = copy (this, D)

      ## Input validation
      if (nargin != 2)
        error ("geom.Region.copy: invalid number of input arguments.");
      endif
      if (! isnumeric (D) || ! isreal (D) || ! ismatrix (D) ...
          || columns (D) != 2 || rows (D) < 1 || ! all (isfinite (D(:))))
        error (strcat ("geom.Region.copy: D must be an N-by-2 real matrix", ...
                       " of finite offsets."));
      endif

      C = copies (this, double (D), 'geom.Region.copy');

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {geom.Region} {@var{C} =} rectarray (@var{R}, @var{COUNT}, @var{SPACING})
    ##
    ## Copies of a region in rows and columns, united.
    ##
    ## @code{@var{C} = rectarray (@var{R}, @var{COUNT}, @var{SPACING})} places
    ## @code{@var{COUNT} = [@var{nx}, @var{ny}]} copies of the region along the
    ## @math{x} and @math{y} axes of its UCS, @code{@var{SPACING} =
    ## [@var{dx}, @var{dy}]} millimetres apart, the first where the region
    ## is; a negative spacing runs the other way.  It returns their union as
    ## @code{geom.Region.copy} does.  This is a grid of holes or slots, drawn
    ## once and subtracted from a plate in one step.
    ##
    ## @example
    ## @group
    ## ## A plate with four rows of six holes of diameter 4, 10 apart
    ## H = rectarray (geom.Region ([8, 10, 1; 12, 10, 1]), [6, 4], [10, 10]);
    ## P = subtract (geom.Region ([0, 0; 70, 0; 70, 50; 0, 50]), H);
    ## @end group
    ## @end example
    ##
    ## @seealso{geom.Region.copy, geom.Region.polararray}
    ## @end deftypefn
    function C = rectarray (this, COUNT, SPACING)

      ## Input validation
      if (nargin != 3)
        error ("geom.Region.rectarray: invalid number of input arguments.");
      endif
      [errmsg, D] = geom.__grid__ (COUNT, SPACING, 2);
      if (! isempty (errmsg))
        error ("geom.Region.rectarray: %s", errmsg);
      endif

      C = copies (this, D, 'geom.Region.rectarray');

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {geom.Region} {@var{C} =} polararray (@var{R}, @var{N}, @var{ANGLE})
    ## @deftypefnx {geom.Region} {@var{C} =} polararray (@var{R}, @var{N}, @var{ANGLE}, @var{P})
    ## @deftypefnx {geom.Region} {@var{C} =} polararray (@dots{}, @qcode{'Rotate'}, @var{TF})
    ##
    ## Copies of a region round a point, united.
    ##
    ## @code{@var{C} = polararray (@var{R}, @var{N}, @var{ANGLE}, @var{P})}
    ## places @var{N} copies of the region round the point @var{P} of its
    ## plane, the origin of its UCS by default, the first where the region is
    ## and the rest turned on anticlockwise, clockwise for a negative
    ## @var{ANGLE}.  A whole turn, @var{ANGLE} of 360, spaces them evenly
    ## @code{@var{ANGLE} / @var{N}} apart; a part of a turn puts one at each
    ## end, @code{@var{ANGLE} / (@var{N} - 1)} apart.  It returns their union as
    ## @code{geom.Region.copy} does.
    ##
    ## Each copy is turned as it goes round, as the holes of a bolt circle or
    ## the spokes of a wheel are.  With @qcode{'Rotate'} set to @code{false}
    ## each copy keeps the region's own direction, moved as the centre of the
    ## box round it moves.
    ##
    ## @example
    ## @group
    ## ## A flange of diameter 60 with a bore of 20 and six bolt holes of 6
    ## ## on a circle of 40
    ## H = polararray (geom.Region ([17, 0, 1; 23, 0, 1]), 6, 360);
    ## F = subtract (geom.Region ([-30, 0, 1; 30, 0, 1], ...
    ##                           @{[-10, 0, 1; 10, 0, 1]@}), H);
    ## @end group
    ## @end example
    ##
    ## @seealso{geom.Region.copy, geom.Region.rectarray}
    ## @end deftypefn
    function C = polararray (this, N, ANGLE, varargin)

      ## Input validation
      if (nargin < 3 || nargin > 6)
        error ("geom.Region.polararray: invalid number of input arguments.");
      endif
      P = [0, 0];
      if (! isempty (varargin) && ! ischar (varargin{1}))
        P = varargin{1};
        varargin(1) = [];
      endif
      [errmsg, a] = geom.__turns__ (N, ANGLE);
      if (isempty (errmsg))
        errmsg = checkpoint (P, 'P');
      endif
      if (isempty (errmsg))
        [errmsg, turning] = flag (varargin, 'Rotate', true);
      endif
      if (! isempty (errmsg))
        error ("geom.Region.polararray: %s", errmsg);
      endif

      P = double (P(:)');
      a *= pi / 180;
      B = __box__ (this.Outline)(:,1:2);
      c = mean (B, 1);
      L = cell (1, numel (a));
      for k = 1:numel (a)
        M = [cos(a(k)), sin(a(k)); -sin(a(k)), cos(a(k))];
        if (turning)
          L{k} = __affine__ (this, M, P - P * M);
        else
          L{k} = __affine__ (this, eye (2), (c - P) * M + P - c);
        endif
      endfor
      C = union (L{:});

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
      ## Holes whose boxes are apart can neither overlap nor touch, which
      ## spares most pairs the polygon tests
      B = cell2mat (cellfun (@(q) [min(q, [], 1), max(q, [], 1)], S(:), ...
                             'UniformOutput', false));
      for j = 2:numel (S)
        for k = j+1:numel (S)
          if (any (B(j,3:4) < B(k,1:2)) || any (B(k,3:4) < B(j,1:2)))
            continue;
          endif
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

  methods (Static, Hidden)

    ## The regions of the faces F that Open CASCADE hands back, each the outer
    ## loop and the inner loops as geom.Path.__loop__ takes them, in the
    ## frame of the UCS U where its plane is z = 0, laid in U, largest first.
    ## Open CASCADE has made and checked the faces, so the checks a region is
    ## made with, which take time growing with the square of the number of
    ## holes, are not run again; the loops are only turned to run as a
    ## region's do, the outline anticlockwise and the holes clockwise.
    function R = __faces__ (F, U)

      R = cell (1, numel (F));
      A = zeros (1, numel (F));
      for k = 1:numel (F)
        O = geom.Path.__loop__ (F{k}.outline);
        a = __area__ (O);
        if (a < 0)
          O = __reversed__ (O);
        endif
        A(k) = abs (a);
        H = cell (1, numel (F{k}.holes));
        for j = 1:numel (H)
          H{j} = geom.Path.__loop__ (F{k}.holes{j});
          h = __area__ (H{j});
          if (h > 0)
            H{j} = __reversed__ (H{j});
          endif
          A(k) -= abs (h);
        endfor
        Q = geom.Region ([0, 0; 1, 0; 0, 1]);
        Q.Outline = O;
        Q.Holes = H;
        Q.UCS = U;
        R{k} = Q;
      endfor
      [~, i] = sort (A, 'descend');
      R = R(i);

    endfunction

  endmethods

endclassdef

## The union of the copies of the region R moved by the rows of D, for CALLER
function C = copies (R, D, caller)

  L = cell (1, rows (D));
  for k = 1:rows (D)
    L{k} = __affine__ (R, eye (2), D(k,:));
  endfor
  C = combine ('union', caller, L);

endfunction

## The value of the option NAME in the Name/Value pairs ARGS, a logical
## scalar, DEF when not given.  Returns an error message body, empty when ARGS
## is valid.
function [errmsg, TF] = flag (ARGS, NAME, DEF)

  errmsg = '';
  TF = DEF;
  if (isempty (ARGS))
    return;
  endif
  if (numel (ARGS) != 2)
    errmsg = "Name/Value arguments must come in pairs.";
  elseif (! ischar (ARGS{1}) || ! strcmp (ARGS{1}, NAME))
    errmsg = "unknown parameter.";
  elseif (! (islogical (ARGS{2}) || isnumeric (ARGS{2})) ...
          || ! isscalar (ARGS{2}) || ! any (ARGS{2} == [0, 1]))
    errmsg = sprintf ("%s must be true or false.", NAME);
  else
    TF = logical (ARGS{2});
  endif

endfunction

## Validate a point of the plane.  Returns an error message body, empty when
## P is valid.
function errmsg = checkpoint (P, NAME)

  errmsg = '';
  if (! isnumeric (P) || ! isreal (P) || numel (P) != 2 ...
      || ! all (isfinite (P)))
    errmsg = sprintf (strcat ("%s must be a real 2-element vector of", ...
                              " finite values."), NAME);
  endif

endfunction

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

## The points and arcs of the closed path Q for a hull: its vertices and the
## points along its splines as rows of P, and each arc as a row of A, its
## centre, its radius, and the angles it runs between anticlockwise
function [P, A] = parts (Q)

  V = Q.Vertices(:,1:2);
  M = Q.Midpoints;
  n = rows (V);
  P = V;
  A = zeros (0, 5);
  for i = find (! isnan (M(:,1)))'
    a = V(i,:);
    m = M(i,1:2);
    b = V(mod (i, n) + 1,:);
    u = a - m;
    w = b - m;
    d = 2 * (u(1) * w(2) - u(2) * w(1));
    c = m + [w(2) * dot(u, u) - u(2) * dot(w, w), ...
             u(1) * dot(w, w) - w(1) * dot(u, u)] / d;
    r = norm (a - c);
    ta = atan2 (a(2) - c(2), a(1) - c(1));
    tb = atan2 (b(2) - c(2), b(1) - c(1));
    ccw = (m(1) - a(1)) * (b(2) - m(2)) - (m(2) - a(2)) * (b(1) - m(1)) > 0;
    if (! ccw)
      [ta, tb] = deal (tb, ta);
    endif
    sweep = mod (tb - ta, 2 * pi);
    A(end+1,:) = [c, r, ta, ta + sweep];
  endfor
  for i = find (! cellfun (@isempty, Q.Splines))'
    S = __sample__ (Q.Splines{i}, 0.1);
    P = [P; S(:,1:2)];
  endfor

endfunction

## The union, difference or intersection, OP, of the regions in ARGS, each a
## region or a cell array of them, for CALLER, which names any error
function R = combine (op, caller, args)

  L = {};
  for k = 1:numel (args)
    a = args{k};
    if (isa (a, 'geom.Region') && isscalar (a))
      L{end+1} = a;
    elseif (iscell (a) && all (cellfun (@(r) isa (r, 'geom.Region') ...
                                         && isscalar (r), a(:)')))
      L = [L, a(:)'];
    else
      error (strcat ("%s: every argument must be a geom.Region object or", ...
                     " a cell array of them."), caller);
    endif
  endfor
  R = cell (1, 0);
  if (isempty (L))
    return;
  endif
  U = L{1}.UCS;
  for k = 2:numel (L)
    V = L{k}.UCS;
    scale = max ([1, abs(U.Origin), abs(V.Origin)]);
    if (abs (V.Normal * U.Normal') < 1 - 1e-9 ...
        || abs ((V.Origin - U.Origin) * U.Normal') > 1e-9 * scale)
      error ("%s: every region must lie in the plane of the first.", caller);
    endif
  endfor
  if (exist ('__occt__') != 3)
    error (strcat ("%s: Open CASCADE is not available: the drafting", ...
                   " package was built without it."), caller);
  endif
  F = __occt__ ('region2d', caller, op, cellfun (@__data__, L, ...
                                                 'UniformOutput', false), ...
                [U.Origin; U.XAxis; U.YAxis; U.Normal]);
  R = geom.Region.__faces__ (F, U);

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

%!testif ; exist ('__occt__') == 3  # union: one outline, or pieces
%! A = geom.Region ([0, 0; 60, 0; 60, 40; 0, 40]);
%! R = union (A, geom.Region ([50, 10; 80, 10; 80, 30; 50, 30]));
%! assert_equal (numel (R), 1);
%! assert_equal (__area__ (R{1}.Outline), 2800, 1e-9);
%! assert_equal (rows (R{1}.Outline.Vertices), 8);
%! R = union (A, geom.Region ([70, 0; 80, 0; 80, 10]));
%! assert_equal (cellfun (@(r) __area__ (r.Outline), R), [2400, 50], 1e-9);
%! ## Meeting along an edge, one block
%! R = union (A, geom.Region ([60, 0; 70, 0; 70, 40; 60, 40]));
%! assert_equal (rows (R{1}.Outline.Vertices), 4);

%!testif ; exist ('__occt__') == 3  # two discs, their arcs exact
%! D = @(x) geom.Region ([x - 10, 0, 1; x + 10, 0, 1]);
%! R = union (D (0), D (10));
%! A = 2 * 100 * acos (0.5) - 10 * sqrt (100 - 25);
%! assert_equal (__area__ (R{1}.Outline), 2 * 100 * pi - A, 1e-9);
%! R = intersect (D (0), D (10));
%! assert_equal (__area__ (R{1}.Outline), A, 1e-9);

%!testif ; exist ('__occt__') == 3  # subtract: a hole, or a cut in two
%! A = geom.Region ([0, 0; 60, 0; 60, 40; 0, 40]);
%! R = subtract (A, geom.Region ([20, 20, 1; 40, 20, 1]));
%! assert_equal (numel (R{1}.Holes), 1);
%! assert_equal (__area__ (R{1}.Holes{1}), -100 * pi, 1e-9);
%! R = subtract (A, geom.Region ([20, -5; 30, -5; 30, 45; 20, 45]));
%! assert_equal (cellfun (@(r) __area__ (r.Outline), R), [1200, 800], 1e-9);
%! assert_equal (subtract (A, A), cell (1, 0));

%!testif ; exist ('__occt__') == 3  # chained, and in a UCS of their own
%! U = geom.UCS ([0, 1, 1], [1, 2, 3]);
%! A = geom.Region ([0, 0; 60, 0; 60, 40; 0, 40]);
%! A.UCS = U;
%! B = geom.Region ([50, 10; 80, 10; 80, 30; 50, 30]);
%! B.UCS = U;
%! C = geom.Region ([20, 20, 1; 40, 20, 1]);
%! C.UCS = U;
%! R = subtract (union (A, B), C);
%! assert_equal (R{1}.UCS, U);
%! assert_equal (__area__ (R{1}.Outline) + __area__ (R{1}.Holes{1}), ...
%!               2800 - 100 * pi, 1e-9);

%!testif ; exist ('__occt__') == 3  # offset: round, sharp and cut corners
%! S = geom.Region ([0, 0; 10, 0; 10, 10; 0, 10]);
%! R = offset (S, 1);
%! assert_equal (__area__ (R{1}.Outline), 140 + pi, 1e-9);
%! R = offset (S, 1, 'Corners', 'sharp');
%! assert_equal (__area__ (R{1}.Outline), 144, 1e-9);
%! R = offset (S, 1, 'Corners', 'chamfer');
%! assert_equal (__area__ (R{1}.Outline), 144 - 4 * (sqrt (2) - 1) ^ 2, 1e-9);
%! assert_equal (rows (R{1}.Outline.Vertices), 8);
%! R = offset (S, -1);
%! assert_equal (__area__ (R{1}.Outline), 64, 1e-9);
%! assert_equal (offset (S, -6), cell (1, 0));
%! R = offset (S, 0);
%! assert_equal (__area__ (R{1}.Outline), 100);

%!testif ; exist ('__occt__') == 3  # an outline of arcs, a hole that closes in
%! S = geom.Region ([0, -6, 0; 40, -6, 1; 40, 6, 0; 0, 6, 1]);
%! R = offset (S, 1);
%! assert_equal (__area__ (R{1}.Outline), 560 + 49 * pi, 1e-9);
%! F = geom.Region ([0, 0; 20, 0; 20, 20; 0, 20], ...
%!                  {[8, 8; 12, 8; 12, 12; 8, 12]});
%! R = offset (F, 1);
%! assert_equal (__area__ (R{1}.Outline), 480 + pi, 1e-9);
%! assert_equal (__area__ (R{1}.Holes{1}), -4, 1e-9);

%!testif ; exist ('__occt__') == 3  # shrinking a dumbbell parts it
%! P = [0, 0; 10, 0; 10, 4.5; 20, 4.5; 20, 0; 30, 0; 30, 10; 20, 10; ...
%!      20, 5.5; 10, 5.5; 10, 10; 0, 10];
%! R = offset (geom.Region (P), -1);
%! assert_equal (numel (R), 2);

%!testif ; exist ('__occt__') == 3  # a spline outline, to Open CASCADE's fit
%! H = geom.Spline ([0, 0; 30, -5; 45, 15; 25, 30; 5, 20], 'Closed', true);
%! S = geom.Region (H);
%! R = offset (S, 1);
%! A = __area__ (S.Outline) + length (H) + pi;
%! assert_equal (__area__ (R{1}.Outline), A, -1e-6);

%!error<geom.Region.union: every argument must be a geom.Region object or a cell array of them.> ...
%! union (geom.Region ([0, 0; 1, 0; 1, 1]), [0, 0; 1, 0; 1, 1])
%!error<geom.Region.subtract: every region must lie in the plane of the first.>
%! A = geom.Region ([0, 0; 1, 0; 1, 1]);
%! B = A;
%! B.UCS = geom.UCS ([0, 0, 1], [0, 0, 1]);
%! subtract (A, B);
%!error<geom.Region.offset: invalid number of input arguments.> ...
%! offset (geom.Region ([0, 0; 1, 0; 1, 1]))
%!error<geom.Region.offset: D must be a finite real scalar.> ...
%! offset (geom.Region ([0, 0; 1, 0; 1, 1]), NaN)
%!error<geom.Region.offset: unknown parameter.> ...
%! offset (geom.Region ([0, 0; 1, 0; 1, 1]), 1, 'Join', 'round')
%!error<geom.Region.offset: Corners must be 'round', 'sharp' or 'chamfer'.> ...
%! offset (geom.Region ([0, 0; 1, 0; 1, 1]), 1, 'Corners', 'square')

## A disc of radius R about [X, Y], for the tests
%!function D = disc (x, y, r)
%!  D = geom.Region ([x - r, y, 1; x + r, y, 1]);
%!endfunction

%!test  # a lever from its two bosses, exact
%! L = hull (disc (0, 0, 10), disc (40, 0, 5));
%! a = asin (5 / 40);
%! A = (pi + 2 * a) * 50 + (pi - 2 * a) * 12.5 + sqrt (40 ^ 2 - 25) * 15;
%! assert_equal (__area__ (L.Outline), A, 1e-9);
%! assert_equal (nnz (isnan (L.Outline.Midpoints(:,1))), 2);

%!test  # a plate rounded from four circles
%! H = hull (disc (0, 0, 3), disc (50, 0, 3), disc (50, 30, 3), ...
%!           {disc(0, 30, 3)});
%! assert_equal (__area__ (H.Outline), 1500 + 6 * 80 + 9 * pi, 1e-9);
%! assert_equal (nnz (! isnan (H.Outline.Midpoints(:,1))), 4);

%!test  # points: those inside and in a line with others left out
%! H = hull (geom.Region ([2, 2; 3, 2; 3, 3]), ...
%!           [0, 0; 10, 0; 10, 10; 0, 10; 5, 5; 5, 0; 10, 5]);
%! assert_equal (sortrows (H.Outline.Vertices(:,1:2)), ...
%!               [0, 0; 0, 10; 10, 0; 10, 10]);

%!test  # a circle and points, against the hull of points along the circle
%! P = [0, 0; 10, 0; 10, 10; 0, 10];
%! H = hull (disc (20, 5, 1), P);
%! t = linspace (0, 2 * pi, 20001)';
%! Q = [P; 20 + cos(t), 5 + sin(t)];
%! k = convhull (Q(:,1), Q(:,2));
%! assert_equal (__area__ (H.Outline), polyarea (Q(k,1), Q(k,2)), -1e-7);

%!test  # holes do not count; in the UCS of the first
%! U = geom.UCS ([0, 1, 1], [1, 2, 3]);
%! A = geom.Region ([0, 0; 10, 0; 10, 10; 0, 10], {[4, 4; 6, 4; 6, 6; 4, 6]});
%! A.UCS = U;
%! B = disc (15, 5, 2);
%! B.UCS = U;
%! H = hull (A, B);
%! assert_equal (H.UCS, U);
%! assert_equal (H.Holes, cell (1, 0));

%!test  # a spline outline, to a tenth of a degree
%! S = geom.Spline ([0, 0; 30, -5; 45, 15; 25, 30; 5, 20], 'Closed', true);
%! H = hull (geom.Region (S));
%! Q = points (S, 20001)(:,1:2);
%! k = convhull (Q(:,1), Q(:,2));
%! assert_equal (__area__ (H.Outline), polyarea (Q(k,1), Q(k,2)), -1e-6);

%!error<geom.Region.hull: every argument must be a geom.Region object, a cell array of them, or after the first an N-by-2 matrix of points.> ...
%! hull (geom.Region ([0, 0; 1, 0; 1, 1]), [0, 0, 0])
%!error<geom.Region.hull: every region must lie in the plane of the first.>
%! A = geom.Region ([0, 0; 1, 0; 1, 1]);
%! B = A;
%! B.UCS = geom.UCS ([0, 0, 1], [0, 0, 1]);
%! hull (A, B);

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

## The area of the region R, the outline less the holes
%!function a = regionarea (R)
%!  a = __area__ (R.Outline) + sum (cellfun (@__area__, R.Holes));
%!endfunction
## The box round the region R in its UCS, [xmin, ymin; xmax, ymax]
%!function B = regionbox (R)
%!  B = __box__ (R.Outline)(:,1:2);
%!endfunction

%!test  # resized evenly: arcs stay arcs, the least corner stays
%! R = geom.Region ([0, 0; 10, 0; 10, 5; 0, 5], {[5, 2.5, 1; 7, 2.5, 1]});
%! S = resize (R, [0, 20]);
%! assert_equal (regionbox (S), [0, 0; 40, 20], 1e-12);
%! assert_equal (regionarea (S), 16 * (50 - pi), -1e-12);
%! assert_equal (any (! isnan (S.Holes{1}.Midpoints(:,1))), true);
%! assert_equal (regionbox (resize (R, [30, 30])), [0, 0; 30, 15], 1e-12);

%!test  # resized unevenly: a disc becomes an exact ellipse
%! E = resize (geom.Region ([-5, 0, 1; 5, 0, 1]), [40, 20], 'Uniform', false);
%! assert_equal (regionbox (E), [-5, -5; 35, 15], 1e-12);
%! assert_equal (regionarea (E), 200 * pi, -1e-12);
%! assert_equal (all (isnan (E.Outline.Midpoints(:,1))), true);
%! F = resize (geom.Region ([0, 0; 10, 0; 10, 5; 0, 5]), [20, 0], ...
%!             'Uniform', false);
%! assert_equal (regionbox (F), [0, 0; 20, 5], 1e-12);

%!test  # an ellipse spline as a region, its box exact
%! R = geom.Region (geom.Spline.ellipse (20, 10), {[-4, 0, 1; 4, 0, 1]});
%! assert_equal (regionarea (R), 200 * pi - 16 * pi, -1e-12);
%! assert_equal (regionbox (resize (R, [10, 0])), [-20, -10; -10, -5], 1e-9);

%!test  # mirrored in a line: the area kept, the loops turned back
%! R = geom.Region ([0, 0; 10, 0; 0, 5], {[1, 1; 3, 1; 1, 2]});
%! M = mirror (R, [1, 0], [20, 0]);
%! assert_equal (regionbox (M), [30, 0; 40, 5], 1e-12);
%! assert_equal (regionarea (M), 24, -1e-12);
%! assert_equal (__area__ (M.Holes{1}) < 0, true);
%! R = geom.Region ([0, 0, 0; 10, 0, 0; 10, 5, 1; 0, 5, 0]);
%! assert_equal (regionarea (mirror (R, [1, 1])), regionarea (R), -1e-12);

%!testif ; exist ('__occt__') == 3  # copies: overlapping ones united
%! D = geom.Region ([-5, 0, 1; 5, 0, 1]);
%! C = copy (D, [0, 0; 20, 0; 8, 0]);
%! assert_equal (numel (C), 2);
%! assert_equal (regionarea (C{2}), 25 * pi, -1e-12);
%! assert_equal (regionbox (C{1}), [-5, -5; 13, 5], 1e-9);

%!testif ; exist ('__occt__') == 3  # a rectangular array of holes
%! H = rectarray (geom.Region ([8, 10, 1; 12, 10, 1]), [3, 2], [10, 10]);
%! assert_equal (numel (H), 6);
%! P = subtract (geom.Region ([0, 0; 40, 0; 40, 30; 0, 30]), H);
%! assert_equal (regionarea (P{1}), 1200 - 24 * pi, -1e-12);
%! assert_equal (__area__ (P{1}.Outline) > 0, true);
%! assert_equal (all (cellfun (@__area__, P{1}.Holes) < 0), true);

%!test  # many holes apart, each pair settled by its boxes
%! [x, y] = ndgrid (10:10:70);
%! H = arrayfun (@(a, b) [a - 2, b, 1; a + 2, b, 1], x(:), y(:), ...
%!               'UniformOutput', false);
%! R = geom.Region ([0, 0; 80, 0; 80, 80; 0, 80], H);
%! assert_equal (numel (R.Holes), 49);
%! assert_equal (regionarea (R), 6400 - 196 * pi, -1e-12);

%!testif ; exist ('__occt__') == 3  # a bolt circle, and a quarter turn
%! H = polararray (geom.Region ([17, 0, 1; 23, 0, 1]), 6, 360);
%! c = cell2mat (cellfun (@(r) mean (regionbox (r), 1), H(:), ...
%!                        'UniformOutput', false));
%! assert_equal (sortrows (round (c * 1e6) / 1e6), ...
%!               sortrows (round (20 * [cosd(0:60:300); sind(0:60:300)]' ...
%!                                * 1e6) / 1e6), 1e-6);
%! Q = polararray (geom.Region ([15, -1; 25, -1; 25, 1; 15, 1]), 3, 90);
%! assert_equal (numel (Q), 3);
%! assert_equal (sum (cellfun (@regionarea, Q)), 60, -1e-12);

%!testif ; exist ('__occt__') == 3  # copies kept as the region faces
%! Q = polararray (geom.Region ([15, -1; 25, -1; 25, 1; 15, 1]), 2, 90, ...
%!                 [0, 0], 'Rotate', false);
%! B = sortrows (cell2mat (cellfun (@(r) regionbox (r)(:)', Q(:), ...
%!                                  'UniformOutput', false)));
%! assert_equal (B, [-5, 5, 19, 21; 15, 25, -1, 1], 1e-12);

%!error<geom.Region.resize: invalid number of input arguments.> ...
%! resize (geom.Region ([0, 0; 1, 0; 0, 1]))
%!error<geom.Region.resize: SZ must be a 2-element vector of nonnegative finite sizes, not all zero.> ...
%! resize (geom.Region ([0, 0; 1, 0; 0, 1]), [0, 0])
%!error<geom.Region.resize: SZ must be a 2-element vector of nonnegative finite sizes, not all zero.> ...
%! resize (geom.Region ([0, 0; 1, 0; 0, 1]), [1, 1, 1])
%!error<geom.Region.resize: unknown parameter.> ...
%! resize (geom.Region ([0, 0; 1, 0; 0, 1]), [1, 1], 'Even', true)
%!error<geom.Region.resize: Uniform must be true or false.> ...
%! resize (geom.Region ([0, 0; 1, 0; 0, 1]), [1, 1], 'Uniform', 2)
%!error<geom.Region.mirror: invalid number of input arguments.> ...
%! mirror (geom.Region ([0, 0; 1, 0; 0, 1]))
%!error<geom.Region.mirror: N must be a nonzero real 2-element vector.> ...
%! mirror (geom.Region ([0, 0; 1, 0; 0, 1]), [0, 0])
%!error<geom.Region.mirror: P must be a real 2-element vector of finite values.> ...
%! mirror (geom.Region ([0, 0; 1, 0; 0, 1]), [1, 0], [1, 2, 3])
%!error<geom.Region.copy: invalid number of input arguments.> ...
%! copy (geom.Region ([0, 0; 1, 0; 0, 1]))
%!error<geom.Region.copy: D must be an N-by-2 real matrix of finite offsets.> ...
%! copy (geom.Region ([0, 0; 1, 0; 0, 1]), [1, 2, 3])
%!error<geom.Region.rectarray: invalid number of input arguments.> ...
%! rectarray (geom.Region ([0, 0; 1, 0; 0, 1]), [2, 2])
%!error<geom.Region.rectarray: COUNT must be a 2-element vector of positive integers.> ...
%! rectarray (geom.Region ([0, 0; 1, 0; 0, 1]), [2, 0], [5, 5])
%!error<geom.Region.rectarray: SPACING must be nonzero where COUNT is more than one.> ...
%! rectarray (geom.Region ([0, 0; 1, 0; 0, 1]), [2, 2], [5, 0])
%!error<geom.Region.polararray: invalid number of input arguments.> ...
%! polararray (geom.Region ([0, 0; 1, 0; 0, 1]), 3)
%!error<geom.Region.polararray: N must be a positive integer.> ...
%! polararray (geom.Region ([0, 0; 1, 0; 0, 1]), 0, 90)
%!error<geom.Region.polararray: ANGLE must be a nonzero real scalar of at most 360 degrees.> ...
%! polararray (geom.Region ([0, 0; 1, 0; 0, 1]), 3, 720)
%!error<geom.Region.polararray: P must be a real 2-element vector of finite values.> ...
%! polararray (geom.Region ([0, 0; 1, 0; 0, 1]), 3, 90, [1, 2, 3])
%!error<geom.Region.polararray: Rotate must be true or false.> ...
%! polararray (geom.Region ([0, 0; 1, 0; 0, 1]), 3, 90, 'Rotate', 'no')
%!error<geom.Region.polararray: Name/Value arguments must come in pairs.> ...
%! polararray (geom.Region ([0, 0; 1, 0; 0, 1]), 3, 90, [0, 0], 'Rotate')
