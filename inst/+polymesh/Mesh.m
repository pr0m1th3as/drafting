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

classdef Mesh
  ## -*- texinfo -*-
  ## @deftp {drafting} polymesh.Mesh
  ##
  ## A triangle mesh in millimetres.
  ##
  ## @code{polymesh.Mesh} holds a surface made of flat triangles: the points
  ## of its vertices, the triangles as indices into them, and optionally a
  ## colour for each vertex or each triangle.  It is what
  ## @code{polymesh.read} makes of an STL, OBJ or PLY file, what its method
  ## @code{write} saves to one, and what @code{solid.polyhedron} builds a
  ## solid from.  A mesh from elsewhere, such as the faces and vertices
  ## @code{isosurface} returns, becomes one through the constructor.
  ##
  ## A mesh is measured by @code{area}, @code{volume} and @code{bbox}, moved
  ## by @code{translate}, @code{rotate}, @code{mirror} and @code{scale} as a
  ## @code{solid.Shape} is, and cut with a plane into regions by
  ## @code{section}.
  ##
  ## @example
  ## @group
  ## ## A tetrahedron, its triangles turned outwards
  ## V = [0, 0, 0; 10, 0, 0; 0, 10, 0; 0, 0, 10];
  ## F = [1, 3, 2; 1, 2, 4; 2, 3, 4; 3, 1, 4];
  ## C = [1, 0, 0; 0, 1, 0; 0, 0, 1; 1, 1, 0];
  ## M = polymesh.Mesh (V, F, 'FaceColour', C);
  ## volume (M)
  ## @result{} 166.67
  ## @end group
  ## @end example
  ##
  ## The class is a @emph{value} class.  Every operation returns a new mesh
  ## and leaves its operand unchanged.  The vertices and triangles are set
  ## when the mesh is made; the colours can be set at any time.
  ##
  ## @seealso{polymesh.read, polymesh.Mesh.write, solid.polyhedron}
  ## @end deftp

  properties (SetAccess = private)

    ## -*- texinfo -*-
    ## @deftp {polymesh.Mesh} {property} Vertices
    ##
    ## Points of the mesh
    ##
    ## The vertices as an @math{N}-by-3 matrix of @var{x}, @var{y} and
    ## @var{z} in millimetres.
    ##
    ## @end deftp
    Vertices = zeros (0, 3);

    ## -*- texinfo -*-
    ## @deftp {polymesh.Mesh} {property} Faces
    ##
    ## Triangles of the mesh
    ##
    ## The triangles as a @math{K}-by-3 matrix of indices into the rows of
    ## @code{Vertices}, one row for each triangle.  The order of its corners
    ## turns the triangle: seen from the side its normal points to, they run
    ## anticlockwise.
    ##
    ## @end deftp
    Faces = zeros (0, 3);

  endproperties

  properties

    ## -*- texinfo -*-
    ## @deftp {polymesh.Mesh} {property} VertexColour
    ##
    ## Colour of each vertex
    ##
    ## An @math{N}-by-3 matrix of red, green and blue from 0 to 1, a row for
    ## each vertex, or empty for none.
    ##
    ## @end deftp
    VertexColour = [];

    ## -*- texinfo -*-
    ## @deftp {polymesh.Mesh} {property} FaceColour
    ##
    ## Colour of each triangle
    ##
    ## A @math{K}-by-3 matrix of red, green and blue from 0 to 1, a row for
    ## each triangle, or empty for none.
    ##
    ## @end deftp
    FaceColour = [];

  endproperties

  methods (Hidden)

    function disp (this)

      c = '';
      if (! isempty (this.VertexColour))
        c = ", vertex colours";
      endif
      if (! isempty (this.FaceColour))
        c = [c, ", face colours"];
      endif
      vn = rows (this.Vertices);
      vw = 'vertex';
      if (vn != 1)
        vw = 'vertices';
      endif
      tn = rows (this.Faces);
      tw = 'triangle';
      if (tn != 1)
        tw = 'triangles';
      endif
      printf ("  polymesh.Mesh: %d %s, %d %s%s\n", vn, vw, tn, tw, c);

    endfunction

  endmethods

  methods (Access = public)

    ## -*- texinfo -*-
    ## @deftypefn  {polymesh.Mesh} {@var{M} =} polymesh.Mesh ()
    ## @deftypefnx {polymesh.Mesh} {@var{M} =} polymesh.Mesh (@var{V}, @var{F})
    ## @deftypefnx {polymesh.Mesh} {@var{M} =} polymesh.Mesh (@var{S})
    ## @deftypefnx {polymesh.Mesh} {@var{M} =} polymesh.Mesh (@dots{}, @var{name}, @var{value})
    ##
    ## Make a triangle mesh.
    ##
    ## @code{@var{M} = polymesh.Mesh ()} returns the empty mesh, which has no
    ## vertices and no triangles.
    ##
    ## @code{@var{M} = polymesh.Mesh (@var{V}, @var{F})} makes the mesh of the
    ## points @var{V}, an @math{N}-by-3 matrix, and the triangles @var{F}, a
    ## @math{K}-by-3 matrix of indices into the rows of @var{V}.
    ##
    ## @code{@var{M} = polymesh.Mesh (@var{S})} takes them from a struct with
    ## the fields @code{vertices} and @code{faces}, the form @code{patch},
    ## @code{isosurface} and @code{reducepatch} use.
    ##
    ## @multitable @columnfractions 0.25 0.75
    ## @headitem Name @tab Value
    ## @item @qcode{'VertexColour'} @tab an @math{N}-by-3 matrix of red, green
    ## and blue from 0 to 1, a row for each vertex
    ## @item @qcode{'FaceColour'} @tab a @math{K}-by-3 matrix of red, green
    ## and blue from 0 to 1, a row for each triangle
    ## @end multitable
    ##
    ## A vertex that no triangle uses is kept, and so is a triangle two of
    ## whose corners are one vertex.
    ##
    ## @end deftypefn
    function this = Mesh (varargin)

      if (nargin == 0)
        return;
      endif

      ## Input validation
      if (isstruct (varargin{1}))
        S = varargin{1};
        if (! isscalar (S) || ! isfield (S, 'vertices') ||
            ! isfield (S, 'faces'))
          error (strcat ("polymesh.Mesh: S must be a scalar struct with", ...
                         " the fields vertices and faces."));
        endif
        V = S.vertices;
        F = S.faces;
        args = varargin(2:end);
      elseif (nargin >= 2)
        V = varargin{1};
        F = varargin{2};
        args = varargin(3:end);
      else
        error ("polymesh.Mesh: invalid number of input arguments.");
      endif
      if (isempty (V))
        V = zeros (0, 3);
      endif
      if (isempty (F))
        F = zeros (0, 3);
      endif
      if (! isnumeric (V) || ! isreal (V) || ! ismatrix (V) ||
          columns (V) != 3 || ! all (isfinite (V(:))))
        error (strcat ("polymesh.Mesh: V must be an N-by-3 matrix of", ...
                       " finite real values."));
      endif
      if (! isnumeric (F) || ! isreal (F) || ! ismatrix (F) ||
          columns (F) != 3 || any (F(:) != fix (F(:))) ||
          any (F(:) < 1) || any (F(:) > rows (V)))
        error (strcat ("polymesh.Mesh: F must be a K-by-3 matrix of", ...
                       " indices into the rows of V."));
      endif
      if (mod (numel (args), 2) != 0)
        error ("polymesh.Mesh: Name/Value arguments must come in pairs.");
      endif

      this.Vertices = double (V);
      this.Faces = double (F);
      for ii = 1:2:numel (args)
        name = args{ii};
        val = args{ii+1};
        if (! ischar (name) || ! isrow (name))
          error ("polymesh.Mesh: option names must be character vectors.");
        endif
        switch (lower (name))
          case 'vertexcolour'
            this.VertexColour = val;
          case 'facecolour'
            this.FaceColour = val;
          otherwise
            error ("polymesh.Mesh: unknown option '%s'.", name);
        endswitch
      endfor

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {polymesh.Mesh} {@var{R} =} section (@var{M}, @var{U})
    ## @deftypefnx {polymesh.Mesh} {@var{R} =} section (@var{M}, @var{U}, @qcode{'Tolerance'}, @var{T})
    ## @deftypefnx {polymesh.Mesh} {[@var{R}, @var{OPEN}] =} section (@dots{})
    ##
    ## Cut a mesh with a plane.
    ##
    ## @code{@var{R} = section (@var{M}, @var{U})} cuts the mesh @var{M} with
    ## the plane of the @code{geom.UCS} @var{U}, and returns the cut as
    ## @code{solid.Shape.section} returns the cut of a solid: a
    ## 1-by-@math{N} cell array of @code{geom.Region} objects in @var{U}, one
    ## for each separate piece, largest first, each an outline with the holes
    ## in it, or the empty @code{cell (1, 0)} when the cut has no area.  A
    ## face of the mesh lying in the plane is part of the cut.
    ##
    ## The cut of a mesh is a polygon, and the regions are made of straight
    ## segments, exact for the mesh: a round hole in a mesh is a polygon of
    ## its facets.  The triangles may be turned either way, inwards or
    ## outwards, which many files get wrong; outlines and holes are told
    ## apart by how they nest.  @code{geom.Region.fit} turns the polygon back
    ## into lines, arcs and splines within a tolerance, so that a faceted
    ## bore is a circle again.
    ##
    ## @code{@var{R} = section (@var{M}, @var{U}, @qcode{'Tolerance'},
    ## @var{T})} heals a mesh with gaps: where the cut through it breaks off,
    ## ends closer than @var{T} are joined, nearest first, and points of the
    ## cut closer than @var{T} are taken as one.  The default @var{T} is a
    ## millionth of the size of the mesh, which joins nothing but rounding.
    ##
    ## @code{[@var{R}, @var{OPEN}] = section (@dots{})} returns in @var{OPEN}
    ## what could not be made into regions, as a cell array of @math{N}-by-2
    ## polylines in the coordinates of @var{U}: chains that still break off,
    ## where the mesh has a hole wider than @var{T}, and loops that cross
    ## themselves or one another, where the mesh does.  A closed loop repeats
    ## its first point at its end.
    ##
    ## @example
    ## @group
    ## ## A slice half way up a part, healed where it was saved with gaps
    ## M = polymesh.read ('part.stl');
    ## [R, OPEN] = section (M, geom.UCS ([0, 0, 1], [0, 0, 12]), ...
    ##                      'Tolerance', 0.01);
    ## @end group
    ## @end example
    ##
    ## @seealso{solid.Shape.section, geom.Region, geom.Region.fit}
    ## @end deftypefn
    function [R, OPEN] = section (this, U, varargin)

      ## Input validation
      if (nargin < 2)
        error ("polymesh.Mesh.section: invalid number of input arguments.");
      endif
      if (! isa (U, 'geom.UCS') || ! isscalar (U))
        error ("polymesh.Mesh.section: U must be a geom.UCS object.");
      endif
      V = this.Vertices;
      if (mod (numel (varargin), 2) != 0)
        error (strcat ("polymesh.Mesh.section: Name/Value arguments must", ...
                       " come in pairs."));
      endif
      T = 1e-6 * norm (max (V, [], 1) - min (V, [], 1));
      for ii = 1:2:numel (varargin)
        name = varargin{ii};
        val = varargin{ii+1};
        if (! ischar (name) || ! isrow (name))
          error (strcat ("polymesh.Mesh.section: option names must be", ...
                         " character vectors."));
        endif
        switch (lower (name))
          case 'tolerance'
            T = val;
            if (! isnumeric (T) || ! isreal (T) || ! isscalar (T)
                || ! isfinite (T) || T < 0)
              error (strcat ("polymesh.Mesh.section: Tolerance must be a", ...
                             " non-negative finite real scalar."));
            endif
          otherwise
            error ("polymesh.Mesh.section: unknown option '%s'.", name);
        endswitch
      endfor

      R = cell (1, 0);
      OPEN = cell (1, 0);
      if (isempty (this.Faces))
        return;
      endif
      L = (V - U.Origin) * [U.XAxis; U.YAxis; U.Normal]';
      [P, OPEN] = __mesh__ ('section', 'polymesh.Mesh.section', L, ...
                            this.Faces, double (T));
      R = cell (1, numel (P));
      for k = 1:numel (P)
        R{k} = __trusted__ (geom.Region ([0, 0; 1, 0; 0, 1]), ...
                            P{k}.outline, P{k}.holes);
        R{k}.UCS = U;
      endfor

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {polymesh.Mesh} {} write (@var{M}, @var{FILE})
    ## @deftypefnx {polymesh.Mesh} {} write (@var{M}, @var{FILE}, @qcode{'Encoding'}, @var{E})
    ##
    ## Write a mesh to an STL, OBJ, PLY or 3MF file.
    ##
    ## @code{write (@var{M}, @var{FILE})} writes the mesh @var{M} to
    ## @var{FILE}, in the format the extension of @var{FILE} names,
    ## @file{.stl}, @file{.obj}, @file{.ply} or @file{.3mf} in any case, with
    ## its colours where the format holds them.
    ##
    ## @itemize
    ## @item
    ## An STL file is binary: each triangle its normal, computed from its
    ## corners, and its corners as 32-bit floats, about seven significant
    ## figures.  It holds no colours.
    ##
    ## @item
    ## An OBJ file is text, each coordinate in the fewest digits that read
    ## back as the same number.  A vertex's colour follows its coordinates.
    ## Face colours are materials, one for each distinct colour, in a
    ## library beside @var{FILE} with its name and the extension
    ## @file{.mtl}, which replaces any file of that name.
    ##
    ## @item
    ## A PLY file is binary, little-endian, its coordinates 64-bit floats.
    ## Colours are the properties @qcode{red}, @qcode{green} and
    ## @qcode{blue} of its vertices and of its faces, as @qcode{uchar} from 0
    ## to 255.
    ##
    ## @item
    ## A 3MF file is the archive slicers take, in millimetres: one object
    ## named after @var{FILE}, each coordinate in the fewest digits that read
    ## back as the same number, and the colours of the triangles as base
    ## materials.  It holds no vertex colours.  The empty mesh cannot be
    ## written to it.
    ## @end itemize
    ##
    ## @code{write (@var{M}, @var{FILE}, @qcode{'Encoding'}, @var{E})}
    ## writes a PLY file as text, each coordinate in the fewest digits that
    ## read back as the same number, when @var{E} is @qcode{'ascii'}, or
    ## binary when it is @qcode{'binary'}, the default; no other format
    ## takes it.
    ##
    ## So OBJ, PLY and 3MF keep every coordinate exactly, and STL keeps a few
    ## microns on a part tens of millimetres across.  @code{polymesh.read}
    ## reads all four back.
    ##
    ## @seealso{polymesh.read}
    ## @end deftypefn
    function write (this, FILE, varargin)

      ## Input validation
      if (nargin < 2)
        error ("polymesh.Mesh.write: invalid number of input arguments.");
      endif
      if (! ischar (FILE) || ! isrow (FILE))
        error ("polymesh.Mesh.write: FILE must be a character vector.");
      endif
      [~, ~, ext] = fileparts (FILE);
      fmt = lower (ext);
      if (! any (strcmp (fmt, {'.stl', '.obj', '.ply', '.3mf'})))
        error (strcat ("polymesh.Mesh.write: FILE must end in .stl, .obj,", ...
                       " .ply or .3mf."));
      endif
      if (mod (numel (varargin), 2) != 0)
        error ("polymesh.Mesh.write: Name/Value arguments must come in pairs.");
      endif
      binary = true;
      for ii = 1:2:numel (varargin)
        name = varargin{ii};
        val = varargin{ii+1};
        if (! ischar (name) || ! isrow (name))
          error (strcat ("polymesh.Mesh.write: option names must be", ...
                         " character vectors."));
        endif
        switch (lower (name))
          case 'encoding'
            E = val;
            if (! ischar (E) || ! any (strcmp (E, {'binary', 'ascii'})))
              error (strcat ("polymesh.Mesh.write: Encoding must be", ...
                             " 'binary' or 'ascii'."));
            endif
            if (! strcmp (fmt, '.ply'))
              error (strcat ("polymesh.Mesh.write: Encoding applies only", ...
                             " to PLY files."));
            endif
            binary = strcmp (E, 'binary');
          otherwise
            error ("polymesh.Mesh.write: unknown option '%s'.", name);
        endswitch
      endfor

      if (strcmp (fmt, '.3mf'))
        if (isempty (this))
          error ("polymesh.Mesh.write: a 3MF file cannot hold the empty mesh.");
        endif
        [~, base] = fileparts (FILE);
        __mesh__ ('write3mf', 'polymesh.Mesh.write', FILE, {base}, ...
                  {this.Vertices}, {this.Faces}, {this.FaceColour}, {[]});
      else
        __mesh__ ('write', 'polymesh.Mesh.write', FILE, this.Vertices, ...
                  this.Faces, this.VertexColour, this.FaceColour, ...
                  fmt(2:end), binary);
      endif

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {polymesh.Mesh} {} show (@var{M})
    ## @deftypefnx {polymesh.Mesh} {@var{V} =} show (@var{M})
    ##
    ## Show a mesh in a viewer of its own, redrawing in place.
    ##
    ## @code{show (@var{M})} shows the mesh in a @code{model.Viewer} kept
    ## for its variable and titled with its name, which opens the first time
    ## and redraws in place after, the camera where it was; a mesh given as an
    ## expression rather than a variable shares one viewer with the rest.
    ## The mesh is
    ## shaded facet by facet in its faces' colours where it has them, else in
    ## its vertices', else in grey.  In the viewer @kbd{C} turns to its other
    ## colourings and @kbd{E} draws its triangle edges or hides them.
    ##
    ## @code{@var{V} = show (@var{M})} also returns the viewer, a
    ## @code{model.Viewer}, whose @code{pick} returns points clicked on the
    ## mesh and @code{pickucs} a coordinate system.
    ##
    ## The viewer is built with the package when Open CASCADE and X11 are
    ## found, and needs a display to run.  It runs on Linux.
    ##
    ## @seealso{model.Viewer, solid.Shape.show}
    ## @end deftypefn
    function V = show (this)

      viewer = model.Viewer.__named__ (inputname (1, false));
      viewer.Shape = this;
      if (nargout > 0)
        V = viewer;
      endif

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {polymesh.Mesh} {@var{M} =} translate (@var{M}, @var{V})
    ##
    ## Move a mesh by the vector @var{V}.
    ##
    ## @var{V} is a 3-element vector in millimetres.
    ##
    ## @seealso{polymesh.Mesh.rotate, polymesh.Mesh.mirror, polymesh.Mesh.scale}
    ## @end deftypefn
    function this = translate (this, V)

      ## Input validation
      if (nargin != 2)
        error ("polymesh.Mesh.translate: invalid number of input arguments.");
      endif
      errmsg = checkvec (V, 'V');
      if (! isempty (errmsg))
        error ("polymesh.Mesh.translate: %s", errmsg);
      endif

      this.Vertices = this.Vertices + double (V(:)');

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {polymesh.Mesh} {@var{M} =} rotate (@var{M}, @var{ANGLE}, @var{AXIS})
    ## @deftypefnx {polymesh.Mesh} {@var{M} =} rotate (@var{M}, @var{ANGLE}, @var{AXIS}, @var{P})
    ##
    ## Rotate a mesh about an axis.
    ##
    ## @var{ANGLE} is in degrees and turns the mesh anticlockwise when seen
    ## from the tip of @var{AXIS} looking back, the right-hand rule.
    ## @var{AXIS} is a nonzero 3-element direction, and @var{P} a point on
    ## the axis, the origin by default.
    ##
    ## @seealso{polymesh.Mesh.translate, polymesh.Mesh.mirror,
    ## polymesh.Mesh.scale}
    ## @end deftypefn
    function this = rotate (this, ANGLE, AXIS, P = [0, 0, 0])

      ## Input validation
      if (nargin < 3 || nargin > 4)
        error ("polymesh.Mesh.rotate: invalid number of input arguments.");
      endif
      if (! isnumeric (ANGLE) || ! isreal (ANGLE) || ! isscalar (ANGLE) ||
          ! isfinite (ANGLE))
        error ("polymesh.Mesh.rotate: ANGLE must be a finite real scalar.");
      endif
      errmsg = checkvec (AXIS, 'AXIS', true);
      if (isempty (errmsg))
        errmsg = checkvec (P, 'P');
      endif
      if (! isempty (errmsg))
        error ("polymesh.Mesh.rotate: %s", errmsg);
      endif

      k = double (AXIS(:)) / norm (double (AXIS(:)));
      K = [0, -k(3), k(2); k(3), 0, -k(1); -k(2), k(1), 0];
      R = eye (3) + sind (ANGLE) * K + (1 - cosd (ANGLE)) * K ^ 2;
      P = double (P(:)');
      this.Vertices = (this.Vertices - P) * R' + P;

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {polymesh.Mesh} {@var{M} =} mirror (@var{M}, @var{N})
    ## @deftypefnx {polymesh.Mesh} {@var{M} =} mirror (@var{M}, @var{N}, @var{P})
    ##
    ## Reflect a mesh in a plane.
    ##
    ## The plane passes through the point @var{P}, the origin by default,
    ## with the nonzero 3-element normal @var{N}.  The corners of every
    ## triangle are taken in the other order, so a triangle turned outwards
    ## stays turned outwards.
    ##
    ## @seealso{polymesh.Mesh.translate, polymesh.Mesh.rotate,
    ## polymesh.Mesh.scale}
    ## @end deftypefn
    function this = mirror (this, N, P = [0, 0, 0])

      ## Input validation
      if (nargin < 2 || nargin > 3)
        error ("polymesh.Mesh.mirror: invalid number of input arguments.");
      endif
      errmsg = checkvec (N, 'N', true);
      if (isempty (errmsg))
        errmsg = checkvec (P, 'P');
      endif
      if (! isempty (errmsg))
        error ("polymesh.Mesh.mirror: %s", errmsg);
      endif

      n = double (N(:)') / norm (double (N(:)));
      D = (this.Vertices - double (P(:)')) * n';
      this.Vertices = this.Vertices - 2 * D * n;
      this.Faces = this.Faces(:,[1, 3, 2]);

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {polymesh.Mesh} {@var{M} =} scale (@var{M}, @var{F})
    ## @deftypefnx {polymesh.Mesh} {@var{M} =} scale (@var{M}, @var{F}, @var{P})
    ##
    ## Scale a mesh uniformly about a point.
    ##
    ## Every length is multiplied by the positive factor @var{F}, so the
    ## volume grows by its cube.  @var{P}, the origin by default, is the
    ## point that stays where it is.
    ##
    ## @seealso{polymesh.Mesh.translate, polymesh.Mesh.rotate,
    ## polymesh.Mesh.mirror}
    ## @end deftypefn
    function this = scale (this, F, P = [0, 0, 0])

      ## Input validation
      if (nargin < 2 || nargin > 3)
        error ("polymesh.Mesh.scale: invalid number of input arguments.");
      endif
      if (! isnumeric (F) || ! isreal (F) || ! isscalar (F) ||
          ! isfinite (F) || F <= 0)
        error (strcat ("polymesh.Mesh.scale: F must be a positive and", ...
                       " finite real scalar."));
      endif
      errmsg = checkvec (P, 'P');
      if (! isempty (errmsg))
        error ("polymesh.Mesh.scale: %s", errmsg);
      endif

      P = double (P(:)');
      this.Vertices = (this.Vertices - P) * double (F) + P;

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {polymesh.Mesh} {@var{A} =} area (@var{M})
    ##
    ## The surface area of a mesh in square millimetres.
    ##
    ## The area is the sum of the areas of the triangles.  The empty mesh has
    ## area zero.
    ##
    ## @seealso{polymesh.Mesh.volume}
    ## @end deftypefn
    function A = area (this)

      [a, b, c] = corners (this);
      A = sum (sqrt (sum (cross (b - a, c - a, 2) .^ 2, 2))) / 2;

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {polymesh.Mesh} {@var{V} =} volume (@var{M})
    ##
    ## The volume a closed mesh encloses, in cubic millimetres.
    ##
    ## The mesh must be closed, as @code{isclosed} tells; an open mesh
    ## encloses nothing and is an error.  The volume is the same whichever
    ## way the triangles are turned, as long as they all agree.  The empty
    ## mesh has volume zero.
    ##
    ## @seealso{polymesh.Mesh.isclosed, polymesh.Mesh.area}
    ## @end deftypefn
    function V = volume (this)

      if (! isclosed (this))
        error (strcat ("polymesh.Mesh.volume: M must be closed, every", ...
                       " edge shared by two triangles turned opposite", ...
                       " ways."));
      endif
      [a, b, c] = corners (this);
      V = abs (sum (dot (a, cross (b, c, 2), 2))) / 6;

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {polymesh.Mesh} {@var{B} =} bbox (@var{M})
    ## @deftypefnx {polymesh.Mesh} {[@var{B}, @var{L}] =} bbox (@var{M})
    ##
    ## Axis-aligned extents of a mesh.
    ##
    ## @var{B} is the 1-by-6 vector @code{[@var{xmin}, @var{ymin},
    ## @var{zmin}, @var{xmax}, @var{ymax}, @var{zmax}]} in millimetres, and
    ## @var{L} the 1-by-3 vector of the lengths along each axis.  Only the
    ## vertices of triangles count.  The empty mesh has no extent and returns
    ## an empty @var{B} and @var{L}.
    ##
    ## @seealso{solid.Shape.bbox}
    ## @end deftypefn
    function [B, L] = bbox (this)

      if (isempty (this.Faces))
        B = [];
        L = [];
      else
        V = this.Vertices(unique (this.Faces(:)),:);
        B = [min(V, [], 1), max(V, [], 1)];
        L = B(4:6) - B(1:3);
      endif

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {polymesh.Mesh} {@var{TF} =} isclosed (@var{M})
    ##
    ## True if a mesh is closed.
    ##
    ## A mesh is closed when every edge is shared by exactly two triangles
    ## turned opposite ways, so that the triangles agree on which side is
    ## out.  Edges are told by their vertices, not by their points: two
    ## vertices at the same point are not joined.  The empty mesh is closed.
    ##
    ## @seealso{polymesh.Mesh.volume, solid.polyhedron}
    ## @end deftypefn
    function TF = isclosed (this)

      F = this.Faces;
      E = [F(:,[1, 2]); F(:,[2, 3]); F(:,[3, 1])];
      TF = (rows (unique (E, 'rows')) == rows (E)) ...
           && all (ismember (E(:,[2, 1]), E, 'rows'));

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {polymesh.Mesh} {@var{TF} =} isempty (@var{M})
    ##
    ## True for a mesh with no triangles.
    ##
    ## @end deftypefn
    function TF = isempty (this)

      if (! isscalar (this))
        TF = (numel (this) == 0);
      else
        TF = isempty (this.Faces);
      endif

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {polymesh.Mesh} {@var{N} =} numvertices (@var{M})
    ##
    ## The number of vertices of a mesh.
    ##
    ## @seealso{polymesh.Mesh.numfaces}
    ## @end deftypefn
    function N = numvertices (this)

      N = rows (this.Vertices);

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {polymesh.Mesh} {@var{N} =} numfaces (@var{M})
    ##
    ## The number of triangles of a mesh.
    ##
    ## @seealso{polymesh.Mesh.numvertices}
    ## @end deftypefn
    function N = numfaces (this)

      N = rows (this.Faces);

    endfunction

  endmethods

  methods

    function this = set.VertexColour (this, C)

      if (! iscolour (C, rows (this.Vertices)))
        error (strcat ("polymesh.Mesh: VertexColour must be empty or an", ...
                       " N-by-3 matrix of values from 0 to 1, a row for", ...
                       " each vertex."));
      endif
      this.VertexColour = double (C);

    endfunction

    function this = set.FaceColour (this, C)

      if (! iscolour (C, rows (this.Faces)))
        error (strcat ("polymesh.Mesh: FaceColour must be empty or a", ...
                       " K-by-3 matrix of values from 0 to 1, a row for", ...
                       " each triangle."));
      endif
      this.FaceColour = double (C);

    endfunction

  endmethods

endclassdef

## The corners of every triangle of M, three K-by-3 matrices
function [a, b, c] = corners (M)

  V = M.Vertices;
  F = M.Faces;
  a = V(F(:,1),:);
  b = V(F(:,2),:);
  c = V(F(:,3),:);

endfunction

## Returns an error message body, empty when V is a real 3-element vector of
## finite values, and nonzero when NONZERO is true
function errmsg = checkvec (V, name, nonzero = false)

  errmsg = '';
  if (! isnumeric (V) || ! isreal (V) || numel (V) != 3 ||
      ! isvector (V) || ! all (isfinite (V)))
    errmsg = sprintf (strcat ("%s must be a real 3-element vector of", ...
                              " finite values."), name);
  elseif (nonzero && all (V == 0))
    errmsg = sprintf ("%s must not be the zero vector.", name);
  endif

endfunction

## True when C is empty or an N-by-3 matrix of values from 0 to 1
function TF = iscolour (C, N)

  TF = isempty (C) || (isfloat (C) && isreal (C) && ismatrix (C) ...
                       && isequal (size (C), [N, 3]) ...
                       && all (C(:) >= 0 & C(:) <= 1));

endfunction

## The unit cube, its triangles turned outwards, and the prism over the
## anticlockwise polygon P, its caps the triangles T, from z = 0 to z = H,
## and the torus of N by N quadrilaterals, for the tests
%!function M = unitcube ()
%!  V = [0, 0, 0; 1, 0, 0; 1, 1, 0; 0, 1, 0; ...
%!       0, 0, 1; 1, 0, 1; 1, 1, 1; 0, 1, 1];
%!  F = [1, 3, 2; 1, 4, 3; 5, 6, 7; 5, 7, 8; 1, 2, 6; 1, 6, 5; ...
%!       2, 3, 7; 2, 7, 6; 3, 4, 8; 3, 8, 7; 4, 1, 5; 4, 5, 8];
%!  M = polymesh.Mesh (V, F);
%!endfunction
%!function M = prismmesh (P, T, H)
%!  n = rows (P);
%!  V = [P, zeros(n, 1); P, H * ones(n, 1)];
%!  i = (1:n)';
%!  j = [2:n, 1]';
%!  F = [T(:,[1, 3, 2]); T + n; i, j, j + n; i, j + n, i + n];
%!  M = polymesh.Mesh (V, F);
%!endfunction
%!function M = torusmesh (N, R, r)
%!  [u, v] = ndgrid ((0:N-1) / N * 2 * pi);
%!  V = [(R + r * cos(v(:))) .* cos(u(:)), (R + r * cos(v(:))) .* sin(u(:)), ...
%!       r * sin(v(:))];
%!  id = reshape (1:N*N, N, N);
%!  a = id;
%!  b = circshift (id, -1, 1);
%!  c = circshift (id, -1, 2);
%!  d = circshift (b, -1, 2);
%!  M = polymesh.Mesh (V, [a(:), b(:), d(:); a(:), d(:), c(:)]);
%!endfunction

%!test  # the empty mesh
%! M = polymesh.Mesh ();
%! assert_equal (size (M.Vertices), [0, 3]);
%! assert_equal (size (M.Faces), [0, 3]);
%! assert_equal (isempty (M), true);
%! assert_equal (isempty (polymesh.Mesh ([], [])), true);

%!test  # from vertices and faces, or from a struct
%! M = polymesh.Mesh (single ([0, 0, 0; 1, 0, 0; 0, 1, 0]), int32 ([1, 2, 3]));
%! assert_equal (M.Vertices, [0, 0, 0; 1, 0, 0; 0, 1, 0]);
%! assert_equal (M.Faces, [1, 2, 3]);
%! S = struct ('vertices', [0, 0, 0; 1, 0, 0; 0, 1, 0], 'faces', [1, 2, 3]);
%! assert_equal (polymesh.Mesh (S).Faces, [1, 2, 3]);

%!test  # an unused vertex and a collapsed triangle are kept
%! M = polymesh.Mesh ([0, 0, 0; 1, 0, 0; 0, 1, 0; 5, 5, 5], [1, 2, 3; 1, 1, 2]);
%! assert_equal (numvertices (M), 4);
%! assert_equal (numfaces (M), 2);

%!test  # colours given, set and cleared
%! M = polymesh.Mesh ([0, 0, 0; 1, 0, 0; 0, 1, 0], [1, 2, 3], ...
%!                    'FaceColour', [1, 0, 0], 'VertexColour', eye (3));
%! assert_equal (M.FaceColour, [1, 0, 0]);
%! assert_equal (M.VertexColour, eye (3));
%! M.FaceColour = single ([0, 0.5, 1]);
%! assert_equal (M.FaceColour, [0, 0.5, 1]);
%! M.VertexColour = [];
%! assert_equal (M.VertexColour, []);

%!test  # translate, rotate, scale and mirror move the vertices
%! M = polymesh.Mesh ([1, 0, 0; 2, 0, 0; 1, 1, 0], [1, 2, 3]);
%! assert_equal (translate (M, [1, 2, 3]).Vertices, ...
%!               [2, 2, 3; 3, 2, 3; 2, 3, 3]);
%! assert_equal (rotate (M, 90, [0, 0, 1]).Vertices, ...
%!               [0, 1, 0; 0, 2, 0; -1, 1, 0]);
%! assert_equal (rotate (M, 180, [0, 0, 1], [1, 0, 0]).Vertices, ...
%!               [1, 0, 0; 0, 0, 0; 1, -1, 0]);
%! assert_equal (scale (M, 2, [1, 0, 0]).Vertices, [1, 0, 0; 3, 0, 0; 1, 2, 0]);
%! assert_equal (mirror (M, [1, 0, 0], [1, 0, 0]).Vertices, ...
%!               [1, 0, 0; 0, 0, 0; 1, 1, 0]);

%!test  # a mirrored mesh stays turned outwards; colours go with it
%! M = unitcube ();
%! M.FaceColour = repmat ([1, 0, 0], 12, 1);
%! R = mirror (M, [1, 1, 0]);
%! assert_equal (isclosed (R), true);
%! assert_equal (R.Faces, M.Faces(:,[1, 3, 2]));
%! assert_equal (R.FaceColour, M.FaceColour);

%!test  # area, volume and extents of the unit cube
%! M = unitcube ();
%! assert_equal (area (M), 6);
%! assert_equal (volume (M), 1);
%! assert_equal (volume (scale (M, 3)), 27, 1e-12);
%! [B, L] = bbox (translate (M, [1, 2, 3]));
%! assert_equal (B, [1, 2, 3, 2, 3, 4]);
%! assert_equal (L, [1, 1, 1]);

%!test  # the volume does not depend on which way all triangles are turned
%! M = unitcube ();
%! assert_equal (volume (polymesh.Mesh (M.Vertices, fliplr (M.Faces))), 1);

%!test  # the empty mesh: no extent, area or volume
%! M = polymesh.Mesh ();
%! assert_equal (bbox (M), []);
%! assert_equal (area (M), 0);
%! assert_equal (volume (M), 0);
%! assert_equal (isclosed (M), true);

%!test  # a missing triangle, or one turned against the rest, opens a mesh
%! M = unitcube ();
%! M2 = polymesh.Mesh (M.Vertices, M.Faces(2:end,:));
%! assert_equal (isclosed (M2), false);
%! F = M.Faces;
%! F(1,:) = F(1,[1, 3, 2]);
%! assert_equal (isclosed (polymesh.Mesh (M.Vertices, F)), false);

%!test  # section: a box cut through the middle
%! M = prismmesh ([0, 0; 10, 0; 10, 20; 0, 20], [1, 2, 3; 1, 3, 4], 30);
%! U = geom.UCS ([0, 0, 1], [0, 0, 15]);
%! R = section (M, U);
%! assert_equal (numel (R), 1);
%! assert_equal (R{1}.UCS, U);
%! assert_equal (__area__ (R{1}.Outline), 200, 1e-9);
%! assert_equal (rows (R{1}.Outline.Vertices), 4);

%!test  # section: a face in the plane is the cut, below the mesh or above it
%! M = prismmesh ([0, 0; 10, 0; 10, 20; 0, 20], [1, 2, 3; 1, 3, 4], 30);
%! R = section (M, geom.UCS ([0, 0, 1], [0, 0, 0]));
%! assert_equal (__area__ (R{1}.Outline), 200, 1e-9);
%! R = section (M, geom.UCS ([0, 0, 1], [0, 0, 30]));
%! assert_equal (__area__ (R{1}.Outline), 200, 1e-9);

%!test  # section: a face in the plane and a cut, one piece
%! P = [0, 0; 30, 0; 30, 5; 5, 5; 5, 20; 0, 20];
%! M = prismmesh (P, [1, 2, 3; 1, 3, 4; 1, 4, 6; 4, 5, 6], 10);
%! R = section (M, geom.UCS ([0, 1, 0], [0, 5, 0]));
%! assert_equal (numel (R), 1);
%! assert_equal (__area__ (R{1}.Outline), 300, 1e-9);

%!test  # section: missed, or touched along an edge
%! M = prismmesh ([0, 0; 10, 0; 10, 20; 0, 20], [1, 2, 3; 1, 3, 4], 30);
%! assert_equal (section (M, geom.UCS ([0, 0, 1], [0, 0, 31])), cell (1, 0));
%! assert_equal (section (M, geom.UCS ([1, 1, 0], [0, 0, 0])), cell (1, 0));
%! assert_equal (section (polymesh.Mesh (), geom.UCS ()), cell (1, 0));

%!test  # section: a torus through a ring of its vertices, an outline and a hole
%! N = 48;
%! R = section (torusmesh (N, 10, 2), geom.UCS ([0, 0, 1], [0, 0, 0]));
%! assert_equal (numel (R), 1);
%! assert_equal (numel (R{1}.Holes), 1);
%! A = @(r) N / 2 * r ^ 2 * sin (2 * pi / N);
%! assert_equal (__area__ (R{1}.Outline), A (12), 1e-9);
%! assert_equal (__area__ (R{1}.Holes{1}), -A (8), 1e-9);

%!test  # section: separate pieces, largest first; triangles turned either way
%! P = [0, 0; 30, 0; 30, 20; 25, 20; 25, 5; 10, 5; 10, 20; 0, 20];
%! T = [1, 2, 5; 2, 3, 4; 2, 4, 5; 1, 5, 6; 1, 6, 7; 1, 7, 8];
%! M = prismmesh (P, T, 10);
%! U = geom.UCS ([0, 1, 0], [0, 10, 0]);
%! R = section (M, U);
%! assert_equal (cellfun (@(r) abs (__area__ (r.Outline)), R), [100, 50], 1e-9);
%! F = M.Faces;
%! F(1:2:end,:) = fliplr (F(1:2:end,:));
%! R = section (polymesh.Mesh (M.Vertices, F), U);
%! assert_equal (cellfun (@(r) abs (__area__ (r.Outline)), R), [100, 50], 1e-9);

%!test  # section: cracks, joined within a tolerance, or left open
%! M = prismmesh ([0, 0; 10, 0; 10, 20; 0, 20], [1, 2, 3; 1, 3, 4], 30);
%! V = [M.Vertices; M.Vertices(7,:) + [1e-4, 0, 0]];
%! F = M.Faces;
%! k = find (any (F == 7, 2) & any (F == 3, 2), 1);
%! F(k, F(k,:) == 7) = 9;
%! M = polymesh.Mesh (V, F);
%! U = geom.UCS ([0, 0, 1], [0, 0, 15]);
%! [R, OPEN] = section (M, U, 'Tolerance', 0);
%! assert_equal (R, cell (1, 0));
%! assert_equal (numel (OPEN), 2);
%! [R, OPEN] = section (M, U, 'Tolerance', 1e-3);
%! assert_equal (numel (R), 1);
%! assert_equal (OPEN, cell (1, 0));
%! assert_equal (__area__ (R{1}.Outline), 200, 2e-3);

%!test  # section: a cylinder of 64 facets cut, and fitted back into a circle
%! a = (0:63)' * 2 * pi / 64;
%! T = [ones(62, 1), (2:63)', (3:64)'];
%! M = prismmesh ([10 * cos(a), 10 * sin(a)], T, 20);
%! R = section (M, geom.UCS ([0, 0, 1], [0, 0, 7]));
%! assert_equal (rows (R{1}.Outline.Vertices), 64);
%! F = fit (R{1});
%! assert_equal (rows (F.Outline.Vertices), 2);
%! assert_equal (__area__ (F.Outline), 100 * pi, 1e-9);
%! assert_equal (F.UCS, R{1}.UCS);

## A tetrahedron turned outwards whose coordinates have no short binary
## form; the mesh M read back after it is written to a file with the
## extension EXT, and the text of that file
%!function M = oddtetra ()
%!  V = [0.1, 0.2, 0.3; pi, 0.2, 0.3; 0.1, exp(1), 0.3; 0.1, 0.2, 1/3];
%!  M = polymesh.Mesh (V, [1, 3, 2; 1, 2, 4; 2, 3, 4; 3, 1, 4]);
%!endfunction
%!function R = writeread (M, ext, varargin)
%!  f = [tempname(), ext];
%!  unwind_protect
%!    write (M, f, varargin{:});
%!    R = polymesh.read (f);
%!  unwind_protect_cleanup
%!    delete (f);
%!    if (isfile ([f(1:end-4), '.mtl']))
%!      delete ([f(1:end-4), '.mtl']);
%!    endif
%!  end_unwind_protect
%!endfunction
%!function t = writtentext (M, ext, varargin)
%!  f = [tempname(), ext];
%!  unwind_protect
%!    write (M, f, varargin{:});
%!    t = fileread (f);
%!  unwind_protect_cleanup
%!    delete (f);
%!  end_unwind_protect
%!endfunction

%!test  # write: through OBJ, exactly
%! M = oddtetra ();
%! R = writeread (M, '.obj');
%! assert_equal (R.Vertices(R.Faces',:), M.Vertices(M.Faces',:));

%!test  # write: through binary PLY, exactly
%! M = oddtetra ();
%! R = writeread (M, '.ply');
%! assert_equal (R.Vertices(R.Faces',:), M.Vertices(M.Faces',:));

%!test  # write: through ASCII PLY, exactly
%! M = oddtetra ();
%! R = writeread (M, '.PLY', 'Encoding', 'ascii');
%! assert_equal (R.Vertices(R.Faces',:), M.Vertices(M.Faces',:));

%!test  # write: through STL, as 32-bit floats
%! M = oddtetra ();
%! R = writeread (M, '.stl');
%! assert_equal (R.Vertices(R.Faces',:), ...
%!               double (single (M.Vertices(M.Faces',:))));

%!test  # write: OBJ text, each number in the fewest digits that read back
%! t = writtentext (oddtetra (), '.obj');
%! assert_equal (strncmp (t, '#', 1), true);
%! assert_equal (! isempty (strfind (t, "\nv 0.1 0.2 0.3\n")), true);
%! assert_equal (! isempty (strfind (t, "\nf 1 3 2\n")), true);

%!test  # write: the PLY header names the encoding; ASCII faces count from 0
%! t = writtentext (oddtetra (), '.ply', 'Encoding', 'ascii');
%! assert_equal (strncmp (t, "ply\nformat ascii 1.0\n", 21), true);
%! assert_equal (! isempty (strfind (t, "\n3 0 2 1\n")), true);
%! t = writtentext (oddtetra (), '.ply');
%! assert_equal (strncmp (t, "ply\nformat binary_little_endian 1.0\n", 36), ...
%!               true);

%!test  # write: STL, 84 bytes and 50 a triangle, each normal of unit length
%! f = [tempname(), '.stl'];
%! unwind_protect
%!   write (unitcube (), f);
%!   fid = fopen (f, 'r');
%!   b = fread (fid, Inf, 'uint8=>uint8');
%!   fclose (fid);
%! unwind_protect_cleanup
%!   delete (f);
%! end_unwind_protect
%! assert_equal (numel (b), 84 + 50 * 12);
%! B = reshape (b(85:end), 50, 12);
%! N = reshape (typecast (reshape (B(1:12,:), [], 1), 'single'), 3, 12);
%! assert_equal (double (sum (N .^ 2, 1)), ones (1, 12), 1e-6);

%!test  # write: OBJ vertex colours, exactly
%! M = oddtetra ();
%! M.VertexColour = [0.1, 0.2, 0.3; 1, 0, 0; 1/3, 2/3, 1; 0, 0, 0];
%! R = writeread (M, '.obj');
%! assert_equal (R.VertexColour(R.Faces',:), M.VertexColour(M.Faces',:));
%! assert_equal (R.FaceColour, []);

%!test  # write: OBJ face colours as materials in a library beside the file
%! M = oddtetra ();
%! M.FaceColour = [1, 0, 0; 1, 0, 0; 0, 0, 1; 0.25, 1/3, 0.75];
%! f = [tempname(), '.obj'];
%! l = [f(1:end-4), '.mtl'];
%! unwind_protect
%!   write (M, f);
%!   [~, name] = fileparts (l);
%!   assert_equal (! isempty (strfind (fileread (f), ...
%!                                     ["mtllib ", name, ".mtl\n"])), true);
%!   assert_equal (numel (strfind (fileread (l), "newmtl")), 3);
%!   R = polymesh.read (f);
%!   assert_equal (R.FaceColour, M.FaceColour);
%! unwind_protect_cleanup
%!   delete (f);
%!   delete (l);
%! end_unwind_protect

%!test  # write: binary PLY colours to the nearest 255th
%! M = oddtetra ();
%! M.VertexColour = [0.1, 0.2, 0.3; 1, 0, 0; 1/3, 2/3, 1; 0, 0, 0];
%! M.FaceColour = [1, 0, 0; 0.5, 0.5, 0.5; 0, 0, 1; 0.25, 1/3, 0.75];
%! R = writeread (M, '.ply');
%! assert_equal (R.VertexColour(R.Faces',:), M.VertexColour(M.Faces',:), ...
%!               0.5 / 255);
%! assert_equal (R.FaceColour, M.FaceColour, 0.5 / 255);

%!test  # write: ASCII PLY colours to the nearest 255th
%! M = oddtetra ();
%! M.VertexColour = [0.1, 0.2, 0.3; 1, 0, 0; 1/3, 2/3, 1; 0, 0, 0];
%! M.FaceColour = [1, 0, 0; 0.5, 0.5, 0.5; 0, 0, 1; 0.25, 1/3, 0.75];
%! R = writeread (M, '.ply', 'Encoding', 'ascii');
%! assert_equal (R.VertexColour(R.Faces',:), M.VertexColour(M.Faces',:), ...
%!               0.5 / 255);
%! assert_equal (R.FaceColour, M.FaceColour, 0.5 / 255);

## The model of the 3MF file F, its XML
%!function t = modelxml (f)
%!  d = tempname ();
%!  unwind_protect
%!    unzip (f, d);
%!    t = fileread (fullfile (d, '3D', '3dmodel.model'));
%!  unwind_protect_cleanup
%!    confirm_recursive_rmdir (false, 'local');
%!    rmdir (d, 's');
%!  end_unwind_protect
%!endfunction

%!testif ; ! isempty (file_in_path (getenv ('PATH'), 'unzip')) || ! isempty (file_in_path (getenv ('PATH'), 'unzip.exe'))
%! ## write: 3MF, one object named after the file, in millimetres
%! f = [tempname(), '.3mf'];
%! [~, base] = fileparts (f);
%! unwind_protect
%!   write (oddtetra (), f);
%!   t = modelxml (f);
%!   assert_equal (! isempty (strfind (t, 'unit="millimeter"')), true);
%!   assert_equal (! isempty (strfind (t, ['name="', base, '"'])), true);
%!   assert_equal (numel (strfind (t, '<vertex ')), 4);
%!   assert_equal (numel (strfind (t, '<triangle ')), 4);
%!   v = '<vertex x="0.1" y="0.2" z="0.3"/>';
%!   assert_equal (! isempty (strfind (t, v)), true);
%! unwind_protect_cleanup
%!   [~] = unlink (f);
%! end_unwind_protect

%!testif ; ! isempty (file_in_path (getenv ('PATH'), 'unzip')) || ! isempty (file_in_path (getenv ('PATH'), 'unzip.exe'))
%! ## write: 3MF face colours as base materials
%! M = oddtetra ();
%! M.FaceColour = [1, 0, 0; 1, 0, 0; 0, 0, 1; 0.2, 0.4, 0.6];
%! f = [tempname(), '.3mf'];
%! unwind_protect
%!   write (M, f);
%!   t = modelxml (f);
%!   assert_equal (numel (strfind (t, '<base ')), 3);
%!   assert_equal (! isempty (strfind (t, 'displaycolor="#336699"')), true);
%!   assert_equal (numel (strfind (t, 'pid="1" p1=')), 4);
%! unwind_protect_cleanup
%!   [~] = unlink (f);
%! end_unwind_protect

%!test  # write: STL has no colours
%! M = oddtetra ();
%! M.FaceColour = repmat ([1, 0, 0], 4, 1);
%! R = writeread (M, '.stl');
%! assert_equal (R.FaceColour, []);
%! assert_equal (R.VertexColour, []);

%!test  # write: the empty mesh, and back
%! assert_equal (isempty (writeread (polymesh.Mesh (), '.stl')), true);
%! assert_equal (isempty (writeread (polymesh.Mesh (), '.obj')), true);
%! assert_equal (isempty (writeread (polymesh.Mesh (), '.ply')), true);

%!testif ; ! isempty (getenv ('DISPLAY'))
%! ## show: the mesh in its variable's viewer
%! old = getappdata (0, 'drafting_model_show');
%! VP = model.Viewer ('Hidden', true);
%! setappdata (0, 'drafting_model_show', struct ('v_part', VP.Id));
%! unwind_protect
%!   part = unitcube ();
%!   W = show (part);
%!   assert_equal (W.Id, VP.Id);
%!   assert_equal (VP.__title__ (), 'part (drafting)');
%!   assert_equal (VP.Shape.Faces, part.Faces);
%! unwind_protect_cleanup
%!   close (VP);
%!   setappdata (0, 'drafting_model_show', old);
%! end_unwind_protect

%!error<polymesh.Mesh: invalid number of input arguments.> ...
%! polymesh.Mesh (zeros (0, 3))
%!error<polymesh.Mesh: S must be a scalar struct with the fields vertices and faces.> ...
%! polymesh.Mesh (struct ('vertices', zeros (0, 3)))
%!error<polymesh.Mesh: V must be an N-by-3 matrix of finite real values.> ...
%! polymesh.Mesh ([0, 0; 1, 0; 0, 1], [1, 2, 3])
%!error<polymesh.Mesh: V must be an N-by-3 matrix of finite real values.> ...
%! polymesh.Mesh ([0, 0, 0; 1, 0, 0; 0, NaN, 0], [1, 2, 3])
%!error<polymesh.Mesh: F must be a K-by-3 matrix of indices into the rows of V.> ...
%! polymesh.Mesh ([0, 0, 0; 1, 0, 0; 0, 1, 0], [1, 2, 4])
%!error<polymesh.Mesh: F must be a K-by-3 matrix of indices into the rows of V.> ...
%! polymesh.Mesh ([0, 0, 0; 1, 0, 0; 0, 1, 0], [0, 1, 2])
%!error<polymesh.Mesh: F must be a K-by-3 matrix of indices into the rows of V.> ...
%! polymesh.Mesh ([0, 0, 0; 1, 0, 0; 0, 1, 0], [1, 2.5, 3])
%!error<polymesh.Mesh: F must be a K-by-3 matrix of indices into the rows of V.> ...
%! polymesh.Mesh ([0, 0, 0; 1, 0, 0; 0, 1, 0], [1, 2, 3, 1])
%!error<polymesh.Mesh: Name/Value arguments must come in pairs.> ...
%! polymesh.Mesh ([0, 0, 0; 1, 0, 0; 0, 1, 0], [1, 2, 3], 'FaceColour')
%!error<polymesh.Mesh: unknown option 'Colour'.> ...
%! polymesh.Mesh ([0, 0, 0; 1, 0, 0; 0, 1, 0], [1, 2, 3], 'Colour', [1, 0, 0])
%!error<polymesh.Mesh: option names must be character vectors.> ...
%! polymesh.Mesh ([0, 0, 0; 1, 0, 0; 0, 1, 0], [1, 2, 3], 1, [1, 0, 0])
%!test  # option names ignore case
%! M = polymesh.Mesh ([0, 0, 0; 1, 0, 0; 0, 1, 0], [1, 2, 3], ...
%!                    'facecolour', [1, 0, 0]);
%! assert_equal (M.FaceColour, [1, 0, 0]);
%!error<polymesh.Mesh: VertexColour must be empty or an N-by-3 matrix of values from 0 to 1, a row for each vertex.> ...
%! polymesh.Mesh ([0, 0, 0; 1, 0, 0; 0, 1, 0], [1, 2, 3], ...
%!                'VertexColour', [1, 0, 0])
%!error<polymesh.Mesh: VertexColour must be empty or an N-by-3 matrix of values from 0 to 1, a row for each vertex.> ...
%! polymesh.Mesh ([0, 0, 0; 1, 0, 0; 0, 1, 0], [1, 2, 3], ...
%!                'VertexColour', uint8 (eye (3)))
%!error<polymesh.Mesh: FaceColour must be empty or a K-by-3 matrix of values from 0 to 1, a row for each triangle.> ...
%! polymesh.Mesh ([0, 0, 0; 1, 0, 0; 0, 1, 0], [1, 2, 3], ...
%!                'FaceColour', [1.5, 0, 0])
%!error<polymesh.Mesh: FaceColour must be empty or a K-by-3 matrix of values from 0 to 1, a row for each triangle.> ...
%! polymesh.Mesh ([0, 0, 0; 1, 0, 0; 0, 1, 0], [1, 2, 3], ...
%!                'FaceColour', [NaN, 0, 0])
%!error<polymesh.Mesh.translate: invalid number of input arguments.> ...
%! translate (polymesh.Mesh ())
%!error<polymesh.Mesh.translate: V must be a real 3-element vector of finite values.> ...
%! translate (polymesh.Mesh (), [1, 2])
%!error<polymesh.Mesh.rotate: invalid number of input arguments.> ...
%! rotate (polymesh.Mesh (), 90)
%!error<polymesh.Mesh.rotate: ANGLE must be a finite real scalar.> ...
%! rotate (polymesh.Mesh (), Inf, [0, 0, 1])
%!error<polymesh.Mesh.rotate: AXIS must not be the zero vector.> ...
%! rotate (polymesh.Mesh (), 90, [0, 0, 0])
%!error<polymesh.Mesh.rotate: P must be a real 3-element vector of finite values.> ...
%! rotate (polymesh.Mesh (), 90, [0, 0, 1], [0, 0])
%!error<polymesh.Mesh.mirror: invalid number of input arguments.> ...
%! mirror (polymesh.Mesh ())
%!error<polymesh.Mesh.mirror: N must not be the zero vector.> ...
%! mirror (polymesh.Mesh (), [0, 0, 0])
%!error<polymesh.Mesh.mirror: P must be a real 3-element vector of finite values.> ...
%! mirror (polymesh.Mesh (), [1, 0, 0], NaN (1, 3))
%!error<polymesh.Mesh.scale: invalid number of input arguments.> ...
%! scale (polymesh.Mesh ())
%!error<polymesh.Mesh.scale: F must be a positive and finite real scalar.> ...
%! scale (polymesh.Mesh (), 0)
%!error<polymesh.Mesh.scale: P must be a real 3-element vector of finite values.> ...
%! scale (polymesh.Mesh (), 2, 'abc')
%!error<polymesh.Mesh.volume: M must be closed, every edge shared by two triangles turned opposite ways.> ...
%! volume (polymesh.Mesh ([0, 0, 0; 1, 0, 0; 0, 1, 0], [1, 2, 3]))
%!error<polymesh.Mesh.section: invalid number of input arguments.> ...
%! section (polymesh.Mesh ())
%!error<polymesh.Mesh.section: U must be a geom.UCS object.> ...
%! section (polymesh.Mesh (), 1)
%!error<polymesh.Mesh.section: unknown option 'Heal'.> ...
%! section (polymesh.Mesh (), geom.UCS (), 'Heal', 1)
%!error<polymesh.Mesh.section: option names must be character vectors.> ...
%! section (polymesh.Mesh (), geom.UCS (), 1, 1)
%!error<polymesh.Mesh.section: Name/Value arguments must come in pairs.> ...
%! section (polymesh.Mesh (), geom.UCS (), 'Tolerance')
%!test  # option names ignore case
%! M = tessellate (solid.box (2, 2, 2));
%! U = geom.UCS ([0, 0, 1], [0, 0, 1]);
%! R1 = section (M, U, 'tolerance', 1e-3);
%! R2 = section (M, U, 'Tolerance', 1e-3);
%! S1 = solid.extrude (R1{1}, 1);
%! S2 = solid.extrude (R2{1}, 1);
%! assert_equal (isequal (S1, S2), true);
%!error<polymesh.Mesh.section: Tolerance must be a non-negative finite real scalar.> ...
%! section (polymesh.Mesh (), geom.UCS (), 'Tolerance', NaN)
%!error<polymesh.Mesh.write: invalid number of input arguments.> ...
%! write (polymesh.Mesh ())
%!error<polymesh.Mesh.write: Name/Value arguments must come in pairs.> ...
%! write (polymesh.Mesh (), 'a.ply', 'Encoding')
%!error<polymesh.Mesh.write: FILE must be a character vector.> ...
%! write (polymesh.Mesh (), 42)
%!error<polymesh.Mesh.write: FILE must end in .stl, .obj, .ply or .3mf.> ...
%! write (polymesh.Mesh (), 'a.off')
%!error<polymesh.Mesh.write: unknown option 'Format'.> ...
%! write (polymesh.Mesh (), 'a.ply', 'Format', 'ascii')
%!error<polymesh.Mesh.write: option names must be character vectors.> ...
%! write (polymesh.Mesh (), 'a.ply', 1, 'ascii')
%!test  # option names ignore case
%! f = [tempname(), '.ply'];
%! unwind_protect
%!   write (tessellate (solid.box (1, 1, 1)), f, 'encoding', 'ascii');
%!   assert_equal (strncmp (fileread (f), "ply\nformat ascii", 16), true);
%! unwind_protect_cleanup
%!   [~] = unlink (f);
%! end_unwind_protect
%!error<polymesh.Mesh.write: Encoding must be 'binary' or 'ascii'.> ...
%! write (polymesh.Mesh (), 'a.ply', 'Encoding', 'text')
%!error<polymesh.Mesh.write: Encoding applies only to PLY files.> ...
%! write (polymesh.Mesh (), 'a.obj', 'Encoding', 'ascii')
%!error<polymesh.Mesh.write: cannot open '.*' for writing.> ...
%! write (polymesh.Mesh (), fullfile (tempname (), 'a.obj'))
%!error<polymesh.Mesh.write: a 3MF file cannot hold the empty mesh.> ...
%! write (polymesh.Mesh (), 'a.3mf')
