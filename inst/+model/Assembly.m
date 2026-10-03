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

classdef Assembly
  ## -*- texinfo -*-
  ## @deftp {drafting} model.Assembly
  ##
  ## Named parts placed together.
  ##
  ## @code{model.Assembly} holds a product as CAD programs exchange one: a
  ## tree of named parts, each placed in the frame of a @code{geom.UCS}, and
  ## of assemblies placed the same way, each part a @code{solid.Shape} or a
  ## @code{polymesh.Mesh}.  A part is defined once and placed as often as it
  ## is used, so the twenty pins of a ring are one part placed twenty
  ## times, as STEP and 3MF keep them.  Each part keeps its colours.
  ##
  ## @example
  ## @group
  ## pin = solid.cylinder (2, 12);
  ## pin.Colour = [0.8, 0.8, 0.8];
  ## A = model.Assembly ('ring');
  ## A = add (A, 'plate', solid.box (60, 60, 4), ...
  ##          geom.UCS ([0, 0, 1], [-30, -30, -4]));
  ## A = add (A, 'pin', pin, geom.UCS ([0, 0, 1], [20, 0, 0]));
  ## A = add (A, 'pin', [], geom.UCS ([0, 0, 1], [-20, 0, 0]));
  ## write (A, 'ring.step');
  ## @end group
  ## @end example
  ##
  ## The class is a @emph{value} class: @code{add} returns a new assembly and
  ## leaves its operand unchanged.
  ##
  ## @seealso{model.read, solid.Shape, geom.UCS}
  ## @end deftp

  properties (SetAccess = private)

    ## -*- texinfo -*-
    ## @deftp {model.Assembly} {property} Name
    ##
    ## Name of the assembly
    ##
    ## The name STEP gives the product.
    ##
    ## @end deftp
    Name = 'assembly';

    ## -*- texinfo -*-
    ## @deftp {model.Assembly} {property} Parts
    ##
    ## Parts defined
    ##
    ## A struct array with the fields @code{name} and @code{item}, the
    ## @code{solid.Shape} or the @code{model.Assembly} defined under that
    ## name, one element for each part however often it is placed.
    ##
    ## @end deftp
    Parts = struct ('name', {}, 'item', {});

    ## -*- texinfo -*-
    ## @deftp {model.Assembly} {property} Instances
    ##
    ## Parts placed
    ##
    ## A struct array with the fields @code{name}, the name of the placement,
    ## @code{part}, the name of the part placed, and @code{placement}, the
    ## @code{geom.UCS} whose frame the part's own coordinates are taken in.
    ##
    ## @end deftp
    Instances = struct ('name', {}, 'part', {}, 'placement', {});

  endproperties

  methods (Hidden)

    function disp (this)

      printf ("  model.Assembly '%s': %d parts, %d placed\n", this.Name, ...
              numparts (this), numinstances (this));

    endfunction

  endmethods

  methods (Access = public)

    ## -*- texinfo -*-
    ## @deftypefn  {model.Assembly} {@var{A} =} model.Assembly ()
    ## @deftypefnx {model.Assembly} {@var{A} =} model.Assembly (@var{NAME})
    ##
    ## Make an empty assembly.
    ##
    ## @code{@var{A} = model.Assembly (@var{NAME})} returns an assembly named
    ## @var{NAME}, @qcode{'assembly'} by default, with no parts; @code{add}
    ## places them.
    ##
    ## @end deftypefn
    function this = Assembly (NAME = 'assembly')

      ## Input validation
      if (! ischar (NAME) || ! isrow (NAME) || isempty (NAME))
        error ("model.Assembly: NAME must be a non-empty character vector.");
      endif

      this.Name = NAME;

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {model.Assembly} {@var{A} =} add (@var{A}, @var{NAME}, @var{X}, @var{U})
    ## @deftypefnx {model.Assembly} {@var{A} =} add (@var{A}, @var{NAME}, [], @var{U})
    ## @deftypefnx {model.Assembly} {@var{A} =} add (@dots{}, @qcode{'Name'}, @var{INSTANCE})
    ##
    ## Place a part in an assembly.
    ##
    ## @code{@var{A} = add (@var{A}, @var{NAME}, @var{X}, @var{U})} places
    ## @var{X}, a @code{solid.Shape}, a @code{polymesh.Mesh} or a
    ## @code{model.Assembly}, as the part named @var{NAME}, its own
    ## coordinates taken in the frame of the @code{geom.UCS} @var{U}.  The
    ## frame is a rigid placement: a part mirrored is another part, made
    ## with @code{solid.Shape.mirror} or @code{polymesh.Mesh.mirror}.
    ##
    ## The first use of a name defines the part.  A later use places the same
    ## part again, and gives the same @var{X}, or @code{[]} for it; another
    ## @var{X} under a name already used is an error.
    ##
    ## Each placement is named after its part, @var{NAME} the first time and
    ## then @var{NAME}@code{:2}, @var{NAME}@code{:3} and so on;
    ## @qcode{'Name'} names it @var{INSTANCE} instead, which must not be used
    ## already.
    ##
    ## @seealso{model.Assembly.shape}
    ## @end deftypefn
    function this = add (this, NAME, X, U, varargin)

      ## Input validation
      if (nargin != 4 && nargin != 6)
        error ("model.Assembly.add: invalid number of input arguments.");
      endif
      if (! ischar (NAME) || ! isrow (NAME) || isempty (NAME))
        error (strcat ("model.Assembly.add: NAME must be a non-empty", ...
                       " character vector."));
      endif
      if (! isa (U, 'geom.UCS') || ! isscalar (U))
        error ("model.Assembly.add: U must be a geom.UCS object.");
      endif
      inst = NAME;
      used = {this.Instances.name};
      if (nargin == 6)
        if (! ischar (varargin{1}) || ! strcmp (varargin{1}, 'Name'))
          error ("model.Assembly.add: unknown parameter.");
        endif
        inst = varargin{2};
        if (! ischar (inst) || ! isrow (inst) || isempty (inst))
          error (strcat ("model.Assembly.add: INSTANCE must be a non-empty", ...
                         " character vector."));
        endif
        if (any (strcmp (inst, used)))
          error ("model.Assembly.add: a placement named '%s' exists.", inst);
        endif
      else
        n = 1;
        while (any (strcmp (inst, used)))
          n++;
          inst = sprintf ("%s:%d", NAME, n);
        endwhile
      endif
      k = find (strcmp (NAME, {this.Parts.name}));
      if (isnumeric (X) && isempty (X))
        if (isempty (k))
          error ("model.Assembly.add: no part named '%s' is defined yet.", ...
                 NAME);
        endif
      elseif (! ((isa (X, 'solid.Shape') || isa (X, 'polymesh.Mesh') ||
                  isa (X, 'model.Assembly')) && isscalar (X)))
        error (strcat ("model.Assembly.add: X must be a solid.Shape, a", ...
                       " polymesh.Mesh or a model.Assembly object, or empty."));
      elseif (isempty (k))
        if (! isa (X, 'model.Assembly') && isempty (X))
          error ("model.Assembly.add: the part '%s' is empty.", NAME);
        endif
        this.Parts(end+1) = struct ('name', NAME, 'item', X);
      elseif (! same (this.Parts(k).item, X))
        error (strcat ("model.Assembly.add: a part named '%s' is already", ...
                       " defined, as another shape."), NAME);
      endif
      this.Instances(end+1) = struct ('name', inst, 'part', NAME, ...
                                      'placement', U);

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {model.Assembly} {@var{S} =} shape (@var{A})
    ##
    ## Every part placed, as one shape.
    ##
    ## @code{@var{S} = shape (@var{A})} returns a @code{solid.Shape} holding
    ## the solids of every part where the assembly places it, sub-assemblies
    ## included, each in its part's colour.  The solids are kept apart, not
    ## united, so parts that touch stay separate solids.  This is the shape
    ## to measure, cut, show or tessellate.  The empty assembly gives the
    ## empty shape.  An assembly with a mesh among its parts has no exact
    ## shape and is an error; @code{tessellate} gives it whole as a mesh.
    ##
    ## @seealso{model.Assembly.tessellate, model.Assembly.write, solid.Shape}
    ## @end deftypefn
    function S = shape (this)

      S = solid.Shape ();
      if (isempty (this.Instances))
        return;
      endif
      name = meshpart (this);
      if (! isempty (name))
        error (strcat ("model.Assembly.shape: the part '%s' is a mesh; use", ...
                       " tessellate for the whole as a mesh."), name);
      endif
      errmsg = solid.__checkocct__ ();
      if (! isempty (errmsg))
        error ("model.Assembly.shape: %s", errmsg);
      endif
      n = numel (this.Instances);
      data = cell (1, n);
      C = cell (n, 1);
      for k = 1:n
        p = strcmp (this.Instances(k).part, {this.Parts.name});
        X = this.Parts(p).item;
        if (isa (X, 'model.Assembly'))
          X = shape (X);
        endif
        U = this.Instances(k).placement;
        data{k} = __occt__ ('place', 'model.Assembly.shape', X.Data, ...
                            [U.Origin; U.XAxis; U.YAxis; U.Normal]);
        C{k} = X.Colour;
        if (isempty (C{k}))
          C{k} = NaN (numsolids (X), 3);
        endif
      endfor
      r = __occt__ ('compound', 'model.Assembly.shape', data{:});
      S = solid.Shape (r{1});
      S.Colour = vertcat (C{:});

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {model.Assembly} {@var{M} =} tessellate (@var{A})
    ## @deftypefnx {model.Assembly} {@var{M} =} tessellate (@var{A}, @var{TOL})
    ##
    ## Every part placed, as one triangle mesh.
    ##
    ## @code{@var{M} = tessellate (@var{A}, @var{TOL})} returns a
    ## @code{polymesh.Mesh} of every part where the assembly places it,
    ## sub-assemblies included: each solid part as
    ## @code{solid.Shape.tessellate} makes it within @var{TOL} millimetres,
    ## 0.01 by default, and each mesh part as it is.  The parts keep their
    ## own vertices, so parts that touch are not joined.  A triangle keeps
    ## its part's colour, and is grey where its part has none, when any
    ## part has one.  The empty assembly gives the empty mesh.
    ##
    ## @seealso{model.Assembly.shape, solid.Shape.tessellate}
    ## @end deftypefn
    function M = tessellate (this, TOL = 0.01)

      ## Input validation
      errmsg = solid.__checkpos__ (TOL, 'TOL');
      if (! isempty (errmsg))
        error ("model.Assembly.tessellate: %s", errmsg);
      endif

      M = polymesh.Mesh ();
      n = numel (this.Instances);
      if (n == 0)
        return;
      endif
      [V, F, C] = deal (cell (n, 1));
      base = 0;
      for k = 1:n
        p = strcmp (this.Instances(k).part, {this.Parts.name});
        X = this.Parts(p).item;
        if (! isa (X, 'polymesh.Mesh'))
          X = tessellate (X, TOL);
        endif
        U = this.Instances(k).placement;
        V{k} = X.Vertices * [U.XAxis; U.YAxis; U.Normal] + U.Origin;
        F{k} = X.Faces + base;
        C{k} = X.FaceColour;
        if (isempty (C{k}))
          C{k} = NaN (numfaces (X), 3);
        endif
        base += numvertices (X);
      endfor
      C = vertcat (C{:});
      if (all (isnan (C(:))))
        C = [];
      else
        bare = isnan (C(:,1));
        C(bare,:) = repmat ([0.72, 0.74, 0.78], nnz (bare), 1);
      endif
      M = polymesh.Mesh (vertcat (V{:}), vertcat (F{:}), 'FaceColour', C);

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {model.Assembly} {} show (@var{A})
    ## @deftypefnx {model.Assembly} {@var{V} =} show (@var{A})
    ##
    ## Show an assembly in a viewer of its own, redrawing in place.
    ##
    ## @code{show (@var{A})} shows @code{shape (@var{A})} in the
    ## @code{model.Viewer} kept for the variable, as
    ## @code{solid.Shape.show} does, each part in its colour, or
    ## @code{tessellate (@var{A})} when a part is a mesh.
    ## @code{@var{V} = show (@var{A})} also returns the viewer.
    ##
    ## @seealso{model.Viewer, solid.Shape.show}
    ## @end deftypefn
    function V = show (this)

      viewer = model.Viewer.__named__ (inputname (1, false));
      if (isempty (meshpart (this)))
        viewer.Shape = shape (this);
      else
        viewer.Shape = tessellate (this);
      endif
      if (nargout > 0)
        V = viewer;
      endif

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {model.Assembly} {} write (@var{A}, @var{FILE})
    ## @deftypefnx {model.Assembly} {} write (@var{A}, @var{FILE}, @qcode{'Tolerance'}, @var{TOL})
    ##
    ## Write an assembly to a STEP, 3MF, STL, OBJ or PLY file.
    ##
    ## @code{write (@var{A}, @var{FILE})} writes the assembly in the format
    ## the extension of @var{FILE} names, in either case.  A STEP file,
    ## @file{.step} or @file{.stp}, keeps its structure: each part once, with
    ## its name and colours, placed by its placements, which carry their
    ## names, and each sub-assembly the same way, so that a CAD program opens
    ## the product as it was built; it cannot hold a mesh part.  A 3MF file,
    ## the archive slicers take, keeps the same structure, each part a mesh
    ## written once and placed as a component, in its colours.  An STL, OBJ
    ## or PLY file holds @code{tessellate (@var{A})}.
    ##
    ## @code{write (@dots{}, @qcode{'Tolerance'}, @var{TOL})} sets, for a
    ## mesh, how far its facets may stray from the parts' surfaces, as
    ## @code{solid.Shape.tessellate} takes it, 0.01 by default.
    ##
    ## @seealso{model.read, solid.write}
    ## @end deftypefn
    function write (this, FILE, varargin)

      ## Input validation
      if (nargin != 2 && nargin != 4)
        error ("model.Assembly.write: invalid number of input arguments.");
      endif
      if (! ischar (FILE) || ! isrow (FILE) || isempty (FILE))
        error (strcat ("model.Assembly.write: FILE must be a non-empty", ...
                       " character vector."));
      endif
      [~, ~, ext] = fileparts (FILE);
      fmt = lower (ext);
      if (! any (strcmp (fmt, {'.step', '.stp', '.3mf', '.stl', '.obj', ...
                               '.ply'})))
        error (strcat ("model.Assembly.write: FILE must end in .step,", ...
                       " .stp, .3mf, .stl, .obj or .ply."));
      endif
      isstep = any (strcmp (fmt, {'.step', '.stp'}));
      TOL = 0.01;
      if (nargin == 4)
        if (! ischar (varargin{1}) || ! strcmp (varargin{1}, 'Tolerance'))
          error ("model.Assembly.write: unknown parameter.");
        endif
        if (isstep)
          error ("model.Assembly.write: Tolerance applies to meshes only.");
        endif
        TOL = varargin{2};
        errmsg = solid.__checkpos__ (TOL, 'TOL');
        if (! isempty (errmsg))
          error ("model.Assembly.write: %s", errmsg);
        endif
      endif
      if (isempty (this.Instances))
        error ("model.Assembly.write: the assembly places nothing.");
      endif
      if (any (strcmp (fmt, {'.stl', '.obj', '.ply'})))
        write (tessellate (this, TOL), FILE);
        return;
      endif
      if (isstep)
        name = meshpart (this);
        if (! isempty (name))
          error (strcat ("model.Assembly.write: STEP cannot hold the mesh", ...
                         " part '%s'."), name);
        endif
        errmsg = solid.__checkocct__ ();
        if (! isempty (errmsg))
          error ("model.Assembly.write: %s", errmsg);
        endif
      endif

      T = struct ('names', {{}}, 'parts', {{}}, 'children', {{}}, ...
                  'instances', {{}});
      T = definitions (this, T);
      ispart = ! cellfun (@isempty, T.parts);
      if (strcmp (fmt, '.3mf'))
        n = numel (T.names);
        [V, F, FC] = deal (cell (1, n));
        for k = find (ispart)
          M = T.parts{k};
          if (! isa (M, 'polymesh.Mesh'))
            M = tessellate (M, TOL);
          endif
          [V{k}, F{k}, FC{k}] = deal (M.Vertices, M.Faces, M.FaceColour);
        endfor
        __mesh__ ('write3mf', 'model.Assembly.write', FILE, T.names, V, ...
                  F, FC, T.children);
      else
        data = repmat ({uint8([])}, 1, numel (T.names));
        colours = cell (1, numel (T.names));
        data(ispart) = cellfun (@(p) p.Data, T.parts(ispart), ...
                                'UniformOutput', false);
        colours(ispart) = cellfun (@(p) p.Colour, T.parts(ispart), ...
                                   'UniformOutput', false);
        __occt__ ('writeassembly', 'model.Assembly.write', FILE, T.names, ...
                  data, colours, T.children, T.instances);
      endif

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {model.Assembly} {@var{N} =} numparts (@var{A})
    ##
    ## The number of parts an assembly defines, however often each is
    ## placed.  A sub-assembly counts as one.
    ##
    ## @seealso{model.Assembly.numinstances}
    ## @end deftypefn
    function N = numparts (this)

      N = numel (this.Parts);

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {model.Assembly} {@var{N} =} numinstances (@var{A})
    ##
    ## The number of placements in an assembly, not counting those inside
    ## its sub-assemblies.
    ##
    ## @seealso{model.Assembly.numparts}
    ## @end deftypefn
    function N = numinstances (this)

      N = numel (this.Instances);

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {model.Assembly} {@var{TF} =} isempty (@var{A})
    ##
    ## True for an assembly that places nothing.
    ##
    ## @end deftypefn
    function TF = isempty (this)

      if (! isscalar (this))
        TF = (numel (this) == 0);
      else
        TF = isempty (this.Instances);
      endif

    endfunction

  endmethods

  methods (Static, Hidden)

    ## The assembly of the definitions model.read gets from a STEP file, as
    ## writeassembly takes them, the whole last: a part placed several times
    ## is one part.  A single part comes back placed in an assembly named
    ## NAME.
    function A = __fromtree__ (T, NAME)

      n = numel (T{1});
      D = cell (1, n);
      for i = 1:n
        if (! isempty (T{2}{i}))
          S = solid.Shape (T{2}{i});
          S.Colour = T{3}{i};
          D{i} = S;
        else
          A = model.Assembly (T{1}{i});
          C = T{4}{i};
          for k = 1:rows (C)
            f = C(k,2:13);
            U = geom.UCS (f(10:12), f(1:3), f(1:3) + f(4:6));
            A = add (A, T{1}{C(k,1)}, D{C(k,1)}, U, 'Name', T{5}{i}{k});
          endfor
          D{i} = A;
        endif
      endfor
      A = D{n};
      if (isa (A, 'solid.Shape'))
        A = add (model.Assembly (NAME), T{1}{n}, A, geom.UCS ());
      endif

    endfunction

    ## The assembly of the objects model.read gets from a 3MF file, as
    ## __mesh__ gives them: a mesh object a mesh part, a group of objects an
    ## assembly, the whole last.  A placement that is not rigid is applied to
    ## a copy of the part, placed where it is and named after it.
    function A = __from3mf__ (T)

      n = numel (T{1});
      D = cell (1, n);
      for i = 1:n
        if (isempty (T{5}{i}))
          D{i} = polymesh.Mesh (T{2}{i}, T{3}{i}, 'FaceColour', T{4}{i});
          continue;
        endif
        A = model.Assembly (T{1}{i});
        C = T{5}{i};
        for k = 1:rows (C)
          X = D{C(k,1)};
          if (isempty (X))
            continue;
          endif
          name = T{1}{C(k,1)};
          R = reshape (C(k,2:10), 3, 3)';
          O = C(k,11:13);
          if (norm (R * R' - eye (3), Inf) < 1e-9 && det (R) > 0)
            A = add (A, name, X, geom.UCS (R(3,:), O, O + R(1,:)));
          else
            if (isa (X, 'model.Assembly'))
              X = tessellate (X);
            endif
            F = X.Faces;
            if (det (R) < 0)
              F = F(:,[1, 3, 2]);
            endif
            X = polymesh.Mesh (X.Vertices * R + O, F, ...
                               'FaceColour', X.FaceColour);
            used = {A.Parts.name};
            name = [name, ' (placed)'];
            m = 1;
            while (any (strcmp (name, used)))
              m++;
              name = sprintf ("%s (placed %d)", T{1}{C(k,1)}, m);
            endwhile
            A = add (A, name, X, geom.UCS ());
          endif
        endfor
        D{i} = A;
      endfor
      A = D{n};

    endfunction

  endmethods

endclassdef

## The name of the first part of A that is a mesh, its own or one of its
## sub-assemblies', or empty when none is
function name = meshpart (A)

  name = '';
  for k = 1:numel (A.Parts)
    X = A.Parts(k).item;
    if (isa (X, 'polymesh.Mesh'))
      name = A.Parts(k).name;
    elseif (isa (X, 'model.Assembly'))
      name = meshpart (X);
    endif
    if (! isempty (name))
      return;
    endif
  endfor

endfunction

## True when the parts X and Y are the same: shapes of the same bytes and
## colours, or assemblies of the same name, parts and placements
function TF = same (X, Y)

  if (isa (X, 'solid.Shape') && isa (Y, 'solid.Shape'))
    TF = isequal (X.Data, Y.Data) && isequaln (X.Colour, Y.Colour);
  elseif (isa (X, 'polymesh.Mesh') && isa (Y, 'polymesh.Mesh'))
    TF = (isequal (X.Vertices, Y.Vertices) && isequal (X.Faces, Y.Faces) &&
          isequal (X.FaceColour, Y.FaceColour) &&
          isequal (X.VertexColour, Y.VertexColour));
  elseif (isa (X, 'model.Assembly') && isa (Y, 'model.Assembly'))
    P = [X.Instances.placement];
    Q = [Y.Instances.placement];
    TF = (strcmp (X.Name, Y.Name) && numel (X.Parts) == numel (Y.Parts) &&
          numel (X.Instances) == numel (Y.Instances) &&
          isequal ({X.Parts.name}, {Y.Parts.name}) &&
          isequal ({X.Instances.name}, {Y.Instances.name}) &&
          isequal ({X.Instances.part}, {Y.Instances.part}) &&
          all (arrayfun (@(k) same (X.Parts(k).item, Y.Parts(k).item),
                         1:numel (X.Parts))) &&
          all (arrayfun (@(k) P(k) == Q(k), 1:numel (P))));
  else
    TF = false;
  endif

endfunction

## T with the definitions of the assembly A added, the parts and
## sub-assemblies it places first, then A itself: each its name, its
## solid.Shape or [] for an assembly, and for an assembly the rows of its
## placements, the index from 1 of the definition placed and its frame,
## origin, x axis, y axis and normal, and the names of the placements
function T = definitions (A, T)

  idx = zeros (1, numel (A.Parts));
  for k = 1:numel (A.Parts)
    X = A.Parts(k).item;
    if (isa (X, 'model.Assembly'))
      T = definitions (X, T);
      T.names{end} = A.Parts(k).name;
    else
      T.names{end+1} = A.Parts(k).name;
      T.parts{end+1} = X;
      T.children{end+1} = [];
      T.instances{end+1} = {};
    endif
    idx(k) = numel (T.names);
  endfor
  n = numel (A.Instances);
  C = zeros (n, 13);
  for k = 1:n
    U = A.Instances(k).placement;
    C(k,:) = [idx(strcmp (A.Instances(k).part, {A.Parts.name})), ...
              U.Origin, U.XAxis, U.YAxis, U.Normal];
  endfor
  T.names{end+1} = A.Name;
  T.parts{end+1} = [];
  T.children{end+1} = C;
  T.instances{end+1} = {A.Instances.name};

endfunction

## A plate and three pins, two upright and one lying, each part coloured
%!function A = pinring ()
%!  pin = solid.cylinder (2, 12);
%!  pin.Colour = [0.8, 0.2, 0.2];
%!  plate = solid.box (60, 60, 4);
%!  plate.Colour = [0.2, 0.4, 0.8];
%!  A = model.Assembly ('ring');
%!  A = add (A, 'plate', plate, geom.UCS ([0, 0, 1], [-30, -30, -4]));
%!  A = add (A, 'pin', pin, geom.UCS ([0, 0, 1], [20, 0, 0]));
%!  A = add (A, 'pin', [], geom.UCS ([0, 0, 1], [-20, 0, 0]));
%!  A = add (A, 'pin', [], geom.UCS ([1, 0, 0], [0, 20, 6]), 'Name', 'lying');
%!endfunction

%!test  # the empty assembly
%! A = model.Assembly ();
%! assert_equal (A.Name, 'assembly');
%! assert_equal ([numparts(A), numinstances(A)], [0, 0]);
%! assert_equal (isempty (A), true);
%! assert_equal (isempty (shape (A)), true);

%!test  # a part defined once and placed three times, the placements named
%! A = pinring ();
%! assert_equal ([numparts(A), numinstances(A)], [2, 4]);
%! assert_equal ({A.Parts.name}, {'plate', 'pin'});
%! assert_equal ({A.Instances.name}, {'plate', 'pin', 'pin:2', 'lying'});
%! assert_equal ({A.Instances.part}, {'plate', 'pin', 'pin', 'pin'});

%!test  # a part placed again with the same shape
%! pin = solid.cylinder (2, 12);
%! A = add (model.Assembly (), 'pin', pin, geom.UCS ());
%! A = add (A, 'pin', pin, geom.UCS ([0, 0, 1], [10, 0, 0]));
%! assert_equal ([numparts(A), numinstances(A)], [1, 2]);

%!testif ; exist ('__occt__') == 3  # shape: the parts apart, in their colours
%! S = shape (pinring ());
%! assert_equal (numsolids (S), 4);
%! assert_equal (S.Colour, [0.2, 0.4, 0.8; repmat([0.8, 0.2, 0.2], 3, 1)]);

%!testif ; exist ('__occt__') == 3  # shape: a part where its frame puts it
%! A = add (model.Assembly (), 'pin', solid.cylinder (2, 12), ...
%!          geom.UCS ([1, 0, 0], [5, 0, 0]));
%! assert_equal (bbox (shape (A)), [5, -2, -2, 17, 2, 2], 1e-9);

%!testif ; exist ('__occt__') == 3  # shape: a sub-assembly placed twice
%! B = model.Assembly ('top');
%! B = add (B, 'stage', pinring (), geom.UCS ());
%! B = add (B, 'stage', [], geom.UCS ([0, 0, 1], [0, 0, 50]));
%! assert_equal ([numparts(B), numinstances(B)], [1, 2]);
%! assert_equal (numsolids (shape (B)), 8);

%!testif ; exist ('__occt__') == 3  # write: STEP defines each part once
%! B = model.Assembly ('top');
%! B = add (B, 'stage', pinring (), geom.UCS ());
%! B = add (B, 'stage', [], geom.UCS ([0, 0, 1], [0, 0, 50]));
%! f = [tempname(), '.step'];
%! unwind_protect
%!   write (B, f);
%!   t = fileread (f);
%!   assert_equal (numel (strfind (t, "PRODUCT('pin'")), 1);
%!   assert_equal (numel (strfind (t, "PRODUCT('stage'")), 1);
%!   assert_equal (numel (strfind (t, 'NEXT_ASSEMBLY_USAGE_OCCURRENCE')), 6);
%! unwind_protect_cleanup
%!   unlink (f);
%! end_unwind_protect

## The model of the 3MF file F, its XML
%!function t = ringxml (f)
%!  d = tempname ();
%!  unwind_protect
%!    unzip (f, d);
%!    t = fileread (fullfile (d, '3D', '3dmodel.model'));
%!  unwind_protect_cleanup
%!    confirm_recursive_rmdir (false, 'local');
%!    rmdir (d, 's');
%!  end_unwind_protect
%!endfunction

%!testif ; exist ('__occt__') == 3 && (! isempty (file_in_path (getenv ('PATH'), 'unzip')) || ! isempty (file_in_path (getenv ('PATH'), 'unzip.exe')))
%! ## write: 3MF, each part one object, placed as components
%! f = [tempname(), '.3mf'];
%! unwind_protect
%!   write (pinring (), f);
%!   t = ringxml (f);
%!   assert_equal (numel (strfind (t, '<object ')), 3);
%!   assert_equal (numel (strfind (t, '<mesh>')), 2);
%!   assert_equal (numel (strfind (t, '<component ')), 4);
%!   assert_equal (numel (strfind (t, '<base ')), 2);
%!   m = 'transform="0 1 0 0 0 1 1 0 0 0 20 6"';
%!   assert_equal (! isempty (strfind (t, m)), true);
%! unwind_protect_cleanup
%!   unlink (f);
%! end_unwind_protect

%!testif ; exist ('__occt__') == 3  # write: an STL of every part placed
%! f = [tempname(), '.stl'];
%! unwind_protect
%!   write (pinring (), f, 'Tolerance', 0.05);
%!   M = polymesh.read (f);
%!   V = 60 * 60 * 4 + 3 * volume (solid.cylinder (2, 12));
%!   assert_equal (volume (M), V, -1e-2);
%! unwind_protect_cleanup
%!   unlink (f);
%! end_unwind_protect

## A tetrahedron as a mesh, its triangles turned outwards
%!function M = tetrapart ()
%!  M = polymesh.Mesh ([0, 0, 0; 1, 0, 0; 0, 1, 0; 0, 0, 1], ...
%!                     [1, 3, 2; 1, 2, 4; 2, 3, 4; 3, 1, 4]);
%!endfunction

%!test  # a mesh part placed twice
%! A = add (model.Assembly (), 'tet', tetrapart (), geom.UCS ());
%! A = add (A, 'tet', [], geom.UCS ([0, 0, 1], [5, 0, 0]));
%! assert_equal ([numparts(A), numinstances(A)], [1, 2]);

%!test  # tessellate: mesh parts where their frames put them
%! A = add (model.Assembly (), 'tet', tetrapart (), ...
%!          geom.UCS ([1, 0, 0], [5, 0, 0]));
%! M = tessellate (A);
%! assert_equal ([min(M.Vertices); max(M.Vertices)], [5, 0, 0; 6, 1, 1], ...
%!               1e-12);

%!testif ; exist ('__occt__') == 3  # tessellate: solids and meshes, coloured
%! T = tetrapart ();
%! T.FaceColour = repmat ([1, 0, 0], 4, 1);
%! A = add (model.Assembly (), 'tet', T, geom.UCS ([0, 0, 1], [5, 0, 0]));
%! A = add (A, 'box', solid.box (1, 1, 1), geom.UCS ());
%! M = tessellate (A);
%! assert_equal (numfaces (M), 16);
%! assert_equal (sortrows (unique (M.FaceColour, 'rows')), ...
%!               [0.72, 0.74, 0.78; 1, 0, 0]);

%!test  # tessellate: the empty assembly
%! assert_equal (isempty (tessellate (model.Assembly ())), true);

%!error<model.Assembly: NAME must be a non-empty character vector.> ...
%! model.Assembly ('')
%!error<model.Assembly.add: invalid number of input arguments.> ...
%! add (model.Assembly (), 'pin', solid.Shape ())
%!error<model.Assembly.add: NAME must be a non-empty character vector.> ...
%! add (model.Assembly (), 1, solid.Shape (), geom.UCS ())
%!error<model.Assembly.add: U must be a geom.UCS object.> ...
%! add (model.Assembly (), 'pin', solid.Shape (), 1)
%!error<model.Assembly.add: X must be a solid.Shape, a polymesh.Mesh or a model.Assembly object, or empty.> ...
%! add (model.Assembly (), 'pin', 1, geom.UCS ())
%!error<model.Assembly.add: the part 'pin' is empty.> ...
%! add (model.Assembly (), 'pin', solid.Shape (), geom.UCS ())
%!error<model.Assembly.add: no part named 'pin' is defined yet.> ...
%! add (model.Assembly (), 'pin', [], geom.UCS ())
%!error<model.Assembly.add: a part named 'pin' is already defined, as another shape.>
%! A = add (model.Assembly (), 'pin', solid.cylinder (2, 12), geom.UCS ());
%! add (A, 'pin', solid.cylinder (3, 12), geom.UCS ());
%!error<model.Assembly.add: unknown parameter.> ...
%! add (model.Assembly (), 'pin', [], geom.UCS (), 'Label', 'a')
%!error<model.Assembly.add: INSTANCE must be a non-empty character vector.>
%! A = add (model.Assembly (), 'pin', solid.cylinder (2, 12), geom.UCS ());
%! add (A, 'pin', [], geom.UCS (), 'Name', 3)
%!error<model.Assembly.add: a placement named 'pin' exists.>
%! A = add (model.Assembly (), 'pin', solid.cylinder (2, 12), geom.UCS ());
%! add (A, 'pin', [], geom.UCS (), 'Name', 'pin')
%!error<model.Assembly.write: invalid number of input arguments.> ...
%! write (model.Assembly (), 'a.step', 'Tolerance')
%!error<model.Assembly.write: FILE must be a non-empty character vector.> ...
%! write (model.Assembly (), 1)
%!error<model.Assembly.write: Tolerance applies to meshes only.> ...
%! write (model.Assembly (), 'a.step', 'Tolerance', 0.1)
%!error<model.Assembly.write: FILE must end in .step, .stp, .3mf, .stl, .obj or .ply.> ...
%! write (model.Assembly (), 'a.dxf')
%!error<model.Assembly.write: unknown parameter.> ...
%! write (model.Assembly (), 'a.3mf', 'Angle', 0.1)
%!error<model.Assembly.write: TOL must be a positive and finite real scalar.> ...
%! write (model.Assembly (), 'a.3mf', 'Tolerance', 0)
%!error<model.Assembly.write: the assembly places nothing.> ...
%! write (model.Assembly (), 'a.step')
%!error<model.Assembly.shape: the part 'tet' is a mesh; use tessellate for the whole as a mesh.>
%! shape (add (model.Assembly (), 'tet', tetrapart (), geom.UCS ()))
%!error<model.Assembly.write: STEP cannot hold the mesh part 'tet'.>
%! write (add (model.Assembly (), 'tet', tetrapart (), geom.UCS ()), 'a.step')
%!error<model.Assembly.tessellate: TOL must be a positive and finite real scalar.> ...
%! tessellate (model.Assembly (), 0)
