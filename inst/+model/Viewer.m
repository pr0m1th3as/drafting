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

classdef Viewer < handle
  ## -*- texinfo -*-
  ## @deftp {drafting} model.Viewer
  ##
  ## A window showing a solid, a triangle mesh or an assembly, in which
  ## edges, faces, solids and coordinate systems can be picked, and solids
  ## hidden or shown through.
  ##
  ## Assigning a @code{solid.Shape} to the @code{Model} of a viewer opens its
  ## window, or redraws it in place, keeping the camera where it was; each
  ## solid is drawn in its colour, grey where it has none.  Nothing
  ## else redraws it.  A @code{polymesh.Mesh} is shown the same way, shaded
  ## facet by facet, however many triangles it has, in its faces' colours
  ## where it has them, else in its vertices', blended across each facet,
  ## else in grey.  A @code{model.Assembly} is shown as its shape, each part
  ## in its colour.  The @code{show} method of a shape, a mesh or an assembly
  ## keeps a viewer for each variable and is the usual way in; a viewer of
  ## your own is for when you want to hold it yourself.
  ##
  ## @code{model.Viewer.opacity} hides solids or shows them through, to look
  ## inside a model, and @code{pick} with @qcode{'solid'} tells which solid
  ## is which.  See-through solids are blended so that the nearer reads as
  ## in front, whatever order they are drawn in.
  ##
  ## The window is drawn by Open CASCADE in a process of its own, so a complex
  ## model turns smoothly and never holds up the Octave prompt.  The world
  ## axes are drawn in the lower right corner, turning with the view, @math{x}
  ## red, @math{y} green and @math{z} blue.  The left mouse button rotates,
  ## the middle one pans and the wheel zooms.  The view turns keeping
  ## @math{z} up the window, as Octave's @code{rotate3d} turns a plot, until
  ## @kbd{T} lets it turn any way.  It turns about the centre of the window,
  ## wherever it has been panned to, or about a point of the shape chosen by
  ## double-clicking it; a double click that misses the shape, or fitting the
  ## view, returns to the centre of the window.  During a pick a double click
  ## is a click like any other.  Keys:
  ##
  ## @multitable @columnfractions 0.15 0.85
  ## @item @kbd{F} @tab fit the shape to the window, and turn about the
  ## centre of the window again
  ## @item @kbd{0} @tab isometric view
  ## @item @kbd{1} @tab front view, looking along @math{+y}
  ## @item @kbd{2} @tab top view, looking down @math{z}
  ## @item @kbd{3} @tab right view, looking along @math{-x}
  ## @item @kbd{T} @tab let the mouse turn the view any way, or keep
  ## @math{z} up again, standing the view upright
  ## @item @kbd{C} @tab on a mesh, the next of the colourings it has: its
  ## faces' colours, its vertices', grey
  ## @item @kbd{E} @tab on a mesh, its triangle edges drawn or not, not at
  ## first
  ## @end multitable
  ##
  ## What @kbd{C} and @kbd{E} choose holds for every mesh the viewer shows
  ## after, where the mesh has that colouring.
  ##
  ## Closing the window ends the viewer; assigning a shape again opens a new
  ## one.  The window closes with Octave.
  ##
  ## The viewer needs a display to run.  It runs on Linux, FreeBSD, Windows
  ## and macOS.
  ##
  ## @seealso{solid.Shape.show, polymesh.Mesh.show, model.Assembly.show,
  ## model.Viewer.pick, model.Viewer.opacity}
  ## @end deftp

  properties (Dependent)

    ## -*- texinfo -*-
    ## @deftp {model.Viewer} {property} Model
    ##
    ## Model shown
    ##
    ## The @code{solid.Shape}, the @code{polymesh.Mesh} or the
    ## @code{model.Assembly} shown.  Assigning any of them opens the window if
    ## it is not open and redraws it in place if it is.  An assembly is drawn
    ## as @code{model.Assembly.shape} gives it, or as one mesh where a part of
    ## it is a mesh, and its solids are chosen by name and path in
    ## @code{model.Viewer.opacity}.  The empty shape opens the window empty,
    ## or clears it if it is open; the first shape shown after it is fitted to
    ## the window.
    ##
    ## @end deftp
    Model

    ## -*- texinfo -*-
    ## @deftp {model.Viewer} {property} Name
    ##
    ## Name of the shape shown
    ##
    ## The name of the variable holding the shape shown.  Setting it titles
    ## the window with the name, so that several viewers can be told apart,
    ## and the queries @code{model.Viewer.pick} prints use it.  Until it is set
    ## the window is titled @qcode{drafting} and the queries use @qcode{'S'}.
    ##
    ## @end deftp
    Name

  endproperties

  properties (Dependent, Hidden)

    Shape

  endproperties

  properties (Hidden, SetAccess = private)

    Id = 0;

  endproperties

  methods (Hidden)

    function disp (this)

      st = state (this);
      if (isopen (this))
        printf ("  model.Viewer: open, showing %s\n", st.name);
      else
        printf ("  model.Viewer: closed\n");
      endif

    endfunction

    ## The pixel at which the model point P lands
    function PX = __project__ (this, P)

      send (this, sprintf ("project %.17g %.17g %.17g", P));
      r = strsplit (receive (this, 10));
      PX = str2double (r(2:3));

    endfunction

    ## Start a pick of KIND without waiting for it, so that tests can click
    function __pickstart__ (this, KIND)

      send (this, ["pick " KIND]);

    endfunction

    ## Start a single pick of KIND, face or point, without waiting for it
    function __pickonestart__ (this, KIND)

      send (this, ["pickone " KIND]);

    endfunction

    ## A click at the pixel PX during a single pick; the viewer's reply
    function r = __clickone__ (this, PX)

      send (this, sprintf ("click %d %d", round (PX)));
      r = receive (this, 10);

    endfunction

    ## A double click at the pixel PX outside a pick: the point the view now
    ## turns about, empty where the pixel misses the shape
    function C = __dblclick__ (this, PX)

      send (this, sprintf ("dblclick %d %d", round (PX)));
      r = strsplit (receive (this, 10));
      C = str2double (r(2:end));
      if (any (isnan (C)))
        C = [];
      endif

    endfunction

    ## The left button dragged from the pixel PX to the pixel QX
    function __drag__ (this, PX, QX)

      send (this, sprintf ("drag %d %d %d %d", round (PX), round (QX)));
      receive (this, 10);

    endfunction

    ## As pressing the key K, a letter or a digit
    function __key__ (this, K)

      send (this, ["key " K]);
      receive (this, 10);

    endfunction

    ## How the mouse turns the view: 'upright' or 'free'
    function T = __turn__ (this)

      send (this, "getturn");
      r = strsplit (receive (this, 10));
      T = r{2};

    endfunction

    ## A click at the pixel PX during a pick; the number of items now picked
    function N = __click__ (this, PX)

      send (this, sprintf ("click %d %d", round (PX)));
      N = str2double (receive (this, 10)(10:end));

    endfunction

    ## How a mesh is shown: its colouring, face, vertex or grey, and whether
    ## its edges are drawn, on or off
    function [LOOK, EDGES] = __look__ (this)

      send (this, "getlook");
      r = strsplit (receive (this, 10));
      LOOK = r{2};
      EDGES = r{3};

    endfunction

    ## Choose a mesh's colouring, as the key C does
    function __colours__ (this, LOOK)

      send (this, ["colours " LOOK]);

    endfunction

    ## Draw a mesh's edges or not, as the key E does
    function __edges__ (this, ON)

      send (this, ["edges " ON]);

    endfunction

    ## Finish a pick as the Enter key does; what it picked: on a mesh the
    ## points and their triangles, else the edges and faces
    function [A, B] = __pickend__ (this)

      send (this, "enter");
      R = replies (this, 10);
      if (isa (state (this).mesh, 'polymesh.Mesh'))
        [A, B] = meshpoints (R);
      else
        [A, B] = items (R);
      endif

    endfunction

    ## The picking behind pick.  CLICKS, for tests and the guide, replaces
    ## the mouse: a row of pixels per click, then NaN for the Enter key or
    ## Inf for Escape, Enter when neither ends it; empty is the mouse.
    function varargout = __pick__ (this, KIND, CLICKS)

      ## Input validation
      if (! ischar (KIND)
          || ! any (strcmp (KIND, {'edge', 'face', 'point', 'solid', 'any'})))
        error (strcat ("model.Viewer.pick: KIND must be 'edge', 'face',", ...
                       " 'point', 'solid' or 'any'."));
      endif
      ismesh = isa (state (this).mesh, 'polymesh.Mesh');
      if (ismesh && ! any (strcmp (KIND, {'any', 'point'})))
        error ("model.Viewer.pick: a mesh has only points to pick.");
      endif
      ## The parts of an assembly are not edited, so a pick on one only
      ## tells its solids, or points
      if (! ismesh && ! isempty (state (this).model)
          && ! strcmp (KIND, 'point'))
        if (any (strcmp (KIND, {'edge', 'face'})))
          error (strcat ("model.Viewer.pick: the parts of an assembly are", ...
                         " not edited; pick 'solid' to identify one."));
        endif
        KIND = 'solid';
      endif
      if (! isopen (this) || isempty (this.Model))
        error ("model.Viewer.pick: the viewer is showing no shape.");
      endif
      if (strcmp (KIND, 'point'))
        [varargout{1:2}] = pickpoints (this, CLICKS);
        return;
      endif

      ## Lines left from an earlier exchange are stale
      st = state (this);
      while (ischar (fgetl (st.out)))
      endwhile
      fclear (st.out);

      send (this, ["pick " KIND]);
      finished = false;
      unwind_protect
        if (isempty (CLICKS))
          [R, r] = replies (this, Inf);
        else
          for k = 1:rows (CLICKS)
            if (any (isnan (CLICKS(k,:)) | isinf (CLICKS(k,:))))
              break;
            endif
            send (this, sprintf ("click %d %d", round (CLICKS(k,:))));
            receive (this, 10);
          endfor
          if (! isempty (CLICKS) && any (isinf (CLICKS(k,:))))
            send (this, "cancel");
          else
            send (this, "enter");
          endif
          [R, r] = replies (this, 10);
        endif
        finished = true;
      unwind_protect_cleanup
        if (! finished && isopen (this))
          send (this, "cancel");
        endif
      end_unwind_protect
      if (strcmp (r, 'closed'))
        error ("model.Viewer.pick: the window was closed during the pick.");
      endif
      if (ismesh)
        [varargout{1:2}] = meshpoints (R);
        return;
      endif
      [E, F, I] = items (R);
      if (strcmp (KIND, 'solid'))
        CODE = '';
        if (! isempty (I))
          CODE = solidcode (st, I);
        endif
        varargout = {I, CODE};
        return;
      endif

      ## The code that selects them again
      S = shown (this);
      ECODE = '';
      FCODE = '';
      if (! isempty (E))
        ECODE = model.Viewer.__query__ (S, 'edge', E, st.name);
      endif
      if (! isempty (F))
        FCODE = model.Viewer.__query__ (S, 'face', F, st.name);
      endif

      switch (KIND)
        case 'edge'
          varargout = {E, ECODE};
        case 'face'
          varargout = {F, FCODE};
        otherwise
          varargout = {E, F, ECODE, FCODE};
      endswitch

    endfunction

    ## The UCS picking behind pickucs.  CLICKS, for tests, replaces the mouse:
    ## a row of pixels per click, NaN for the Enter key and Inf for Escape;
    ## empty is the mouse.  SHOWN is the prompts shown, in order, and CODE the
    ## expression that makes U.  Each
    ## prompt opens with what the click before it took, so that a click that
    ## took something unintended shows at once.
    function [U, SHOWN, CODE] = __pickucs__ (this, MODE, CLICKS)

      st = state (this);
      while (ischar (fgetl (st.out)))
      endwhile
      fclear (st.out);
      S = shown (this);
      B = bbox (S);
      scale = max (abs (B));
      SHOWN = {};
      told = '';
      finished = false;
      unwind_protect

        ## The axes
        if (strcmp (MODE, 'face'))
          if (isa (S, 'solid.Shape'))
            info = __occt__ ('faces', 'model.Viewer.pickucs', S.Data);
          endif
          ask = "Pick a flat face for the plane";
          do
            [r, CLICKS, SHOWN] = one (this, 'face', ask, CLICKS, SHOWN);
            RF = r;
            n = [];
            if (strcmp (r{1}, 'face'))
              k = str2double (r{2});
              n = info{2}(k,:);
              f = str2double (r(3:5));
            elseif (strcmp (r{1}, 'facet'))
              n = str2double (r(2:4));
              f = str2double (r(5:7));
            endif
            ask = "That face is not flat: pick a flat face for the plane";
          until (! isempty (n) && ! any (isnan (n)))
          told = "Plane: a flat face.\n";
          ask = [told "Pick the start of the x axis"];
          [p1, r, CLICKS, SHOWN] = point (this, ask, CLICKS, SHOWN);
          RP = {r};
          told = describe ("Start of x", r, scale);
          ask = [told "Pick a point towards +x"];
          do
            [p2, r, CLICKS, SHOWN] = point (this, ask, CLICKS, SHOWN);
            A = struct ('normal', n, 'face', f, 'points', [p1; p2]);
            ask = "No direction in the face: pick another point towards +x";
          until (isvalidaxes (A))
          RP{2} = r;
          told = describe ("Towards +x", r, scale);
        else
          RF = {};
          ask = "Pick the start of the x axis";
          [p1, r, CLICKS, SHOWN] = point (this, ask, CLICKS, SHOWN);
          RP = {r};
          told = describe ("Start of x", r, scale);
          ask = [told "Pick a point towards +x"];
          do
            [p2, r, CLICKS, SHOWN] = point (this, ask, CLICKS, SHOWN);
            ask = "Pick a point away from the first, towards +x";
          until (! isequal (p1, p2))
          RP{2} = r;
          told = describe ("Towards +x", r, scale);
          ask = [told "Pick a point on the +y side"];
          do
            [p3, r, CLICKS, SHOWN] = point (this, ask, CLICKS, SHOWN);
            A = struct ('points', [p1; p2; p3]);
            ask = "That point is on the x axis: pick one on the +y side";
          until (isvalidaxes (A))
          RP{3} = r;
          told = describe ("+y side", r, scale);
        endif

        ## The origin
        O = zeros (0, 3);
        RO = {};
        [r, CLICKS, SHOWN] = one (this, 'point', ...
                                  [told "Pick the origin, or Enter to keep", ...
                                   " the start of x"], CLICKS, SHOWN);
        if (strcmp (r{1}, 'point'))
          O = str2double (r(2:4));
          RO = {r};
          told = describe ("Origin", r, scale);
          [r, CLICKS, SHOWN] = one (this, 'point', ...
                                    [told "Pick a point to take the", ...
                                     " origin's y from, or Enter to put it", ...
                                     " here"], CLICKS, SHOWN);
          if (strcmp (r{1}, 'point'))
            O(2,:) = str2double (r(2:4));
            RO{2} = r;
          endif
        endif
        U = model.Viewer.__ucs__ (A, O);
        finished = true;

      unwind_protect_cleanup
        if (isopen (this))
          if (! finished)
            send (this, "cancel");
          endif
          send (this, "clearmarks");
          send (this, "prompt");
        endif
      end_unwind_protect

      v = @(x) sprintf ("[%s]", strjoin (arrayfun (@(c) sprintf ("%.10g", ...
                                                   c + 0), x, ...
                                                   'UniformOutput', false), ...
                                         ", "));
      CODE = sprintf ("geom.UCS (%s, %s, %s)", v (U.Normal), v (U.Origin), ...
                      v (U.Origin + U.XAxis));
      if (isa (S, 'solid.Shape') && isempty (st.model))
        named = ucscode (S, U, RF, RP, RO, scale, st.name);
        if (! isempty (named))
          CODE = named;
        endif
      endif

    endfunction

    ## The title the window carries
    function T = __title__ (this)

      send (this, "gettitle");
      T = receive (this, 10)(7:end);

    endfunction

    ## What lies at the pixel PX: "edge K", "face K" or "none"
    function r = __pickat__ (this, KIND, PX)

      send (this, sprintf ("pickat %s %d %d", KIND, round (PX)));
      r = receive (this, 10);

    endfunction

  endmethods

  methods (Static, Hidden)

    ## The viewer kept for the variable NAME, or the one that shapes without
    ## a name share when NAME is empty or not a variable name, opened afresh
    ## when its window has gone and titled with the name.  The show methods
    ## come here.  The registry lives in the graphics root, where it
    ## outlasts clear all.
    function V = __named__ (NAME)

      if (isempty (NAME) || ! isvarname (NAME))
        NAME = '';
        key = 'unnamed';
      else
        key = ['v_' NAME];
      endif
      ids = getappdata (0, 'drafting_model_show');
      if (! isstruct (ids))
        ids = struct ();
      endif
      if (isfield (ids, key) &&
          ! isempty (getappdata (0, sprintf ('drafting_model_viewer_%d',
                                             ids.(key)))))
        V = model.Viewer ('__id__', ids.(key));
      else
        V = model.Viewer ();
        ids.(key) = V.Id;
        setappdata (0, 'drafting_model_show', ids);
      endif
      if (! isempty (NAME))
        V.Name = NAME;
      endif

    endfunction

    ## The UCS from picked points.  AXES holds the axes picked: a planar face
    ## (its outward normal NORMAL and a point FACE on it) and two POINTS, the
    ## start of the x axis and a point towards +x, or three POINTS with no
    ## face.  ORIGIN holds none, one or two points for the origin.
    function U = __ucs__ (AXES, ORIGIN)

      P = AXES.points;
      if (isfield (AXES, 'normal') && ! isempty (AXES.normal))
        n = AXES.normal / norm (AXES.normal);
        p1 = P(1,:) - ((P(1,:) - AXES.face) * n') * n;
        U = geom.UCS (n, p1, P(2,:));
      else
        U = geom.UCS.threepoint (P(1,:), P(2,:), P(3,:));
      endif
      O = U.Origin;
      switch (rows (ORIGIN))
        case 1
          d = ORIGIN(1,:) - O;
          O = O + (d * U.XAxis') * U.XAxis + (d * U.YAxis') * U.YAxis;
        case 2
          O = O + ((ORIGIN(1,:) - O) * U.XAxis') * U.XAxis ...
                + ((ORIGIN(2,:) - O) * U.YAxis') * U.YAxis;
      endswitch
      U = geom.UCS (U.Normal, O, O + U.XAxis);

    endfunction

    ## The code that selects exactly the items IDX of KIND, edge or face, of
    ## the shape S held in the variable NAME: one query by what they share
    ## where it finds them alone, which gives them in increasing order, else
    ## one query for each, joined in the order of IDX, and their indices only
    ## where an item cannot be told apart by any query.  Faces with names, and
    ## edges of faces with names, are found by those names first, as
    ## namedfaces and namededges write it; an item without names among them by
    ## its kind, direction and position.
    function Q = __query__ (S, KIND, IDX, NAME)

      IDX = unique (IDX(:)', 'stable');
      names = __occt__ ('names', 'model.Viewer.pick', S.Data);
      if (strcmp (KIND, 'edge'))
        info = __occt__ ('edges', 'model.Viewer.pick', S.Data);
        F = unique ([zeros(1, 0), info{5}{IDX}]);
        named = @namededges;
      else
        info = __occt__ ('faces', 'model.Viewer.pick', S.Data);
        F = IDX;
        named = @namedfaces;
      endif
      if (names{2} || ! any (cellfun (@(r) any (! cellfun ('isempty', r)), ...
                                      names{1}(F))))
        names = {};
      endif
      if (isempty (names))
        Q = itemquery (KIND, info, IDX, 1000, ' ');
      else
        Q = named (S, IDX, info, names, ' ');
      endif
      if (isempty (Q) || ! isequal (sort (chosen (S, Q)), sort (IDX)))
        parts = cell (1, numel (IDX));
        for k = 1:numel (IDX)
          if (! isempty (names) && numel (IDX) > 1)
            parts{k} = named (S, IDX(k), info, names, '');
            if (! isempty (parts{k}))
              continue;
            endif
          endif
          for digits = [1000, 1e6]
            parts{k} = itemquery (KIND, info, IDX(k), digits, '');
            if (isequal (chosen (S, parts{k}), IDX(k)))
              break;
            endif
          endfor
        endfor
        Q = sprintf ("[%s]", strjoin (parts, ", "));
        if (! isequal (chosen (S, Q), IDX))
          Q = sprintf ("[%s]", strjoin (arrayfun (@num2str, IDX, ...
                                                  'UniformOutput', false), ...
                                        ", "));
        endif
      endif
      Q = strrep (Q, '__shape__', NAME);

    endfunction

  endmethods

  methods (Access = public)

    ## -*- texinfo -*-
    ## @deftypefn  {model.Viewer} {@var{V} =} model.Viewer ()
    ## @deftypefnx {model.Viewer} {@var{V} =} model.Viewer (@qcode{'Hidden'}, @var{TF})
    ##
    ## Make a viewer.
    ##
    ## @code{@var{V} = model.Viewer ()} returns a viewer that shows nothing
    ## yet; its window opens when a shape, even the empty one, is assigned to
    ## its @code{Model}:
    ##
    ## @example
    ## @group
    ## V = model.Viewer ();
    ## V.Model = solid.box (80, 40, 12);
    ## V.Model = hole (V.Model, [20, 20, 12], 8, Inf);
    ## @end group
    ## @end example
    ##
    ## @code{@var{V} = model.Viewer ('Hidden', true)} never shows its
    ## window.  It draws and picks all the same, which is how the viewer is
    ## tested.
    ##
    ## @end deftypefn
    function this = Viewer (varargin)

      ## A wrapper over an existing viewer, for model.Viewer.__named__
      if (nargin == 2 && strcmp (varargin{1}, '__id__'))
        this.Id = varargin{2};
        return;
      endif

      ## Input validation
      if (mod (numel (varargin), 2) != 0)
        error ("model.Viewer: Name/Value arguments must come in pairs.");
      endif
      hidden = false;
      for ii = 1:2:numel (varargin)
        name = varargin{ii};
        val = varargin{ii+1};
        if (! ischar (name) || ! isrow (name))
          error ("model.Viewer: option names must be character vectors.");
        endif
        switch (lower (name))
          case 'hidden'
            hidden = val;
            if (! islogical (hidden) || ! isscalar (hidden))
              error ("model.Viewer: Hidden must be true or false.");
            endif
          otherwise
            error ("model.Viewer: unknown option '%s'.", name);
        endswitch
      endfor

      ## The state lives in the graphics root, where it outlasts clear all
      id = getappdata (0, 'drafting_model_viewer_next');
      if (isempty (id))
        id = 1;
      endif
      setappdata (0, 'drafting_model_viewer_next', id + 1);
      this.Id = id;
      setstate (this, struct ('pid', -1, 'in', -1, 'out', -1, ...
                              'hidden', logical (hidden), ...
                              'data', uint8 ([]), 'shape', [], ...
                              'mesh', [], 'name', 'S', ...
                              'named', false, 'model', [], 'list', [], ...
                              'rules', {{}}, 'opacity', []));

    endfunction

    function S = get.Model (this)

      st = state (this);
      if (! isempty (st.model))
        S = st.model;
      else
        S = shown (this);
      endif

    endfunction

    function set.Model (this, S)

      isasm = isa (S, 'model.Assembly') && isscalar (S);
      ismesh = isa (S, 'polymesh.Mesh') && isscalar (S);
      if (! isasm && ! ismesh && (! isa (S, 'solid.Shape') || ! isscalar (S)))
        error (strcat ("model.Viewer: Model must be a solid.Shape, a", ...
                       " polymesh.Mesh or a model.Assembly object."));
      endif
      st = state (this);
      st.model = [];
      st.list = [];
      ## An assembly is drawn as its shape, or as one mesh where a part is a
      ## mesh
      if (isasm)
        st.model = S;
        if (hasmesh (S))
          S = tessellate (S);
          ismesh = true;
        else
          S = shape (S);
        endif
      endif
      if (ismesh)
        st.data = uint8 ([]);
        st.shape = [];
        st.mesh = S;
      else
        st.data = S.Data;
        st.shape = S;
        st.mesh = [];
      endif
      setstate (this, st);
      if (! isopen (this))
        launch (this);
      endif
      ## The solids listed beside the shape, so that a name or a path finds
      ## them
      if (! ismesh)
        st = state (this);
        if (isasm)
          st.list = solids (st.model);
        else
          st.list = solids (S);
        endif
        setstate (this, st);
      endif
      if (ismesh && ! isempty (S))
        ## The colours follow the triangles, the vertices' before the faces'
        V = S.Vertices';
        F = uint32 (S.Faces' - 1);
        data = [typecast(V(:), 'uint8'); typecast(F(:), 'uint8')];
        CK = 0;
        if (! isempty (S.VertexColour))
          CK += 1;
          data = [data; reshape(uint8 (255 * S.VertexColour'), [], 1)];
        endif
        if (! isempty (S.FaceColour))
          CK += 2;
          data = [data; reshape(uint8 (255 * S.FaceColour'), [], 1)];
        endif
        send (this, sprintf ("mesh %d %d %d", numvertices (S), ...
                             numfaces (S), CK), data);
      else
        ## Each coloured solid after the shape: its index and its colour
        C = [];
        k = zeros (1, 0);
        if (! ismesh && ! isempty (S.Colour))
          C = S.Colour;
          k = find (! isnan (C(:,1)))';
        endif
        rec = [reshape(typecast (uint32 (k), 'uint8'), 4, []);
               uint8(255 * C(k,:)')];
        send (this, sprintf ("shape %d %d", numel (st.data), numel (k)), ...
              [st.data(:); rec(:)]);
      endif
      reapply (this);

    endfunction

    function N = get.Name (this)

      N = state (this).name;

    endfunction

    function set.Name (this, N)

      if (! ischar (N) || ! isvarname (N))
        error ("model.Viewer: Name must be a valid variable name.");
      endif
      st = state (this);
      st.name = N;
      st.named = true;
      setstate (this, st);
      if (isopen (this))
        send (this, ["title " title(st)]);
      endif

    endfunction

    ## Shape is Model's former name, kept until 0.3.0
    function S = get.Shape (this)

      warning (strcat ("model.Viewer: Shape is obsolete and will be", ...
                       " removed in drafting 0.3.0; use Model instead."));
      S = this.Model;

    endfunction

    function set.Shape (this, S)

      warning (strcat ("model.Viewer: Shape is obsolete and will be", ...
                       " removed in drafting 0.3.0; use Model instead."));
      this.Model = S;

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {model.Viewer} {[@var{E}, @var{F}] =} pick (@var{V})
    ## @deftypefnx {model.Viewer} {[@var{E}, @var{F}, @var{ECODE}, @var{FCODE}] =} pick (@var{V})
    ## @deftypefnx {model.Viewer} {[@var{E}, @var{CODE}] =} pick (@var{V}, @qcode{'edge'})
    ## @deftypefnx {model.Viewer} {[@var{F}, @var{CODE}] =} pick (@var{V}, @qcode{'face'})
    ## @deftypefnx {model.Viewer} {[@var{I}, @var{CODE}] =} pick (@var{V}, @qcode{'solid'})
    ## @deftypefnx {model.Viewer} {[@var{P}, @var{CODE}] =} pick (@var{V}, @qcode{'point'})
    ## @deftypefnx {model.Viewer} {[@var{P}, @var{F}] =} pick (@var{V})
    ##
    ## Pick edges and faces of a solid, or points on a mesh, with the mouse.
    ##
    ## @code{[@var{E}, @var{F}] = pick (@var{V})} waits while you click edges
    ## and faces in the viewer's window, then returns the indices of the edges
    ## in @var{E} and of the faces in @var{F}, in the order you picked them,
    ## in the numbering @code{solid.Shape.edges} and @code{solid.Shape.faces}
    ## use.  A click selects what is under the pointer, which stays drawn in
    ## orange, a selected edge thick and a selected face filled, and a second
    ## click on it lets it go; the shape can still be turned between clicks.
    ## @kbd{Enter} finishes and @kbd{Escape} cancels, returning nothing.  With
    ## @qcode{'edge'} or @qcode{'face'} only that kind can be picked, and its
    ## indices are the first output.
    ##
    ## Indices belong to the shape they were picked on, and a script that holds
    ## them breaks as soon as an earlier step adds a feature.  So @code{pick}
    ## also returns, as a character vector, the code that selects the same
    ## items: @var{CODE} for one kind, and @var{ECODE} and @var{FCODE} for
    ## edges and faces picked together, empty where none was picked.  The code
    ## selects exactly the items picked.
    ##
    ## A face with a name, given by the @qcode{'Label'} of the step that made
    ## it, is found by that name, as @code{solid.Shape.faces} takes it, so
    ## the code keeps finding the face when an earlier step changes.  Where
    ## the name has other faces too, the code narrows it by what tells the
    ## face apart, tried in this order and kept only where needed: the copy
    ## of an array it is in (@qcode{'Copy'}), the segment of a sweep's path it
    ## runs along (@qcode{'Along'}), the named faces it borders
    ## (@qcode{'Adjacent'}), its normal, kind or axis, and last the box round
    ## it (@qcode{'Within'}).  Faces picked together are found by a name they
    ## share, else by a list of their names, else one by one.  A face of
    ## several names is found by the one that gives the shortest code.
    ##
    ## An edge is found by the names of the faces it bounds, as
    ## @code{solid.Shape.edges} takes them: @qcode{'Between'} a name of each
    ## of its two faces, or @qcode{'Face'} with the name of the one face that
    ## has a name, narrowed where needed by @qcode{'Copy'}, @qcode{'Along'},
    ## its kind, its direction and last the box round it.  Edges picked
    ## together are found by @qcode{'Face'} with a name of the faces they
    ## bound, or with the names of faces they go all round, else
    ## @qcode{'Between'} a face they all bound and the others, else one by
    ## one; the shortest code is kept.
    ##
    ## Items with no names are found by kind, direction and position: one
    ## query where what they share finds them alone, else one query for each,
    ## joined, and their indices only where an item cannot be told apart from
    ## the others by any query.  The code names the shape by
    ## the variable the viewer shows, and @code{eval (@var{CODE})} gives the
    ## indices again: in the order picked where it names the items one by
    ## one, and in increasing order where one query names them all.  Put it
    ## in the script in place of the numbers:
    ##
    ## @example
    ## @group
    ## ## Four upright edges picked on a block 80 by 40 by 12
    ## [E, CODE] = pick (V, 'edge');
    ## ## CODE holds the query for the script
    ## E = edges (part, 'Type', 'line', 'Direction', [0, 0, 1], ...
    ##            'Within', [0, 0, 0, 80, 40, 12]);
    ## part = fillet (part, E, 3);
    ##
    ## ## The same edges of a block made with 'Label', 'plate'
    ## E = edges (part, 'Face', 'plate', 'Direction', [0, 0, 1]);
    ##
    ## ## The round of the third of six rounded blocks in a ring, on its front
    ## [F, CODE] = pick (V, 'face');
    ## F = faces (ring, 'Label', 'edge_round', 'Copy', 3, ...
    ##            'Adjacent', 'plate.ymin');
    ## @end group
    ## @end example
    ##
    ## @code{[@var{I}, @var{CODE}] = pick (@var{V}, 'solid')} picks
    ## whole solids: a click on any face of a solid selects it, and @var{I}
    ## returns the indices of the solids picked, in the order you picked them,
    ## numbered as @code{solid.Shape.solids} and @code{model.Assembly.solids}
    ## list them, for @code{model.Viewer.opacity}.  The face clicked stays
    ## drawn in orange.  @var{CODE} is what selects the same solids in
    ## @code{opacity}, as code: the name they share, else the path they
    ## share, where either selects them alone, else their indices.
    ##
    ## @code{[@var{P}, @var{CODE}] = pick (@var{V}, 'point')} picks
    ## points: each click snaps as for @code{model.Viewer.pickucs}, a corner
    ## to its vertex, a circular edge to its centre, another edge to its
    ## midpoint halfway along its length, a face to the point clicked, and is
    ## marked, until @kbd{Enter}; @kbd{Escape} cancels, returning nothing.
    ## @var{P} is an @math{N}-by-3 matrix of the points in the order picked.
    ## @var{CODE} rebuilds them from the names of the faces: a corner as
    ## @code{solid.Shape.corner} of the fewest named faces that meet there
    ## and share no other corner, a centre or midpoint as
    ## @code{solid.Shape.centre} or @code{solid.Shape.midpoint} of the edge,
    ## found as for an edge picked; a point on a face, and one the names
    ## cannot rebuild, by its coordinates.  Several points are the rows of one
    ## matrix.  On a mesh, on an assembly and on a shape without names
    ## @var{CODE} is the coordinates.
    ##
    ## @example
    ## @group
    ## ## The top front right corner of a block made with 'Label', 'plate'
    ## [P, CODE] = pick (V, 'point');
    ## P = corner (part, faces (part, 'Label', ...
    ##                          @{'plate.xmax', 'plate.ymin', 'plate.zmax'@}));
    ## @end group
    ## @end example
    ##
    ## When the viewer shows a @code{model.Assembly}, picking only tells its
    ## solids apart, since the parts of an assembly are edited as parts, not
    ## in the assembly.  @code{pick (@var{V})} then picks solids,
    ## @qcode{'point'} picks points, and @qcode{'edge'} and @qcode{'face'} are
    ## refused.
    ##
    ## When the viewer shows a @code{polymesh.Mesh}, @code{[@var{P}, @var{F}]
    ## = pick (@var{V})} waits while you click points on it, each marked
    ## where it lands, and returns them in @var{P}, an @math{N}-by-3 matrix of
    ## the points where the clicks hit the mesh, and in @var{F} an
    ## @math{N}-by-4 matrix: for each point the index of the triangle it lies
    ## on, a row of the mesh's @code{Faces}, and the triangle's unit normal,
    ## turned as its corners run.  A click that misses the mesh adds nothing.
    ## @kbd{Enter} finishes and @kbd{Escape} cancels, returning nothing.  A
    ## mesh has no edges, faces or solids in the sense of a solid, so
    ## @qcode{'edge'}, @qcode{'face'} and @qcode{'solid'} are refused;
    ## @qcode{'point'} picks points as on a solid.
    ##
    ## @seealso{solid.Shape.edges, solid.Shape.faces, solid.Shape.show,
    ## model.Viewer.opacity}
    ## @end deftypefn
    function varargout = pick (this, KIND = 'any')

      [varargout{1:max (nargout, 1)}] = __pick__ (this, KIND, []);

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {model.Viewer} {@var{U} =} pickucs (@var{V})
    ## @deftypefnx {model.Viewer} {@var{U} =} pickucs (@var{V}, @var{MODE})
    ## @deftypefnx {model.Viewer} {[@var{U}, @var{CODE}] =} pickucs (@dots{})
    ##
    ## Pick a user coordinate system with the mouse.
    ##
    ## @code{@var{U} = pickucs (@var{V})} returns the @code{geom.UCS} you
    ## pick on the shape in the viewer's window, in two steps, each prompted at
    ## the foot of the window.  @code{geom.UCS (@var{V})} does the same.
    ##
    ## The axes come first.  Click a flat face, which gives the plane and its
    ## outward normal, then two points: the direction from the first to the
    ## second, laid in the face, is @math{+x}.  The points can be anywhere on
    ## the part, two corners along an edge for instance.  With @var{MODE}
    ## @qcode{'points'} no face is picked; three points give the axes instead,
    ## @math{+x} from the first to the second and the third on the @math{+y}
    ## side, as for @code{geom.UCS.threepoint}.  @var{MODE} is @qcode{'face'}
    ## by default.
    ##
    ## The origin comes second.  Click one point and the origin is there, laid
    ## in the plane.  Click a second and the origin takes its @math{x} from the
    ## first point and its @math{y} from the second, which puts a datum corner
    ## where a fillet or chamfer leaves no vertex to click.  Press @kbd{Enter}
    ## at once to keep the origin at the first point of the axes.
    ##
    ## Every point snaps to what it lands on: a corner to its vertex, a
    ## circular edge to its centre, another edge to its midpoint, a face to the
    ## point clicked.  The tip of a cone and the poles of a sphere are corners
    ## too, as for @code{solid.Shape.corner}.  Each is marked in the window.
    ## On a triangle mesh the face clicked is a triangle, which gives the plane
    ## where the mesh is flat, and a point snaps to a corner of the triangle
    ## under it or the middle of one of its sides when the click is near, or
    ## else lies where it was clicked.  The shape can be turned between clicks,
    ## and @kbd{Escape} cancels with an error.
    ##
    ## A pick depends on the shape it was made on, so
    ## @code{[@var{U}, @var{CODE}] = pickucs (@dots{})} also returns
    ## @var{CODE}, the expression that makes the same UCS, as a character
    ## vector to put in the script in place of the pick, laid out in lines of
    ## at most 80 columns.  @code{eval (@var{CODE})} gives the UCS again.
    ##
    ## On a solid whose faces have names, @var{CODE} makes the UCS from them,
    ## so that it follows the part when an earlier step changes.  The normal
    ## is @code{solid.Shape.normal} of the face picked, and each point is
    ## written as @code{model.Viewer.pick} with @qcode{'point'} writes it, by
    ## @code{solid.Shape.corner}, @code{solid.Shape.centre} or
    ## @code{solid.Shape.midpoint}:
    ##
    ## @itemize
    ## @item
    ## with @kbd{Enter} for the origin and the start of @math{x} on the face's
    ## plane, @code{geom.UCS (@var{N}, @var{P1}, @var{P2})}, the origin at the
    ## start of @math{x};
    ##
    ## @item
    ## with one point for the origin on the face's plane,
    ## @code{geom.UCS (@var{N}, @var{O}, @var{O} + (@var{P2} - @var{P1}))},
    ## @math{x} running from it as from the start of @math{x} to the point
    ## towards @math{+x};
    ##
    ## @item
    ## with an origin laid into the plane from a point off it, or taken from
    ## two points, the same with the origin as its coordinates;
    ##
    ## @item
    ## with @var{MODE} @qcode{'points'} and @kbd{Enter} for the origin,
    ## @code{geom.UCS.threepoint (@var{P1}, @var{P2}, @var{P3})}.
    ## @end itemize
    ##
    ## A face or point without a name is written by its coordinates.  With
    ## @var{MODE} @qcode{'points'} and an origin picked, on a mesh, on an
    ## assembly and on a shape without names, @var{CODE} makes the UCS from
    ## coordinates, to the ten significant digits it carries.
    ##
    ## @example
    ## @group
    ## ## The top of a block made with 'Label', 'plate', x along its front
    ## [U, CODE] = pickucs (V);
    ## R.UCS = geom.UCS (normal (part, faces (part, 'Label', 'plate.zmax')), ...
    ##                   corner (part, faces (part, 'Label', ...
    ##                                        @{'plate.xmin', 'plate.ymin', ...
    ##                                         'plate.zmax'@})), ...
    ##                   corner (part, faces (part, 'Label', ...
    ##                                        @{'plate.xmax', 'plate.ymin', ...
    ##                                         'plate.zmax'@})));
    ##
    ## ## The same picked on a block without names
    ## R.UCS = geom.UCS ([0, 0, 1], [0, 0, 12], [1, 0, 12]);
    ## @end group
    ## @end example
    ##
    ## @seealso{geom.UCS, model.Viewer.pick}
    ## @end deftypefn
    function [U, CODE] = pickucs (this, MODE = 'face')

      ## Input validation
      if (! ischar (MODE) || ! any (strcmp (MODE, {'face', 'points'})))
        error ("model.Viewer.pickucs: MODE must be 'face' or 'points'.");
      endif
      if (! isopen (this) || isempty (this.Model))
        error ("model.Viewer.pickucs: the viewer is showing no shape.");
      endif

      [U, ~, CODE] = __pickucs__ (this, MODE, []);

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {model.Viewer} {} opacity (@var{V}, @var{WHAT}, @var{A})
    ## @deftypefnx {model.Viewer} {@var{A} =} opacity (@var{V})
    ##
    ## Hide solids, or show them through, to look inside a model.
    ##
    ## @code{opacity (@var{V}, @var{WHAT}, @var{A})} draws the solids
    ## @var{WHAT} chooses at the opacity @var{A}, from 1, opaque, as every
    ## solid is at first, to 0, hidden.  A hidden solid is neither drawn nor
    ## picked, so a click goes through it to what lies behind; a solid shown
    ## through is picked as before.  The window changes in place: nothing is
    ## drawn again but the solids chosen, and the view stays where it is.
    ## This is the viewer's own setting, for looking at a model: it is not
    ## kept by the shape, and no file carries it.
    ##
    ## @var{WHAT} chooses by any of:
    ##
    ## @multitable @columnfractions 0.2 0.8
    ## @item indices @tab the solids of those indices, in the order
    ## @code{solid.Shape.solids} and @code{model.Assembly.solids} list them
    ## @item a name @tab every solid of that @code{solid.Shape.Name}, and in
    ## an assembly every solid under a placement of that name, at any depth
    ## @item a path @tab a cell row of placement names from the top of the
    ## assembly, as the @code{path} field of @code{model.Assembly.solids}
    ## gives it, choosing every solid under the placement it ends at
    ## @item @qcode{'all'} @tab every solid
    ## @end multitable
    ##
    ## Names and paths match exactly, case included.  A name or a path that
    ## matches nothing is an error.  A mesh has no solids, so it takes one
    ## opacity for the whole, through @qcode{'all'} or the index 1.
    ##
    ## @example
    ## @group
    ## V = show (A);
    ## opacity (V, 'casing', 0.3);          # see into the casing
    ## opacity (V, @{'rotor', 'shaft'@}, 0);  # and hide the shaft
    ## opacity (V, 'all', 1);               # everything solid again
    ## @end group
    ## @end example
    ##
    ## Assigning @code{Model} again, as @code{show} does after a change to the
    ## model, keeps what was set by a name, a path or @qcode{'all'} and
    ## applies it to the new model wherever it still matches.  What was set by
    ## indices is dropped, since indices change with the model.
    ##
    ## @code{@var{A} = opacity (@var{V})} returns the opacity of every solid
    ## as a column, in the order of their indices, or the one of a mesh.  A
    ## viewer whose window was closed keeps what is set, for the next model
    ## it shows.
    ##
    ## @seealso{model.Viewer.pick, solid.Shape.solids, model.Assembly.solids}
    ## @end deftypefn
    function varargout = opacity (this, WHAT, A)

      if (nargin == 1)
        varargout = {state(this).opacity};
        return;
      endif

      ## Input validation
      if (nargin != 3)
        error ("model.Viewer.opacity: invalid number of input arguments.");
      endif
      if (! isfloat (A) || ! isreal (A) || ! isscalar (A)
          || ! (A >= 0 && A <= 1))
        error ("model.Viewer.opacity: A must be a real scalar from 0 to 1.");
      endif
      if (isempty (this.Model))
        error ("model.Viewer.opacity: the viewer is showing no shape.");
      endif
      st = state (this);
      ismesh = isa (st.mesh, 'polymesh.Mesh');
      if (ischar (WHAT) && isrow (WHAT))
        if (ismesh && ! strcmp (WHAT, 'all'))
          error (strcat ("model.Viewer.opacity: a mesh has no solids to", ...
                         " name; use 'all'."));
        endif
      elseif (iscellstr (WHAT) && isvector (WHAT)
              && all (cellfun (@isrow, WHAT)))
        if (ismesh)
          error (strcat ("model.Viewer.opacity: a mesh has no solids to", ...
                         " name; use 'all'."));
        endif
        WHAT = WHAT(:)';
      elseif (isnumeric (WHAT) && isreal (WHAT) && ! isempty (WHAT))
        n = numel (st.opacity);
        if (any (WHAT(:) != fix (WHAT(:))) || any (WHAT(:) < 1)
            || any (WHAT(:) > n))
          error (strcat ("model.Viewer.opacity: indices must be integers", ...
                         " from 1 to %d."), n);
        endif
      else
        error (strcat ("model.Viewer.opacity: WHAT must be indices, a", ...
                       " name, a path or 'all'."));
      endif
      I = matching (st, WHAT);
      if (isempty (I) && ischar (WHAT))
        error ("model.Viewer.opacity: nothing is named %s.", literal (WHAT));
      elseif (isempty (I))
        error ("model.Viewer.opacity: nothing lies at the path %s.", ...
               literal (WHAT));
      endif

      ## Kept for the next model shown, but for indices
      st.opacity(I) = A;
      if (ischar (WHAT) && strcmp (WHAT, 'all'))
        st.rules = {};
      endif
      if (! isnumeric (WHAT))
        same = cellfun (@(r) isequal (r{1}, WHAT), st.rules);
        st.rules = [st.rules(! same), {{WHAT, A}}];
      endif
      setstate (this, st);
      if (isopen (this))
        sendopacity (this, I, repmat (A, size (I)));
      endif

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {model.Viewer} {} view (@var{V}, @var{AZ}, @var{EL})
    ## @deftypefnx {model.Viewer} {} view (@dots{}, @qcode{'Zoom'}, @var{ZOOM})
    ## @deftypefnx {model.Viewer} {} view (@dots{}, @qcode{'Target'}, @var{TARGET})
    ## @deftypefnx {model.Viewer} {[@var{AZ}, @var{EL}, @var{ZOOM}, @var{TARGET}] =} view (@var{V})
    ##
    ## Set or query the direction the viewer looks from, and how close.
    ##
    ## @code{view (@var{V}, @var{AZ}, @var{EL})} turns the view to look at the
    ## shape from azimuth @var{AZ} and elevation @var{EL}, in degrees, and fits
    ## the shape to the window.  The angles are those Octave's @code{view}
    ## takes for a plot: @var{AZ} turns anticlockwise about @math{z}, seen from
    ## above, starting from the negative @math{y} axis, and @var{EL} rises from
    ## the @math{x}-@math{y} plane, from -90 looking straight up to 90 looking
    ## straight down.  The @math{z} axis points up the window; looking
    ## straight down or up, the @math{y} axis does, turned by @var{AZ}.  The
    ## mouse still turns the view afterwards.
    ##
    ## The option @qcode{'Zoom'} then magnifies the shape @var{ZOOM} times
    ## about the centre of the window: 1, the default, is the shape fitted, 2
    ## shows it twice as large and 0.5 half as large.
    ##
    ## The option @qcode{'Target'} looks at the point @var{TARGET}, a
    ## 3-element vector in millimetres, instead of the middle of the shape:
    ## the point Octave calls the camera target.  It is put at the centre of
    ## the window, @var{ZOOM} magnifies about it, and the mouse turns the view
    ## about it afterwards, as after a double click.  So a detail is seen
    ## close up from a script.
    ##
    ## @code{[@var{AZ}, @var{EL}, @var{ZOOM}, @var{TARGET}] = view (@var{V})}
    ## returns the view as it is now, however it got there: the angles it
    ## looks from, @var{AZ} from -180 to 180, its magnification against the
    ## shape fitted, and the point at the centre of the window, wherever the
    ## view was panned to.  Given back to @code{view}, as
    ## @code{view (@var{V}, @var{AZ}, @var{EL}, 'Zoom', @var{ZOOM}, 'Target',
    ## @var{TARGET})}, they restore it, so a view found with the mouse can be
    ## kept in a script.  After @kbd{T},
    ## the mouse can also turn the view about the line of sight, which they
    ## do not hold, so such a view is restored upright.
    ##
    ## The keys of the window give four of these views: @kbd{0} is
    ## @code{view (@var{V}, 45, 35.26)}, near enough, the isometric view the
    ## window opens with, @kbd{1} is @code{view (@var{V}, 0, 0)}, @kbd{2} is
    ## @code{view (@var{V}, 0, 90)} and @kbd{3} is
    ## @code{view (@var{V}, 90, 0)}.
    ##
    ## @example
    ## @group
    ## ## A shallow part looks deeper than it is from the isometric view;
    ## ## look from higher up
    ## part = solid.box (80, 40, 4);
    ## V = show (part);
    ## view (V, 30, 60);
    ## ## Closer, on the middle of the part
    ## view (V, 30, 60, 'Zoom', 2);
    ## ## Four times larger, on a corner
    ## view (V, 30, 60, 'Zoom', 4, 'Target', [80, 40, 4]);
    ## ## Keep a view found with the mouse, and restore it
    ## [az, el, zoom, target] = view (V);
    ## view (V, az, el, 'Zoom', zoom, 'Target', target);
    ## @end group
    ## @end example
    ##
    ## @seealso{solid.Shape.show}
    ## @end deftypefn
    function varargout = view (this, varargin)

      ## Input validation
      if (numel (varargin) == 1)
        error ("model.Viewer.view: invalid number of input arguments.");
      endif
      ZOOM = 1;
      TARGET = [];
      if (numel (varargin) > 0)
        if (nargout > 0)
          error ("model.Viewer.view: invalid number of output arguments.");
        endif
        AZ = varargin{1};
        EL = varargin{2};
        if (! isfloat (AZ) || ! isreal (AZ) || ! isscalar (AZ)
            || ! isfinite (AZ))
          error ("model.Viewer.view: AZ must be a finite real scalar.");
        endif
        if (! isfloat (EL) || ! isreal (EL) || ! isscalar (EL)
            || ! (EL >= -90 && EL <= 90))
          error (strcat ("model.Viewer.view: EL must be a real scalar in", ...
                         " the range [-90, 90] degrees."));
        endif
        opts = varargin(3:end);
        if (mod (numel (opts), 2) != 0)
          error ("model.Viewer.view: Name/Value arguments must come in pairs.");
        endif
        for ii = 1:2:numel (opts)
          name = opts{ii};
          val = opts{ii+1};
          if (! ischar (name) || ! isrow (name))
            error (strcat ("model.Viewer.view: option names must be", ...
                           " character vectors."));
          endif
          switch (lower (name))
            case 'zoom'
              if (! isfloat (val) || ! isreal (val) || ! isscalar (val)
                  || ! isfinite (val) || ! (val > 0))
                error (strcat ("model.Viewer.view: Zoom must be a positive", ...
                               " and finite real scalar."));
              endif
              ZOOM = val;
            case 'target'
              if (! isfloat (val) || ! isreal (val) || numel (val) != 3
                  || ! isvector (val) || ! all (isfinite (val)))
                error (strcat ("model.Viewer.view: Target must be a real", ...
                               " 3-element vector of finite values."));
              endif
              TARGET = val;
            otherwise
              error ("model.Viewer.view: unknown option '%s'.", name);
          endswitch
        endfor
      endif
      if (! isopen (this))
        error ("model.Viewer.view: the viewer's window is not open.");
      endif

      if (numel (varargin) > 0)
        send (this, sprintf ("view%s", sprintf (" %.17g", double (AZ), ...
                                                 double (EL), double (ZOOM), ...
                                                 double (TARGET))));
        receive (this, 10);
      else
        send (this, "getview");
        r = strsplit (receive (this, 10));
        ## Rounded to 1e-9, so that a view set reads back as given
        A = round (str2double (r(2:7)) * 1e9) / 1e9 + 0;
        varargout = {A(1), A(2), A(3), A(4:6)};
      endif

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {model.Viewer} {@var{IMG} =} capture (@var{V})
    ## @deftypefnx {model.Viewer} {} capture (@var{V}, @var{FILE})
    ## @deftypefnx {model.Viewer} {} capture (@dots{}, @qcode{'Size'}, [@var{W}, @var{H}])
    ##
    ## The picture the viewer shows, as an image or a file.
    ##
    ## @code{@var{IMG} = capture (@var{V})} returns what the window shows, the
    ## shape as it is turned and lit, as an @math{H}-by-@math{W}-by-3
    ## @code{uint8} image of red, green and blue, the size of the window: the
    ## form @code{imread} gives and @code{image} and @code{imwrite} take.  The
    ## size is in the pixels of the screen, so on a Mac's Retina screen, with
    ## two pixels to a point, the picture is twice the window's size in points
    ## and as sharp as the window.
    ##
    ## @code{capture (@var{V}, @var{FILE})} writes it to @var{FILE} instead,
    ## in the format its extension names, as @code{imwrite} writes it; PNG
    ## keeps every pixel.
    ##
    ## @code{capture (@dots{}, 'Size', [@var{W}, @var{H}])} draws the
    ## picture @var{W} pixels wide and @var{H} high instead, whatever the size
    ## of the window, so a picture for print can be finer than the screen.
    ## The view keeps its height: a picture of another shape than the window
    ## shows more or less at the sides.  Text, lines and the axes are drawn
    ## as on a screen of one pixel to a point, so the same size gives the
    ## same picture on every system.
    ##
    ## @example
    ## @group
    ## V = show (solid.cylinder (10, 30));
    ## view (V, 30, 20);
    ## capture (V, 'cylinder.png', 'Size', [1800, 1400]);
    ## @end group
    ## @end example
    ##
    ## @seealso{model.Viewer.view, imwrite}
    ## @end deftypefn
    function varargout = capture (this, varargin)

      ## Input validation
      FILE = '';
      if (mod (numel (varargin), 2) == 1)
        FILE = varargin{1};
        varargin(1) = [];
        if (! ischar (FILE) || ! isrow (FILE))
          error (strcat ("model.Viewer.capture: FILE must be a non-empty", ...
                         " character vector."));
        endif
      endif
      SZ = [0, 0];
      for ii = 1:2:numel (varargin)
        name = varargin{ii};
        val = varargin{ii+1};
        if (! ischar (name) || ! isrow (name))
          error (strcat ("model.Viewer.capture: option names must be", ...
                         " character vectors."));
        endif
        switch (lower (name))
          case 'size'
            if (! isnumeric (val) || ! isreal (val) || numel (val) != 2
                || ! all (isfinite (val)) || any (val < 1)
                || any (val != fix (val)))
              error (strcat ("model.Viewer.capture: Size must be [W, H],", ...
                             " two positive whole numbers of pixels."));
            endif
            SZ = double (val(:)');
          otherwise
            error ("model.Viewer.capture: unknown option '%s'.", name);
        endswitch
      endfor
      if (! isempty (FILE))
        folder = fileparts (FILE);
        if (! isempty (folder) && ! isfolder (folder))
          error ("model.Viewer.capture: folder '%s' does not exist.", folder);
        endif
      endif
      if (! isopen (this))
        error ("model.Viewer.capture: the viewer's window is not open.");
      endif

      send (this, sprintf ("capture %d %d", SZ));
      r = strsplit (receive (this, 30));
      if (! strcmp (r{1}, 'image'))
        error ("model.Viewer.capture: %s", strjoin (r(2:end), ' '));
      endif
      W = str2double (r{2});
      H = str2double (r{3});
      B = bytes (this, 3 * W * H, 30);
      IMG = permute (reshape (B, 3, W, H), [3, 2, 1]);
      if (! isempty (FILE))
        imwrite (IMG, FILE);
      endif
      if (isempty (FILE) || nargout > 0)
        varargout = {IMG};
      endif

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {model.Viewer} {} close (@var{V})
    ##
    ## Close the viewer's window.
    ##
    ## Assigning a shape afterwards opens a new window.
    ##
    ## @end deftypefn
    function close (this)

      st = state (this);
      if (isopen (this))
        send (this, "close");
        fclose (st.in);
        fclose (st.out);
        waitpid (st.pid);
      endif
      st.pid = -1;
      setstate (this, st);

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {model.Viewer} {@var{TF} =} isopen (@var{V})
    ##
    ## True while the viewer's window is open.
    ##
    ## @end deftypefn
    function TF = isopen (this)

      st = state (this);
      TF = (st.pid > 0);
      if (TF && ! alive (st.pid))
        ## The window was closed; release what is left of the process
        fclose (st.in);
        fclose (st.out);
        st.pid = -1;
        setstate (this, st);
        TF = false;
      endif

    endfunction

  endmethods

  methods (Access = private)

    ## One pick of KIND, face or point, prompted with ASK, which SHOWN
    ## records: the viewer's reply as words.  A click is taken from CLICKS
    ## when it is not empty, so that tests need no mouse; a NaN row there is
    ## the Enter key and an Inf row Escape.  Escape or a closed window ends the
    ## whole pick with an error.
    function [r, CLICKS, SHOWN] = one (V, KIND, ASK, CLICKS, SHOWN)

      SHOWN{end+1} = ASK;
      send (V, ["prompt " strrep(ASK, "\n", '\n')]);
      send (V, ["pickone " KIND]);
      if (! isempty (CLICKS))
        if (any (isnan (CLICKS(1,:))))
          send (V, "enter");
        elseif (any (isinf (CLICKS(1,:))))
          send (V, "cancel");
        else
          send (V, sprintf ("click %d %d", round (CLICKS(1,:))));
        endif
        CLICKS(1,:) = [];
      endif
      r = strsplit (receive (V, Inf));
      if (any (strcmp (r{1}, {'cancel', 'closed'})))
        error ("model.Viewer.pickucs: the pick was cancelled.");
      endif

    endfunction

    ## The points of pick (V, 'point'): each click snapped as pickucs snaps
    ## it, until Enter; Escape returns none.  CLICKS as __pick__ takes them.
    ## CODE rebuilds the points of a solid from the names of its faces, as
    ## pointcode writes it, a point it cannot rebuild by its coordinates, as
    ## the rows of one matrix for several points; on a mesh or an assembly
    ## it is their coordinates.
    function [P, CODE] = pickpoints (V, CLICKS)

      st = state (V);
      while (ischar (fgetl (st.out)))
      endwhile
      fclear (st.out);
      P = zeros (0, 3);
      R = {};
      scripted = ! isempty (CLICKS);
      send (V, "prompt Pick points: Enter finishes, Escape cancels");
      finished = false;
      unwind_protect
        while (! finished)
          send (V, "pickone point");
          if (scripted)
            if (isempty (CLICKS) || any (isnan (CLICKS(1,:))))
              send (V, "enter");
            elseif (any (isinf (CLICKS(1,:))))
              send (V, "cancel");
            else
              send (V, sprintf ("click %d %d", round (CLICKS(1,:))));
            endif
            CLICKS(1:min (1, rows (CLICKS)),:) = [];
            r = strsplit (receive (V, 10));
          else
            r = strsplit (receive (V, Inf));
          endif
          switch (r{1})
            case 'point'
              P(end+1,:) = str2double (r(2:4));
              R{end+1} = r;
            case 'skip'
              finished = true;
            case 'cancel'
              P = zeros (0, 3);
              R = {};
              finished = true;
            case 'closed'
              error (strcat ("model.Viewer.pick: the window was closed", ...
                             " during the pick."));
          endswitch
        endwhile
      unwind_protect_cleanup
        if (isopen (V))
          if (! finished)
            send (V, "cancel");
          endif
          send (V, "clearmarks");
          send (V, "prompt");
        endif
      end_unwind_protect

      CODE = '';
      if (isempty (P))
        return;
      endif
      S = shown (V);
      named = isa (S, 'solid.Shape') && isempty (st.model);
      SP = ' ';
      if (rows (P) > 1)
        SP = '';
      endif
      codes = cell (rows (P), 1);
      for k = 1:rows (P)
        codes{k} = valuetext (P(k,:));
        if (named)
          codes{k} = pointcode (S, R{k}, P(k,:), SP);
        endif
      endfor
      CODE = strjoin (codes, "; ");
      if (rows (P) > 1)
        CODE = sprintf ("[%s]", CODE);
      endif
      CODE = strrep (CODE, '__shape__', st.name);

    endfunction

    ## One point, prompted with ASK until a point is picked
    function [p, r, CLICKS, SHOWN] = point (V, ASK, CLICKS, SHOWN)

      do
        [r, CLICKS, SHOWN] = one (V, 'point', ASK, CLICKS, SHOWN);
      until (strcmp (r{1}, 'point'))
      p = str2double (r(2:4));

    endfunction

    function st = state (this)

      st = getappdata (0, sprintf ('drafting_model_viewer_%d', this.Id));

    endfunction

    function setstate (this, st)

      setappdata (0, sprintf ('drafting_model_viewer_%d', this.Id), st);

    endfunction

    ## The solid.Shape or polymesh.Mesh the window draws, an assembly's shape
    ## or mesh where an assembly is shown
    function S = shown (this)

      st = state (this);
      if (isa (st.mesh, 'polymesh.Mesh'))
        S = st.mesh;
      elseif (isa (st.shape, 'solid.Shape') && isequal (st.shape.Data, st.data))
        S = st.shape;
      else
        S = solid.Shape (st.data);
      endif

    endfunction

    ## The opacities set by name, path or 'all', applied again to the model
    ## now shown; those that no longer match anything are dropped
    function reapply (this)

      st = state (this);
      st.opacity = ones (numopaque (st), 1);
      keep = false (1, numel (st.rules));
      for k = 1:numel (st.rules)
        I = matching (st, st.rules{k}{1});
        if (! isempty (I))
          st.opacity(I) = st.rules{k}{2};
          keep(k) = true;
        endif
      endfor
      st.rules = st.rules(keep);
      setstate (this, st);
      I = find (st.opacity != 1);
      if (! isempty (I))
        sendopacity (this, I, st.opacity(I));
      endif

    endfunction

    ## Solids I drawn at the opacities A, a record of index and value each
    function sendopacity (this, I, A)

      idx = reshape (typecast (uint32 (I(:)'), 'uint8'), 4, []);
      val = reshape (typecast (double (A(:)'), 'uint8'), 8, []);
      send (this, sprintf ("opacity %d", numel (I)), [idx; val](:));

    endfunction

    function launch (this)

      if (! ispc () && ! ismac () && isempty (getenv ('DISPLAY')))
        error ("model.Viewer: the viewer needs a display, and none is set.");
      endif
      exe = '__occtview__';
      if (ispc ())
        exe = [exe, '.exe'];
      endif
      exe = file_in_loadpath (exe);
      st = state (this);
      args = {};
      if (st.hidden)
        args = {'--hidden'};
      endif
      if (ispc ())
        ## Open CASCADE's DLLs may sit beside the oct files, not the viewer
        old = getenv ('PATH');
        octdir = fileparts (file_in_loadpath ('__occt__.oct'));
        setenv ('PATH', [octdir, pathsep(), old]);
        unwind_protect
          [st.in, st.out, st.pid] = popen2 (exe, args);
        unwind_protect_cleanup
          setenv ('PATH', old);
        end_unwind_protect
      else
        [st.in, st.out, st.pid] = popen2 (exe, args);
      endif
      setstate (this, st);
      r = receive (this, 30);
      if (! strcmp (r, 'ready'))
        close (this);
        error ("model.Viewer: the viewer could not start: %s", r);
      endif
      send (this, ["title " title(st)]);

    endfunction

    function send (this, line, data = [])

      st = state (this);
      fputs (st.in, [line "\n"]);
      if (! isempty (data))
        fwrite (st.in, data, 'uint8');
      endif
      fflush (st.in);

    endfunction

    ## The lines a pick replies with, up to its last, LAST: done, cancel or
    ## closed, waiting up to TIMEOUT seconds for each
    function [R, LAST] = replies (this, TIMEOUT)

      R = {};
      do
        LAST = receive (this, TIMEOUT);
        R{end+1} = LAST;
      until (any (strcmp (LAST, {'done', 'cancel', 'closed'})))

    endfunction

    ## The next N bytes from the viewer, waiting up to TIMEOUT seconds for
    ## each part of them
    function B = bytes (this, N, TIMEOUT)

      st = state (this);
      B = zeros (N, 1, 'uint8');
      got = 0;
      t0 = tic ();
      while (got < N)
        [b, n] = fread (st.out, N - got, 'uint8=>uint8');
        if (n > 0)
          B(got+1:got+n) = b;
          got += n;
          t0 = tic ();
          continue;
        endif
        fclear (st.out);
        if (! alive (st.pid))
          error ("model.Viewer: the viewer closed.");
        endif
        if (toc (t0) > TIMEOUT)
          error ("model.Viewer: the viewer did not reply.");
        endif
        pause (0.001);
      endwhile

    endfunction

    ## The next line from the viewer, waiting up to TIMEOUT seconds
    function r = receive (this, timeout)

      st = state (this);
      t0 = tic ();
      while (true)
        r = fgetl (st.out);
        if (ischar (r))
          return;
        endif
        fclear (st.out);
        if (! alive (st.pid))
          r = 'closed';
          return;
        endif
        if (toc (t0) > timeout)
          error ("model.Viewer: the viewer did not reply.");
        endif
        pause (0.01);
      endwhile

    endfunction

  endmethods

endclassdef

## Whether the viewer's process PID is still running.  On Windows Octave's
## waitpid ignores WNOHANG and waits for the process to end, so it is asked
## of Windows itself
function TF = alive (pid)

  if (ispc ())
    TF = __mesh__ ('alive', 'model.Viewer', pid);
  else
    TF = (waitpid (pid, WNOHANG ()) == 0);
  endif

endfunction

## The edges E and the faces F a pick replied with in the lines R, in the
## order they were picked
function [E, F, I] = items (R)

  E = zeros (1, 0);
  F = zeros (1, 0);
  I = zeros (1, 0);
  for k = 1:numel (R)
    if (strncmp (R{k}, 'edge ', 5))
      E(end+1) = str2double (R{k}(6:end));
    elseif (strncmp (R{k}, 'face ', 5))
      F(end+1) = str2double (R{k}(6:end));
    elseif (strncmp (R{k}, 'solid ', 6))
      I(end+1) = str2double (R{k}(7:end));
    endif
  endfor
  E = unique (E, 'stable');
  F = unique (F, 'stable');
  I = unique (I, 'stable');

endfunction

## The points P and their triangles F, index and normal, a pick on a mesh
## replied with in the lines R
function [P, F] = meshpoints (R)

  P = zeros (0, 3);
  F = zeros (0, 4);
  for k = 1:numel (R)
    if (strncmp (R{k}, 'point ', 6))
      x = str2double (strsplit (R{k}(7:end)));
      P(end+1,:) = x(1:3);
      F(end+1,:) = x(4:7);
    endif
  endfor

endfunction

## The window's title: the name of the variable shown, once it is known
function T = title (st)

  if (st.named)
    T = sprintf ("%s (drafting)", st.name);
  else
    T = "drafting";
  endif

endfunction

## What a point pick took, for the next prompt: LABEL, what the click snapped
## to and where, rounded to what the eye can use, residue below the size SCALE
## of the part shown as zero
function t = describe (LABEL, r, SCALE)

  what = struct ('vertex', "a vertex", 'centre', "the centre of a circle", ...
                 'midpoint', "the midpoint of an edge", ...
                 'face', "a point on a face");
  p = str2double (r(2:4));
  p(abs (p) < 1e-9 * max (SCALE, 1)) = 0;
  c = strjoin (arrayfun (@(x) sprintf ("%.4g", x), p, ...
                         'UniformOutput', false), ", ");
  t = sprintf ("%s: %s at (%s).\n", LABEL, what.(r{5}), c);

endfunction

## True when the picked axes define a UCS
function TF = isvalidaxes (A)

  try
    model.Viewer.__ucs__ (A, zeros (0, 3));
    TF = true;
  catch
    TF = false;
  end_try_catch

endfunction

## True when every row of D is a direction parallel to the first, either way
function TF = alike (D)

  TF = ! any (isnan (D(:))) ...
       && all (sqrt (sum (cross (D, repmat (D(1,:), rows (D), 1), 2) .^ 2, ...
                          2)) <= 1e-9);

endfunction

## The query for the items IDX of KIND by what they share: their kind, a
## direction or normal or axis they share, and the box round them, widened
## to whole parts in DIGITS of a millimetre.  SP stands between the name of
## the query and its parenthesis, none for a query inside brackets.
function Q = itemquery (KIND, info, IDX, DIGITS, SP)

  if (strcmp (KIND, 'edge'))
    [type, dir, box] = info{1:3};
    args = {};
    if (all (strcmp (type(IDX), type{IDX(1)})))
      args(end+1:end+2) = {'Type', type{IDX(1)}};
    endif
    if (alike (dir(IDX,:)))
      args(end+1:end+2) = {'Direction', dir(IDX(1),:)};
    endif
  else
    [type, normal, axis, box] = info{:};
    args = {};
    if (all (strcmp (type(IDX), type{IDX(1)})))
      args(end+1:end+2) = {'Type', type{IDX(1)}};
    endif
    n = normal(IDX,:);
    a = axis(IDX,:);
    if (! any (isnan (n(:))) && all (n * n(1,:)' >= 1 - 1e-9))
      args(end+1:end+2) = {'Normal', n(1,:)};
    elseif (alike (a))
      args(end+1:end+2) = {'Axis', a(1,:)};
    endif
  endif
  b = [min(box(IDX,1:3), [], 1), max(box(IDX,4:6), [], 1)];
  b = [floor(b(1:3) * DIGITS), ceil(b(4:6) * DIGITS)] / DIGITS;
  args(end+1:end+2) = {'Within', b};

  Q = sprintf ("%ss%s(__shape__", KIND, SP);
  for k = 1:2:numel (args)
    v = args{k+1};
    if (ischar (v))
      v = sprintf ("'%s'", v);
    else
      v(abs (v) < 1e-12) = 0;
      v = arrayfun (@(x) sprintf ("%.10g", x), v, 'UniformOutput', false);
      v = sprintf ("[%s]", strjoin (v, ", "));
    endif
    Q = sprintf ("%s, '%s', %s", Q, args{k}, v);
  endfor
  Q = [Q ")"];

endfunction

## The code that selects exactly the faces T of the shape S by their names,
## INFO and NAMES what Open CASCADE reports of its faces and their names, the
## shape named __shape__ and SP the space before the call's parenthesis; empty
## when the names cannot select them.  One face is found by each of its names
## with the filters NARROWED adds, the shortest code winning, then the name
## that selects fewer faces alone, then the first in alphabetical order.
## Several faces are found by the longest dotted name every one of them has
## or begins with, with the filters NARROWED adds, else by a cell array of
## their names when each selects only faces among them.
function Q = namedfaces (S, T, INFO, NAMES, SP)

  Q = '';
  [labels, ~, copies, along] = NAMES{:};
  [type, normal, axis, box] = INFO{:};
  e = __occt__ ('edges', 'model.Viewer.pick', S.Data);
  [seam, onfaces] = e{4:5};
  onfaces(seam) = {[]};
  T = sort (T(:)');
  own = @(i) labels{i}(! cellfun ('isempty', labels{i}));

  ## What every face of T has in common, for the filters: the copies and the
  ## path labels of their names, the names of the faces all of them border,
  ## and their normal, kind and axis where they share one
  cand.Copy = {};
  cand.Along = {};
  for i = T
    for j = find (! cellfun ('isempty', labels{i}))
      c = copies{i}{j};
      if (isscalar (c))
        cand.Copy{end+1} = c;
      elseif (! isempty (c))
        cand.Copy{end+1} = num2cell (c);
      endif
    endfor
    cand.Along = [cand.Along, along{i}];
  endfor
  cand.Along = unique (cand.Along);
  near = [];
  for i = T
    touch = cellfun (@(f) any (f == i), onfaces);
    n = setdiff ([zeros(1, 0), onfaces{touch}], i);
    if (i == T(1))
      near = n;
    else
      near = intersect (near, n);
    endif
  endfor
  near = setdiff (near, T);
  cand.Adjacent = {};
  for i = near(:)'
    cand.Adjacent = [cand.Adjacent, own(i)];
  endfor
  cand.Adjacent = unique (cand.Adjacent);
  cand.Normal = {};
  n = normal(T,:);
  if (! any (isnan (n(:))) && all (n * n(1,:)' >= 1 - 1e-9))
    cand.Normal = {n(1,:)};
  endif
  cand.Type = {};
  if (all (strcmp (type(T), type{T(1)})))
    cand.Type = type(T(1));
  endif
  cand.Axis = {};
  if (alike (axis(T,:)))
    cand.Axis = {axis(T(1),:)};
  endif
  b = [min(box(T,1:3), [], 1), max(box(T,4:6), [], 1)];
  cand.Within = arrayfun (@(d) [floor(b(1:3) * d), ceil(b(4:6) * d)] / d, ...
                          [1000, 1e6], 'UniformOutput', false);

  query = @(a) faces (S, a{:});
  steps = {'Copy', 'Along', 'Adjacent', 'Adjacent', 'Normal', 'Type', ...
           'Axis', 'Within'};
  if (isscalar (T))
    Q = shortest (query, T, cellfun (@(c) {'Label', c}, own (T), ...
                                     'UniformOutput', false), ...
                  cand, steps, 'face', SP);
    return;
  endif

  ## The dotted names every face of T has or begins with, longest first
  common = {};
  for i = T
    p = {};
    for name = own (i)
      parts = strsplit (name{1}, '.');
      for k = 1:numel (parts)
        p{end+1} = strjoin (parts(1:k), '.');
      endfor
    endfor
    if (i == T(1))
      common = unique (p);
    else
      common = intersect (common, p);
    endif
  endfor
  depth = cellfun (@(c) numel (strfind (c, '.')), common);
  [~, k] = sort (-depth);
  for name = common(k)
    args = narrowed (query, T, {'Label', name{1}}, cand, steps);
    if (! isempty (args))
      Q = querytext ('face', args, SP);
      return;
    endif
  endfor

  ## A cell array of names, each selecting faces of T only, taken while they
  ## add faces until they select all of T
  alone = {};
  for i = T
    alone = [alone, own(i)];
  endfor
  alone = unique (alone);
  sel = cellfun (@(c) faces (S, 'Label', c), alone, 'UniformOutput', false);
  inside = cellfun (@(f) all (ismember (f, T)), sel);
  alone = alone(inside);
  sel = sel(inside);
  got = zeros (1, 0);
  given = {};
  while (! isequal (got, T) && ! isempty (alone))
    [m, k] = max (cellfun (@(f) numel (setdiff (f, got)), sel));
    if (m == 0)
      break;
    endif
    given{end+1} = alone{k};
    got = union (got, sel{k});
    alone(k) = [];
    sel(k) = [];
  endwhile
  if (isequal (got, T))
    Q = querytext ('face', {'Label', given}, SP);
  endif

endfunction

## The code that selects exactly the edges T of the shape S by the names of
## their faces, INFO and NAMES what Open CASCADE reports of its edges and the
## names of its faces, the shape named __shape__ and SP the space before the
## call's parenthesis; empty when the names cannot select them.  One edge is
## found 'Between' a name of each of its two faces, or where only one is
## named by 'Face' with its name, with the filters NARROWED adds, the
## shortest code winning, then the base that selects fewer edges alone, then
## the first in alphabetical order.  Several edges are found by 'Face' with
## a name or the beginning of one, or with a cell array of names whose faces
## have only edges of T, else 'Between' a name of a face they all bound and
## the names of their other faces, with the filters NARROWED adds, the
## shortest code winning.
function Q = namededges (S, T, INFO, NAMES, SP)

  Q = '';
  [labels, ~, copies, along] = NAMES{:};
  [type, dir, box, seam, onfaces] = INFO{:};
  T = sort (T(:)');
  own = @(i) labels{i}(! cellfun ('isempty', labels{i}));
  query = @(a) edges (S, a{:});
  steps = {'Copy', 'Along', 'Type', 'Direction', 'Within'};

  ## The faces each edge of T bounds, and what all the edges share, for the
  ## filters: the copies and path labels of the names of those faces, and
  ## their kind and direction where they share one
  F = unique ([zeros(1, 0), onfaces{T}]);
  cand.Copy = {};
  cand.Along = {};
  for i = F
    for j = find (! cellfun ('isempty', labels{i}))
      c = copies{i}{j};
      if (isscalar (c))
        cand.Copy{end+1} = c;
      elseif (! isempty (c))
        cand.Copy{end+1} = num2cell (c);
      endif
    endfor
    cand.Along = [cand.Along, along{i}];
  endfor
  cand.Along = unique (cand.Along);
  cand.Type = {};
  if (all (strcmp (type(T), type{T(1)})))
    cand.Type = type(T(1));
  endif
  cand.Direction = {};
  if (alike (dir(T,:)))
    cand.Direction = {dir(T(1),:)};
  endif
  b = [min(box(T,1:3), [], 1), max(box(T,4:6), [], 1)];
  cand.Within = arrayfun (@(d) [floor(b(1:3) * d), ceil(b(4:6) * d)] / d, ...
                          [1000, 1e6], 'UniformOutput', false);

  if (isscalar (T))
    f = unique (onfaces{T});
    bases = {};
    if (numel (f) == 2 && ! isempty (own (f(1))) && ! isempty (own (f(2))))
      for a = own (f(1))
        for z = own (f(2))
          bases{end+1} = {'Between', sort([a, z])};
        endfor
      endfor
      Q = shortest (query, T, bases, cand, steps, 'edge', SP);
    endif
    if (isempty (Q))
      bases = {};
      for i = f
        for a = own (i)
          bases{end+1} = {'Face', a{1}};
        endfor
      endfor
      Q = shortest (query, T, bases, cand, steps, 'edge', SP);
    endif
    return;
  endif

  ## 'Face' with each name of the faces they bound and each beginning of one,
  ## and with the names whose faces have only edges of T, taken while they
  ## add edges until they select all of T
  bases = {};
  inside = {};
  for i = F
    for name = own (i)
      parts = strsplit (name{1}, '.');
      for k = 1:numel (parts)
        bases{end+1} = {'Face', strjoin(parts(1:k), '.')};
      endfor
      if (all (ismember (query ({'Face', name{1}}), T)))
        inside{end+1} = name{1};
      endif
    endfor
  endfor
  [~, k] = unique (cellfun (@(c) c{2}, bases, 'UniformOutput', false));
  bases = bases(sort (k));
  inside = unique (inside);
  sel = cellfun (@(c) query ({'Face', c}), inside, 'UniformOutput', false);
  got = zeros (1, 0);
  given = {};
  while (! isequal (got, T) && ! isempty (inside))
    [m, k] = max (cellfun (@(e) numel (setdiff (e, got)), sel));
    if (m == 0)
      break;
    endif
    given{end+1} = inside{k};
    got = union (got, sel{k});
    inside(k) = [];
    sel(k) = [];
  endwhile
  if (numel (given) > 1 && isequal (got, T))
    bases{end+1} = {'Face', given};
  endif
  Q = shortest (query, T, bases, cand, steps, 'edge', SP);
  if (! isempty (Q))
    return;
  endif

  ## 'Between' a name of a face every edge bounds and the names of the other
  ## faces, as their longest common beginning or as a cell array of them
  shared = F;
  for e = T
    shared = intersect (shared, onfaces{e});
  endfor
  bases = {};
  for s = shared(:)'
    others = setdiff (F, s);
    if (isempty (others) || any (cellfun (@(i) isempty (own (i)), ...
                                          num2cell (others))))
      continue;
    endif
    common = {};
    for i = others
      p = {};
      for name = own (i)
        parts = strsplit (name{1}, '.');
        for k = 1:numel (parts)
          p{end+1} = strjoin (parts(1:k), '.');
        endfor
      endfor
      if (i == others(1))
        common = unique (p);
      else
        common = intersect (common, p);
      endif
    endfor
    firsts = cell (1, numel (others));
    for k = 1:numel (others)
      names = own (others(k));
      firsts{k} = names{1};
    endfor
    for a = own (s)
      for c = common
        bases{end+1} = {'Between', {a{1}, c{1}}};
      endfor
      bases{end+1} = {'Between', {a{1}, unique(firsts)}};
    endfor
  endfor
  Q = shortest (query, T, bases, cand, steps, 'edge', SP);

endfunction

## The code that rebuilds the point P of the solid S that the viewer's reply
## R snapped to, the shape named __shape__ and SP the space before each
## call's parenthesis: for a vertex, corner of the fewest named faces that
## meet there and share it alone, the shortest code among as many; for the
## centre of a circle or the midpoint of another edge, centre or midpoint of
## the edge as namededges finds it.  A point on a face, and one the names
## cannot rebuild, is its coordinates.
function Q = pointcode (S, R, P, SP)

  Q = valuetext (P);
  names = __occt__ ('names', 'model.Viewer.pick', S.Data);
  if (names{2} || numel (R) < 6)
    return;
  endif
  K = str2double (R(6:end));
  if (strcmp (R{5}, 'vertex'))
    info = __occt__ ('faces', 'model.Viewer.pick', S.Data);
    K = K(arrayfun (@(i) any (! cellfun ('isempty', names{1}{i})), K));
    for n = 1:numel (K)
      best = '';
      sets = nchoosek (K, n);
      for j = 1:rows (sets)
        F = namedfaces (S, sets(j,:), info, names, SP);
        if (isempty (F))
          continue;
        endif
        c = sprintf ("corner%s(__shape__, %s)", SP, F);
        if (! rebuilds (S, c, P))
          continue;
        endif
        [~, order] = sort ({c, best});
        if (isempty (best) || numel (c) < numel (best)
            || (numel (c) == numel (best) && order(1) == 1))
          best = c;
        endif
      endfor
      if (! isempty (best))
        Q = best;
        return;
      endif
    endfor
  elseif (any (strcmp (R{5}, {'centre', 'midpoint'})))
    info = __occt__ ('edges', 'model.Viewer.pick', S.Data);
    E = namededges (S, K, info, names, SP);
    c = sprintf ("%s%s(__shape__, %s)", R{5}, SP, E);
    if (! isempty (E) && rebuilds (S, c, P))
      Q = c;
    endif
  endif

endfunction

## The code that makes the UCS U picked on the solid S from the names of its
## faces, as one expression laid out by wrapped; empty when no part of it
## comes from names or it does not make U.  RF is the viewer's reply for
## the face picked, empty in the points mode, RP its replies for the two or
## three points of the axes and RO those for the origin, none, one or two.
## The normal is normal of the face, its vector for a face without a name,
## and each point as pointcode writes it.  The origin is the start of x when
## that lies in the face's plane, or the one point picked for it when that
## does, x running from it as from the start of x towards the second point;
## an origin laid into the plane, or taken from two points, is its
## coordinates.  The points mode gives threepoint of its three points, and
## its coordinates when an origin was picked.  A point lies in the plane
## within a millionth of SCALE, the size of the part.  The shape is named
## NAME in the code.
function Q = ucscode (S, U, RF, RP, RO, SCALE, NAME)

  Q = '';
  names = __occt__ ('names', 'model.Viewer.pickucs', S.Data);
  if (names{2})
    return;
  endif
  at = @(r) str2double (r(2:4));
  pt = cellfun (@(r) pointcode (S, r, at (r), ' '), RP, 'UniformOutput', false);
  tol = 1e-6 * max (SCALE, 1);
  if (isempty (RF))
    if (! isempty (RO))
      return;
    endif
    args = pt;
    head = "geom.UCS.threepoint (";
  else
    info = __occt__ ('faces', 'model.Viewer.pickucs', S.Data);
    k = str2double (RF{2});
    n = info{2}(k,:);
    f = str2double (RF(3:5));
    inplane = @(p) abs ((p - f) * n') <= tol;
    F = namedfaces (S, k, info, names, ' ');
    N = valuetext (n);
    if (! isempty (F))
      N = sprintf ("normal (__shape__, %s)", F);
    endif
    step = sprintf ("(%s - %s)", pt{2}, pt{1});
    if (isempty (RO) && inplane (at (RP{1})))
      args = {N, pt{1}, pt{2}};
    elseif (isscalar (RO) && inplane (at (RO{1})))
      o = pointcode (S, RO{1}, at (RO{1}), ' ');
      args = {N, o, sprintf("%s + %s", o, step)};
    else
      o = valuetext (U.Origin);
      args = {N, o, sprintf("%s + %s", o, step)};
    endif
    head = "geom.UCS (";
  endif
  code = [head, strjoin(args, ", "), ")"];
  if (isempty (strfind (code, '__shape__')))
    return;
  endif
  try
    V = eval (strrep (code, '__shape__', 'S'));
    same = norm (V.Normal - U.Normal) <= 1e-6 ...
           && norm (V.XAxis - U.XAxis) <= 1e-6 ...
           && norm (V.Origin - U.Origin) <= tol;
  catch
    same = false;
  end_try_catch
  if (same)
    Q = wrapped (strrep (code, '__shape__', NAME));
  endif

endfunction

## The code C laid out in lines of at most 80 columns, counted from column
## 0.  It breaks after every comma between the arguments of its outer call,
## the next argument aligned under the first.  Inside an argument it breaks
## after a comma where the line would otherwise pass 80 columns before the
## next place it could break, and before a ' + ' or ' - ' where the operand
## that follows would pass them, the rest aligned after the bracket that
## holds it.  Each break ends its line with ' ...'.
function T = wrapped (C)

  T = '';
  col = 0;
  open = [];
  k = 1;
  n = numel (C);
  ## The places a line can break: after the ', ' at K, before the operator
  ## of the ' + ' or ' - ' at K
  comma = @(k) k < n && C(k) == ',' && C(k+1) == ' ';
  oper = @(k) k + 2 <= n && C(k) == ' ' && any (C(k+1) == '+-') ...
              && C(k+2) == ' ';
  while (k <= n)
    ch = C(k);
    if (comma (k) || oper (k))
      ## What follows up to the next place to break, or for an operator its
      ## whole operand
      from = k + 2 * comma (k) + oper (k);
      j = from + 1;
      d = 0;
      while (j <= n && ! ((comma (k) || d == 0)
                          && (comma (j) || oper (j)
                              || (d == 0 && any (C(j) == ')]}')))))
        d += any (C(j) == '([{') - any (C(j) == ')]}');
        j += 1;
      endwhile
      room = col + comma (k) + (j - from) + 4 > 80;
      if (comma (k))
        if (numel (open) == 1 || room)
          T = [T, ", ...", "\n", repmat(' ', 1, open(end))];
          col = open(end);
        else
          T = [T, ", "];
          col += 2;
        endif
        k += 2;
      else
        if (room)
          T = [T, " ...", "\n", repmat(' ', 1, open(end))];
          col = open(end);
        else
          T(end+1) = ' ';
          col += 1;
        endif
        k += 1;
      endif
      continue;
    endif
    T(end+1) = ch;
    col += 1;
    if (any (ch == '([{'))
      open(end+1) = col;
    elseif (any (ch == ')]}'))
      open(end) = [];
    endif
    k += 1;
  endwhile

endfunction

## Whether the code Q, run on the shape __shape__, gives the point P, to a
## millionth of its size; code that errs gives none
function TF = rebuilds (__shape__, Q, P)

  try
    TF = norm (eval (Q) - P) <= 1e-6 * max (1, norm (P));
  catch
    TF = false;
  end_try_catch

endfunction

## The shortest code that selects exactly the items T of KIND, edge or face,
## by QUERY: each base of BASES narrowed by the filters STEPS with the values
## CAND gives, as NARROWED does, ties going to the base that selects fewer
## items alone, then to the first in alphabetical order.  SP is the space
## before the call's parenthesis.  Empty when no base can select T.
function code = shortest (QUERY, T, BASES, CAND, STEPS, KIND, SP)

  code = '';
  fewest = Inf;
  [~, k] = sort (cellfun (@valuetext, BASES, 'UniformOutput', false));
  for base = BASES(k)
    args = narrowed (QUERY, T, base{1}, CAND, STEPS);
    if (isempty (args))
      continue;
    endif
    c = querytext (KIND, args, SP);
    n = numel (QUERY (base{1}));
    if (isempty (code) || numel (c) < numel (code)
        || (numel (c) == numel (code) && n < fewest))
      code = c;
      fewest = n;
    endif
  endfor

endfunction

## The Name/Value pairs that select exactly the items T, faces or edges, by
## QUERY, which takes Name/Value pairs in a cell array: BASE, then the
## filters STEPS in order, each value among those CAND gives for it; an
## 'Adjacent' that comes twice adds a second face to border, beside the
## first.  A filter is added with the value that leaves the fewest items,
## when it leaves fewer than before and all of T, until only T is left; then
## each filter added is dropped again when T is still all that is left
## without it.  Empty when the filters cannot leave T alone.
function args = narrowed (QUERY, T, BASE, CAND, STEPS)

  args = BASE;
  sel = QUERY (BASE);
  if (! all (ismember (T, sel)))
    args = {};
    return;
  endif
  for k = 1:numel (STEPS)
    if (isequal (sel, T))
      break;
    endif
    key = STEPS{k};
    values = CAND.(key);
    at = find (strcmp (args(1:2:end), key)) * 2;
    if (strcmp (key, 'Adjacent') && ! isempty (at))
      ## The second neighbour, beside the one already added
      values = cellfun (@(v) {args{at}, v}, setdiff (values, args{at}), ...
                        'UniformOutput', false);
    endif
    best = [];
    for v = values(:)'
      trial = [args, {key, v{1}}];
      if (! isempty (at))
        trial = args;
        trial{at} = v{1};
      endif
      f = QUERY (trial);
      if (all (ismember (T, f)) && numel (f) < numel (sel)
          && (isempty (best) || numel (f) < numel (best.sel)))
        best = struct ('args', {trial}, 'sel', f);
      endif
    endfor
    if (! isempty (best))
      args = best.args;
      sel = best.sel;
    endif
  endfor
  if (! isequal (sel, T))
    args = {};
    return;
  endif
  for k = numel (args) - 1:-2:numel (BASE) + 1
    without = args([1:k-1, k+2:end]);
    if (isequal (QUERY (without), T))
      args = without;
    endif
  endfor

endfunction

## The call KIND + 's' on the shape __shape__ with the Name/Value pairs ARGS,
## as code, SP the space before its parenthesis
function Q = querytext (KIND, ARGS, SP)

  Q = sprintf ("%ss%s(__shape__", KIND, SP);
  for k = 1:2:numel (ARGS)
    Q = sprintf ("%s, '%s', %s", Q, ARGS{k}, valuetext (ARGS{k+1}));
  endfor
  Q = [Q ")"];

endfunction

## A value of a query as code: text quoted, a number as it is, a vector in
## brackets and a cell array in braces
function t = valuetext (v)

  if (iscell (v))
    t = sprintf ("{%s}", strjoin (cellfun (@valuetext, v, ...
                                           'UniformOutput', false), ", "));
  elseif (ischar (v))
    t = sprintf ("'%s'", v);
  else
    v(abs (v) < 1e-12) = 0;
    t = strjoin (arrayfun (@(x) sprintf ("%.10g", x), v, ...
                           'UniformOutput', false), ", ");
    if (! isscalar (v))
      t = sprintf ("[%s]", t);
    endif
  endif

endfunction

## The indices the code Q selects on the shape S, run as written, in the
## order it gives them
function I = chosen (__shape__, Q)

  I = eval (Q);
  I = I(:)';

endfunction

## How many opacities the model shown has: one for each solid, or one for
## the whole of a mesh
function n = numopaque (st)

  if (isa (st.mesh, 'polymesh.Mesh'))
    n = double (! isempty (st.mesh));
  else
    n = numel (st.list);
  endif

endfunction

## The indices WHAT selects: every one for 'all'; for a name, the solids of
## that name and those under a placement of that name at any depth; for a
## path, the solids under it; nothing by name or path on a mesh
function I = matching (st, WHAT)

  if (ischar (WHAT) && strcmp (WHAT, 'all'))
    I = 1:numopaque (st);
  elseif (isnumeric (WHAT))
    I = unique (WHAT(:)');
  elseif (isa (st.mesh, 'polymesh.Mesh'))
    I = zeros (1, 0);
  elseif (ischar (WHAT))
    L = st.list;
    I = find (strcmp ({L.name}, WHAT) ...
              | cellfun (@(p) any (strcmp (p, WHAT)), {L.path}));
  else
    L = st.list;
    m = numel (WHAT);
    I = find (cellfun (@(p) numel (p) >= m && isequal (p(1:m), WHAT), ...
                       {L.path}));
  endif

endfunction

## X as Octave code: a name quoted, a path a cell of them, indices a number
## or a row of them
function t = literal (X)

  if (ischar (X))
    t = ["'" strrep(X, "'", "''") "'"];
  elseif (iscell (X))
    t = ["{" strjoin(cellfun (@literal, X, 'UniformOutput', false), ", ") "}"];
  elseif (isscalar (X))
    t = sprintf ("%d", X);
  else
    t = ["[" strjoin(arrayfun (@(k) sprintf ("%d", k), X, ...
                               'UniformOutput', false), ", ") "]"];
  endif

endfunction

## The code that selects the solids I again: the name they share, else the
## longest path they share, where either selects them alone, else I
function CODE = solidcode (st, I)

  L = st.list;
  names = unique ({L(I).name});
  if (numel (names) == 1 && ! isempty (names{1})
      && isequal (matching (st, names{1}), sort (I)))
    CODE = literal (names{1});
    return;
  endif
  P = L(I(1)).path;
  for k = I(2:end)
    q = L(k).path;
    m = 0;
    while (m < min (numel (P), numel (q)) && strcmp (P{m+1}, q{m+1}))
      m++;
    endwhile
    P = P(1:m);
  endfor
  if (! isempty (P) && isequal (matching (st, P), sort (I)))
    CODE = literal (P);
  else
    CODE = literal (I);
  endif

endfunction

## Whether an assembly has a mesh among its parts, at any depth
function TF = hasmesh (A)

  TF = false;
  for k = 1:numel (A.Parts)
    X = A.Parts(k).item;
    TF = isa (X, 'polymesh.Mesh') || (isa (X, 'model.Assembly') && hasmesh (X));
    if (TF)
      return;
    endif
  endfor

endfunction

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## The window opens with the first shape and closes on demand
%! V = model.Viewer ('Hidden', true);
%! assert_equal (isopen (V), false);
%! V.Model = solid.box (10, 20, 30);
%! assert_equal (isopen (V), true);
%! assert_equal (volume (V.Model), 6000, 1e-9);
%! close (V);
%! assert_equal (isopen (V), false);

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## A shape read back keeps its colours and names
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   S = solid.box (10, 20, 30);
%!   S.Colour = [1, 0, 0];
%!   S.Name = {'block'};
%!   V.Model = S;
%!   assert_equal (V.Model.Colour, [1, 0, 0]);
%!   assert_equal (V.Model.Name, {'block'});
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## A double click takes the point of the shape under it
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.box (10, 20, 30);
%!   C = V.__dblclick__ (V.__project__ ([5, 10, 30]));
%!   assert_equal (C, [5, 10, 30], 0.05);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## and the view turns about it: the point stays where it is on screen
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.box (10, 20, 30);
%!   C = V.__dblclick__ (V.__project__ ([10, 20, 30]));
%!   PX = V.__project__ (C);
%!   V.__drag__ ([450, 350], [520, 300]);
%!   assert_equal (V.__project__ (C), PX, 1);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## The mouse turns the view keeping z up the window
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.box (80, 40, 30);
%!   assert_equal (V.__turn__ (), 'upright');
%!   V.__drag__ ([450, 350], [520, 280]);
%!   u = diff ([V.__project__([0, 0, 0]); V.__project__([0, 0, 30])]);
%!   assert_equal (u(1), 0, 1);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## so a view the mouse found is restored as it was
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.box (80, 40, 30);
%!   V.__drag__ ([450, 350], [520, 280]);
%!   I = capture (V);
%!   [az, el, zoom, target] = view (V);
%!   view (V, az, el, 'Zoom', zoom, 'Target', target);
%!   assert_equal (nnz (any (capture (V) != I, 3)) <= 20, true);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## T lets the mouse turn the view any way
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.box (80, 40, 30);
%!   V.__key__ ('T');
%!   assert_equal (V.__turn__ (), 'free');
%!   V.__drag__ ([450, 350], [520, 280]);
%!   u = diff ([V.__project__([0, 0, 0]); V.__project__([0, 0, 30])]);
%!   assert_equal (abs (u(1)) > 5, true);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## and T again stands the view upright
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.box (80, 40, 30);
%!   V.__key__ ('T');
%!   V.__drag__ ([450, 350], [520, 280]);
%!   V.__key__ ('T');
%!   assert_equal (V.__turn__ (), 'upright');
%!   u = diff ([V.__project__([0, 0, 0]); V.__project__([0, 0, 30])]);
%!   assert_equal (u(1), 0, 1);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## A double click that misses the shape takes nothing
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.box (10, 20, 30);
%!   assert_equal (V.__dblclick__ ([2, 2]), []);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## The window opens on the isometric view
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.box (10, 20, 30);
%!   [az, el] = view (V);
%!   assert_equal ([az, el], [45, atand(1 / sqrt (2))], 1e-8);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## A view set reads back as given
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.box (10, 20, 30);
%!   view (V, 30, 60);
%!   [az, el] = view (V);
%!   assert_equal ([az, el], [30, 60]);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## Straight down, the azimuth is kept
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.box (10, 20, 30);
%!   view (V, 30, 90);
%!   [az, el] = view (V);
%!   assert_equal ([az, el], [30, 90]);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## The azimuth reads back from -180 to 180
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.box (10, 20, 30);
%!   view (V, 200, -20);
%!   [az, el] = view (V);
%!   assert_equal ([az, el], [-160, -20]);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## Seen from above, x runs right and y up the window
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.box (10, 20, 30);
%!   view (V, 0, 90);
%!   O = V.__project__ ([0, 0, 30]);
%!   X = V.__project__ ([10, 0, 30]);
%!   Y = V.__project__ ([0, 20, 30]);
%!   assert_equal ([X(1) > O(1), Y(2) < O(2)], [true, true]);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## Seen from the front, z runs up the window
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.box (10, 20, 30);
%!   view (V, 0, 0);
%!   O = V.__project__ ([0, 0, 0]);
%!   Z = V.__project__ ([0, 0, 30]);
%!   assert_equal (Z(2) < O(2), true);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## and looks along y
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.box (10, 20, 30);
%!   view (V, 0, 0);
%!   assert_equal (V.__project__ ([5, 20, 10]), V.__project__ ([5, 0, 10]));
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## A zoom set reads back as given
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.box (10, 20, 30);
%!   view (V, 30, 60, 'Zoom', 2.5);
%!   [az, el, zoom] = view (V);
%!   assert_equal ([az, el, zoom], [30, 60, 2.5]);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## A view set without a zoom fits the shape
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.box (10, 20, 30);
%!   view (V, 30, 60, 'Zoom', 2);
%!   view (V, 30, 60);
%!   [~, ~, zoom] = view (V);
%!   assert_equal (zoom, 1);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## A zoom of 2 shows the shape twice as large
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.box (10, 20, 30);
%!   view (V, 0, 0);
%!   a = norm (diff ([V.__project__([0, 0, 0]); V.__project__([10, 0, 0])]));
%!   view (V, 0, 0, 'Zoom', 2);
%!   b = norm (diff ([V.__project__([0, 0, 0]); V.__project__([10, 0, 0])]));
%!   assert_equal (b / a, 2, 0.02);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## A target set reads back as given
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.box (80, 40, 4);
%!   view (V, 30, 60, 'Zoom', 4, 'Target', [80, 40, 4]);
%!   [az, el, zoom, target] = view (V);
%!   assert_equal ([az, el, zoom, target], [30, 60, 4, 80, 40, 4]);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## The target is at the centre of the window
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.box (80, 40, 4);
%!   view (V, 30, 60, 'Zoom', 4, 'Target', [80, 40, 4]);
%!   assert_equal (V.__project__ ([80, 40, 4]), [450, 350], 1);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## Without a target, the middle of the shape is
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.box (80, 40, 4);
%!   view (V, 30, 60, 'Zoom', 4);
%!   [~, ~, ~, target] = view (V);
%!   assert_equal (target, [40, 20, 2], 1e-9);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## A target set without a zoom keeps the shape fitted
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.box (80, 40, 4);
%!   view (V, 30, 60, 'Target', [80, 40, 4]);
%!   [~, ~, zoom, target] = view (V);
%!   assert_equal ([zoom, target], [1, 80, 40, 4]);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## A view read back and set again reads back the same
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.box (80, 40, 4);
%!   view (V, 30, 60, 'Zoom', 4, 'Target', [80, 40, 4]);
%!   [az, el, zoom, target] = view (V);
%!   view (V, az, el, 'Zoom', zoom, 'Target', target);
%!   [az2, el2, zoom2, target2] = view (V);
%!   assert_equal ([az2, el2, zoom2, target2], [az, el, zoom, target]);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## A view read back and set again draws the same picture.  The view comes
%! ## back to within 1e-9, which can flip a pixel on an edge; a view 0.1
%! ## degrees or 1% of zoom off changes some 350 pixels.
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.box (80, 40, 4);
%!   view (V, 30, 60, 'Zoom', 4, 'Target', [80, 40, 4]);
%!   I = capture (V);
%!   [az, el, zoom, target] = view (V);
%!   view (V, az, el, 'Zoom', zoom, 'Target', target);
%!   assert_equal (nnz (any (capture (V) != I, 3)) <= 20, true);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!error<model.Viewer.view: invalid number of input arguments.> ...
%! view (model.Viewer ('Hidden', true), 30)
%!error<model.Viewer.view: invalid number of output arguments.> ...
%! A = view (model.Viewer ('Hidden', true), 30, 60);
%!error<model.Viewer.view: AZ must be a finite real scalar.> ...
%! view (model.Viewer ('Hidden', true), Inf, 60)
%!error<model.Viewer.view: AZ must be a finite real scalar.> ...
%! view (model.Viewer ('Hidden', true), [30, 40], 60)
%!error<model.Viewer.view: EL must be a real scalar in the range \[-90, 90\] degrees.> ...
%! view (model.Viewer ('Hidden', true), 30, 91)
%!error<model.Viewer.view: EL must be a real scalar in the range \[-90, 90\] degrees.> ...
%! view (model.Viewer ('Hidden', true), 30, NaN)
%!error<model.Viewer.view: EL must be a real scalar in the range \[-90, 90\] degrees.> ...
%! view (model.Viewer ('Hidden', true), 30, 'a')
%!error<model.Viewer.view: Name/Value arguments must come in pairs.> ...
%! view (model.Viewer ('Hidden', true), 30, 60, 2)
%!error<model.Viewer.view: option names must be character vectors.> ...
%! view (model.Viewer ('Hidden', true), 30, 60, 2, [1, 2, 3])
%!error<model.Viewer.view: unknown option 'Zom'.> ...
%! view (model.Viewer ('Hidden', true), 30, 60, 'Zom', 2)
%!error<model.Viewer.view: Zoom must be a positive and finite real scalar.> ...
%! view (model.Viewer ('Hidden', true), 30, 60, 'Zoom', 0)
%!error<model.Viewer.view: Zoom must be a positive and finite real scalar.> ...
%! view (model.Viewer ('Hidden', true), 30, 60, 'Zoom', Inf)
%!error<model.Viewer.view: Zoom must be a positive and finite real scalar.> ...
%! view (model.Viewer ('Hidden', true), 30, 60, 'Zoom', [1, 2])
%!error<model.Viewer.view: Zoom must be a positive and finite real scalar.> ...
%! view (model.Viewer ('Hidden', true), 30, 60, 'Zoom', [])
%!error<model.Viewer.view: Target must be a real 3-element vector of finite values.> ...
%! view (model.Viewer ('Hidden', true), 30, 60, 'Target', [1, 2])
%!error<model.Viewer.view: Target must be a real 3-element vector of finite values.> ...
%! view (model.Viewer ('Hidden', true), 30, 60, 'Target', [1, 2, NaN])
%!error<model.Viewer.view: Target must be a real 3-element vector of finite values.> ...
%! view (model.Viewer ('Hidden', true), 30, 60, 'Target', 'abc')
%!error<model.Viewer.view: Target must be a real 3-element vector of finite values.> ...
%! view (model.Viewer ('Hidden', true), 30, 60, 'Target', [])
%!error<model.Viewer.view: invalid number of output arguments.> ...
%! A = view (model.Viewer ('Hidden', true), 30, 60, 'Zoom', 2);

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## capture: the window's picture, the right way up
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.box (10, 20, 30);
%!   I = capture (V);
%!   assert_equal ([size(I), isa(I, 'uint8')], [700, 900, 3, true]);
%!   assert_equal (mean (I(1,:,:)(:)) > mean (I(end,:,:)(:)), true);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## capture: Size draws the picture at any size
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.box (10, 20, 30);
%!   assert_equal (size (capture (V, 'Size', [1800, 400])), [400, 1800, 3]);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## capture: a file holds the picture
%! V = model.Viewer ('Hidden', true);
%! f = [tempname(), '.png'];
%! unwind_protect
%!   V.Model = solid.box (10, 20, 30);
%!   capture (V, f, 'size', [300, 200]);
%!   assert_equal (imread (f), capture (V, 'Size', [300, 200]));
%! unwind_protect_cleanup
%!   close (V);
%!   [~] = unlink (f);
%! end_unwind_protect

%!error<model.Viewer.capture: FILE must be a non-empty character vector.> ...
%! capture (model.Viewer ('Hidden', true), 1)
%!error<model.Viewer.capture: Size must be \[W, H\], two positive whole numbers of pixels.> ...
%! capture (model.Viewer ('Hidden', true), 'Size', [0, 10])
%!error<model.Viewer.capture: Size must be \[W, H\], two positive whole numbers of pixels.> ...
%! capture (model.Viewer ('Hidden', true), 'Size', [10.5, 10])
%!error<model.Viewer.capture: Size must be \[W, H\], two positive whole numbers of pixels.> ...
%! capture (model.Viewer ('Hidden', true), 'Size', 10)
%!error<model.Viewer.capture: unknown option 'Width'.> ...
%! capture (model.Viewer ('Hidden', true), 'Width', 10)
%!error<model.Viewer.capture: option names must be character vectors.> ...
%! capture (model.Viewer ('Hidden', true), 'a.png', 1, 2)
%!error<model.Viewer.capture: folder 'no_such_folder_9f2c' does not exist.> ...
%! capture (model.Viewer ('Hidden', true), fullfile ('no_such_folder_9f2c', 'a.png'))
%!error<model.Viewer.capture: the viewer's window is not open.> ...
%! capture (model.Viewer ('Hidden', true))
%!error<model.Viewer.view: the viewer's window is not open.> ...
%! view (model.Viewer ('Hidden', true))

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## A pixel picks the face and the edge the queries name
%! B = solid.box (10, 20, 30);
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = B;
%!   r = V.__pickat__ ('face', V.__project__ ([5, 10, 30]));
%!   assert_equal (r, sprintf ("face %d", faces (B, 'Normal', [0, 0, 1])));
%!   r = V.__pickat__ ('edge', V.__project__ ([5, 0, 30]));
%!   assert_equal (r, sprintf ("edge %d", ...
%!                             edges (B, 'Within', [0, 0, 30, 10, 0, 30])));
%!   assert_equal (V.__pickat__ ('face', [2, 2]), 'none');
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## The seam of a cylinder is never offered
%! C = solid.cylinder (4, 12);
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = C;
%!   assert_equal (V.__pickat__ ('edge', V.__project__ ([4, 0, 6])), 'none');
%!   assert_equal (V.__pickat__ ('any', V.__project__ ([4, 0, 6])), ...
%!                 sprintf ("face %d", faces (C, 'Type', 'cylinder')));
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## A new shape replaces the old one, and the empty shape clears the view
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.box (10, 20, 30);
%!   px = V.__project__ ([5, 10, 30]);
%!   V.Model = solid.Shape ();
%!   assert_equal (V.__pickat__ ('face', px), 'none');
%!   V.Model = solid.box (10, 20, 30);
%!   assert_equal (V.__pickat__ ('face', px)(1:4), 'face');
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## What a pick holds is drawn in orange, so that a click visibly took
%! orange = @(I) I(:,:,1) > 2 * I(:,:,2) & I(:,:,3) < 60;
%! near = @(M, p) any (any (M(round (p(2)) + (-3:5), round (p(1)) + (-3:5))));
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.box (10, 20, 30);
%!   pe = V.__project__ ([5, 0, 30]);
%!   pf = V.__project__ ([10, 10, 15]);
%!   V.__pickstart__ ('any');
%!   M = orange (capture (V));
%!   assert_equal ([near(M, pe), near(M, pf)], [false, false]);
%!   assert_equal (V.__click__ (pe), 1);
%!   M = orange (capture (V));
%!   assert_equal (near (M, pe), true);
%!   assert_equal (near (M, pf), false);
%!   assert_equal (V.__click__ (pf), 2);
%!   assert_equal (near (orange (capture (V)), pf), true);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## A bore cut by a tool longer than the part is picked where it is, not in
%! ## the air beside the part (Open CASCADE 7.8 places its analytic cylinder
%! ## where the untrimmed surface begins)
%! B = hole (solid.box (80, 40, 12), [20, 20, 12], 8, Inf);
%! W = sprintf ("face %d", faces (B, 'Type', 'cylinder'));
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = B;
%!   wall = V.__pickat__ ('face', V.__project__ ([17.17, 22.83, 10]));
%!   air = V.__pickat__ ('face', V.__project__ ([16, 20, 20]));
%!   assert_equal (wall, W);
%!   assert_equal (strcmp (air, W), false);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!test  # four upright edges share one query
%! B = solid.box (10, 20, 30);
%! Q = model.Viewer.__query__ (B, 'edge', edges (B, 'Direction', ...
%!                                               [0, 0, 1]), 'part');
%! assert_equal (Q, ["edges (part, 'Type', 'line', 'Direction',", ...
%!                   " [0, 0, 1], 'Within', [0, 0, 0, 10, 20, 30])"]);

%!test  # the top face of a block
%! B = solid.box (10, 20, 30);
%! Q = model.Viewer.__query__ (B, 'face', faces (B, 'Normal', ...
%!                                               [0, 0, 1]), 'B');
%! assert_equal (Q, ["faces (B, 'Type', 'plane', 'Normal',", ...
%!                   " [0, 0, 1], 'Within', [0, 0, 30, 10, 20, 30])"]);
%!test  # a face of a mirrored block, by its true outward normal
%! B = mirror (solid.box (10, 20, 30), [1, 0, 0], [5, 0, 0]);
%! Q = model.Viewer.__query__ (B, 'face', faces (B, 'Within', ...
%!                                               [10, 0, 0, 10, 20, 30]), 'B');
%! assert_equal (Q, ["faces (B, 'Type', 'plane', 'Normal',", ...
%!                   " [1, 0, 0], 'Within', [10, 0, 0, 10, 20, 30])"]);
%!test  # every face of a cylinder, by the box round them alone
%! C = solid.cylinder (4, 12);
%! Q = model.Viewer.__query__ (C, 'face', 1:3, 'C');
%! assert_equal (Q, "faces (C, 'Within', [-4, -4, 0, 4, 4, 12])");
%!test  # two top edges one query would overshoot get one query each
%! B = solid.box (80, 40, 12);
%! E = [edges(B, 'Direction', [1, 0, 0], 'Within', [0, 0, 12, 80, 0, 12]), ...
%!      edges(B, 'Direction', [0, 1, 0], 'Within', [80, 0, 12, 80, 40, 12])];
%! Q = model.Viewer.__query__ (B, 'edge', E, 'B');
%! assert_equal (sort (eval (Q)), sort (E));
%!test  # the code joins one query for each
%! B = solid.box (80, 40, 12);
%! E = [edges(B, 'Direction', [1, 0, 0], 'Within', [0, 0, 12, 80, 0, 12]), ...
%!      edges(B, 'Direction', [0, 1, 0], 'Within', [80, 0, 12, 80, 40, 12])];
%! Q = model.Viewer.__query__ (B, 'edge', E, 'B');
%! assert_equal (strncmp (Q, "[edges(B, ", 10), true);
%!test  # a named face by its name
%! B = solid.box (60, 40, 10, 'Label', 'plate');
%! Q = model.Viewer.__query__ (B, 'face', faces (B, 'Label', 'plate.zmax'), ...
%!                             'B');
%! assert_equal (Q, "faces (B, 'Label', 'plate.zmax')");
%!test  # every face of a name by the name they share
%! B = solid.box (60, 40, 10, 'Label', 'plate');
%! Q = model.Viewer.__query__ (B, 'face', 1:6, 'B');
%! assert_equal (Q, "faces (B, 'Label', 'plate')");
%!test  # two faces by a cell array of their names
%! B = solid.box (60, 40, 10, 'Label', 'plate');
%! F = faces (B, 'Label', {'plate.zmax', 'plate.xmin'});
%! Q = model.Viewer.__query__ (B, 'face', F, 'B');
%! assert_equal (Q, "faces (B, 'Label', {'plate.xmin', 'plate.zmax'})");
%!test  # a wall of an unlabelled segment by its name, neighbour and normal
%! R = geom.Region ([0, 0; 40, 0; 40, 5; 5, 5; 5, 30; 0, 30], ...
%!                  'Label', {'base', '', '', 'inside', '', ''});
%! S = solid.extrude (R, 10, 'Label', 'rib');
%! Q = model.Viewer.__query__ (S, 'face', ...
%!                             faces (S, 'Within', [40, 0, 0, 40, 5, 10]), 'S');
%! assert_equal (Q, ["faces (S, 'Label', 'rib.side', 'Adjacent',", ...
%!                   " 'rib.side.base', 'Normal', [1, 0, 0])"]);
%!test  # a round of one copy of an array, by its copy and a neighbour
%! B = translate (solid.box (20, 10, 5, 'Label', 'plate'), [30, -5, 0]);
%! B = fillet (B, edges (B, 'Face', 'plate.zmax'), 2, 'Label', 'edge_round');
%! S = polararray (B, 6, 360);
%! F = faces (S, 'Label', 'edge_round', 'Copy', 3, ...
%!            'Adjacent', {'plate.zmax', 'plate.ymin'});
%! Q = model.Viewer.__query__ (S, 'face', F, 'S');
%! assert_equal (Q, ["faces (S, 'Label', 'edge_round', 'Copy', 3,", ...
%!                   " 'Adjacent', 'plate.ymin')"]);
%!test  # a swept face of one copy, by its copy and its path segment
%! R = geom.Region ([-5, -3; 5, -3; 5, 3; -5, 3], ...
%!                  'Label', {'', '', 'top', ''});
%! P = geom.Path ([0, 0, 0; 0, 0, 40; 30, 0, 40], ...
%!                'Label', {'upright', 'arm'});
%! S = rectarray (solid.sweep (R, P, 'Label', 'bracket'), [3, 1, 1], ...
%!                [50, 0, 0]);
%! F = faces (S, 'Label', 'bracket.side.top', 'Copy', 2, 'Along', 'arm');
%! Q = model.Viewer.__query__ (S, 'face', F, 'S');
%! assert_equal (Q, ["faces (S, 'Label', 'bracket.side.top', 'Copy', 2,", ...
%!                   " 'Along', 'arm')"]);
%!test  # a copy dropped again where a neighbour picks the face out alone
%! post = solid.extrude (geom.Region ([0, 0; 10, 0; 10, 10; 0, 10]), 20, ...
%!                       'Label', 'post');
%! S = union (rectarray (post, [2, 1, 1], [30, 0, 0]), ...
%!            solid.box (5, 4, 4, geom.UCS ([0, 0, 1], [40, 3, 8]), ...
%!                       'Label', 'lug'));
%! F = faces (S, 'Label', 'post.side', 'Copy', 2, 'Normal', [1, 0, 0]);
%! Q = model.Viewer.__query__ (S, 'face', F, 'S');
%! assert_equal (Q, "faces (S, 'Label', 'post.side', 'Adjacent', 'lug.ymax')");
%!test  # a face of two names by the first of equal codes alphabetically
%! S = union (solid.box (60, 40, 10, 'Label', 'plate'), ...
%!            translate (solid.box (20, 40, 10, 'Label', 'block'), ...
%!                       [60, 0, 0]));
%! Q = model.Viewer.__query__ (S, 'face', faces (S, 'Label', 'plate.zmax'), ...
%!                             'S');
%! assert_equal (Q, "faces (S, 'Label', 'block.zmax')");
%!test  # named and unnamed faces, one query each
%! S = union (solid.box (60, 40, 10, 'Label', 'plate'), ...
%!            translate (solid.cylinder (5, 20), [20, 20, 10]));
%! F = [faces(S, 'Label', 'plate.xmin'), faces(S, 'Type', 'cylinder')];
%! Q = model.Viewer.__query__ (S, 'face', F, 'S');
%! assert_equal (strncmp (Q, "[faces(S, 'Label', 'plate.xmin'), faces(S, ", ...
%!                        43), true);
%! assert_equal (eval (Q), F);
%!test  # an edge between two named faces
%! B = solid.box (60, 40, 10, 'Label', 'plate');
%! E = edges (B, 'Between', {'plate.zmax', 'plate.ymin'});
%! Q = model.Viewer.__query__ (B, 'edge', E, 'B');
%! assert_equal (Q, "edges (B, 'Between', {'plate.ymin', 'plate.zmax'})");
%!test  # the edges round a named face
%! B = solid.box (60, 40, 10, 'Label', 'plate');
%! Q = model.Viewer.__query__ (B, 'edge', edges (B, 'Face', 'plate.zmax'), ...
%!                             'B');
%! assert_equal (Q, "edges (B, 'Face', 'plate.zmax')");
%!test  # the edges round two named faces
%! B = solid.box (60, 40, 10, 'Label', 'plate');
%! E = edges (B, 'Face', {'plate.zmax', 'plate.xmin'});
%! Q = model.Viewer.__query__ (B, 'edge', E, 'B');
%! assert_equal (Q, "edges (B, 'Face', {'plate.xmin', 'plate.zmax'})");
%!test  # upright edges by the name of the faces they bound and a direction
%! B = solid.box (60, 40, 10, 'Label', 'plate');
%! E = edges (B, 'Direction', [0, 0, 1]);
%! Q = model.Viewer.__query__ (B, 'edge', E, 'B');
%! assert_equal (Q, "edges (B, 'Face', 'plate', 'Direction', [0, 0, 1])");
%!test  # edges of one face to two others
%! B = solid.box (60, 40, 10, 'Label', 'plate');
%! E = edges (B, 'Between', {'plate.zmax', {'plate.ymin', 'plate.xmax'}});
%! Q = model.Viewer.__query__ (B, 'edge', E, 'B');
%! assert_equal (Q, ["edges (B, 'Between', {'plate.zmax',", ...
%!                   " {'plate.xmax', 'plate.ymin'}})"]);
%!test  # an edge of one copy of an array
%! B = translate (solid.box (20, 10, 5, 'Label', 'plate'), [30, -5, 0]);
%! S = polararray (B, 6, 360);
%! E = edges (S, 'Between', {'plate.zmax', 'plate.ymin'}, 'Copy', 3);
%! Q = model.Viewer.__query__ (S, 'edge', E, 'S');
%! assert_equal (Q, ["edges (S, 'Between', {'plate.ymin', 'plate.zmax'},", ...
%!                   " 'Copy', 3)"]);
%!test  # an edge with one named face, by that face and its kind
%! S = hole (solid.box (60, 40, 10, 'Label', 'plate'), [20, 20, 10], 8, Inf);
%! E = edges (S, 'Type', 'circle', 'Within', [0, 0, 10, 60, 40, 10]);
%! Q = model.Viewer.__query__ (S, 'edge', E, 'S');
%! assert_equal (Q, "edges (S, 'Face', 'plate.zmax', 'Type', 'circle')");

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## The window is titled with the name, before it opens and after
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Name = 'plate';
%!   V.Model = solid.box (10, 20, 30);
%!   assert_equal (V.__title__ (), 'plate (drafting)');
%!   V.Name = 'bracket';
%!   assert_equal (V.__title__ (), 'bracket (drafting)');
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## The empty shape opens the window empty
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.Shape ();
%!   assert_equal (isopen (V), true);
%!   assert_equal (V.__pickat__ ('any', [450, 350]), 'none');
%!   V.Model = solid.box (10, 20, 30);
%!   assert_equal (V.__pickat__ ('face', V.__project__ ([5, 10, 30]))(1:4), ...
%!                 'face');
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!test  # axes from a face and two points, the origin from one point
%! A = struct ('normal', [0, 0, 2], 'face', [5, 5, 12], ...
%!             'points', [0, 0, 12; 80, 0, 12]);
%! U = model.Viewer.__ucs__ (A, [20, 20, 3]);
%! assert_equal (U == geom.UCS ([0, 0, 1], [20, 20, 12], [21, 20, 12]), true);

%!test  # the start of the x axis is laid in the face; Enter keeps it
%! A = struct ('normal', [0, -1, 0], 'face', [10, 0, 6], ...
%!             'points', [0, -3, 0; 80, -3, 0]);
%! U = model.Viewer.__ucs__ (A, zeros (0, 3));
%! assert_equal (U.Origin, [0, 0, 0]);
%! assert_equal ([U.XAxis; U.YAxis], [1, 0, 0; 0, 0, 1]);

%!test  # three points, and a datum corner from two
%! A = struct ('points', [0, 0, 12; 80, 0, 12; 0, 40, 12]);
%! U = model.Viewer.__ucs__ (A, [80, 17, 3; 31, 0, 9]);
%! assert_equal (U.Origin, [80, 0, 12]);
%! assert_equal (U.XAxis, [1, 0, 0]);
%! assert_equal (U.Normal, [0, 0, 1]);

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## A face and two corners, then a hole's rim for the origin: its centre
%! B = hole (solid.box (80, 40, 12), [20, 20, 12], 8, Inf);
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = B;
%!   px = @(p) V.__project__ (p);
%!   C = [px([40, 30, 12]); px([0, 0, 12]); px([80, 0, 12]); ...
%!        px([20, 24, 12]); NaN, NaN];
%!   evalc ("[U, SHOWN] = V.__pickucs__ ('face', C);");
%!   assert_equal (U == geom.UCS ([0, 0, 1], [20, 20, 12], [21, 20, 12]), true);
%!   ## Each prompt says what the click before it took
%!   t4 = strcat ("Towards +x: a vertex at (80, 0, 12).\nPick the", ...
%!                " origin, or Enter to keep the start of x");
%!   t5 = strcat ("Origin: the centre of a circle at (20, 20, 12).\nPick", ...
%!                " a point to take the origin's y from, or Enter to put", ...
%!                " it here");
%!   t2 = "Plane: a flat face.\nPick the start of the x axis";
%!   t3 = "Start of x: a vertex at (0, 0, 12).\nPick a point towards +x";
%!   assert_equal (SHOWN, {"Pick a flat face for the plane", t2, t3, t4, t5});
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## A curved face is refused and asked for again; a datum corner from a
%! ## point on the right face and one on the front
%! B = hole (solid.box (80, 40, 12), [20, 20, 12], 8, Inf);
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = B;
%!   px = @(p) V.__project__ (p);
%!   C = [px([17.17, 22.83, 10]); px([40, 30, 12]); px([0, 0, 12]); ...
%!        px([80, 0, 12]); px([80, 20, 6]); px([40, 0, 6])];
%!   evalc ("U = V.__pickucs__ ('face', C);");
%!   assert_equal (U.Origin, [80, 0, 12], 1e-9);
%!   assert_equal (U.Normal, [0, 0, 1]);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## Three corners, Enter keeping the first: the code of the UCS picked
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.box (80, 40, 12);
%!   px = @(p) V.__project__ (p);
%!   C = [px([0, 0, 12]); px([80, 0, 12]); px([0, 40, 12]); NaN, NaN];
%!   [~, ~, CODE] = V.__pickucs__ ('points', C);
%!   assert_equal (CODE, "geom.UCS ([0, 0, 1], [0, 0, 12], [1, 0, 12])");
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## The code makes the UCS picked on a sloping face again
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.wedge (60, 40, 30, 10);
%!   px = @(p) V.__project__ (p);
%!   C = [px([35, 20, 15]); px([60, 0, 0]); px([60, 40, 0]); NaN, NaN];
%!   [U, ~, CODE] = V.__pickucs__ ('face', C);
%!   W = eval (CODE);
%!   assert_equal ([W.Normal, W.Origin, W.XAxis], ...
%!                 [U.Normal, U.Origin, U.XAxis], 1e-9);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## A face and two corners of it, by their names
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   S = solid.box (60, 40, 10, 'Label', 'plate');
%!   V.Model = S;
%!   px = @(p) V.__project__ (p);
%!   C = [px([30, 20, 10]); px([0, 0, 10]); px([60, 0, 10]); NaN, NaN];
%!   [U, ~, CODE] = V.__pickucs__ ('face', C);
%!   pad = repmat (' ', 1, 41);
%!   L = {"geom.UCS (normal (S, faces (S, 'Label', 'plate.zmax')), ...", ...
%!        ["          corner (S, faces (S, 'Label', {'plate.xmin',", ...
%!         " 'plate.ymin', ..."], ...
%!        [pad, "'plate.zmax'})), ..."], ...
%!        ["          corner (S, faces (S, 'Label', {'plate.xmax',", ...
%!         " 'plate.ymin', ..."], ...
%!        [pad, "'plate.zmax'})))"]};
%!   assert_equal (CODE, strjoin (L, "\n"));
%!   assert_equal (eval (CODE) == U, true);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## An origin in the plane, x running from it as from the start
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   S = solid.box (60, 40, 10, 'Label', 'plate');
%!   V.Model = S;
%!   px = @(p) V.__project__ (p);
%!   C = [px([30, 20, 10]); px([0, 0, 10]); px([60, 0, 10]); ...
%!        px([30, 40, 10]); NaN, NaN];
%!   [U, ~, CODE] = V.__pickucs__ ('face', C);
%!   L = strsplit (CODE, "\n");
%!   assert_equal (L{2}, ["          midpoint (S, edges (S, 'Between',", ...
%!                        " {'plate.ymax', 'plate.zmax'})), ..."]);
%!   assert_equal (strncmp (strtrim (L{4}), "+ (", 3), true);
%!   assert_equal (eval (CODE) == U, true);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## An origin laid into the plane is its coordinates
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   S = solid.box (60, 40, 10, 'Label', 'plate');
%!   V.Model = S;
%!   px = @(p) V.__project__ (p);
%!   C = [px([30, 20, 10]); px([0, 0, 10]); px([60, 0, 10]); px([60, 0, 0]); ...
%!        NaN, NaN];
%!   [U, ~, CODE] = V.__pickucs__ ('face', C);
%!   L = strsplit (CODE, "\n");
%!   assert_equal (L{2}, "          [60, 0, 10], ...");
%!   assert_equal (eval (CODE) == U, true);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## An origin from two points is its coordinates
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   S = solid.box (60, 40, 10, 'Label', 'plate');
%!   V.Model = S;
%!   px = @(p) V.__project__ (p);
%!   C = [px([30, 20, 10]); px([0, 0, 10]); px([60, 0, 10]); ...
%!        px([30, 0, 10]); px([0, 20, 10]); NaN, NaN];
%!   [U, ~, CODE] = V.__pickucs__ ('face', C);
%!   L = strsplit (CODE, "\n");
%!   assert_equal (L{2}, "          [30, 20, 10], ...");
%!   assert_equal (eval (CODE) == U, true);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## Every line of the code within 80 columns
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   S = solid.box (60, 40, 10, 'Label', 'plate');
%!   V.Model = S;
%!   px = @(p) V.__project__ (p);
%!   C = [px([30, 20, 10]); px([0, 0, 10]); px([60, 0, 10]); ...
%!        px([30, 40, 10]); NaN, NaN];
%!   [U, ~, CODE] = V.__pickucs__ ('face', C);
%!   assert_equal (all (cellfun (@numel, strsplit (CODE, "\n")) <= 80), true);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## Three corners by their names
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   S = solid.box (60, 40, 10, 'Label', 'plate');
%!   V.Model = S;
%!   px = @(p) V.__project__ (p);
%!   C = [px([0, 0, 10]); px([60, 0, 10]); px([0, 40, 10]); NaN, NaN];
%!   [U, ~, CODE] = V.__pickucs__ ('points', C);
%!   assert_equal (strncmp (CODE, "geom.UCS.threepoint (corner (S, ", 32), ...
%!                 true);
%!   assert_equal (eval (CODE) == U, true);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## Three points and an origin are coordinates
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   S = solid.box (60, 40, 10, 'Label', 'plate');
%!   V.Model = S;
%!   px = @(p) V.__project__ (p);
%!   C = [px([0, 0, 10]); px([60, 0, 10]); px([0, 40, 10]); px([30, 0, 10]); ...
%!        NaN, NaN];
%!   [U, ~, CODE] = V.__pickucs__ ('points', C);
%!   assert_equal (CODE, "geom.UCS ([0, 0, 1], [30, 0, 10], [31, 0, 10])");
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## A pick prints nothing
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.box (80, 40, 12);
%!   px = @(p) V.__project__ (p);
%!   C = [px([0, 0, 12]); px([80, 0, 12]); px([0, 40, 12]); NaN, NaN];
%!   assert_equal (evalc ("U = V.__pickucs__ ('points', C);"), "");
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## Escape cancels the pick with an error, and the viewer goes on
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.box (80, 40, 12);
%!   C = [V.__project__([40, 30, 12]); Inf, Inf];
%!   msg = '';
%!   try
%!     V.__pickucs__ ('face', C);
%!   catch err
%!     msg = err.message;
%!   end_try_catch
%!   assert_equal (msg, "model.Viewer.pickucs: the pick was cancelled.");
%!   assert_equal (V.__pickat__ ('face', V.__project__ ([40, 20, 12]))(1:4), ...
%!                 'face');
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

## A box as a triangle mesh, its triangles turned outwards, for the tests
%!function M = boxmesh (DX, DY, DZ)
%!  P = [0, 0, 0; DX, 0, 0; DX, DY, 0; 0, DY, 0; ...
%!       0, 0, DZ; DX, 0, DZ; DX, DY, DZ; 0, DY, DZ];
%!  F = [1, 3, 2; 1, 4, 3; 5, 6, 7; 5, 7, 8; 1, 2, 6; 1, 6, 5; ...
%!       2, 3, 7; 2, 7, 6; 3, 4, 8; 3, 8, 7; 4, 1, 5; 4, 5, 8];
%!  M = polymesh.Mesh (P, F);
%!endfunction

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## A mesh is shown and handed back; a click on it is a facet or a point
%! M = boxmesh (80, 40, 12);
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = M;
%!   assert_equal (V.Model.Vertices, M.Vertices);
%!   V.__pickonestart__ ('face');
%!   r = str2double (strsplit (V.__clickone__ (V.__project__ ([40, 30, 12]))));
%!   assert_equal (r(2:4), [0, 0, 1], 1e-12);
%!   assert_equal (r(5:7), [40, 30, 12], 0.5);
%!   V.__pickonestart__ ('point');
%!   r = V.__clickone__ (V.__project__ ([80, 0, 12]));
%!   assert_equal (r, "point 80 0 12 vertex");
%!   V.__pickonestart__ ('point');
%!   r = V.__clickone__ (V.__project__ ([40, 0, 12]));
%!   assert_equal (r, "point 40 0 12 midpoint");
%!   V.__pickonestart__ ('point');
%!   r = strsplit (V.__clickone__ (V.__project__ ([30, 25, 12])));
%!   assert_equal (r{end}, 'face');
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## A UCS picked on a mesh: a facet and two corners, Enter for the origin
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = boxmesh (80, 40, 12);
%!   px = @(p) V.__project__ (p);
%!   C = [px([40, 30, 12]); px([0, 0, 12]); px([80, 0, 12]); NaN, NaN];
%!   evalc ("[U, SHOWN] = V.__pickucs__ ('face', C);");
%!   assert_equal (U == geom.UCS ([0, 0, 1], [0, 0, 12], [1, 0, 12]), true);
%!   assert_equal (SHOWN{2}, ...
%!                 "Plane: a flat face.\nPick the start of the x axis");
%!   ## The same three corners in the points mode
%!   C = [px([0, 0, 12]); px([80, 0, 12]); px([0, 40, 12]); NaN, NaN];
%!   evalc ("U = V.__pickucs__ ('points', C);");
%!   assert_equal (U == geom.UCS ([0, 0, 1], [0, 0, 12], [1, 0, 12]), true);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## Points picked on a mesh, with the triangle each lies on and its normal;
%! ## a click that misses adds nothing, and a shape replaces the mesh.  The
%! ## top's triangles 3 and 4 meet on its diagonal, y = x / 2; the side's 7
%! ## lies below z = 0.3 y
%! M = boxmesh (80, 40, 12);
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = M;
%!   V.__pickstart__ ('any');
%!   T = [60, 10, 12; 20, 30, 12; 80, 30, 4];
%!   assert_equal (V.__click__ (V.__project__ (T(1,:))), 1);
%!   assert_equal (V.__click__ ([2, 2]), 1);
%!   assert_equal (V.__click__ (V.__project__ (T(2,:))), 2);
%!   assert_equal (V.__click__ (V.__project__ (T(3,:))), 3);
%!   [P, F] = V.__pickend__ ();
%!   assert_equal (P, T, 0.5);
%!   assert_equal (F, [3, 0, 0, 1; 4, 0, 0, 1; 7, 1, 0, 0], 1e-12);
%!   V.Model = solid.box (10, 20, 30);
%!   assert_equal (volume (V.Model), 6000, 1e-9);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## Each solid is shown in its colour, one without a colour in grey
%! B = solid.box (10, 10, 10);
%! U = union (B, translate (B, [20, 0, 0]));
%! U.Colour = [1, 0, 0; NaN, NaN, NaN];
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = U;
%!   I = double (capture (V));
%!   p = round ([V.__project__([5, 5, 10]); V.__project__([25, 5, 10])]);
%!   c = [squeeze(I(p(1,2), p(1,1), :))'; squeeze(I(p(2,2), p(2,1), :))'];
%!   red = c(:,1) > 100 & c(:,2) < 40 & c(:,3) < 40;
%!   grey = max (c, [], 2) - min (c, [], 2) < 30;
%!   assert_equal (sort ([red, grey], 1), [false, false; true, true]);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## A mesh is shown in its faces' colours, its vertices' or grey
%! M = boxmesh (80, 40, 12);
%! M.FaceColour = repmat ([1, 0, 0], 12, 1);
%! M.VertexColour = repmat ([0, 0, 1], 8, 1);
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = M;
%!   p = round (V.__project__ ([40, 20, 12]));
%!   at = @(I) double (squeeze (I(p(2), p(1), :)))';
%!   assert_equal (V.__look__ (), 'face');
%!   c = at (capture (V));
%!   assert_equal (c(1) > 100 && c(2) < 40 && c(3) < 40, true);
%!   V.__colours__ ('vertex');
%!   assert_equal (V.__look__ (), 'vertex');
%!   c = at (capture (V));
%!   assert_equal (c(3) > 100 && c(1) < 40 && c(2) < 40, true);
%!   V.__colours__ ('grey');
%!   c = at (capture (V));
%!   assert_equal (max (c) - min (c) < 30 && min (c) > 60, true);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## A colouring chosen holds for the meshes after that have it; one that
%! ## lacks it is shown in the first it has
%! M = boxmesh (10, 20, 30);
%! M.FaceColour = repmat ([1, 0, 0], 12, 1);
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = M;
%!   V.__colours__ ('vertex');
%!   assert_equal (V.__look__ (), 'face');
%!   M.VertexColour = repmat ([0, 0, 1], 8, 1);
%!   V.Model = M;
%!   assert_equal (V.__look__ (), 'vertex');
%!   V.Model = boxmesh (10, 20, 30);
%!   assert_equal (V.__look__ (), 'grey');
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## A mesh's triangle edges are drawn when asked for, and only then
%! dark = @(I) all (I < 90, 3);
%! near = @(D, p) any (any (D(round (p(2)) + (-3:3), round (p(1)) + (-3:3))));
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = boxmesh (80, 40, 12);
%!   p = V.__project__ ([40, 20, 12]);
%!   [~, edges] = V.__look__ ();
%!   assert_equal (edges, 'off');
%!   assert_equal (near (dark (capture (V)), p), false);
%!   V.__edges__ ('on');
%!   [~, edges] = V.__look__ ();
%!   assert_equal (edges, 'on');
%!   assert_equal (near (dark (capture (V)), p), true);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!test
%! V = model.Viewer ();
%! assert_equal (isopen (V), false);
%! assert_equal (isempty (V.Model), true);
%! assert_equal (V.Name, 'S');
%! V.Name = 'part';
%! assert_equal (V.Name, 'part');

%!error<model.Viewer: Name/Value arguments must come in pairs.> ...
%! model.Viewer ('Hidden')
%!error<model.Viewer: unknown option 'Visible'.> model.Viewer ('Visible', true)
%!error<model.Viewer: option names must be character vectors.> model.Viewer (1, true)
## Option names ignore case
%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! V = model.Viewer ('hidden', true);
%! assert_equal (isopen (V), false);
%!error<model.Viewer: Hidden must be true or false.> ...
%! model.Viewer ('Hidden', 2)
%!error<model.Viewer: Hidden must be true or false.> ...
%! model.Viewer ('Hidden', 1)
%!error<model.Viewer: Model must be a solid.Shape, a polymesh.Mesh or a model.Assembly object.>
%! V = model.Viewer ();
%! V.Model = 1;
## Shape, Model's former name, warns and forwards to Model
%!warning<model.Viewer: Shape is obsolete and will be removed in drafting 0.3.0; use Model instead.>
%! V = model.Viewer ();
%! S = V.Shape;
%!error<model.Viewer: Model must be a solid.Shape, a polymesh.Mesh or a model.Assembly object.>
%! V = model.Viewer ();
%! V.Shape = 1;
%!error<model.Viewer: Name must be a valid variable name.>
%! V = model.Viewer ();
%! V.Name = '1part';
%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## An edge clicked, then Enter: the code that selects it
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.box (80, 40, 12);
%!   C = [V.__project__([40, 0, 12]); NaN, NaN];
%!   [~, CODE] = V.__pick__ ('edge', C);
%!   assert_equal (CODE, ["edges (S, 'Type', 'line', 'Direction',", ...
%!                        " [1, 0, 0], 'Within', [0, 0, 12, 80, 0, 12])"]);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## Faces come back in the order picked, and so does their code
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   S = solid.box (50, 5, 20);
%!   V.Model = S;
%!   C = [V.__project__([25, 2.5, 20]); V.__project__([50, 2.5, 10]); ...
%!        V.__project__([25, 0, 10]); NaN, NaN];
%!   [F, CODE] = V.__pick__ ('face', C);
%!   assert_equal (F, [6, 2, 3]);
%!   assert_equal (eval (CODE), [6, 2, 3]);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## A named face picked comes back as its name
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   S = solid.box (50, 5, 20, 'Label', 'plate');
%!   V.Model = S;
%!   [F, CODE] = V.__pick__ ('face', [V.__project__([25, 2.5, 20]); NaN, NaN]);
%!   assert_equal (F, faces (S, 'Label', 'plate.zmax'));
%!   assert_equal (CODE, "faces (S, 'Label', 'plate.zmax')");
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## A picked edge of named faces comes back between their names
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   S = solid.box (50, 5, 20, 'Label', 'plate');
%!   V.Model = S;
%!   [E, CODE] = V.__pick__ ('edge', [V.__project__([25, 0, 20]); NaN, NaN]);
%!   assert_equal (E, edges (S, 'Between', {'plate.zmax', 'plate.ymin'}));
%!   assert_equal (CODE, "edges (S, 'Between', {'plate.ymin', 'plate.zmax'})");
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## A picked corner is the corner of the named faces that meet there
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   S = solid.box (60, 40, 10, 'Label', 'plate');
%!   V.Model = S;
%!   [P, CODE] = V.__pick__ ('point', [V.__project__([60, 0, 10]); NaN, NaN]);
%!   assert_equal (P, [60, 0, 10], 1e-9);
%!   assert_equal (CODE, ["corner (S, faces (S, 'Label', {'plate.xmax',", ...
%!                        " 'plate.ymin', 'plate.zmax'}))"]);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## A picked midpoint is the midpoint of the edge between named faces
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   S = solid.box (60, 40, 10, 'Label', 'plate');
%!   V.Model = S;
%!   [P, CODE] = V.__pick__ ('point', [V.__project__([30, 0, 10]); NaN, NaN]);
%!   assert_equal (P, [30, 0, 10], 1e-9);
%!   assert_equal (CODE, ["midpoint (S, edges (S, 'Between',", ...
%!                        " {'plate.ymin', 'plate.zmax'}))"]);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## A picked centre is the centre of the circle between named faces
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   S = union (solid.box (60, 40, 10, 'Label', 'plate'), ...
%!              solid.cylinder (5, 20, geom.UCS ([0, 0, 1], [20, 20, 10]), ...
%!                              'Label', 'boss'));
%!   V.Model = S;
%!   [P, CODE] = V.__pick__ ('point', [V.__project__([25, 20, 30]); NaN, NaN]);
%!   assert_equal (P, [20, 20, 30], 1e-9);
%!   assert_equal (CODE, ["centre (S, edges (S, 'Between',", ...
%!                        " {'boss.end', 'boss.side'}))"]);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## A point picked inside a face is its coordinates
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   S = solid.box (60, 40, 10, 'Label', 'plate');
%!   V.Model = S;
%!   [P, CODE] = V.__pick__ ('point', [V.__project__([30, 20, 10]); NaN, NaN]);
%!   assert_equal (P(3), 10, 1e-9);
%!   assert_equal (CODE(1), '[');
%!   assert_equal (eval (CODE), P, 1e-6);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## Several points are the rows of one matrix
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   S = solid.box (60, 40, 10, 'Label', 'plate');
%!   V.Model = S;
%!   [P, CODE] = V.__pick__ ('point', [V.__project__([60, 0, 10]); ...
%!                                     V.__project__([30, 0, 10]); NaN, NaN]);
%!   assert_equal (P, [60, 0, 10; 30, 0, 10], 1e-9);
%!   assert_equal (strncmp (CODE, "[corner(S, faces(S, 'Label', ", 29), true);
%!   assert_equal (eval (CODE), P, 1e-9);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## The tip of a cone is a corner of its side
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   S = solid.cone (3, 0, 10, 'Label', 'tip');
%!   V.Model = S;
%!   [P, CODE] = V.__pick__ ('point', [V.__project__([0, 0, 10]); NaN, NaN]);
%!   assert_equal (P, [0, 0, 10], 1e-9);
%!   assert_equal (CODE, "corner (S, faces (S, 'Label', 'tip.side'))");
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## The pole of a sphere snaps, but its one face has two corners
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.sphere (5, 'Label', 'ball');
%!   [P, CODE] = V.__pick__ ('point', [V.__project__([0, 0, 5]); NaN, NaN]);
%!   assert_equal (P, [0, 0, 5], 1e-9);
%!   assert_equal (CODE, "[0, 0, 5]");
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## Points of a shape without names are their coordinates
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.box (60, 40, 10);
%!   [P, CODE] = V.__pick__ ('point', [V.__project__([60, 0, 10]); NaN, NaN]);
%!   assert_equal (CODE, "[60, 0, 10]");
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## Escape returns no point
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.box (60, 40, 10, 'Label', 'plate');
%!   [P, CODE] = V.__pick__ ('point', [V.__project__([60, 0, 10]); Inf, Inf]);
%!   assert_equal (size (P), [0, 3]);
%!   assert_equal (CODE, '');
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## Points of a mesh are their coordinates
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = boxmesh (80, 40, 12);
%!   [P, CODE] = V.__pick__ ('point', [V.__project__([80, 0, 12]); NaN, NaN]);
%!   assert_equal (P, [80, 0, 12]);
%!   assert_equal (CODE, "[80, 0, 12]");
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## Edges one query names all come back in the order picked, their code
%! ## in increasing order
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   S = solid.box (50, 5, 20);
%!   V.Model = S;
%!   C = [V.__project__([50, 2.5, 20]); V.__project__([25, 0, 20]); ...
%!        V.__project__([0, 2.5, 20]); V.__project__([25, 5, 20]); NaN, NaN];
%!   [E, CODE] = V.__pick__ ('edge', C);
%!   assert_equal (E, [6, 10, 2, 12]);
%!   assert_equal (CODE, ["edges (S, 'Type', 'line',", ...
%!                        " 'Within', [0, 0, 20, 50, 5, 20])"]);
%!   assert_equal (eval (CODE), [2, 6, 10, 12]);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## Edges come back in the order picked, and so does their code
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   S = solid.box (50, 5, 20);
%!   V.Model = S;
%!   C = [V.__project__([25, 0, 20]); V.__project__([0, 0, 10]); NaN, NaN];
%!   [E, CODE] = V.__pick__ ('edge', C);
%!   assert_equal (E, [10, 1]);
%!   assert_equal (eval (CODE), [10, 1]);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## A pick of edges prints nothing
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.box (80, 40, 12);
%!   C = [V.__project__([40, 0, 12]); NaN, NaN];
%!   assert_equal (evalc ("E = V.__pick__ ('edge', C);"), "");
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## Escape picks nothing
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = solid.box (80, 40, 12);
%!   E = V.__pick__ ('edge', [V.__project__([40, 0, 12]); Inf, Inf]);
%!   assert_equal (isempty (E), true);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!error<model.Viewer.pick: KIND must be 'edge', 'face', 'point', 'solid' or 'any'.>
%! pick (model.Viewer (), 'vertex')
%!error<model.Viewer.pick: the viewer is showing no shape.>
%! pick (model.Viewer ())
%!error<model.Viewer.pick: a mesh has only points to pick.>
%! V = model.Viewer ();
%! setappdata (0, sprintf ('drafting_model_viewer_%d', V.Id), ...
%!             setfield (getappdata (0, sprintf ('drafting_model_viewer_%d', ...
%!                                               V.Id)), 'mesh', ...
%!                       polymesh.Mesh ()));
%! pick (V, 'edge')
%!testif ; ! ispc () && ! ismac ()
%! ## Windows and macOS need no DISPLAY, so only elsewhere is its absence an
%! ## error
%! d = getenv ('DISPLAY');
%! unwind_protect
%!   setenv ('DISPLAY', '');
%!   fail ("V = model.Viewer (); V.Model = solid.box (1, 1, 1);", ...
%!         "model.Viewer: the viewer needs a display, and none is set.");
%! unwind_protect_cleanup
%!   setenv ('DISPLAY', d);
%! end_unwind_protect
%!error<model.Viewer.pickucs: MODE must be 'face' or 'points'.> ...
%! pickucs (model.Viewer (), 'edges')
%!error<model.Viewer.pickucs: the viewer is showing no shape.> ...
%! pickucs (model.Viewer ())

## Two blocks, A in front and B behind it seen from the front, red and blue
%!function S = frontback ()
%!  S = union (solid.box (20, 10, 20), ...
%!             translate (solid.box (20, 10, 20), [0, 30, 0]));
%!  S.Colour = [1, 0, 0; 0, 0, 1];
%!endfunction

## A viewer that holds X as though it showed it, with no window
%!function V = unopened (X)
%!  V = model.Viewer ();
%!  key = sprintf ('drafting_model_viewer_%d', V.Id);
%!  st = getappdata (0, key);
%!  if (isa (X, 'polymesh.Mesh'))
%!    st.mesh = X;
%!    st.opacity = 1;
%!  else
%!    if (isa (X, 'model.Assembly'))
%!      st.model = X;
%!      st.list = solids (X);
%!      X = shape (X);
%!    else
%!      st.list = solids (X);
%!    endif
%!    st.data = X.Data;
%!    st.opacity = ones (numsolids (X), 1);
%!  endif
%!  setappdata (0, key, st);
%!endfunction

%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## A hidden solid is neither drawn nor picked: the one behind shows
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = frontback ();
%!   view (V, 0, 0);
%!   p = round (V.__project__ ([10, 0, 10]));
%!   I = capture (V);
%!   assert_equal (squeeze (I(p(2), p(1), :))' > [150, 50, 255], ...
%!                 [true, false, false]);
%!   opacity (V, 1, 0);
%!   I = capture (V);
%!   assert_equal (squeeze (I(p(2), p(1), :))' > [50, 50, 150], ...
%!                 [false, false, true]);
%!   assert_equal (V.__pickat__ ('solid', p), 'solid 2');
%!   assert_equal (opacity (V), [0; 1]);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect
%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## A solid shown through blends with the one behind and is still picked
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = frontback ();
%!   view (V, 0, 0);
%!   p = round (V.__project__ ([10, 0, 10]));
%!   opacity (V, 1, 0.4);
%!   c = double (squeeze (capture (V)(p(2), p(1), :)))';
%!   assert_equal (c(1) > 100 && c(3) > 60, true);
%!   assert_equal (V.__pickat__ ('solid', p), 'solid 1');
%!   opacity (V, 'all', 1);
%!   c = double (squeeze (capture (V)(p(2), p(1), :)))';
%!   assert_equal (c(3) < 50, true);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect
%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## A pick of solids: the indices, and the name that selects them again
%! S = frontback ();
%! S.Name = {'front'; 'back'};
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = S;
%!   view (V, 0, 0);
%!   [I, CODE] = V.__pick__ ('solid', V.__project__ ([10, 0, 10]));
%!   assert_equal (I, 1);
%!   assert_equal (CODE, "'front'");
%!   opacity (V, eval (CODE), 0);
%!   assert_equal (opacity (V), [0; 1]);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect
%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## Unnamed solids are given back by index
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = frontback ();
%!   view (V, 0, 0);
%!   [I, CODE] = V.__pick__ ('solid', V.__project__ ([10, 0, 10]));
%!   assert_equal ({I, CODE}, {1, '1'});
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect
%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## An assembly: kept as itself, picked by solid, its path given back
%! A = add (model.Assembly ('pair'), 'front', solid.box (20, 10, 20), ...
%!          geom.UCS ());
%! A = add (A, 'back', solid.box (20, 10, 20), ...
%!          geom.UCS ([0, 0, 1], [0, 30, 0]));
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = A;
%!   assert_equal (class (V.Model), 'model.Assembly');
%!   view (V, 0, 0);
%!   [I, CODE] = V.__pick__ ('any', V.__project__ ([10, 0, 10]));
%!   assert_equal ({I, CODE}, {1, "{'front'}"});
%!   opacity (V, {'back'}, 0.5);
%!   assert_equal (opacity (V), [1; 0.5]);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect
%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## A new model keeps what was set by name, path or 'all', not by index
%! S = frontback ();
%! S.Name = {'front'; 'back'};
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = S;
%!   opacity (V, 'front', 0);
%!   opacity (V, 2, 0.5);
%!   V.Model = S;
%!   assert_equal (opacity (V), [0; 1]);
%!   V.Model = solid.box (5, 5, 5);
%!   assert_equal (opacity (V), 1);
%!   V.Model = S;
%!   assert_equal (opacity (V), [1; 1]);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect
%!testif ; ispc () || ismac () || ! isempty (getenv ('DISPLAY'))
%! ## A mesh is hidden or shown through as a whole
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Model = boxmesh (20, 10, 20);
%!   view (V, 0, 0);
%!   p = round (V.__project__ ([10, 0, 10]));
%!   assert_equal (V.__pickat__ ('face', p)(1:4), 'face');
%!   opacity (V, 'all', 0);
%!   assert_equal (V.__pickat__ ('face', p), 'none');
%!   opacity (V, 1, 0.4);
%!   assert_equal (opacity (V), 0.4);
%!   assert_equal (V.__pickat__ ('face', p)(1:4), 'face');
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!test
%! V = unopened (frontback ());
%! opacity (V, [1, 2], 0.5);
%! assert_equal (opacity (V), [0.5; 0.5]);
%!test  # a name matches solids and placements at any depth
%! B = add (model.Assembly ('stage'), 'pin', solid.cylinder (2, 12), ...
%!          geom.UCS ());
%! A = add (model.Assembly ('top'), 'pin', solid.cylinder (2, 12), ...
%!          geom.UCS ([0, 0, 1], [10, 0, 0]));
%! A = add (A, 'stage', B, geom.UCS ([0, 0, 1], [0, 0, 20]));
%! V = unopened (A);
%! opacity (V, 'pin', 0);
%! assert_equal (opacity (V), [0; 0]);
%! opacity (V, {'stage'}, 1);
%! assert_equal (opacity (V), [0; 1]);
%! opacity (V, {'stage', 'pin'}, 0.5);
%! assert_equal (opacity (V), [0; 0.5]);
%!test  # names match case and all
%! S = frontback ();
%! S.Name = {'Front'; 'back'};
%! V = unopened (S);
%! opacity (V, 'Front', 0);
%! assert_equal (opacity (V), [0; 1]);
%!error<model.Viewer.opacity: nothing is named 'front'.>
%! S = frontback ();
%! S.Name = {'Front'; 'back'};
%! opacity (unopened (S), 'front', 0);
%!error<model.Viewer.opacity: nothing lies at the path {'front', 'x'}.>
%! A = add (model.Assembly (), 'front', solid.box (2, 2, 2), geom.UCS ());
%! opacity (unopened (A), {'front', 'x'}, 0);
%!error<model.Viewer.opacity: indices must be integers from 1 to 2.>
%! opacity (unopened (frontback ()), 3, 0);
%!error<model.Viewer.opacity: indices must be integers from 1 to 2.>
%! opacity (unopened (frontback ()), 1.5, 0);
%!error<model.Viewer.opacity: WHAT must be indices, a name, a path or 'all'.>
%! opacity (unopened (frontback ()), {1}, 0);
%!error<model.Viewer.opacity: A must be a real scalar from 0 to 1.>
%! opacity (model.Viewer (), 1, 2);
%!error<model.Viewer.opacity: A must be a real scalar from 0 to 1.>
%! opacity (model.Viewer (), 1, [0, 1]);
%!error<model.Viewer.opacity: invalid number of input arguments.>
%! opacity (model.Viewer (), 1);
%!error<model.Viewer.opacity: the viewer is showing no shape.>
%! opacity (model.Viewer (), 'all', 0);
%!error<model.Viewer.opacity: a mesh has no solids to name; use 'all'.>
%! opacity (unopened (boxmesh (2, 2, 2)), 'tet', 0);
%!error<model.Viewer.opacity: a mesh has no solids to name; use 'all'.>
%! opacity (unopened (boxmesh (2, 2, 2)), {'tet'}, 0);
%!error<model.Viewer.pick: the parts of an assembly are not edited; pick 'solid' to identify one.>
%! A = add (model.Assembly (), 'front', solid.box (2, 2, 2), geom.UCS ());
%! pick (unopened (A), 'edge')
%!error<model.Viewer.pick: a mesh has only points to pick.>
%! pick (unopened (boxmesh (2, 2, 2)), 'solid')
