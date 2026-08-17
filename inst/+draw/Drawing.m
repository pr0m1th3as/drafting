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
## @deftypefn  {drafting} {@var{D} =} draw.Drawing ()
## @deftypefnx {drafting} {@var{D} =} draw.Drawing (@var{NAME})
##
## A two-dimensional drawing in model space.
##
## @code{draw.Drawing} holds an ordered list of drawing entities in
## millimetres, each assigned to a named layer, together with the machinery to
## append more.  It is the single geometry model behind every output format:
## the CAD file, the report figure and the screen preview are three renderings
## of one @code{draw.Drawing}.
##
## The class is a @emph{value} class, so every method that appends an entity
## returns a new object and the original is unchanged.  Append methods are
## written to chain:
##
## @example
## @group
## D = draw.Drawing ('plate');
## D.Layer = 'outline';
## D = D.polyline ([0, 0; 160, 0; 160, 180; 0, 180], true);
## D = D.circle ([80, 90], 25).text ([0, -20], 'PLATE', 3.5);
## @end group
## @end example
##
## New entities are placed on the layer named by the @code{Layer} property,
## exactly as a CAD application places them on its current layer.  Draw on
## another layer by assigning to @code{Layer} first; no append method takes a
## layer argument.
##
## @code{Linetype} and @code{Colour} work the same way and are governed by the
## same rule: they apply to what is appended after they are set, and never to
## what came before.  @code{Linetype} is a name --- see @code{draw.linetype} ---
## and defaults to @qcode{'CONTINUOUS'}.  @code{Colour} is an index, or a name
## that @code{draw.colour} resolves to one, and defaults to 256, meaning take
## the layer's colour.
##
## Three properties rather than arguments is what lets a caller set a drawing
## convention once and then draw, which is how a draughtsman works and how CAD
## is built.  It is also why a dimension's exploded parts inherit all three:
## the rule has no exceptions.
##
## Dimensions are stored @strong{semantically} --- the two measured points, a
## perpendicular offset and a direction --- and are turned into lines,
## arrowheads and text by whichever backend renders them.  Nothing about how a
## dimension looks is decided here.
##
## @subheading Properties
##
## @multitable @columnfractions .18 .82
## @item @code{Name} @tab Drawing name, a character vector.  Carried through to
## the output where the format has somewhere to put it.
## @item @code{Layer} @tab The current layer.  New entities go on it.  Defaults
## to @qcode{'0'}, which is the DXF default layer.
## @item @code{Entities} @tab Read-only.  The entity struct array, in the order
## the entities were appended.
## @end multitable
##
## @subheading Entity record
##
## Each element of @code{Entities} is a struct with the same thirteen fields,
## whatever its type; fields that do not apply to a type are left empty.
##
## @multitable @columnfractions .16 .84
## @item @code{type} @tab One of @qcode{'line'}, @qcode{'polyline'},
## @qcode{'arc'}, @qcode{'circle'}, @qcode{'text'}, @qcode{'hatch'},
## @qcode{'dim'}.
## @item @code{layer} @tab The layer the entity was drawn on.
## @item @code{pts} @tab @math{N}-by-2 coordinates in millimetres.  Its meaning
## depends on the type: the two endpoints of a line, the vertices of a
## polyline, the centre of an arc or circle, the insertion point of a text, the
## boundary of a hatch, the two measured points of a dimension.
## @item @code{closed} @tab Logical.  Polylines and hatch boundaries only.
## @item @code{radius} @tab Arcs and circles, in millimetres.
## @item @code{angles} @tab Arcs only: @code{[@var{A1}, @var{A2}]} in degrees,
## counter-clockwise from @var{A1} to @var{A2}.
## @item @code{angle} @tab A single angle in degrees: text rotation, or hatch
## pattern direction.
## @item @code{text} @tab Text entities, and the override string of a
## dimension.
## @item @code{height} @tab Text cap height in millimetres.
## @item @code{offset} @tab Dimensions: perpendicular distance from the
## measured points to the dimension line, in millimetres.  Signed.
## @item @code{direction} @tab Dimensions: @qcode{'aligned'},
## @qcode{'horizontal'} or @qcode{'vertical'}.
## @item @code{pattern} @tab Hatch pattern name.
## @item @code{spacing} @tab Hatch line spacing in millimetres.
## @end multitable
##
## A uniform field set costs a few empty fields per entity and buys the thing
## that matters: a backend is a @code{switch} over @code{type} that can read
## any field without testing whether it exists.
##
## @seealso{dxf.write, geom.bbox}
## @end deftypefn

classdef Drawing

  properties

    ## Drawing name, carried into the output where the format allows.
    Name = 'untitled';

    ## The current layer.  New entities are placed on it.
    Layer = '0';

    ## The current line type.  New entities are drawn with it.
    Linetype = 'CONTINUOUS';

    ## The current colour index.  256 takes the layer's colour.
    Colour = 256;

  endproperties

  properties (SetAccess = private)

    ## Block definitions, by name.  Each holds a drawing placed by 'insert'.
    Blocks = struct ('name', {}, 'drawing', {});

  endproperties

  properties (SetAccess = private)

    ## The entities, in the order they were appended.
    Entities = struct ('type', {}, 'layer', {}, 'linetype', {}, ...
                       'colour', {}, 'pts', {}, 'closed', {}, ...
                       'radius', {}, 'angles', {}, 'angle', {}, 'text', {}, ...
                       'height', {}, 'offset', {}, 'direction', {}, ...
                       'pattern', {}, 'spacing', {}, 'block', {}, ...
                       'scale', {}, 'bulge', {});

  endproperties

  methods (Access = public)

    ## -*- texinfo -*-
    ## @deftypefn  {draw.Drawing} {@var{D} =} Drawing ()
    ## @deftypefnx {draw.Drawing} {@var{D} =} Drawing (@var{NAME})
    ##
    ## Create an empty drawing, optionally named.
    ##
    ## @end deftypefn
    function this = Drawing (NAME)

      if (nargin == 1)
        this.Name = NAME;
      endif

    endfunction

    ## Validate on assignment rather than on use, so a bad name is rejected at
    ## the point the mistake was made.
    function this = set.Name (this, NAME)

      if (! ischar (NAME) || ! isrow (NAME) || isempty (NAME))
        error (strcat ("draw.Drawing: NAME must be a non-empty character", ...
                       " vector."));
      endif
      this.Name = NAME;

    endfunction

    function this = set.Layer (this, LAYER)

      if (! ischar (LAYER) || ! isrow (LAYER) || isempty (LAYER))
        error (strcat ("draw.Drawing: LAYER must be a non-empty character", ...
                       " vector."));
      endif
      this.Layer = LAYER;

    endfunction

    function this = set.Linetype (this, LT)

      if (! ischar (LT) || ! isrow (LT) || isempty (LT))
        error (strcat ("draw.Drawing: LINETYPE must be a non-empty", ...
                       " character vector."));
      endif
      this.Linetype = LT;

    endfunction

    function this = set.Colour (this, C)

      if (ischar (C))
        C = draw.colour (C);
      endif
      if (! isnumeric (C) || ! isreal (C) || ! isscalar (C) ...
          || ! isfinite (C) || C != fix (C) || C < 0 || C > 256)
        error (strcat ("draw.Drawing: COLOUR must be a name or an integer", ...
                       " index from 0 to 256."));
      endif
      this.Colour = C;

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {draw.Drawing} {@var{D} =} line (@var{D}, @var{P1}, @var{P2})
    ##
    ## Append a straight line segment from @var{P1} to @var{P2}.
    ##
    ## Both points are 1-by-2 vectors in millimetres.  A zero-length line is an
    ## error rather than an invisible entity in the output.
    ##
    ## @end deftypefn
    function this = line (this, P1, P2)

      if (nargin != 3)
        error ("draw.Drawing.line: invalid number of input arguments.");
      endif
      errmsg = checkpt (P1);
      if (! isempty (errmsg))
        error ("draw.Drawing.line: P1 %s", errmsg);
      endif
      errmsg = checkpt (P2);
      if (! isempty (errmsg))
        error ("draw.Drawing.line: P2 %s", errmsg);
      endif
      if (isequal (P1, P2))
        error ("draw.Drawing.line: P1 and P2 must not be the same point.");
      endif

      e = makeentity ('line', this.Layer, this.Linetype, this.Colour);
      e.pts = [P1; P2];
      this.Entities(end+1) = e;

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {draw.Drawing} {@var{D} =} polyline (@var{D}, @var{P})
    ## @deftypefnx {draw.Drawing} {@var{D} =} polyline (@var{D}, @var{P}, @var{CLOSED})
    ## @deftypefnx {draw.Drawing} {@var{D} =} polyline (@dots{}, @var{BULGE})
    ##
    ## Append a polyline through the vertices given as rows of @var{P}.
    ##
    ## @var{P} is an @math{N}-by-2 matrix in millimetres with at least two
    ## rows.  @var{CLOSED} is a logical scalar, @code{false} by default; when
    ## it is @code{true} the polyline closes back onto its first vertex.
    ##
    ## A closed polyline must @strong{not} repeat its first vertex at the end.
    ## The closed flag does that work, which is the implicitly closed
    ## convention the @code{geom} namespace uses throughout.
    ##
    ## @var{BULGE} gives one value per vertex, turning the segment that leaves
    ## that vertex into a circular arc.  The value is the tangent of a quarter
    ## of the arc's included angle, which is the convention DXF uses: zero is a
    ## straight segment and 1 a semicircle.
    ##
    ## A @strong{positive} bulge is the arc that runs counter-clockwise from the
    ## vertex to the next, which places it to the @emph{right} of the direction
    ## of travel; a negative one runs clockwise, to the left.  That is worth
    ## reading twice, because the sign is easy to guess backwards: an arc from
    ## @code{[0, 0]} to @code{[20, 0]} with a bulge of 1 dips @emph{below} the
    ## chord.  A polyline of arcs and lines together is how a slot, a
    ## rounded plate or an obround is drawn as one entity rather than as a
    ## handful that a later edit can pull apart.
    ##
    ## @end deftypefn
    function this = polyline (this, P, CLOSED = false, BULGE = [])

      if (nargin < 2 || nargin > 4)
        error ("draw.Drawing.polyline: invalid number of input arguments.");
      endif
      errmsg = checkpts (P);
      if (! isempty (errmsg))
        error ("draw.Drawing.polyline: P %s", errmsg);
      endif
      if (rows (P) < 2)
        error (strcat ("draw.Drawing.polyline: P must contain at least 2", ...
                       " vertices."));
      endif
      if (! (islogical (CLOSED) || isnumeric (CLOSED)) || ! isscalar (CLOSED))
        error ("draw.Drawing.polyline: CLOSED must be a logical scalar.");
      endif

      e = makeentity ('polyline', this.Layer, this.Linetype, this.Colour);
      e.pts = double (P);
      e.closed = logical (CLOSED);
      if (! isempty (BULGE))
        if (! isnumeric (BULGE) || ! isreal (BULGE) || ! isvector (BULGE) ...
            || numel (BULGE) != rows (P) || ! all (isfinite (BULGE)))
          error (strcat ("draw.Drawing.polyline: BULGE must hold one real", ...
                         " finite value per vertex."));
        endif
        e.bulge = BULGE(:)';
      endif
      this.Entities(end+1) = e;

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {draw.Drawing} {@var{D} =} arc (@var{D}, @var{C}, @var{R}, @var{A1}, @var{A2})
    ##
    ## Append a circular arc centred on @var{C} with radius @var{R}.
    ##
    ## @var{A1} and @var{A2} are the start and end angles in @strong{degrees},
    ## measured counter-clockwise from the positive @math{x} axis.  The arc is
    ## always swept counter-clockwise from @var{A1} to @var{A2}, which is the
    ## DXF convention; to sweep the other way, exchange the two angles.
    ##
    ## Equal start and end angles describe a full circle, since the two bound a
    ## sweep of 360 degrees.  Prefer @code{circle} when that is what is meant.
    ##
    ## @end deftypefn
    function this = arc (this, C, R, A1, A2)

      if (nargin != 5)
        error ("draw.Drawing.arc: invalid number of input arguments.");
      endif
      errmsg = checkpt (C);
      if (! isempty (errmsg))
        error ("draw.Drawing.arc: C %s", errmsg);
      endif
      errmsg = checkradius (R);
      if (! isempty (errmsg))
        error ("draw.Drawing.arc: R %s", errmsg);
      endif
      if (! isnumeric (A1) || ! isreal (A1) || ! isscalar (A1) ...
          || ! isfinite (A1) || ! isnumeric (A2) || ! isreal (A2) ...
          || ! isscalar (A2) || ! isfinite (A2))
        error (strcat ("draw.Drawing.arc: A1 and A2 must be real finite", ...
                       " scalar angles in degrees."));
      endif

      e = makeentity ('arc', this.Layer, this.Linetype, this.Colour);
      e.pts = double (C);
      e.radius = double (R);
      e.angles = double ([A1, A2]);
      this.Entities(end+1) = e;

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {draw.Drawing} {@var{D} =} circle (@var{D}, @var{C}, @var{R})
    ##
    ## Append a full circle centred on @var{C} with radius @var{R} millimetres.
    ##
    ## @end deftypefn
    function this = circle (this, C, R)

      if (nargin != 3)
        error ("draw.Drawing.circle: invalid number of input arguments.");
      endif
      errmsg = checkpt (C);
      if (! isempty (errmsg))
        error ("draw.Drawing.circle: C %s", errmsg);
      endif
      errmsg = checkradius (R);
      if (! isempty (errmsg))
        error ("draw.Drawing.circle: R %s", errmsg);
      endif

      e = makeentity ('circle', this.Layer, this.Linetype, this.Colour);
      e.pts = double (C);
      e.radius = double (R);
      this.Entities(end+1) = e;

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {draw.Drawing} {@var{D} =} text (@var{D}, @var{P}, @var{S})
    ## @deftypefnx {draw.Drawing} {@var{D} =} text (@var{D}, @var{P}, @var{S}, @var{H})
    ## @deftypefnx {draw.Drawing} {@var{D} =} text (@var{D}, @var{P}, @var{S}, @var{H}, @var{ROT})
    ##
    ## Append the single-line text @var{S} with its insertion point at @var{P}.
    ##
    ## @var{H} is the cap height in millimetres and defaults to @math{2.5}, the
    ## smallest of the ISO 3098 sizes and the usual height for notes on a
    ## drawing at @math{1:50}.  @var{ROT} rotates the text about its insertion
    ## point, in degrees counter-clockwise, and defaults to zero.
    ##
    ## The text is stored as given.  No backend measures it, so a drawing knows
    ## where its text starts but not how wide it ends up.
    ##
    ## @end deftypefn
    function this = text (this, P, S, H = 2.5, ROT = 0)

      if (nargin < 3 || nargin > 5)
        error ("draw.Drawing.text: invalid number of input arguments.");
      endif
      errmsg = checkpt (P);
      if (! isempty (errmsg))
        error ("draw.Drawing.text: P %s", errmsg);
      endif
      if (! ischar (S) || ! isrow (S) || isempty (S))
        error (strcat ("draw.Drawing.text: S must be a non-empty character", ...
                       " vector."));
      endif
      if (! isnumeric (H) || ! isreal (H) || ! isscalar (H) ...
          || ! isfinite (H) || H <= 0)
        error ("draw.Drawing.text: H must be a real positive finite scalar.");
      endif
      if (! isnumeric (ROT) || ! isreal (ROT) || ! isscalar (ROT) ...
          || ! isfinite (ROT))
        error ("draw.Drawing.text: ROT must be a real finite scalar.");
      endif

      e = makeentity ('text', this.Layer, this.Linetype, this.Colour);
      e.pts = double (P);
      e.text = S;
      e.height = double (H);
      e.angle = double (ROT);
      this.Entities(end+1) = e;

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {draw.Drawing} {@var{D} =} hatch (@var{D}, @var{P})
    ## @deftypefnx {draw.Drawing} {@var{D} =} hatch (@var{D}, @var{P}, @var{PATTERN})
    ## @deftypefnx {draw.Drawing} {@var{D} =} hatch (@var{D}, @var{P}, @var{PATTERN}, @var{ANGLE}, @var{SPACING})
    ##
    ## Append a hatched region bounded by the closed polygon @var{P}.
    ##
    ## @var{P} is an @math{N}-by-2 matrix of at least three vertices,
    ## implicitly closed.  @var{PATTERN} names the fill and defaults to
    ## @qcode{'ANSI31'}, the 45-degree hatch that means cut material.
    ## @var{ANGLE} rotates the pattern, in degrees, and @var{SPACING} sets the
    ## line spacing in millimetres.
    ##
    ## Not every backend can render a hatch.  DXF R12 has no @code{HATCH}
    ## entity at all, so a drawing may legitimately carry hatches that the DXF
    ## output cannot express; see @code{dxf.write}.  The model records the
    ## intent regardless, which is what lets the backend decide what to do
    ## about it.
    ##
    ## @end deftypefn
    function this = hatch (this, P, PATTERN = 'ANSI31', ANGLE = 0, ...
                           SPACING = 2.5)

      if (nargin < 2 || nargin > 5)
        error ("draw.Drawing.hatch: invalid number of input arguments.");
      endif
      if (nargin == 4)
        error (strcat ("draw.Drawing.hatch: ANGLE and SPACING must be", ...
                       " given together."));
      endif
      errmsg = checkpts (P);
      if (! isempty (errmsg))
        error ("draw.Drawing.hatch: P %s", errmsg);
      endif
      if (rows (P) < 3)
        error (strcat ("draw.Drawing.hatch: P must contain at least 3", ...
                       " vertices."));
      endif
      if (! ischar (PATTERN) || ! isrow (PATTERN) || isempty (PATTERN))
        error (strcat ("draw.Drawing.hatch: PATTERN must be a non-empty", ...
                       " character vector."));
      endif
      if (! isnumeric (ANGLE) || ! isreal (ANGLE) || ! isscalar (ANGLE) ...
          || ! isfinite (ANGLE))
        error ("draw.Drawing.hatch: ANGLE must be a real finite scalar.");
      endif
      if (! isnumeric (SPACING) || ! isreal (SPACING) ...
          || ! isscalar (SPACING) || ! isfinite (SPACING) || SPACING <= 0)
        error (strcat ("draw.Drawing.hatch: SPACING must be a real", ...
                       " positive finite scalar."));
      endif

      e = makeentity ('hatch', this.Layer, this.Linetype, this.Colour);
      e.pts = double (P);
      e.closed = true;
      e.pattern = PATTERN;
      e.angle = double (ANGLE);
      e.spacing = double (SPACING);
      this.Entities(end+1) = e;

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {draw.Drawing} {@var{D} =} dim (@var{D}, @var{P1}, @var{P2}, @var{OFFSET})
    ## @deftypefnx {draw.Drawing} {@var{D} =} dim (@var{D}, @var{P1}, @var{P2}, @var{OFFSET}, @var{DIRECTION})
    ## @deftypefnx {draw.Drawing} {@var{D} =} dim (@var{D}, @var{P1}, @var{P2}, @var{OFFSET}, @var{DIRECTION}, @var{LABEL})
    ##
    ## Append a dimension measuring between @var{P1} and @var{P2}.
    ##
    ## @var{OFFSET} is the perpendicular distance in millimetres from the
    ## measured points to the dimension line.  Its sign selects which side the
    ## dimension line falls on: positive offsets lie to the left of the
    ## direction of travel from @var{P1} to @var{P2}.
    ##
    ## @var{DIRECTION} selects what is being measured and defaults to
    ## @qcode{'aligned'}:
    ##
    ## @itemize
    ## @item @qcode{'aligned'} --- the distance between the two points.
    ## @item @qcode{'horizontal'} --- the difference in @math{x} alone.
    ## @item @qcode{'vertical'} --- the difference in @math{y} alone.
    ## @end itemize
    ##
    ## A horizontal dimension between two points at the same @math{x}, or a
    ## vertical one between two points at the same @math{y}, measures nothing
    ## and is an error.
    ##
    ## @var{LABEL} overrides the measured value with a literal string, for the
    ## cases every drawing eventually has --- a nominal size, a range, a note
    ## in place of a number.  Without it the backend formats the measurement it
    ## computes.  A dimension therefore carries no text of its own by default,
    ## which is precisely what keeps it truthful when the geometry changes.
    ##
    ## @end deftypefn
    function this = dim (this, P1, P2, OFFSET, DIRECTION = 'aligned', ...
                         LABEL = '')

      if (nargin < 4 || nargin > 6)
        error ("draw.Drawing.dim: invalid number of input arguments.");
      endif
      errmsg = checkpt (P1);
      if (! isempty (errmsg))
        error ("draw.Drawing.dim: P1 %s", errmsg);
      endif
      errmsg = checkpt (P2);
      if (! isempty (errmsg))
        error ("draw.Drawing.dim: P2 %s", errmsg);
      endif
      if (isequal (P1, P2))
        error ("draw.Drawing.dim: P1 and P2 must not be the same point.");
      endif
      if (! isnumeric (OFFSET) || ! isreal (OFFSET) || ! isscalar (OFFSET) ...
          || ! isfinite (OFFSET))
        error ("draw.Drawing.dim: OFFSET must be a real finite scalar.");
      endif
      if (! ischar (DIRECTION) || ! isrow (DIRECTION) ...
          || ! any (strcmpi (DIRECTION, {'aligned', 'horizontal', 'vertical'})))
        error (strcat ("draw.Drawing.dim: DIRECTION must be 'aligned',", ...
                       " 'horizontal' or 'vertical'."));
      endif
      if (! ischar (LABEL) || ! (isrow (LABEL) || isempty (LABEL)))
        error ("draw.Drawing.dim: LABEL must be a character vector.");
      endif

      DIRECTION = lower (DIRECTION);
      if (strcmp (DIRECTION, 'horizontal') && P1(1) == P2(1))
        error (strcat ("draw.Drawing.dim: a horizontal dimension needs two", ...
                       " points differing in x."));
      endif
      if (strcmp (DIRECTION, 'vertical') && P1(2) == P2(2))
        error (strcat ("draw.Drawing.dim: a vertical dimension needs two", ...
                       " points differing in y."));
      endif

      e = makeentity ('dim', this.Layer, this.Linetype, this.Colour);
      e.pts = [P1; P2];
      e.offset = double (OFFSET);
      e.direction = DIRECTION;
      e.text = LABEL;
      this.Entities(end+1) = e;

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {draw.Drawing} {@var{N} =} numentities (@var{D})
    ##
    ## Return the number of entities in the drawing.
    ##
    ## @end deftypefn
    function N = numentities (this)

      N = numel (this.Entities);

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {draw.Drawing} {@var{TF} =} isempty (@var{D})
    ##
    ## Return true when the drawing holds no entities.
    ##
    ## The current layer and the name have no bearing on this: a drawing is
    ## empty when there is nothing to render.
    ##
    ## @end deftypefn
    function TF = isempty (this)

      TF = isempty (this.Entities);

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {draw.Drawing} {@var{L} =} layers (@var{D})
    ##
    ## Return the layers the drawing actually uses, as a sorted cellstr.
    ##
    ## The current layer appears only if something was drawn on it, so this
    ## reports the layers a backend has to declare, not the layers that were
    ## selected along the way.
    ##
    ## @end deftypefn
    function L = layers (this)

      if (isempty (this.Entities))
        L = {};
        return;
      endif
      L = unique ({this.Entities.layer});

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {draw.Drawing} {@var{B} =} bbox (@var{D})
    ## @deftypefnx {draw.Drawing} {[@var{B}, @var{W}, @var{H}] =} bbox (@var{D})
    ##
    ## Axis-aligned extents of the drawing, as
    ## @code{[@var{xmin}, @var{ymin}, @var{xmax}, @var{ymax}]} in millimetres.
    ##
    ## @code{[@var{B}, @var{W}, @var{H}] = bbox (@var{D})} additionally returns
    ## the width and height, matching @code{geom.bbox}.
    ##
    ## Curved entities contribute their true extent rather than their control
    ## points: a circle contributes its centre displaced by the radius in each
    ## of the four cardinal directions, and an arc contributes its two
    ## endpoints together with whichever of those four points its sweep
    ## actually passes through.  Taking the centre alone would understate a
    ## circle by a radius on every side.
    ##
    ## Two things are deliberately not accounted for, because the model does
    ## not know them: the rendered width and height of a text entity, of which
    ## only the insertion point is counted, and the dimension lines and text a
    ## backend will place at a dimension's offset, of which only the two
    ## measured points are counted.  A frame drawn to this box therefore needs
    ## a margin, which any drawing wants regardless.
    ##
    ## An empty drawing has no extent, and returns an empty @var{B}.
    ##
    ## @end deftypefn
    function [B, W, H] = bbox (this)

      if (isempty (this.Entities))
        B = [];
        W = [];
        H = [];
        return;
      endif

      P = [];
      for ii = 1:numel (this.Entities)
        P = [P; extentpoints(this.Entities(ii))];
      endfor

      [B, W, H] = geom.bbox (P);

    endfunction


    ## -*- texinfo -*-
    ## @deftypefn  {draw.Drawing} {@var{D} =} transform (@var{D}, @var{T})
    ## @deftypefnx {draw.Drawing} {@var{D} =} transform (@var{D}, @var{OP}, @var{VAL})
    ## @deftypefnx {draw.Drawing} {@var{D} =} transform (@var{D}, @var{OP}, @var{VAL}, @var{CENTRE})
    ##
    ## Apply a planar transformation to every entity of the drawing.
    ##
    ## The arguments after the drawing are those of @code{geom.transform}, and
    ## mean the same: a 3-by-3 homogeneous matrix, or a named operation
    ## (@qcode{'translate'}, @qcode{'rotate'}, @qcode{'scale'},
    ## @qcode{'mirror'}) with its value and an optional centre.
    ##
    ## This is what lets a part be drawn once and placed more than once, a view
    ## be mirrored, or a detail be built at the origin and moved onto a sheet.
    ##
    ## @subheading Entities are transformed, not just their points
    ##
    ## A circle keeps its centre and scales its radius; an arc rotates its
    ## angles; text moves, rotates and scales its height; a hatch rotates its
    ## pattern and scales its spacing.  A dimension carries its measured points
    ## and scales its offset.
    ##
    ## @strong{A reflection reverses the sweep of an arc.}  Arcs run
    ## counter-clockwise from the first angle to the second, so mirroring one
    ## and keeping the order would silently give the complementary arc --- the
    ## piece that was not there before.  The endpoints are exchanged instead.
    ##
    ## @subheading What is refused, and why
    ##
    ## @strong{A non-uniform scaling that would turn a circle into an ellipse}
    ## raises.  There is no ellipse entity to put the result in, and quietly
    ## scaling the radius by one of the two factors would move the geometry off
    ## the part.  A drawing with no arcs or circles scales anisotropically
    ## without complaint.
    ##
    ## @strong{A rotation that would leave an axis-locked dimension off its
    ## axis} raises, naming the entity.  A @qcode{'horizontal'} dimension
    ## measures the horizontal distance between two points; after a rotation of
    ## thirty degrees it would still measure a horizontal distance, but not the
    ## one the drawing was dimensioned for, and the number on the sheet would
    ## change without anyone asking it to.  Rotations by a multiple of a quarter
    ## turn are fine and exchange horizontal with vertical; so are mirrors about
    ## either axis.  A dimension made @qcode{'aligned'} rotates freely.
    ##
    ## @seealso{geom.transform, merge, bbox}
    ## @end deftypefn
    function this = transform (this, varargin)

      if (nargin < 2)
        error ("draw.Drawing.transform: invalid number of input arguments.");
      endif

      ## Recover the linear part by transforming the origin and the two unit
      ## vectors, rather than rebuilding the matrix geom.transform already
      ## knows how to make
      B = geom.transform ([0, 0; 1, 0; 0, 1], varargin{:});
      t = B(1,:);
      M = [(B(2,:) - t)', (B(3,:) - t)'];

      sx = norm (M(:,1));
      sy = norm (M(:,2));
      uniform = (abs (sx - sy) <= 1e-12 * max (sx, sy)) ...
                && abs (M(:,1)' * M(:,2)) <= 1e-12 * sx * sy;
      reflected = (det (M) < 0);
      onaxes = (all (abs (M([2, 3])) <= 1e-12 * max (sx, sy)) ...
                || all (abs (M([1, 4])) <= 1e-12 * max (sx, sy)));

      for ii = 1:numel (this.Entities)
        e = this.Entities(ii);

        if (! isempty (e.pts))
          e.pts = geom.transform (e.pts, varargin{:});
        endif

        switch (e.type)
          case {'circle', 'arc'}
            if (! uniform)
              error (strcat ("draw.Drawing.transform: entity %d is a %s", ...
                             " and the scaling is not uniform; the result", ...
                             " would be an ellipse."), ii, e.type);
            endif
            e.radius *= sx;
            if (strcmp (e.type, 'arc'))
              a = [dirangle(M, e.angles(1)), dirangle(M, e.angles(2))];
              if (reflected)
                a = a([2, 1]);
              endif
              e.angles = a;
            endif

          case 'text'
            if (! uniform)
              error (strcat ("draw.Drawing.transform: entity %d is text", ...
                             " and the scaling is not uniform."), ii);
            endif
            e.height *= sx;
            e.angle = dirangle (M, e.angle);

          case 'hatch'
            e.angle = dirangle (M, e.angle);
            e.spacing *= sx;

          case 'dim'
            if (! any (strcmp (e.direction, {'aligned'})) && ! onaxes)
              error (strcat ("draw.Drawing.transform: entity %d is a '%s'", ...
                             " dimension and the transformation would", ...
                             " leave it off its axis; make it 'aligned'", ...
                             " first."), ii, e.direction);
            endif
            if (onaxes && ! isempty (e.direction) ...
                && ! strcmp (e.direction, 'aligned'))
              e.direction = axisafter (M, e.direction);
            endif
            e.offset *= sx;
        endswitch

        this.Entities(ii) = e;
      endfor

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {draw.Drawing} {@var{D} =} merge (@var{D}, @var{D2}, @dots{})
    ##
    ## Append the entities of one or more drawings to this one.
    ##
    ## @code{@var{D} = merge (@var{D1}, @var{D2})} returns a drawing holding
    ## every entity of @var{D1} followed by every entity of @var{D2}, each
    ## keeping the layer, line type and colour it was drawn with.  Any number of
    ## drawings may be given.
    ##
    ## The result takes its name and its current layer, line type and colour
    ## from the first drawing.  Those are the state a caller would carry on
    ## drawing with, and the first drawing is the one being added to.
    ##
    ## Merging is what turns separately-built parts into an assembly, or
    ## separately-built views into a sheet.  With @code{transform} it is the
    ## whole of composition: build once, place as often as needed.
    ##
    ## @seealso{transform, numentities, layers}
    ## @end deftypefn
    function this = merge (this, varargin)

      for k = 1:numel (varargin)
        other = varargin{k};
        if (! isa (other, 'draw.Drawing'))
          error (strcat ("draw.Drawing.merge: argument %d is not a", ...
                         " draw.Drawing object."), k);
        endif
        for ii = 1:numel (other.Entities)
          this.Entities(end+1) = other.Entities(ii);
        endfor
      endfor

    endfunction


    ## -*- texinfo -*-
    ## @deftypefn {draw.Drawing} {@var{D} =} block (@var{D}, @var{NAME}, @var{B})
    ##
    ## Define a named block from another drawing.
    ##
    ## A block is a drawing kept once and placed as often as wanted by
    ## @code{insert}.  Nothing of it appears until it is inserted; defining one
    ## adds no entity.
    ##
    ## Redefining a name replaces the definition, and every insert of it takes
    ## the new geometry --- which is the point of a block, and the reason a
    ## drawing that repeats a feature two dozen times should use one.
    ##
    ## @seealso{insert, merge, transform}
    ## @end deftypefn
    function this = block (this, NAME, B)

      if (nargin != 3)
        error ("draw.Drawing.block: invalid number of input arguments.");
      endif
      if (! ischar (NAME) || ! isrow (NAME) || isempty (NAME))
        error (strcat ("draw.Drawing.block: NAME must be a non-empty", ...
                       " character vector."));
      endif
      if (! isa (B, 'draw.Drawing'))
        error ("draw.Drawing.block: B must be a draw.Drawing object.");
      endif

      k = find (strcmpi (NAME, {this.Blocks.name}), 1);
      if (isempty (k))
        k = numel (this.Blocks) + 1;
      endif
      this.Blocks(k).name = NAME;
      this.Blocks(k).drawing = B;

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {draw.Drawing} {@var{D} =} insert (@var{D}, @var{NAME}, @var{POS})
    ## @deftypefnx {draw.Drawing} {@var{D} =} insert (@dots{}, @var{ROT}, @var{SCALE})
    ##
    ## Place a defined block at a point.
    ##
    ## @code{@var{D} = insert (@var{D}, @var{NAME}, @var{POS})} places the block
    ## @var{NAME} with its origin at @var{POS}.  @var{ROT} rotates it, in
    ## degrees counter-clockwise, and @var{SCALE} scales it; both default to
    ## leaving it alone.
    ##
    ## An insert is a @emph{reference}, not a copy.  Twenty-five identical bores
    ## are one definition and twenty-five references, which is what a
    ## draughtsman expects to receive and a fraction of the file that
    ## twenty-five copies would make.
    ##
    ## The block must already be defined; inserting a name that is not raises,
    ## rather than leaving a reference that resolves to nothing when the file is
    ## opened.
    ##
    ## @seealso{block, merge, transform}
    ## @end deftypefn
    function this = insert (this, NAME, POS, ROT = 0, SCALE = 1)

      if (nargin < 3 || nargin > 5)
        error ("draw.Drawing.insert: invalid number of input arguments.");
      endif
      if (! ischar (NAME) || ! isrow (NAME) || isempty (NAME))
        error (strcat ("draw.Drawing.insert: NAME must be a non-empty", ...
                       " character vector."));
      endif
      if (isempty (this.Blocks) || ! any (strcmpi (NAME, {this.Blocks.name})))
        error (strcat ("draw.Drawing.insert: no block named '%s' is", ...
                       " defined; define it with block first."), NAME);
      endif
      errmsg = checkpt (POS);
      if (! isempty (errmsg))
        error ("draw.Drawing.insert: POS %s", errmsg);
      endif
      if (! isnumeric (ROT) || ! isreal (ROT) || ! isscalar (ROT) ...
          || ! isfinite (ROT))
        error ("draw.Drawing.insert: ROT must be a real finite scalar.");
      endif
      if (! isnumeric (SCALE) || ! isreal (SCALE) || ! isscalar (SCALE) ...
          || ! isfinite (SCALE) || SCALE <= 0)
        error (strcat ("draw.Drawing.insert: SCALE must be a positive real", ...
                       " finite scalar."));
      endif

      e = makeentity ('insert', this.Layer, this.Linetype, this.Colour);
      e.pts = POS(:)';
      e.block = NAME;
      e.angle = ROT;
      e.scale = SCALE;
      this.Entities(end+1) = e;

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {draw.Drawing} {@var{D} =} expand (@var{D})
    ##
    ## Replace every insert with the geometry it refers to.
    ##
    ## The result holds no blocks and no inserts, only the entities they stood
    ## for, each transformed to where its reference put it.  This is what a
    ## backend with no block of its own needs, and what @code{draw.plot} and
    ## @code{draw.tikz} do before rendering.
    ##
    ## Blocks may contain inserts of other blocks and are expanded through.  A
    ## block keeps its own definitions and inherits the enclosing drawing's only
    ## for names it does not define itself.
    ##
    ## A block cannot come to refer to itself: its drawing is captured by value
    ## when the block is defined, so redefining a name later cannot reach back
    ## into a definition already taken.  The hundred-level limit is therefore a
    ## backstop against a construction this class does not permit, not a rule a
    ## caller can meet by accident.
    ##
    ## @seealso{block, insert, draw.entities}
    ## @end deftypefn
    function this = expand (this, depth = 0)

      if (depth > 100)
        error (strcat ("draw.Drawing.expand: blocks are nested more than a", ...
                       " hundred deep, or one of them refers to itself."));
      endif
      if (isempty (this.Entities))
        return;
      endif

      out = this;
      out.Entities(:) = [];
      for ii = 1:numel (this.Entities)
        e = this.Entities(ii);
        if (! strcmp (e.type, 'insert'))
          out.Entities(end+1) = e;
          continue;
        endif
        k = find (strcmpi (e.block, {this.Blocks.name}), 1);
        if (isempty (k))
          error (strcat ("draw.Drawing.expand: entity %d inserts block", ...
                         " '%s', which is not defined."), ii, e.block);
        endif
        ## A block keeps its own definitions and inherits the enclosing
        ## drawing's only for names it does not define itself
        sub = this.Blocks(k).drawing;
        for bb = 1:numel (this.Blocks)
          if (isempty (sub.Blocks) ...
              || ! any (strcmpi (this.Blocks(bb).name, {sub.Blocks.name})))
            sub.Blocks(end+1) = this.Blocks(bb);
          endif
        endfor
        sub = expand (sub, depth + 1);
        if (e.scale != 1)
          sub = sub.transform ('scale', e.scale);
        endif
        if (e.angle != 0)
          sub = sub.transform ('rotate', e.angle);
        endif
        sub = sub.transform ('translate', e.pts);
        for jj = 1:numel (sub.Entities)
          out.Entities(end+1) = sub.Entities(jj);
        endfor
      endfor
      this = out;

    endfunction


    ## -*- texinfo -*-
    ## @deftypefn  {draw.Drawing} {@var{D} =} ellipse (@var{D}, @var{C}, @var{A}, @var{B})
    ## @deftypefnx {draw.Drawing} {@var{D} =} ellipse (@var{D}, @var{C}, @var{A}, @var{B}, @var{ROT})
    ##
    ## Append an ellipse centred at @var{C} with semi-axes @var{A} and @var{B}.
    ##
    ## @var{ROT} turns the first axis away from horizontal, in degrees
    ## counter-clockwise, and defaults to zero.
    ##
    ## An ellipse is what a circle becomes when a round feature is seen
    ## obliquely, which is most of the time on an isometric or an auxiliary
    ## view, and what a chamfer on a cylinder projects to.
    ##
    ## @strong{The DXF revision this package writes has no ellipse entity}, so
    ## one reaches a file as a closed polyline sampled to a chordal tolerance,
    ## and @code{draw.entities} records the substitution.  The shape is right to
    ## within that tolerance; what is lost is the ability to edit it as an
    ## ellipse afterwards.
    ##
    ## @seealso{circle, arc, polyline}
    ## @end deftypefn
    function this = ellipse (this, C, A, B, ROT = 0)

      if (nargin < 4 || nargin > 5)
        error ("draw.Drawing.ellipse: invalid number of input arguments.");
      endif
      errmsg = checkpt (C);
      if (! isempty (errmsg))
        error ("draw.Drawing.ellipse: C %s", errmsg);
      endif
      errmsg = checkradius (A);
      if (! isempty (errmsg))
        error ("draw.Drawing.ellipse: A %s", errmsg);
      endif
      errmsg = checkradius (B);
      if (! isempty (errmsg))
        error ("draw.Drawing.ellipse: B %s", errmsg);
      endif
      if (! isnumeric (ROT) || ! isreal (ROT) || ! isscalar (ROT) ...
          || ! isfinite (ROT))
        error ("draw.Drawing.ellipse: ROT must be a real finite scalar.");
      endif

      e = makeentity ('ellipse', this.Layer, this.Linetype, this.Colour);
      e.pts = C(:)';
      e.radius = [A, B];
      e.angle = ROT;
      this.Entities(end+1) = e;

    endfunction


    ## -*- texinfo -*-
    ## @deftypefn  {draw.Drawing} {@var{D} =} diam (@var{D}, @var{C}, @var{R})
    ## @deftypefnx {draw.Drawing} {@var{D} =} diam (@dots{}, @var{ANG}, @var{LABEL})
    ##
    ## Append a diameter dimension across a circle.
    ##
    ## @var{C} is the centre and @var{R} the radius.  @var{ANG} sets the
    ## direction the dimension line lies along, in degrees, and defaults to 45,
    ## which keeps it clear of the centre lines.  @var{LABEL} overrides the
    ## text, which is otherwise the diameter symbol and the measured figure.
    ##
    ## A round feature is dimensioned by its diameter and never by its radius,
    ## because a diameter is what a bore gauge and a micrometer measure.  A
    ## radius is used only where the full circle is not there to measure ---
    ## which is what @code{radius} is for.
    ##
    ## @seealso{radius, angdim, centremark, draw.symbol}
    ## @end deftypefn
    function this = diam (this, C, R, ANG = 45, LABEL = '')

      if (nargin < 3 || nargin > 5)
        error ("draw.Drawing.diam: invalid number of input arguments.");
      endif
      e = dimcircle (this, 'diam', C, R, ANG, LABEL);
      if (isempty (e.text))
        ## Three decimals is a micron in millimetres, finer than anything this
        ## package's own output is accurate to and past any drawing's need
        e.text = sprintf ('%%%%c%g', round (2 * R * 1000) / 1000);
      endif
      this.Entities(end+1) = e;

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {draw.Drawing} {@var{D} =} radius (@var{D}, @var{C}, @var{R})
    ## @deftypefnx {draw.Drawing} {@var{D} =} radius (@dots{}, @var{ANG}, @var{LABEL})
    ##
    ## Append a radius dimension from a centre out to an arc.
    ##
    ## The arguments are those of @code{diam}, and @var{ANG} is the direction
    ## the leader runs in.  The label is otherwise the letter R and the figure.
    ##
    ## Use it for a fillet or any arc that is less than a full circle, where
    ## there is no diameter to measure across.
    ##
    ## @seealso{diam, angdim, centremark}
    ## @end deftypefn
    function this = radius (this, C, R, ANG = 45, LABEL = '')

      if (nargin < 3 || nargin > 5)
        error ("draw.Drawing.radius: invalid number of input arguments.");
      endif
      e = dimcircle (this, 'radius', C, R, ANG, LABEL);
      if (isempty (e.text))
        e.text = sprintf ('R%g', round (R * 1000) / 1000);
      endif
      this.Entities(end+1) = e;

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {draw.Drawing} {@var{D} =} angdim (@var{D}, @var{V}, @var{P1}, @var{P2}, @var{RAD})
    ## @deftypefnx {draw.Drawing} {@var{D} =} angdim (@dots{}, @var{LABEL})
    ##
    ## Append an angular dimension at a vertex.
    ##
    ## @var{V} is the vertex, @var{P1} and @var{P2} points along the two arms,
    ## and @var{RAD} the radius at which the dimension arc is struck.  The label
    ## is otherwise the measured angle and the degree symbol.
    ##
    ## The angle measured is the one from the first arm to the second going
    ## counter-clockwise, so giving the arms the other way round dimensions the
    ## explement instead.  That is the choice being offered, not an ambiguity:
    ## a corner and its outside both get dimensioned on real drawings.
    ##
    ## @seealso{diam, radius, draw.symbol}
    ## @end deftypefn
    function this = angdim (this, V, P1, P2, RAD, LABEL = '')

      if (nargin < 5 || nargin > 6)
        error ("draw.Drawing.angdim: invalid number of input arguments.");
      endif
      for pr = {{V, 'V'}, {P1, 'P1'}, {P2, 'P2'}}
        errmsg = checkpt (pr{1}{1});
        if (! isempty (errmsg))
          error ("draw.Drawing.angdim: %s %s", pr{1}{2}, errmsg);
        endif
      endfor
      errmsg = checkradius (RAD);
      if (! isempty (errmsg))
        error ("draw.Drawing.angdim: RAD %s", errmsg);
      endif
      if (! ischar (LABEL) || ! (isrow (LABEL) || isempty (LABEL)))
        error ("draw.Drawing.angdim: LABEL must be a character vector.");
      endif
      if (isequal (P1(:)', V(:)') || isequal (P2(:)', V(:)'))
        error (strcat ("draw.Drawing.angdim: an arm point must differ from", ...
                       " the vertex."));
      endif

      e = makeentity ('angdim', this.Layer, this.Linetype, this.Colour);
      e.pts = [V(:)'; P1(:)'; P2(:)'];
      e.radius = RAD;
      e.text = LABEL;
      if (isempty (e.text))
        a1 = atan2 (P1(2) - V(2), P1(1) - V(1));
        a2 = atan2 (P2(2) - V(2), P2(1) - V(1));
        ## Two decimals: a drawing states an angle to a hundredth at most, and
        ## the six significant figures %g would give are measurement noise
        ## rather than a specification
        e.text = sprintf ('%g%%%%d', ...
                          round (mod ((a2 - a1) * 180 / pi, 360) * 100) / 100);
      endif
      this.Entities(end+1) = e;

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {draw.Drawing} {@var{D} =} centremark (@var{D}, @var{C}, @var{R})
    ## @deftypefnx {draw.Drawing} {@var{D} =} centremark (@var{D})
    ##
    ## Append the small cross that marks the centre of a round feature.
    ##
    ## @code{centremark (@var{D}, @var{C}, @var{R})} marks one centre, sized to
    ## a feature of radius @var{R}.
    ##
    ## @code{centremark (@var{D})} with no centre marks @strong{every} circle
    ## and arc already in the drawing.  A drawing of a bolt circle or a bore
    ## pattern carries dozens, and marking them one at a time is how one gets
    ## missed --- which a checker will notice and a machinist will not.
    ##
    ## The marks take the current layer, line type and colour, so the usual
    ## order is to set @qcode{'CENTER'} and the centre-line layer first and then
    ## call this once.
    ##
    ## @seealso{diam, radius, draw.linetype}
    ## @end deftypefn
    function this = centremark (this, C, R)

      if (nargin == 1)
        marks = [];
        for ii = 1:numel (this.Entities)
          e = this.Entities(ii);
          if (any (strcmp (e.type, {'circle', 'arc'})))
            marks = [marks; e.pts, e.radius(1)];
          endif
        endfor
        for k = 1:rows (marks)
          this = centremark (this, marks(k,1:2), marks(k,3));
        endfor
        return;
      endif

      if (nargin != 3)
        error ("draw.Drawing.centremark: invalid number of input arguments.");
      endif
      errmsg = checkpt (C);
      if (! isempty (errmsg))
        error ("draw.Drawing.centremark: C %s", errmsg);
      endif
      errmsg = checkradius (R);
      if (! isempty (errmsg))
        error ("draw.Drawing.centremark: R %s", errmsg);
      endif

      e = makeentity ('centremark', this.Layer, this.Linetype, this.Colour);
      e.pts = C(:)';
      e.radius = R;
      this.Entities(end+1) = e;

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {draw.Drawing} {@var{D} =} leader (@var{D}, @var{P}, @var{TEXT})
    ##
    ## Append a leader: an arrow to a feature with a note at its tail.
    ##
    ## @var{P} is the path, one point per row, starting at the feature being
    ## pointed at and ending where the note sits.  Two points make the usual
    ## straight leader; three make one with a horizontal landing, which is what
    ## a note of more than a word or two wants.
    ##
    ## The note is placed at the last point.  It may carry the codes of
    ## @code{draw.symbol}, so a thread callout or a tolerance reads properly.
    ##
    ## @seealso{diam, radius, draw.symbol}
    ## @end deftypefn
    function this = leader (this, P, TEXT)

      if (nargin != 3)
        error ("draw.Drawing.leader: invalid number of input arguments.");
      endif
      errmsg = checkpts (P);
      if (! isempty (errmsg))
        error ("draw.Drawing.leader: P %s", errmsg);
      endif
      if (rows (P) < 2)
        error ("draw.Drawing.leader: P must hold at least two points.");
      endif
      if (! ischar (TEXT) || ! (isrow (TEXT) || isempty (TEXT)))
        error ("draw.Drawing.leader: TEXT must be a character vector.");
      endif

      e = makeentity ('leader', this.Layer, this.Linetype, this.Colour);
      e.pts = P;
      e.text = TEXT;
      this.Entities(end+1) = e;

    endfunction

  endmethods

  methods (Hidden)

    function disp (this)

      printf ("  draw.Drawing '%s' with %d entities on %d layers\n", ...
              this.Name, numel (this.Entities), numel (layers (this)));
      if (! isempty (this.Entities))
        types = {this.Entities.type};
        known = {'line', 'polyline', 'arc', 'circle', 'text', 'hatch', 'dim'};
        for ii = 1:numel (known)
          n = sum (strcmp (types, known{ii}));
          if (n > 0)
            printf ("    %-9s %d\n", known{ii}, n);
          endif
        endfor
      endif
      printf ("    current layer: '%s'\n", this.Layer);

    endfunction

    function display (this)

      name = inputname (1);
      if (isempty (name))
        name = 'ans';
      endif
      printf ("%s =\n\n", name);
      disp (this);
      printf ("\n");

    endfunction

  endmethods

endclassdef

## Build an entity record with every field present and the type-specific ones
## empty.  Every append method starts here, which is what keeps the field set
## and its order identical across the whole array -- a struct array will not
## grow otherwise, and a backend would have to test for each field.
function e = makeentity (type, layer, linetype, colour)

  e = struct ('type', type, 'layer', layer, 'linetype', linetype, ...
              'colour', colour, 'pts', [], 'closed', false, ...
              'radius', [], 'angles', [], 'angle', [], 'text', '', ...
              'height', [], 'offset', [], 'direction', '', 'pattern', '', ...
              'spacing', [], 'block', '', 'scale', [], 'bulge', []);

endfunction

## Shared validation for the two circular dimensions
function e = dimcircle (this, kind, C, R, ANG, LABEL)

  errmsg = checkpt (C);
  if (! isempty (errmsg))
    error ("draw.Drawing.%s: C %s", kind, errmsg);
  endif
  errmsg = checkradius (R);
  if (! isempty (errmsg))
    error ("draw.Drawing.%s: R %s", kind, errmsg);
  endif
  if (! isnumeric (ANG) || ! isreal (ANG) || ! isscalar (ANG) ...
      || ! isfinite (ANG))
    error ("draw.Drawing.%s: ANG must be a real finite scalar.", kind);
  endif
  if (! ischar (LABEL) || ! (isrow (LABEL) || isempty (LABEL)))
    error ("draw.Drawing.%s: LABEL must be a character vector.", kind);
  endif

  e = makeentity (kind, this.Layer, this.Linetype, this.Colour);
  e.pts = C(:)';
  e.radius = R;
  e.angle = ANG;
  e.text = LABEL;

endfunction

## The angle a direction takes after the linear part M is applied, in degrees
function b = dirangle (M, adeg)

  v = M * [cosd(adeg); sind(adeg)];
  b = mod (atan2 (v(2), v(1)) * 180 / pi, 360);

endfunction

## Which axis a horizontal or vertical dimension measures along once M has been
## applied.  Only called when M maps the axes onto axes.
function d = axisafter (M, d)

  swapped = (abs (M(1,1)) <= abs (M(1,2)));
  if (swapped)
    if (strcmp (d, 'horizontal'))
      d = 'vertical';
    else
      d = 'horizontal';
    endif
  endif

endfunction

## Validate a single point, returning an error-message body for the caller to
## raise under its own name.
function errmsg = checkpt (P)

  errmsg = '';
  if (! isnumeric (P) || ! isreal (P) || ! isequal (size (P), [1, 2]) ...
      || ! all (isfinite (P)))
    errmsg = "must be a real finite 1-by-2 vector.";
  endif

endfunction

## Validate an N-by-2 point set, as above.
function errmsg = checkpts (P)

  errmsg = '';
  if (! isnumeric (P) || ! isreal (P) || ndims (P) != 2 || columns (P) != 2)
    errmsg = "must be an N-by-2 matrix of point coordinates.";
    return;
  endif
  if (! all (isfinite (P(:))))
    errmsg = "must not contain NaN or Inf values.";
  endif

endfunction

## Validate a radius, as above.
function errmsg = checkradius (R)

  errmsg = '';
  if (! isnumeric (R) || ! isreal (R) || ! isscalar (R) || ! isfinite (R) ...
      || R <= 0)
    errmsg = "must be a real positive finite scalar.";
  endif

endfunction

## The points an entity contributes to the drawing extent.  For everything
## straight that is just its coordinates; the curved types need their sweep
## resolved, which is the whole reason this is a function.
function P = extentpoints (e)

  switch (e.type)

    case 'circle'
      C = e.pts;
      R = e.radius;
      P = [C(1) - R, C(2); C(1) + R, C(2); C(1), C(2) - R; C(1), C(2) + R];

    case 'arc'
      P = arcextent (e.pts, e.radius, e.angles(1), e.angles(2));

    otherwise
      P = e.pts;

  endswitch

endfunction

## Extent points of an arc: both endpoints, plus each cardinal point the sweep
## passes through.  The sweep runs counter-clockwise from A1 to A2, and equal
## angles mean a full circle rather than nothing.
function P = arcextent (C, R, A1, A2)

  sweep = mod (A2 - A1, 360);
  if (sweep == 0)
    sweep = 360;
  endif

  P = [C(1) + R * cosd(A1), C(2) + R * sind(A1); ...
       C(1) + R * cosd(A2), C(2) + R * sind(A2)];

  for k = [0, 90, 180, 270]
    if (mod (k - A1, 360) <= sweep)
      P = [P; C(1) + R * cosd(k), C(2) + R * sind(k)];
    endif
  endfor

endfunction
