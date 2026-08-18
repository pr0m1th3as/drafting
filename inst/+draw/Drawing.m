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
## New entities take the layer, line type and colour that are current when
## they are appended, exactly as a CAD application draws on its current layer
## with its current pen.  Set @code{Layer}, @code{Linetype} or @code{Colour}
## first and then draw; no append method takes any of the three as an argument.
## Each governs what follows it and never what came before.
##
## Properties rather than arguments is what lets a caller state a drawing
## convention once and then draw against it, which is how a draughtsman works
## and how CAD is built.  It is also why a dimension's exploded parts inherit
## all three: the rule has no exceptions.
##
## Dimensions are stored @strong{semantically} --- the two measured points, a
## perpendicular offset and a direction --- and are turned into lines,
## arrowheads and text by whichever backend renders them.  Nothing about how a
## dimension looks is decided here, which is what keeps a dimension truthful
## when the geometry it measures moves.
##
## A drawing reports what it holds through @code{numentities}, @code{layers}
## and @code{bbox}, and hands its contents to a backend through
## @code{entities}, which lowers them to the primitives a file can carry.  That
## lowered list is what @code{plot}, @code{print}, @code{tikz} and
## @code{dxf.write} all consume, so a figure shows the entities the file will
## contain rather than a more flattering rendering of them.
##
## @seealso{dxf.write, geom.bbox}
## @end deftypefn

classdef Drawing

  properties

    ## -*- texinfo -*-
    ## @deftp {draw.Drawing} {property} Name
    ##
    ## Drawing name
    ##
    ## The name of the drawing, as a character vector.  It is carried into the
    ## output wherever the format has somewhere to put it: a DXF file records
    ## it, a TikZ picture writes it into a comment.  It defaults to
    ## @qcode{'untitled'} and never affects the geometry.
    ##
    ## @end deftp
    Name = 'untitled';

    ## -*- texinfo -*-
    ## @deftp {draw.Drawing} {property} Layer
    ##
    ## The current layer
    ##
    ## The layer that entities are placed on as they are appended, as a
    ## character vector.  It defaults to @qcode{'0'}, the layer every CAD
    ## drawing has.
    ##
    ## Like @code{Linetype} and @code{Colour}, it applies to what is appended
    ## @emph{after} it is set and never to what came before, so a drawing is
    ## built by setting a property and then adding the entities that belong to
    ## it.  Reading it back says where the next entity will go, not where the
    ## existing ones are; for that, use @code{layers}.
    ##
    ## @end deftp
    Layer = '0';

    ## -*- texinfo -*-
    ## @deftp {draw.Drawing} {property} Linetype
    ##
    ## The current line type
    ##
    ## The line type that entities are drawn with as they are appended, named
    ## as a character vector: one of CONTINUOUS, HIDDEN, CENTER, PHANTOM,
    ## DASHED, DASHDOT or DOT.  It defaults to @qcode{'CONTINUOUS'}.
    ##
    ## It governs what is appended after it is set, never what came before.
    ## The dash lengths themselves are model dimensions scaled by each
    ## backend's line-type scale, not a property of the drawing.
    ##
    ## @end deftp
    Linetype = 'CONTINUOUS';

    ## -*- texinfo -*-
    ## @deftp {draw.Drawing} {property} Colour
    ##
    ## The current colour
    ##
    ## The colour that entities are drawn in as they are appended, as an
    ## AutoCAD colour index from 0 to 256 or as a colour name accepted by
    ## @code{draw.colour}.  It defaults to 256, which is @qcode{'byLayer'} ---
    ## the entity takes whatever colour its layer carries, which is how a CAD
    ## drawing is normally organised.
    ##
    ## It governs what is appended after it is set, never what came before.
    ##
    ## @end deftp
    Colour = 256;

  endproperties

  properties (SetAccess = private, Hidden)

    ## Block definitions, by name.  Each holds a drawing placed by 'insert'.
    ## Internal: 'block', 'insert' and 'expand' are the supported way in.
    Blocks = struct ('name', {}, 'drawing', {});

  endproperties

  properties (SetAccess = private, Hidden)

    ## The entities, in the order they were appended.  Internal: the field
    ## layout is not API.  Use 'entities' for the lowered list a backend sees,
    ## 'numentities' for the count and 'layers' for the layers in use.
    Entities = struct ('type', {}, 'layer', {}, 'linetype', {}, ...
                       'colour', {}, 'pts', {}, 'closed', {}, ...
                       'radius', {}, 'angles', {}, 'angle', {}, 'text', {}, ...
                       'height', {}, 'offset', {}, 'direction', {}, ...
                       'pattern', {}, 'spacing', {}, 'block', {}, ...
                       'scale', {}, 'bulge', {});

  endproperties

  methods (Hidden)

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

################################################################################
##                          ** The drawing object **                          ##
################################################################################
##                             Available Methods                              ##
##                                                                            ##
## 'Drawing'         'numentities'     'isempty'         'layers'             ##
## 'bbox'                                                                     ##
################################################################################

  methods (Access = public)

    ## -*- texinfo -*-
    ## @deftypefn  {draw.Drawing} {@var{D} =} Drawing ()
    ## @deftypefnx {draw.Drawing} {@var{D} =} Drawing (@var{NAME})
    ##
    ## Create an empty drawing, optionally named.
    ##
    ## @code{@var{D} = Drawing ()} returns an empty drawing called
    ## @qcode{'untitled'}.  @code{@var{D} = Drawing (@var{NAME})} names it
    ## instead; the name is carried into the output wherever the format has
    ## somewhere to put it.
    ##
    ## @strong{A drawing is a value, not a handle.}  Every method returns a new
    ## drawing and leaves its input untouched, so the methods chain and a
    ## drawing can be placed twice without the two copies interfering:
    ##
    ## @example
    ## @group
    ## D = draw.Drawing ('plate');
    ## D = D.polyline ([0, 0; 80, 0; 80, 50; 0, 50], true);
    ## D = D.circle ([40, 25], 12);
    ## @end group
    ## @end example
    ##
    ## Entities are appended in the order the methods are called, and each takes
    ## the @code{Layer}, @code{Linetype} and @code{Colour} current at the moment
    ## it is appended.  Setting one of those properties therefore affects what
    ## follows and never what came before, which is how a draughtsman works and
    ## how CAD is built.
    ##
    ## All coordinates are in millimetres.
    ##
    ## @end deftypefn
    function this = Drawing (NAME)

      if (nargin == 1)
        this.Name = NAME;
      endif

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

  endmethods

################################################################################
##                          ** Appending entities **                          ##
################################################################################
##                             Available Methods                              ##
##                                                                            ##
## 'line'            'polyline'        'arc'             'circle'             ##
## 'ellipse'         'text'            'hatch'                                ##
################################################################################

  methods (Access = public)

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
    ## and @code{draw.Drawing.entities} records the substitution.  The shape is
    ## right to
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

  endmethods

################################################################################
##                        ** Dimensioning and notes **                        ##
################################################################################
##                             Available Methods                              ##
##                                                                            ##
## 'dim'             'diam'            'radius'          'angdim'             ##
## 'centremark'      'leader'                                                 ##
################################################################################

  methods (Access = public)

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

################################################################################
##                             ** Composition **                              ##
################################################################################
##                             Available Methods                              ##
##                                                                            ##
## 'transform'       'merge'           'block'           'insert'             ##
## 'expand'                                                                   ##
################################################################################

  methods (Access = public)

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
    ## backend with no block of its own needs, and what @code{draw.Drawing.plot}
    ## and
    ## @code{draw.Drawing.tikz} do before rendering.
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
    ## @seealso{block, insert, draw.Drawing.entities}
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

  endmethods

################################################################################
##                                ** Output **                                ##
################################################################################
##                             Available Methods                              ##
##                                                                            ##
## 'entities'        'plot'            'print'           'tikz'               ##
################################################################################

  methods (Access = public)


    ## -*- texinfo -*-
    ## @deftypefn  {draw.Drawing} {@var{E} =} entities (@var{D})
    ## @deftypefnx {draw.Drawing} {@var{E} =} entities (@var{D}, @var{NAME}, @var{VALUE}, @dots{})
    ## @deftypefnx {draw.Drawing} {[@var{E}, @var{LOST}] =} entities (@dots{})
    ## @deftypefnx {draw.Drawing} {[@var{E}, @var{LOST}, @var{BLOCKS}] =} entities (@dots{})
    ##
    ## Lower a drawing to the flat entity struct array that @code{dxf.write}
    ## takes.
    ##
    ## @code{@var{E} = entities (@var{D})} converts the @code{draw.Drawing}
    ## object @var{D} into the entity vocabulary of the DXF layer: @code{LINE},
    ## @code{POLYLINE}, @code{ARC}, @code{CIRCLE} and @code{TEXT}, each on the
    ## layer it was drawn on.  The result is written with
    ## @code{dxf.write (@var{FILE}, @var{E})}.
    ##
    ## This is the adapter between the two representations and the only place
    ## that
    ## knows both.  @code{dxf} deals in a file format and knows nothing of
    ## dimensions or hatches; @code{draw} models the drawing and knows nothing
    ## of
    ## group codes.
    ##
    ## @subheading Dimensions are exploded here
    ##
    ## A @code{'dim'} entity carries only geometry --- two points, an offset and
    ## a
    ## direction.  It becomes six entities: two extension lines, the dimension
    ## line, two oblique ticks and the text.  Nothing associative is emitted: a
    ## true @code{DIMENSION} needs a @code{*D} block and a @code{DIMSTYLE}
    ## record,
    ## and plots identically.
    ##
    ## Ticks are the 45-degree architectural obliques rather than arrowheads.
    ## R12
    ## draws a filled arrowhead only as a @code{SOLID}, and at drawing scale the
    ## tick is the conventional mark in any case.
    ##
    ## The text is placed @strong{horizontally whatever the dimension measures}
    ## --- unidirectional dimensioning, which ISO 129 permits and which keeps
    ## every
    ## label on the sheet readable from one side of it.
    ##
    ## The label always clears the dimension line, on the far side from the
    ## geometry being measured.  A dimension across the sheet carries its label
    ## above or below the line; one up the sheet carries it to the left or
    ## right,
    ## since a horizontal label beside a vertical dimension has to clear the
    ## line
    ## by its @emph{width}.  Which side is which follows the sign of the offset.
    ##
    ## Without a label a dimension is annotated with the distance it measures,
    ## computed at the moment of conversion, so a dimension cannot fall out of
    ## step
    ## with the geometry it spans.
    ##
    ## @subheading Ornament size
    ##
    ## Dimension ornament --- tick length, text height, the gap between a
    ## measured
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
    ## silently: a @code{'hatch'} becomes its boundary as a closed polyline, so
    ## the
    ## region is outlined but not filled, R12 having no @code{HATCH} entity.
    ##
    ## Text rotation used to be the second such case and no longer is.
    ## @code{dxf.write} emits group code 50, so a rotated @code{'text'} arrives
    ## in
    ## the CAD file at the angle it was drawn at.
    ##
    ## @code{[@var{E}, @var{LOST}] = entities (@dots{})} returns the losses as
    ## a struct array with fields @code{index}, @code{type} and @code{reason},
    ## naming the entity of @var{D} that lost something.  Ask for @var{LOST} and
    ## nothing is printed; omit it and each distinct reason is warned about
    ## once,
    ## because a conversion that quietly discards part of a drawing is the one
    ## failure mode a CAD file will not show you.
    ##
    ## @seealso{dxf.write, draw.Drawing}
    ## @end deftypefn
    function [E, LOST, BLOCKS] = entities (D, varargin)

      ## Input validation
      if (nargin < 1)
        error ("draw.Drawing.entities: invalid number of input arguments.");
      endif
      if (! isa (D, 'draw.Drawing'))
        error ("draw.Drawing.entities: D must be a draw.Drawing object.");
      endif
      if (mod (numel (varargin), 2) != 0)
        error (strcat ("draw.Drawing.entities: optional arguments", ...
               " must come in name-value pairs."));
      endif

      dimScale = 1;
      hatchMode = 'lines';
      blockMode = 'expand';
      chordTol = 0.01;
      bulgeMode = 'keep';
      dimMode = 'associative';
      for ii = 1:2:numel (varargin)
        name = varargin{ii};
        if (! ischar (name) || ! isrow (name))
          error (strcat ("draw.Drawing.entities: option names", ...
                 " must be character vectors."));
        endif
        switch (lower (name))
          case 'dimscale'
            dimScale = varargin{ii+1};
            if (! isnumeric (dimScale) || ! isreal (dimScale) ...
                || ! isscalar (dimScale) || ! isfinite (dimScale) ...
                || dimScale <= 0)
              error (strcat ("draw.Drawing.entities: DimScale must be a", ...
                             " real positive", ...
                             " finite scalar."));
            endif
            dimScale = double (dimScale);
          case 'chordtol'
            chordTol = varargin{ii+1};
            if (! isnumeric (chordTol) || ! isreal (chordTol) ...
                  || ! isscalar (chordTol) || ! isfinite (chordTol) ...
                  || chordTol <= 0)
              error (strcat ("draw.Drawing.entities: ChordTol must be a", ...
                             " real positive", ...
                             " finite scalar."));
            endif
          case 'dimensions'
            dimMode = varargin{ii+1};
            if (! ischar (dimMode) || ! isrow (dimMode) ...
                || ! any (strcmpi (dimMode, {'associative', 'explode'})))
              error (strcat ("draw.Drawing.entities: Dimensions must be", ...
                             " 'associative' or 'explode'."));
            endif
            dimMode = lower (dimMode);

          case 'bulges'
            bulgeMode = varargin{ii+1};
            if (! ischar (bulgeMode) || ! isrow (bulgeMode) ...
                || ! any (strcmpi (bulgeMode, {'keep', 'flatten'})))
              error (strcat ("draw.Drawing.entities: Bulges", ...
                     " must be 'keep' or 'flatten'."));
            endif
            bulgeMode = lower (bulgeMode);
          case 'blocks'
            blockMode = varargin{ii+1};
            if (! ischar (blockMode) || ! isrow (blockMode) ...
                || ! any (strcmpi (blockMode, {'expand', 'reference'})))
              error (strcat ("draw.Drawing.entities: Blocks must be", ...
                             " 'expand' or", ...
                             " 'reference'."));
            endif
            blockMode = lower (blockMode);
          case 'hatch'
            hatchMode = varargin{ii+1};
            if (! ischar (hatchMode) || ! isrow (hatchMode) ...
                || ! any (strcmpi (hatchMode, {'lines', 'boundary'})))
              error (strcat ("draw.Drawing.entities: Hatch must be", ...
                             " 'lines' or", ...
                             " 'boundary'."));
            endif
            hatchMode = lower (hatchMode);
          otherwise
            error ("draw.Drawing.entities: unknown option '%s'.", name);
        endswitch
      endfor

      E = emptyentity ();
      LOST = struct ('index', {}, 'type', {}, 'reason', {});
      BLOCKS = struct ('name', {}, 'entities', {});
      nDim = 0;

      ## An insert is a reference the caller may want kept, but every other
      ## consumer needs the geometry, so expansion is the default
      if (strcmp (blockMode, 'expand'))
        D = D.expand ();
      else
        for bb = 1:numel (D.Blocks)
          BLOCKS(bb).name = D.Blocks(bb).name;
          BLOCKS(bb).entities = entities (D.Blocks(bb).drawing.expand (), ...
                                               'dimscale', dimScale, ...
                                               'hatch', hatchMode);
        endfor
      endif

      src = D.Entities;
      for ii = 1:numel (src)

        e = src(ii);

        switch (e.type)

          case 'line'
            E(end+1) = mkent ('LINE', e, e.pts);

          case 'polyline'
            if (! isempty (e.bulge) && strcmp (bulgeMode, 'flatten'))
              p = mkent ('POLYLINE', e, flattenbulge (e, chordTol));
              p.closed = e.closed;
            else
              p = mkent ('POLYLINE', e, e.pts);
              p.closed = e.closed;
              p.bulge = e.bulge;
            endif
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

          case 'ellipse'
            ## R12 has no ELLIPSE, so it goes out as a closed polyline sampled
            ## to
            ## the chordal tolerance.  Unlike a hatch, something really is lost:
            ## the shape survives but the entity does not, and it can no longer
            ## be
            ## edited as an ellipse.
            a = e.radius(1);
            b = e.radius(2);
            c = cosd (e.angle);
            sn = sind (e.angle);
            f = @(t) e.pts + [a * cos(t) * c - b * sin(t) * sn, ...
                              a * cos(t) * sn + b * sin(t) * c];
            pts = geom.curvesample (@(t) ellipsepts (t, e.pts, a, b, c, sn), ...
                                    [0, 2*pi], chordTol);
            pts(end,:) = [];
            q = mkent ('POLYLINE', e, pts);
            q.closed = true;
            E(end+1) = q;
            LOST(end+1) = struct ('index', ii, 'type', 'ellipse', 'reason', ...
                                  sprintf (strcat ('R12 has no ELLIPSE;', ...
                                     ' emitted as a closed polyline of', ...
                                           ' %d points'), rows (pts)));

          case {'diam', 'radius'}
            parts = explodecirc (e, dimScale);
            if (strcmp (dimMode, 'associative'))
              nDim++;
              bn = sprintf ('*D%d', nDim);
              BLOCKS(end+1) = struct ('name', bn, 'entities', {parts});
              E(end+1) = dimrecord (e, bn, e.type);
            else
              for kk = 1:numel (parts)
                E(end+1) = parts(kk);
              endfor
            endif

          case 'angdim'
            parts = explodeang (e, dimScale);
            if (strcmp (dimMode, 'associative'))
              nDim++;
              bn = sprintf ('*D%d', nDim);
              BLOCKS(end+1) = struct ('name', bn, 'entities', {parts});
              E(end+1) = dimrecord (e, bn, 'angdim');
              continue;
            endif
            for kk = 1:numel (parts)
              E(end+1) = parts(kk);
            endfor

          case 'centremark'
            parts = explodemark (e, dimScale);
            for kk = 1:numel (parts)
              E(end+1) = parts(kk);
            endfor

          case 'leader'
            parts = explodeleader (e, dimScale);
            for kk = 1:numel (parts)
              E(end+1) = parts(kk);
            endfor

          case 'insert'
            s = mkent ('INSERT', e, e.pts);
            s.block = e.block;
            s.rotation = e.angle;
            s.radius = e.scale;
            E(end+1) = s;

          case 'hatch'
            h = mkent ('POLYLINE', e, e.pts);
            h.closed = true;
            E(end+1) = h;
            if (strcmp (hatchMode, 'lines'))
              ## R12 has no HATCH entity, so the fill is generated explicitly.
              ## Emitting the lines is a truer degradation than dropping them:
              ## the recipient sees the section hatched, not an empty outline.
              S = geom.hatchlines (e.pts, e.pattern, e.angle, e.spacing);
              for jj = 1:rows (S)
                E(end+1) = mkent ('LINE', e, [S(jj,1:2); S(jj,3:4)]);
              endfor
              ## Nothing is recorded as lost: R12 has no HATCH entity, but the
              ## fill it would have carried is present as lines, so the
              ## recipient
              ## sees the hatch.  LOST is for what could not be carried at all.
            else
              LOST(end+1) = struct ('index', ii, 'type', 'hatch', 'reason', ...
                              strcat ('fill dropped: R12 has no HATCH,', ...
                                            ' boundary emitted'));
            endif

          case 'dim'
            parts = explodedim (e, dimScale);
            if (strcmp (dimMode, 'associative'))
              nDim++;
              bn = sprintf ('*D%d', nDim);
              BLOCKS(end+1) = struct ('name', bn, 'entities', {parts});
              E(end+1) = dimrecord (e, bn, 'dim');
            else
              for jj = 1:numel (parts)
                E(end+1) = parts(jj);
              endfor
            endif

        endswitch

      endfor

      ## Warn only when the caller has not asked to be told properly.
      if (nargout < 2 && ! isempty (LOST))
        reasons = unique ({LOST.reason});
        for ii = 1:numel (reasons)
          n = sum (strcmp ({LOST.reason}, reasons{ii}));
          if (n == 1)
            warning ("draw.Drawing.entities: 1 entity: %s.", reasons{ii});
          else
            warning ("draw.Drawing.entities: %d entities: %s.", n, reasons{ii});
          endif
        endfor
      endif

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {draw.Drawing} {} plot (@var{D})
    ## @deftypefnx {draw.Drawing} {} plot (@var{HAX}, @var{D})
    ## @deftypefnx {draw.Drawing} {} plot (@dots{}, @var{Name}, @var{Value})
    ## @deftypefnx {draw.Drawing} {@var{H} =} plot (@dots{})
    ##
    ## Draw a @code{draw.Drawing} into a figure, to look at it.
    ##
    ## @code{draw.Drawing.plot (@var{D})} renders the drawing into the current
    ## axes at
    ## equal aspect ratio, honouring each entity's layer, line type and colour.
    ##
    ## @code{draw.Drawing.plot (@var{HAX}, @var{D})} draws into the axes
    ## @var{HAX} instead
    ## of the current ones, as every plotting function in Octave accepts an axes
    ## handle ahead of its data. The @qcode{'Axes'} pair below does the same
    ## thing
    ## and is equivalent.
    ##
    ## @code{@var{H} = draw.Drawing.plot (@dots{})} returns a column of graphics
    ## handles,
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
    ## @item @qcode{'Arc'} @tab 64 @tab segments per full turn when sampling
    ## curves
    ## @item @qcode{'Hatch'} @tab @qcode{'lines'} @tab @qcode{'lines'} to fill a
    ## hatch, @qcode{'boundary'} for its outline alone
    ## @item @qcode{'Linetypes'} @tab @qcode{'true'} @tab @qcode{'true'} to draw
    ## the
    ## real dash patterns, @qcode{'approximate'} for the figure's own four
    ## styles
    ## @item @qcode{'LTScale'} @tab 1 @tab multiplies the dash lengths
    ## @item @qcode{'Margin'} @tab 0.05 @tab blank space kept between the
    ## geometry
    ## and the axes, as a fraction of the drawing's larger side; 0 fits the axes
    ## tight to the geometry
    ## @item @qcode{'FontScale'} @tab @code{[]} @tab points per model unit; when
    ## given, each string is sized from its own entity height instead of from
    ## @qcode{'FontSize'}
    ## @end multitable
    ##
    ## @subheading Why the axes do not fit tight
    ##
    ## Auto-scaled limits stop exactly at the extreme coordinate, so an outline
    ## lying on it is drawn along the frame and reads as part of the axes rather
    ## than as geometry --- which is the common case, not a corner one: a plate
    ## is
    ## usually dimensioned from its own edges. Both axes are therefore padded by
    ## the same absolute amount, which keeps the equal aspect ratio the drawing
    ## depends on, and that amount is @qcode{'Margin'} times the larger of the
    ## two
    ## spans.
    ##
    ## @subheading What you see is what gets written
    ##
    ## The drawing is lowered through @code{draw.Drawing.entities} --- the same
    ## conversion
    ## the DXF backend uses --- and the result of that is what is plotted. A
    ## figure
    ## therefore shows the entities the file will contain, not a more flattering
    ## rendering of them.  In particular a hatch appears as its boundary alone,
    ## because that is what the file will carry; the second output of
    ## @code{draw.Drawing.entities} says so explicitly.
    ##
    ## The alternative, rendering from the drawing model directly, would let the
    ## screen show something the recipient never receives.  For a package whose
    ## output is meant to be manufactured, that is the wrong way round.
    ##
    ## @subheading Line types are drawn properly, not approximated
    ##
    ## A figure offers four line styles and this package defines seven line
    ## types,
    ## so setting @code{linestyle} would collapse three of them onto their
    ## neighbours --- CENTER, DASHDOT and PHANTOM would all come out dash-dot,
    ## and a
    ## phantom line would be indistinguishable from a centre line.
    ##
    ## Instead each run of geometry is cut into its dashes and the pieces are
    ## drawn,
    ## so all seven patterns render as themselves. Dash lengths are in the units
    ## of
    ## the drawing, multiplied by @qcode{'LTScale'}, which is the model-space
    ## convention CAD uses. A drawing spanning tens of millimetres therefore
    ## needs
    ## no adjustment; one spanning metres wants an @qcode{'LTScale'} to match.
    ##
    ## The cost is one graphics object per dash.  Set @qcode{'Linetypes'} to
    ## @qcode{'approximate'} on a large drawing to fall back on the figure's
    ## four
    ## styles and one object per entity.
    ##
    ## @strong{Text is not to scale by default.} A figure sets font size in
    ## points,
    ## which does not track the data units the drawing is in, so text cannot
    ## both
    ## sit at the right size and stay there when the axes are zoomed. It is
    ## drawn
    ## at a fixed point size, positioned correctly.
    ##
    ## That is right for a screen and wrong for a sheet, where a string must
    ## come
    ## out at the height the model gives it. Pass @qcode{'FontScale'}, in points
    ## per model unit, and each string is sized from its own entity height
    ## instead:
    ## at a plot scale of @math{1:S} that factor is @code{72 / (25.4 *
    ## @var{S})},
    ## which is what @code{draw.Drawing.print} supplies. For a rendering where
    ## text is to
    ## scale by construction, use @code{draw.Drawing.tikz}.
    ##
    ## @seealso{draw.Drawing, draw.Drawing.entities, draw.Drawing.tikz,
    ## dxf.write}
    ## @end deftypefn
    function H = plot (varargin)

      ## Input validation
      if (numel (varargin) < 1)
        error ("draw.Drawing.plot: invalid number of input arguments.");
      endif

      ## An axes handle may lead, as it may for every plotting function in
      ## Octave
      hax = [];
      if (! isa (varargin{1}, 'draw.Drawing') && isscalar (varargin{1}) ...
          && ishandle (varargin{1}))
        hax = varargin{1};
        varargin(1) = [];
      endif
      if (numel (varargin) < 1)
        error ("draw.Drawing.plot: invalid number of input arguments.");
      endif
      D = varargin{1};
      varargin(1) = [];
      if (! isa (D, 'draw.Drawing'))
        error ("draw.Drawing.plot: D must be a draw.Drawing object.");
      endif
      if (mod (numel (varargin), 2) != 0)
        error ("draw.Drawing.plot: Name/Value arguments must come in pairs.");
      endif

      opt = struct ('Axes', hax, 'LineWidth', 0.5, 'FontSize', 8, ...
                    'Layers', {{}}, 'Arc', 64, 'Hatch', 'lines', ...
                    'Linetypes', 'true', 'LTScale', 1, 'Margin', 0.05, ...
                    'FontScale', []);
      known = fieldnames (opt);
      for k = 1:2:numel (varargin)
        name = varargin{k};
        if (! ischar (name) || ! isrow (name) || ! any (strcmp (name, known)))
          error ("draw.Drawing.plot: unknown parameter.");
        endif
        opt.(name) = varargin{k+1};
      endfor
      if (! isempty (opt.Layers) && ! iscellstr (opt.Layers))
        error (strcat ("draw.Drawing.plot: Layers must be a cell array of", ...
                       " character vectors."));
      endif
      for f = {'Hatch', 'Linetypes'}
        if (! ischar (opt.(f{1})) || ! isrow (opt.(f{1})))
          error ("draw.Drawing.plot: %s must be a character vector.", f{1});
        endif
      endfor
      if (! any (strcmpi (opt.Hatch, {'lines', 'boundary'})))
        error ("draw.Drawing.plot: Hatch must be 'lines' or 'boundary'.");
      endif
      if (! any (strcmpi (opt.Linetypes, {'true', 'approximate'})))
        error ("draw.Drawing.plot: Linetypes must be 'true' or 'approximate'.");
      endif
      for f = {'LineWidth', 'FontSize', 'Arc', 'LTScale'}
        v = opt.(f{1});
        if (! isnumeric (v) || ! isreal (v) || ! isscalar (v) ...
            || ! isfinite (v) || v <= 0)
          error (strcat ("draw.Drawing.plot: %s must be a positive real", ...
                         " finite scalar."), f{1});
        endif
      endfor
      ## Margin admits 0, which fits the axes tight to the geometry.
      if (! isnumeric (opt.Margin) || ! isreal (opt.Margin) ...
          || ! isscalar (opt.Margin) || ! isfinite (opt.Margin) ...
          || opt.Margin < 0)
        error (strcat ("draw.Drawing.plot: Margin must be a non-negative", ...
                       " real finite scalar."));
      endif
      ## FontScale is empty for the fixed point size, or points per model unit.
      if (! isempty (opt.FontScale) ...
          && (! isnumeric (opt.FontScale) || ! isreal (opt.FontScale) ...
              || ! isscalar (opt.FontScale) || ! isfinite (opt.FontScale) ...
              || opt.FontScale <= 0))
        error (strcat ("draw.Drawing.plot: FontScale must be empty or a", ...
                       " positive real finite scalar."));
      endif

      if (isempty (opt.Axes))
        opt.Axes = gca ();
      elseif (! isscalar (opt.Axes) || ! ishandle (opt.Axes))
        error ("draw.Drawing.plot: Axes must be a graphics handle.");
      endif

      ## The same lowering the file backends use, so the figure shows what the
      ## file will hold rather than a kinder version of it
      ## A renderer wants the picture, not the semantics: the associative form
      ## exists for a file, where a reader can re-measure it.
      E = entities (D, 'hatch', lower (opt.Hatch), 'bulges', 'flatten', ...
                    'dimensions', 'explode');
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
              P = [e.pts(1) + e.radius * cosd(a)', ...
                   e.pts(2) + e.radius * sind(a)'];
              H = [H; polydraw(ax, P, e.linetype, col, opt)];

            case 'TEXT'
              ## With a FontScale the entity's own height decides the size,
              ## which
              ## is what a plotted sheet needs; without one every string is
              ## drawn
              ## at the same fixed point size, which is what a screen needs.
              if (isempty (opt.FontScale))
                fsize = opt.FontSize;
              else
                fsize = e.height * opt.FontScale;
              endif
              H(end+1, 1) = text (e.pts(1), e.pts(2), plainsymbols (e.text), ...
                                  'parent', ax, ...
                                  'color', col, 'fontsize', fsize, ...
                                  'rotation', e.rotation, ...
                                  'horizontalalignment', 'left', ...
                                  'verticalalignment', 'baseline');

            case 'POINT'
              H(end+1, 1) = line (ax, e.pts(1), e.pts(2), 'color', col, ...
                                  'marker', '+', 'linestyle', 'none');
          endswitch
        endfor

        axis (ax, 'equal');

        ## Auto-scaled limits stop at the extreme coordinate, so geometry lying
        ## on
        ## it is drawn along the frame and reads as part of the axes.
        xl = xlim (ax);
        yl = ylim (ax);

        ## A TEXT entity contributes only its insertion point to those limits,
        ## not
        ## the width of the string it renders, so a label near an edge is cut
        ## off.
        ## Widen to the extents the text objects report, which are in data
        ## units.
        ## Text is sized in points, so widening shrinks it and the correction
        ## only
        ## ever errs towards more room.
        if (! isempty (H))
          ht = H(strcmp (get (H, 'type'), 'text'));
          for k = 1:numel (ht)
            e = get (ht(k), 'extent');
            xl = [min(xl(1), e(1)), max(xl(2), e(1) + e(3))];
            yl = [min(yl(1), e(2)), max(yl(2), e(2) + e(4))];
          endfor
        endif

        if (opt.Margin > 0)
          m = opt.Margin * max (diff (xl), diff (yl));
          xl += [-m, m];
          yl += [-m, m];
        endif
        if (diff (xl) > 0 && diff (yl) > 0)
          xlim (ax, xl);
          ylim (ax, yl);
        endif
      unwind_protect_cleanup
        if (! held)
          hold (ax, 'off');
        endif
      end_unwind_protect

      if (nargout == 0)
        clear H;
      endif

    endfunction


    ## -*- texinfo -*-
    ## @deftypefn  {draw.Drawing} {} print (@var{D}, @var{FILE})
    ## @deftypefnx {draw.Drawing} {} print (@var{D}, @var{FILE}, @var{NAME}, @var{VALUE}, @dots{})
    ## @deftypefnx {draw.Drawing} {[@var{PAPER}, @var{SCALE}] =} print (@dots{})
    ##
    ## Plot a drawing onto paper at a stated scale.
    ##
    ## @code{draw.Drawing.print (@var{D}, @var{FILE})} writes the
    ## @code{draw.Drawing}
    ## object @var{D} to @var{FILE} on an A4 landscape sheet, at the largest of
    ## the
    ## preferred scales that fits. The output format is taken from the extension
    ## of @var{FILE}: @file{.pdf}, @file{.eps} and @file{.svg} are vector,
    ## @file{.png}, @file{.jpg} and @file{.tif} are raster.
    ##
    ## @strong{The drawing arrives at its scale, not merely fitted to the page.}
    ## A
    ## distance measured on the sheet, multiplied by the scale denominator, is
    ## the
    ## distance in the model. That is the difference between a plot and a
    ## picture,
    ## and it is what @code{print} on a figure cannot give: it fits the axes to
    ## the
    ## paper, so a millimetre on the page means nothing.
    ##
    ## @subheading Name/Value pairs
    ##
    ## @multitable @columnfractions 0.16 0.16 0.68
    ## @headitem Name @tab Default @tab Meaning
    ## @item @qcode{'Paper'} @tab @qcode{'A4'} @tab sheet, named @qcode{'A0'} to
    ## @qcode{'A5'}, or @code{[@var{width}, @var{height}]} in millimetres
    ## @item @qcode{'Orientation'} @tab @qcode{'landscape'} @tab or
    ## @qcode{'portrait'}; ignored when @qcode{'Paper'} is given as a size
    ## @item @qcode{'Scale'} @tab fitted @tab plot scale denominator: 50 means
    ## 1:50.  The default picks the largest preferred scale the sheet holds
    ## @item @qcode{'Margin'} @tab 10 @tab blank border kept around the drawing,
    ## in
    ## millimetres of paper
    ## @item @qcode{'Resolution'} @tab 600 @tab dots per inch, for a raster
    ## format
    ## only; a vector format ignores it
    ## @item @qcode{'LineWidth'} @tab 0.35 @tab pen width in millimetres of
    ## paper,
    ## from the ISO 128 set 0.25, 0.35, 0.5, 0.7
    ## @end multitable
    ##
    ## @code{[@var{PAPER}, @var{SCALE}] = draw.Drawing.print (@dots{})} returns
    ## the sheet
    ## size actually used, in millimetres, and the scale denominator, which is
    ## worth having when the scale was fitted rather than given.
    ##
    ## @subheading The scale is chosen from the preferred series
    ##
    ## When @qcode{'Scale'} is not given, the denominator is the smallest of
    ## @code{1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000} that leaves
    ## the
    ## drawing inside the sheet's margins. Those are the scales ISO 5455 admits,
    ## so an automatically chosen scale is still one a reader expects to see in
    ## a
    ## title block, rather than the 1:37.4 that fitting exactly would give.
    ##
    ## An explicit @qcode{'Scale'} is never overridden.  If the drawing does not
    ## fit at it, that is an error rather than a silent reduction: a sheet at
    ## the
    ## wrong scale is worse than no sheet.
    ##
    ## @subheading Text is a model dimension, pens are a paper one
    ##
    ## Each string is drawn at the height its entity carries, reduced by the
    ## scale,
    ## exactly as @code{draw.Drawing.tikz} does and as a CAD application does:
    ## lettering
    ## given as 125 mm in the model arrives 2.5 mm tall on a sheet at 1:50.
    ## Author
    ## it as the height wanted on paper times the scale denominator. The height
    ## is
    ## therefore part of the drawing and survives into the DXF, rather than
    ## being a
    ## property of one particular plot.
    ##
    ## @qcode{'LineWidth'} is the opposite: a width on the paper, held there at
    ## every scale, because a 0.35 mm pen is 0.35 mm whatever the sheet shows.
    ##
    ## @seealso{draw.Drawing.plot, draw.Drawing.tikz, draw.titleblock,
    ## dxf.write}
    ## @end deftypefn
    function [PAPER, SCALE] = print (D, FILE, varargin)

      ## Input validation
      if (nargin < 2)
        error ("draw.Drawing.print: invalid number of input arguments.");
      endif
      if (! isa (D, 'draw.Drawing'))
        error ("draw.Drawing.print: D must be a draw.Drawing object.");
      endif
      if (! ischar (FILE) || ! isrow (FILE) || isempty (FILE))
        error (strcat ("draw.Drawing.print: FILE must be a non-empty", ...
                       " character vector."));
      endif
      if (mod (numel (varargin), 2) != 0)
        error ("draw.Drawing.print: Name/Value arguments must come in pairs.");
      endif

      opt = struct ('Paper', 'A4', 'Orientation', 'landscape', 'Scale', [], ...
                    'Margin', 10, 'Resolution', 600, 'LineWidth', 0.35);
      known = fieldnames (opt);
      for k = 1:2:numel (varargin)
        name = varargin{k};
        if (! ischar (name) || ! isrow (name) || ! any (strcmp (name, known)))
          error ("draw.Drawing.print: unknown parameter.");
        endif
        opt.(name) = varargin{k+1};
      endfor

      PAPER = papersize (opt.Paper, opt.Orientation);
      if (! ischar (opt.Orientation) || ! isrow (opt.Orientation) ...
          || ! any (strcmpi (opt.Orientation, {'landscape', 'portrait'})))
        error (strcat ("draw.Drawing.print: Orientation must be", ...
                       " 'landscape' or 'portrait'."));
      endif
      for f = {'Margin', 'Resolution', 'LineWidth'}
        v = opt.(f{1});
        if (! isnumeric (v) || ! isreal (v) || ! isscalar (v) ...
            || ! isfinite (v) || v <= 0)
          error (strcat ("draw.Drawing.print: %s must be a positive real", ...
                         " finite scalar."), f{1});
        endif
      endfor
      if (! isempty (opt.Scale) && (! isnumeric (opt.Scale) ...
          || ! isreal (opt.Scale) || ! isscalar (opt.Scale) ...
          || ! isfinite (opt.Scale) || opt.Scale <= 0))
        error (strcat ("draw.Drawing.print: Scale must be empty or a", ...
                       " positive real finite scalar."));
      endif
      if (isempty (D) || D.numentities () == 0)
        error ("draw.Drawing.print: D is empty, so there is nothing to plot.");
      endif
      usable = PAPER - 2 * opt.Margin;
      if (any (usable <= 0))
        error ("draw.Drawing.print: Margin leaves no room on the sheet.");
      endif

      ## The extents to place are the ones draw.Drawing.plot settles on, margin
      ## and text
      ## included, so the figure is built before the scale can be chosen.
      fig = figure ('visible', 'off');
      unwind_protect
        ax = axes ('parent', fig);
        plot (D, 'Axes', ax, 'Margin', 0);
        span = [diff(xlim(ax)), diff(ylim(ax))];

        SCALE = choosescale (span, usable, opt.Scale);
        if (isempty (SCALE))
          error (strcat ("draw.Drawing.print: the drawing does not fit on", ...
                         " the sheet at any preferred scale; give a larger", ...
                         " Paper."));
        endif
        if (any (span / SCALE > usable + 1e-9))
          error (strcat ("draw.Drawing.print: the drawing does not fit on", ...
                         " the sheet at 1:%g; it needs %.1f by %.1f mm", ...
                         " inside a %.1f by %.1f mm area."), SCALE, ...
                         span(1) / SCALE, span(2) / SCALE, usable(1), ...
                         usable(2));
        endif

        ## Redraw with text sized from the model: at 1:S a model unit is 1/S mm
        ## on
        ## paper, and a point is 25.4/72 mm.
        cla (ax);
        plot (D, 'Axes', ax, 'Margin', 0, ...
                   'FontScale', 72 / (25.4 * SCALE), ...
                   'LineWidth', opt.LineWidth * 72 / 25.4);
        xlim (ax, xlim (ax));
        ylim (ax, ylim (ax));
        axis (ax, 'off');
        set (ax, 'position', [0, 0, 1, 1]);

        ## Place the drawing centred on the sheet, at scale
        place = span / SCALE;
        set (fig, 'paperunits', 'centimeters');
        set (fig, 'papersize', PAPER / 10);
        set (fig, 'paperposition', [(PAPER - place) / 20, place / 10]);

        args = {};
        raster = {'png', 'jpg', 'jpeg', 'tif', 'tiff'};
        if (any (strcmpi (fileext (FILE), raster)))
          args = {sprintf('-r%d', round (opt.Resolution))};
        endif
        print (fig, FILE, args{:});
      unwind_protect_cleanup
        close (fig);
      end_unwind_protect

      if (nargout == 0)
        clear PAPER SCALE;
      endif

    endfunction


    ## -*- texinfo -*-
    ## @deftypefn  {draw.Drawing} {@var{S} =} tikz (@var{D})
    ## @deftypefnx {draw.Drawing} {@var{S} =} tikz (@var{D}, @var{NAME}, @var{VALUE}, @dots{})
    ##
    ## Render a drawing as a TikZ picture for inclusion in the LaTeX report.
    ##
    ## @code{@var{S} = tikz (@var{D})} returns the TikZ code for the
    ## @code{draw.Drawing} object @var{D} as a character array, one line per row
    ## of
    ## the drawing, ready to be written to a @file{.tex} file and pulled into a
    ## document with @code{\input}.
    ##
    ## The picture is emitted at a stated plot scale, so it arrives on the page
    ## at
    ## the size a drawing is meant to be read at rather than at whatever size
    ## fits.
    ## Model coordinates are written unchanged, in millimetres, and the scale is
    ## carried by the @code{x} and @code{y} unit vectors of the
    ## @code{tikzpicture}: a wall at @math{x = 1600} appears in the output as
    ## @code{1600} whatever the scale, which is what makes the generated source
    ## readable against the drawing it came from.
    ##
    ## Radii, text sizes and dimension ornament cannot follow that convention,
    ## since they must come out at a fixed size on paper regardless of scale.
    ## Those are emitted in absolute millimetres and points, already divided by
    ## the
    ## scale.
    ##
    ## @subheading Options
    ##
    ## @multitable @columnfractions .16 .84
    ## @item @qcode{'Scale'} @tab Plot scale denominator: @math{50} means
    ## @math{1:50}, which is a common scale for a general-arrangement plan and
    ## the
    ## default.  A drawing at @math{1:1} wants @math{1}.
    ## @item @qcode{'File'} @tab Also write the result to this file.  The code
    ## is
    ## returned either way.
    ## @item @qcode{'Styles'} @tab Emit a @code{\tikzset} block defining one
    ## empty
    ## style per layer, so that the document can restyle a layer by redefining
    ## it.
    ## True by default; set it false when the styles are already defined and
    ## redefining them would undo that.
    ## @item @qcode{'LTScale'} @tab Multiplies line-type dash lengths.  Patterns
    ## are model lengths times this factor, exactly as in
    ## @code{draw.Drawing.plot} and as
    ## CAD's own @code{LTSCALE} works.  Defaults to the drawing scale, which
    ## cancels the reduction so dashes reach the page at their nominal size ---
    ## a
    ## centre line reads as a centre line whether the view is at 1:1 or 1:50 ---
    ## while leaving the factor visible and adjustable.
    ## @end multitable
    ##
    ## @subheading Dimensions
    ##
    ## Dimensions are rendered here rather than reused from
    ## @code{draw.Drawing.entities}, which is the point of storing them
    ## semantically.  A
    ## TikZ node anchors itself, so the label is positioned by naming the side
    ## it
    ## should sit on and letting TikZ measure the text --- where the DXF path
    ## has
    ## to estimate the width of a string from its character count.  The same
    ## drawing therefore gets properly centred labels on the report figure and
    ## approximately centred ones in the CAD file, from one model and without a
    ## flag anywhere.
    ##
    ## Labels are unidirectional, matching @code{draw.Drawing.entities}, and
    ## ticks are the
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
    ## @code{lualatex} --- or @code{babel} configured for Greek; that is a
    ## property
    ## of the document, not of this output.
    ##
    ## @seealso{draw.Drawing, draw.Drawing.entities}
    ## @end deftypefn
    function S = tikz (D, varargin)

      ## Input validation
      if (nargin < 1)
        error ("draw.Drawing.tikz: invalid number of input arguments.");
      endif
      if (! isa (D, 'draw.Drawing'))
        error ("draw.Drawing.tikz: D must be a draw.Drawing object.");
      endif
      if (mod (numel (varargin), 2) != 0)
        error (strcat ("draw.Drawing.tikz: optional arguments", ...
               " must come in name-value pairs."));
      endif

      scale = 50;
      fname = '';
      styles = true;
      ltscale = [];
      for ii = 1:2:numel (varargin)
        name = varargin{ii};
        val = varargin{ii+1};
        if (! ischar (name) || ! isrow (name))
          error ("draw.Drawing.tikz: option names must be character vectors.");
        endif
        switch (lower (name))
          case 'scale'
            if (! isnumeric (val) || ! isreal (val) || ! isscalar (val) ...
                || ! isfinite (val) || val <= 0)
              error (strcat ("draw.Drawing.tikz: Scale must be a real", ...
                             " positive finite", ...
                             " scalar."));
            endif
            scale = double (val);
          case 'file'
            if (! ischar (val) || ! isrow (val) || isempty (val))
              error (strcat ("draw.Drawing.tikz: File must be a non-empty", ...
                             " character", ...
                             " vector."));
            endif
            fname = val;
          case 'styles'
            if (! (islogical (val) || isnumeric (val)) || ! isscalar (val))
              error ("draw.Drawing.tikz: Styles must be a logical scalar.");
            endif
            styles = logical (val);
          case 'ltscale'
            if (! isnumeric (val) || ! isreal (val) || ! isscalar (val) ...
                || ! isfinite (val) || val <= 0)
              error (strcat ("draw.Drawing.tikz: LTScale must be a real", ...
                             " positive", ...
                             " finite scalar."));
            endif
            ltscale = double (val);
          otherwise
            error ("draw.Drawing.tikz: unknown option '%s'.", name);
        endswitch
      endfor

      ## Line-type patterns are model lengths times LTScale, as in CAD and as in
      ## draw.Drawing.plot.  Defaulting LTScale to the drawing scale cancels the
      ## reduction,
      ## so dashes arrive at their nominal size on the page -- which is what a
      ## report figure wants -- by an explicit factor rather than by a second
      ## rule.
      if (isempty (ltscale))
        ltscale = scale;
      endif

      ## One model millimetre, in millimetres on the page
      u = 1 / scale;

      ## Lowered through draw.Drawing.entities, exactly as draw.Drawing.plot is,
      ## so that the three
      ## backends agree and none of them can silently fail to know an entity
      ## type.
      ## That is not hypothetical: this one did, when the dimensioning entities
      ## arrived and only this backend still rendered from the drawing model.
      E = entities (D, 'bulges', 'flatten', 'dimensions', 'explode');

      if (isempty (E))
        L = {};
      else
        L = unique ({E.layer});
      endif
      sty = stylenames (L);

      out = {};
      out{end+1} = '% Generated by the drafting package: draw.Drawing.tikz';
      out{end+1} = sprintf ('%% Drawing: %s', D.Name);
      out{end+1} = sprintf (strcat ('%% Plot scale 1:%s. Coordinates are', ...
                                    ' model', ...
                                    ' millimetres.'), fmt (scale));
      if (styles && ! isempty (L))
        out{end+1} = '\tikzset{';
        for ii = 1:numel (L)
          out{end+1} = sprintf ('  %s/.style={}, %% layer ''%s''', ...
                                  sty{ii}, L{ii});
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
          error ("draw.Drawing.tikz: cannot open '%s' for writing.", fname);
        endif
        unwind_protect
          fprintf (fid, "%s\n", S);
        unwind_protect_cleanup
          fclose (fid);
        end_unwind_protect
      endif

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

## Drawing symbols as characters a figure font is likely to hold.  A capital O
## with a stroke stands in for the diameter sign, as it does on a great many
## real drawings; the true glyph is not in every font, and a missing one shows
## as a box, which is worse than a near miss.
function t = plainsymbols (t)

  t = strrep (t, '%%%', "\x00PC\x00");
  for c = {'c', 'C'}
    t = strrep (t, ['%%', c{1}], "\x00DIA\x00");
  endfor
  for c = {'d', 'D'}
    t = strrep (t, ['%%', c{1}], "\x00DEG\x00");
  endfor
  for c = {'p', 'P'}
    t = strrep (t, ['%%', c{1}], "\x00PM\x00");
  endfor
  t = strrep (t, "\x00DIA\x00", 'Ø');
  t = strrep (t, "\x00DEG\x00", '°');
  t = strrep (t, "\x00PM\x00", '±');
  t = strrep (t, "\x00PC\x00", '%');

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


## Sheet size in millimetres, from a name or an explicit [width, height].
function P = papersize (spec, orient)

  if (isnumeric (spec))
    if (! isreal (spec) || ! isequal (size (spec), [1, 2]) ...
        || ! all (isfinite (spec)) || any (spec <= 0))
      error (strcat ("draw.Drawing.print: Paper must be a name or a", ...
                     " 1-by-2 vector of positive millimetres."));
    endif
    P = double (spec);
    return;
  endif
  if (! ischar (spec) || ! isrow (spec))
    error (strcat ("draw.Drawing.print: Paper must be a character vector", ...
                   " or a 1-by-2 vector."));
  endif
  ## ISO 216 A series, portrait, in millimetres
  names = {'A0', 'A1', 'A2', 'A3', 'A4', 'A5'};
  sizes = [841, 1189; 594, 841; 420, 594; 297, 420; 210, 297; 148, 210];
  k = find (strcmpi (spec, names));
  if (isempty (k))
    error ("draw.Drawing.print: Paper '%s' is not one of A0 to A5.", spec);
  endif
  P = sizes(k,:);
  if (ischar (orient) && isrow (orient) && strcmpi (orient, 'landscape'))
    P = P([2, 1]);
  endif

endfunction

## Smallest preferred denominator that fits, or the one given.
function S = choosescale (span, usable, given)

  if (! isempty (given))
    S = double (given);
    return;
  endif
  preferred = [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000];
  S = [];
  for s = preferred
    if (all (span / s <= usable + 1e-9))
      S = s;
      return;
    endif
  endfor

endfunction

## Lower-case extension of a file name, without the dot.
function e = fileext (FILE)

  [~, ~, e] = fileparts (FILE);
  if (! isempty (e))
    e = lower (e(2:end));
  endif

endfunction



## The DIMENSION record for one semantic dimension, referring to the anonymous
## block that holds its picture.  The definition points are what makes the
## dimension associative: a CAD application re-measures from them, which is why
## the text is emitted as "<>" unless the caller overrode it.
function d = dimrecord (e, blockname, kind)

  d = mkent ('DIMENSION', e, [0, 0]);
  d.block = blockname;
  ## "<>" tells the reader to measure for itself, which is the whole point of
  ## an associative dimension.  A label the caller gave is emitted literally
  ## instead -- unless it is exactly what the measurement produces, in which
  ## case the two are indistinguishable on the sheet and "<>" keeps it live.
  d.text = '<>';
  if (isfield (e, 'text') && ! isempty (e.text) ...
      && ! strcmp (e.text, autolabel (e, kind)))
    d.text = e.text;
  endif

  switch (kind)
    case 'dim'
      P1 = e.pts(1,:);
      P2 = e.pts(2,:);
      switch (e.direction)
        case 'horizontal'
          U = [1, 0];
        case 'vertical'
          U = [0, 1];
        otherwise
          U = (P2 - P1) / norm (P2 - P1);
      endswitch
      N = [-U(2), U(1)];
      d.pts = [P1 + e.offset * N; (P1 + P2) / 2 + e.offset * N; ...
               P1; P2; 0, 0; 0, 0];
      d.rotation = atan2d (U(2), U(1));
      d.angles = 0;

    case 'diam'
      C = e.pts(1,:);
      u = [cosd(e.angle), sind(e.angle)];
      d.pts = [C + e.radius * u; C; 0, 0; 0, 0; C - e.radius * u; 0, 0];
      d.angles = 3;

    case 'radius'
      C = e.pts(1,:);
      u = [cosd(e.angle), sind(e.angle)];
      d.pts = [C + e.radius * u; C + e.radius * u / 2; ...
               0, 0; 0, 0; C; 0, 0];
      d.angles = 4;

    case 'angdim'
      V = e.pts(1,:);
      P1 = e.pts(2,:);
      P2 = e.pts(3,:);
      am = (atan2d (P1(2) - V(2), P1(1) - V(1)) ...
            + atan2d (P2(2) - V(2), P2(1) - V(1))) / 2;
      A = V + e.radius * [cosd(am), sind(am)];
      d.pts = [A; A; V; P1; V; P2];
      d.angles = 2;

  endswitch

endfunction

## The label a dimension gives itself from its own measurement, which is what
## 'diam', 'radius' and 'angdim' store when the caller names none.  Kept
## beside dimrecord so the two cannot drift apart.
function t = autolabel (e, kind)

  switch (kind)
    case 'diam'
      t = sprintf ('%%%%c%g', round (2 * e.radius * 1000) / 1000);
    case 'radius'
      t = sprintf ('R%g', round (e.radius * 1000) / 1000);
    case 'angdim'
      V = e.pts(1,:);
      P1 = e.pts(2,:);
      P2 = e.pts(3,:);
      a = mod (atan2d (P2(2) - V(2), P2(1) - V(1)) ...
               - atan2d (P1(2) - V(2), P1(1) - V(1)), 360);
      t = sprintf ('%g%%%%d', round (a * 100) / 100);
    otherwise
      t = '';
  endswitch

endfunction

## The empty entity array, in dxf.write's vocabulary.  Field order is fixed so
## that the array grows by assignment.
function E = emptyentity ()

  E = struct ('type', {}, 'layer', {}, 'linetype', {}, 'colour', {}, ...
              'pts', {}, 'closed', {}, ...
              'radius', {}, 'angles', {}, 'text', {}, 'height', {}, ...
              'rotation', {}, 'bulge', {}, 'block', {});

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
              'rotation', 0, 'bulge', [], 'block', '');

endfunction

## A diameter or radius dimension: the measuring line, a tick where it meets
## the feature, and the text.  A diameter runs right across; a radius runs from
## the centre out, which is why the two share everything but their first point.
function parts = explodecirc (e, scale)

  tick = 1.25 * scale;
  hgt = 2.5 * scale;
  u = [cosd(e.angle), sind(e.angle)];
  outer = e.pts + e.radius * u;
  if (strcmp (e.type, 'diam'))
    inner = e.pts - e.radius * u;
  else
    inner = e.pts;
  endif

  n = [-u(2), u(1)];
  parts = mkent ('LINE', e, [inner; outer]);
  parts(end+1) = mkent ('LINE', e, [outer - tick * (u + n) / sqrt(2); ...
                                    outer + tick * (u + n) / sqrt(2)]);
  if (strcmp (e.type, 'diam'))
    parts(end+1) = mkent ('LINE', e, [inner - tick * (u + n) / sqrt(2); ...
                                      inner + tick * (u + n) / sqrt(2)]);
  endif

  t = mkent ('TEXT', e, outer + 0.5 * hgt * (u + n));
  t.text = e.text;
  t.height = hgt;
  t.rotation = 0;
  parts(end+1) = t;

endfunction

## An angular dimension: the arc between the arms, a tick at each end, and the
## text outside the arc at its middle
function parts = explodeang (e, scale)

  tick = 1.25 * scale;
  hgt = 2.5 * scale;
  V = e.pts(1,:);
  a1 = atan2 (e.pts(2,2) - V(2), e.pts(2,1) - V(1)) * 180 / pi;
  a2 = atan2 (e.pts(3,2) - V(2), e.pts(3,1) - V(1)) * 180 / pi;

  arc = mkent ('ARC', e, V);
  arc.radius = e.radius;
  arc.angles = [mod(a1, 360), mod(a2, 360)];
  parts = arc;

  for a = [a1, a2]
    u = [cosd(a), sind(a)];
    n = [-u(2), u(1)];
    p = V + e.radius * u;
    parts(end+1) = mkent ('LINE', e, [p - tick * n / 2; p + tick * n / 2]);
  endfor

  am = a1 + mod (a2 - a1, 360) / 2;
  t = mkent ('TEXT', e, V + (e.radius + 0.5 * hgt) * [cosd(am), sind(am)]);
  t.text = e.text;
  t.height = hgt;
  t.rotation = 0;
  parts(end+1) = t;

endfunction

## A centre mark: the small cross, with arms reaching a little past a small
## feature and stopping short of a large one, as the convention has it
function parts = explodemark (e, scale)

  a = max (min (e.radius / 4, 3 * scale), 0.5 * scale);
  C = e.pts;
  parts = mkent ('LINE', e, [C - [a, 0]; C + [a, 0]]);
  parts(end+1) = mkent ('LINE', e, [C - [0, a]; C + [0, a]]);

endfunction

## A leader: the path, a tick at the feature end, and the note at the tail
function parts = explodeleader (e, scale)

  tick = 1.25 * scale;
  hgt = 2.5 * scale;
  P = e.pts;
  parts = mkent ('POLYLINE', e, P);

  d = P(2,:) - P(1,:);
  if (norm (d) > 0)
    u = d / norm (d);
    n = [-u(2), u(1)];
    parts(end+1) = mkent ('LINE', e, [P(1,:); P(1,:) + tick * (u + n / 2)]);
    parts(end+1) = mkent ('LINE', e, [P(1,:); P(1,:) + tick * (u - n / 2)]);
  endif

  t = mkent ('TEXT', e, P(end,:) + [0.3 * hgt, 0.3 * hgt]);
  t.text = e.text;
  t.height = hgt;
  t.rotation = 0;
  parts(end+1) = t;

endfunction

## The ellipse, parameterised for geom.curvesample
function P = ellipsepts (t, C, a, b, c, s)

  x = a * cos (t);
  y = b * sin (t);
  P = [C(1) + x * c - y * s, C(2) + x * s + y * c];

endfunction

## Replace a bulged polyline's vertices with points along its arcs, for a
## consumer that has no notion of a bulge
function Q = flattenbulge (e, tol)

  P = e.pts;
  n = rows (P);
  if (e.closed)
    last = n;
  else
    last = n - 1;
  endif

  Q = P(1,:);
  for k = 1:last
    j = mod (k, n) + 1;
    bl = 0;
    if (numel (e.bulge) >= k)
      bl = e.bulge(k);
    endif
    if (bl == 0)
      Q(end+1,:) = P(j,:);
      continue;
    endif
    ## bulge is tan of a quarter of the included angle
    inc = 4 * atan (bl);
    chord = P(j,:) - P(k,:);
    L = norm (chord);
    R = L / (2 * abs (sin (inc / 2)));
    h = sqrt (max (0, R ^ 2 - (L / 2) ^ 2)) * sign (cos (inc / 2));
    mid = (P(k,:) + P(j,:)) / 2;
    nrm = [-chord(2), chord(1)] / L;
    ctr = mid + sign (bl) * h * nrm;
    a1 = atan2 (P(k,2) - ctr(2), P(k,1) - ctr(1));
    steps = max (2, ceil (abs (inc) / (2 * acos (max (-1, 1 - tol / R)))));
    for m = 1:steps
      a = a1 + inc * m / steps;
      Q(end+1,:) = ctr + R * [cos(a), sin(a)];
    endfor
  endfor
  if (e.closed)
    Q(end,:) = [];
  endif

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
## same as in draw.Drawing.entities -- it has to be, or the two outputs would
## disagree
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

## The tests for this classdef are in inst/tests/Drawing.m-tst, which is
## where a classdef of this size keeps them; this block is here so the
## file is not reported as untested.
%!test  # see inst/tests/Drawing.m-tst for the tests of this class
%! assert_equal (isempty (draw.Drawing ()), true);
