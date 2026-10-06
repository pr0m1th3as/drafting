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
  ## A window showing a solid or a triangle mesh, in which edges, faces and
  ## coordinate systems can be picked.
  ##
  ## Assigning a @code{solid.Shape} to the @code{Shape} of a viewer opens its
  ## window, or redraws it in place, keeping the camera where it was; each
  ## solid is drawn in its colour, grey where it has none.  Nothing
  ## else redraws it.  A @code{polymesh.Mesh} is shown the same way, shaded
  ## facet by facet, however many triangles it has, in its faces' colours
  ## where it has them, else in its vertices', blended across each facet,
  ## else in grey.  The @code{show} method of a shape or a mesh keeps a
  ## viewer for each variable and is the usual way in; a viewer of your own
  ## is for when you want to hold it yourself.
  ##
  ## The window is drawn by Open CASCADE in a process of its own, so a complex
  ## model turns smoothly and never holds up the Octave prompt.  The world
  ## axes are drawn in the lower right corner, turning with the view, @math{x}
  ## red, @math{y} green and @math{z} blue.  The left mouse button rotates,
  ## the middle one pans and the wheel zooms.  The view turns about the
  ## centre of the window, wherever it has been panned to, or about a point
  ## of the shape chosen by double-clicking it; a double click that misses
  ## the shape, or fitting the view, returns to the centre of the window.
  ## During a pick a double click is a click like any other.  Keys:
  ##
  ## @multitable @columnfractions 0.15 0.85
  ## @item @kbd{F} @tab fit the shape to the window, and turn about the
  ## centre of the window again
  ## @item @kbd{0} @tab isometric view
  ## @item @kbd{1} @tab front view, looking along @math{+y}
  ## @item @kbd{2} @tab top view, looking down @math{z}
  ## @item @kbd{3} @tab right view, looking along @math{-x}
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
  ## The viewer needs a display to run.  It runs on Linux.
  ##
  ## @seealso{solid.Shape.show, polymesh.Mesh.show, model.Viewer.pick}
  ## @end deftp

  properties (Dependent)

    ## -*- texinfo -*-
    ## @deftp {model.Viewer} {property} Shape
    ##
    ## Shape shown
    ##
    ## The @code{solid.Shape} or the @code{polymesh.Mesh} shown.  Assigning
    ## either opens the window if it is not open and redraws it in place if it
    ## is.  The empty shape opens the window empty, or clears
    ## it if it is open; the first shape shown after it is fitted to the
    ## window.
    ##
    ## @end deftp
    Shape

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

    ## The view as an RGB image
    function IMG = __dump__ (this)

      f = [tempname() '.ppm'];
      send (this, ["dump " f]);
      r = receive (this, 30);
      if (! strcmp (r, 'dumped'))
        error ("model.Viewer: %s", r);
      endif
      IMG = imread (f);
      unlink (f);

    endfunction

    ## The UCS picking behind pickucs.  CLICKS, for tests, replaces the mouse:
    ## a row of pixels per click, NaN for the Enter key and Inf for Escape;
    ## empty is the mouse.  SHOWN is the prompts shown, in order.  Each
    ## prompt opens with what the click before it took, so that a click that
    ## took something unintended shows at once.
    function [U, SHOWN] = __pickucs__ (this, MODE, CLICKS)

      st = state (this);
      while (ischar (fgetl (st.out)))
      endwhile
      fclear (st.out);
      S = this.Shape;
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
          told = describe ("Start of x", r, scale);
          ask = [told "Pick a point towards +x"];
          do
            [p2, r, CLICKS, SHOWN] = point (this, ask, CLICKS, SHOWN);
            A = struct ('normal', n, 'face', f, 'points', [p1; p2]);
            ask = "No direction in the face: pick another point towards +x";
          until (isvalidaxes (A))
          told = describe ("Towards +x", r, scale);
        else
          ask = "Pick the start of the x axis";
          [p1, r, CLICKS, SHOWN] = point (this, ask, CLICKS, SHOWN);
          told = describe ("Start of x", r, scale);
          ask = [told "Pick a point towards +x"];
          do
            [p2, r, CLICKS, SHOWN] = point (this, ask, CLICKS, SHOWN);
            ask = "Pick a point away from the first, towards +x";
          until (! isequal (p1, p2))
          told = describe ("Towards +x", r, scale);
          ask = [told "Pick a point on the +y side"];
          do
            [p3, r, CLICKS, SHOWN] = point (this, ask, CLICKS, SHOWN);
            A = struct ('points', [p1; p2; p3]);
            ask = "That point is on the x axis: pick one on the +y side";
          until (isvalidaxes (A))
          told = describe ("+y side", r, scale);
        endif

        ## The origin
        O = zeros (0, 3);
        [r, CLICKS, SHOWN] = one (this, 'point', ...
                                  [told "Pick the origin, or Enter to keep", ...
                                   " the start of x"], CLICKS, SHOWN);
        if (strcmp (r{1}, 'point'))
          O = str2double (r(2:4));
          told = describe ("Origin", r, scale);
          [r, CLICKS, SHOWN] = one (this, 'point', ...
                                    [told "Pick a point to take the", ...
                                     " origin's y from, or Enter to put it", ...
                                     " here"], CLICKS, SHOWN);
          if (strcmp (r{1}, 'point'))
            O(2,:) = str2double (r(2:4));
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
      printf ("U = geom.UCS (%s, %s, %s);\n", v (U.Normal), v (U.Origin), ...
              v (U.Origin + U.XAxis));

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

    ## The query that finds the edges or faces IDX of S, and how many it finds
    function [Q, N] = __query__ (S, KIND, IDX, NAME)

      if (strcmp (KIND, 'edge'))
        info = __occt__ ('edges', 'model.Viewer.pick', S.Data);
        [type, dir, box] = info{1:3};
        args = {};
        if (all (strcmp (type(IDX), type{IDX(1)})))
          args(end+1:end+2) = {'Type', type{IDX(1)}};
        endif
        if (alike (dir(IDX,:)))
          args(end+1:end+2) = {'Direction', dir(IDX(1),:)};
        endif
      else
        info = __occt__ ('faces', 'model.Viewer.pick', S.Data);
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
      ## The box round all of them, widened to whole thousandths
      b = [min(box(IDX,1:3), [], 1), max(box(IDX,4:6), [], 1)];
      b = [floor(b(1:3) * 1000), ceil(b(4:6) * 1000)] / 1000;
      args(end+1:end+2) = {'Within', b};

      if (strcmp (KIND, 'edge'))
        N = numel (edges (S, args{:}));
        Q = sprintf ("edges (%s", NAME);
      else
        N = numel (faces (S, args{:}));
        Q = sprintf ("faces (%s", NAME);
      endif
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
    ## its @code{Shape}:
    ##
    ## @example
    ## @group
    ## V = model.Viewer ();
    ## V.Shape = solid.box (80, 40, 12);
    ## V.Shape = hole (V.Shape, [20, 20, 12], 8, Inf);
    ## @end group
    ## @end example
    ##
    ## @code{@var{V} = model.Viewer (@qcode{'Hidden'}, true)} never shows its
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
            if (! (islogical (hidden) || isnumeric (hidden))
                || ! isscalar (hidden) || ! any (hidden == [0, 1]))
              error ("model.Viewer: Hidden must be a logical scalar.");
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
                              'data', uint8 ([]), 'mesh', [], 'name', 'S', ...
                              'named', false));

    endfunction

    function S = get.Shape (this)

      st = state (this);
      if (isa (st.mesh, 'polymesh.Mesh'))
        S = st.mesh;
      else
        S = solid.Shape (st.data);
      endif

    endfunction

    function set.Shape (this, S)

      ismesh = isa (S, 'polymesh.Mesh') && isscalar (S);
      if (! ismesh && (! isa (S, 'solid.Shape') || ! isscalar (S)))
        error (strcat ("model.Viewer: Shape must be a solid.Shape or a", ...
                       " polymesh.Mesh object."));
      endif
      st = state (this);
      if (ismesh)
        st.data = uint8 ([]);
        st.mesh = S;
      else
        st.data = S.Data;
        st.mesh = [];
      endif
      setstate (this, st);
      if (! isopen (this))
        launch (this);
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

    ## -*- texinfo -*-
    ## @deftypefn  {model.Viewer} {[@var{E}, @var{F}] =} pick (@var{V})
    ## @deftypefnx {model.Viewer} {@var{E} =} pick (@var{V}, @qcode{'edge'})
    ## @deftypefnx {model.Viewer} {@var{F} =} pick (@var{V}, @qcode{'face'})
    ## @deftypefnx {model.Viewer} {[@var{P}, @var{F}] =} pick (@var{V})
    ##
    ## Pick edges and faces of a solid, or points on a mesh, with the mouse.
    ##
    ## @code{[@var{E}, @var{F}] = pick (@var{V})} waits while you click edges
    ## and faces in the viewer's window, then returns the indices of the edges
    ## in @var{E} and of the faces in @var{F}, in the numbering
    ## @code{solid.Shape.edges} and @code{solid.Shape.faces} use.  A click
    ## selects what is under the pointer, which stays drawn in orange, a
    ## selected edge thick and a selected face filled, and a second click on
    ## it lets it go; the shape can still be turned between clicks.
    ## @kbd{Enter} finishes and @kbd{Escape} cancels, returning nothing.  With
    ## @qcode{'edge'} or @qcode{'face'} only that kind can be picked, and its
    ## indices are the one output.
    ##
    ## Indices belong to the shape they were picked on, and a script that holds
    ## them breaks as soon as an earlier step adds a feature.  So @code{pick}
    ## also prints, for each kind picked, the query that finds the same items
    ## by kind, direction and position, and says whether it finds exactly
    ## those.  Paste the query into the script instead of the numbers:
    ##
    ## @example
    ## @group
    ## E = pick (V, 'edge');
    ## @print{} edges (part, 'Type', 'line', 'Direction', [0, 0, 1], ...
    ## @print{}        'Within', [0, 0, 0, 80, 40, 12])
    ## @print{}   finds exactly the 4 edges picked
    ## part = fillet (part, E, 3);
    ## @end group
    ## @end example
    ##
    ## When the viewer shows a @code{polymesh.Mesh}, @code{[@var{P}, @var{F}]
    ## = pick (@var{V})} waits while you click points on it, each marked
    ## where it lands, and returns them in @var{P}, an @math{N}-by-3 matrix of
    ## the points where the clicks hit the mesh, and in @var{F} an
    ## @math{N}-by-4 matrix: for each point the index of the triangle it lies
    ## on, a row of the mesh's @code{Faces}, and the triangle's unit normal,
    ## turned as its corners run.  A click that misses the mesh adds nothing.
    ## @kbd{Enter} finishes and @kbd{Escape} cancels, returning nothing.  A
    ## mesh has no edges or faces in the sense of a solid, so @qcode{'edge'}
    ## and @qcode{'face'} are refused.
    ##
    ## @seealso{solid.Shape.edges, solid.Shape.faces, solid.Shape.show}
    ## @end deftypefn
    function varargout = pick (this, KIND = 'any')

      ## Input validation
      if (! ischar (KIND) || ! any (strcmp (KIND, {'edge', 'face', 'any'})))
        error ("model.Viewer.pick: KIND must be 'edge', 'face' or 'any'.");
      endif
      ismesh = isa (state (this).mesh, 'polymesh.Mesh');
      if (ismesh && ! strcmp (KIND, 'any'))
        error ("model.Viewer.pick: a mesh has only points to pick.");
      endif
      if (! isopen (this) || isempty (this.Shape))
        error ("model.Viewer.pick: the viewer is showing no shape.");
      endif

      ## Lines left from an earlier exchange are stale
      st = state (this);
      while (ischar (fgetl (st.out)))
      endwhile
      fclear (st.out);

      send (this, ["pick " KIND]);
      finished = false;
      unwind_protect
        [R, r] = replies (this, Inf);
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
      [E, F] = items (R);

      ## The queries that find them again
      S = this.Shape;
      if (! isempty (E))
        [Q, N] = model.Viewer.__query__ (S, 'edge', E, st.name);
        report (Q, N, numel (E), 'edge');
      endif
      if (! isempty (F))
        [Q, N] = model.Viewer.__query__ (S, 'face', F, st.name);
        report (Q, N, numel (F), 'face');
      endif

      switch (KIND)
        case 'edge'
          varargout = {E};
        case 'face'
          varargout = {F};
        otherwise
          varargout = {E, F};
      endswitch

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {model.Viewer} {@var{U} =} pickucs (@var{V})
    ## @deftypefnx {model.Viewer} {@var{U} =} pickucs (@var{V}, @var{MODE})
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
    ## side, as for @code{geom.UCS.threepoint}.  @var{MODE} is
    ## @qcode{'face'} by default.
    ##
    ## The origin comes second.  Click one point and the origin is there, laid
    ## in the plane.  Click a second and the origin takes its @math{x} from the
    ## first point and its @math{y} from the second, which puts a datum corner
    ## where a fillet or chamfer leaves no vertex to click.  Press @kbd{Enter}
    ## at once to keep the origin at the first point of the axes.
    ##
    ## Every point snaps to what it lands on: a corner to its vertex, a
    ## circular edge to its centre, another edge to its midpoint, a face to
    ## the point clicked.  Each is marked in the window.  On a triangle mesh
    ## the face clicked is a triangle, which gives the plane where the mesh is
    ## flat, and a point snaps to a corner of the triangle under it or the
    ## middle of one of its sides when the click is near, or else lies where
    ## it was clicked.  The shape can be
    ## turned between clicks, and @kbd{Escape} cancels with an error.
    ##
    ## A pick depends on the shape it was made on, so @code{pickucs} prints the
    ## line that makes the same UCS from coordinates, for the script:
    ##
    ## @example
    ## @group
    ## U = pickucs (V);
    ## @print{} U = geom.UCS ([0, 0, 1], [20, 20, 12], [21, 20, 12]);
    ## R.UCS = U;
    ## @end group
    ## @end example
    ##
    ## @seealso{geom.UCS, model.Viewer.pick}
    ## @end deftypefn
    function U = pickucs (this, MODE = 'face')

      ## Input validation
      if (! ischar (MODE) || ! any (strcmp (MODE, {'face', 'points'})))
        error ("model.Viewer.pickucs: MODE must be 'face' or 'points'.");
      endif
      if (! isopen (this) || isempty (this.Shape))
        error ("model.Viewer.pickucs: the viewer is showing no shape.");
      endif

      U = __pickucs__ (this, MODE, []);

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
      if (TF && waitpid (st.pid, WNOHANG ()) != 0)
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

    function launch (this)

      if (isempty (getenv ('DISPLAY')))
        error ("model.Viewer: the viewer needs a display, and none is set.");
      endif
      exe = file_in_loadpath ('__occtview__');
      st = state (this);
      args = {};
      if (st.hidden)
        args = {'--hidden'};
      endif
      [st.in, st.out, st.pid] = popen2 (exe, args);
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
        if (waitpid (st.pid, WNOHANG ()) != 0)
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

## The edges E and the faces F a pick replied with in the lines R
function [E, F] = items (R)

  E = zeros (1, 0);
  F = zeros (1, 0);
  for k = 1:numel (R)
    if (strncmp (R{k}, 'edge ', 5))
      E(end+1) = str2double (R{k}(6:end));
    elseif (strncmp (R{k}, 'face ', 5))
      F(end+1) = str2double (R{k}(6:end));
    endif
  endfor
  E = unique (E);
  F = unique (F);

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

## Print a query and whether it finds exactly what was picked
function report (Q, N, n, kind)

  printf ("%s\n", Q);
  if (N == n)
    printf ("  finds exactly the %d %s%s picked\n", n, kind, ...
            repmat ('s', 1, n != 1));
  else
    printf ("  finds %d %ss, among them the %d picked\n", N, kind, n);
  endif

endfunction

%!testif ; ! isempty (getenv ('DISPLAY'))
%! ## The window opens with the first shape and closes on demand
%! V = model.Viewer ('Hidden', true);
%! assert_equal (isopen (V), false);
%! V.Shape = solid.box (10, 20, 30);
%! assert_equal (isopen (V), true);
%! assert_equal (volume (V.Shape), 6000, 1e-9);
%! close (V);
%! assert_equal (isopen (V), false);

%!testif ; ! isempty (getenv ('DISPLAY'))
%! ## A double click takes the point of the shape under it
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Shape = solid.box (10, 20, 30);
%!   C = V.__dblclick__ (V.__project__ ([5, 10, 30]));
%!   assert_equal (C, [5, 10, 30], 0.05);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ! isempty (getenv ('DISPLAY'))
%! ## and the view turns about it: the point stays where it is on screen
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Shape = solid.box (10, 20, 30);
%!   C = V.__dblclick__ (V.__project__ ([10, 20, 30]));
%!   PX = V.__project__ (C);
%!   V.__drag__ ([450, 350], [520, 300]);
%!   assert_equal (V.__project__ (C), PX, 1);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ! isempty (getenv ('DISPLAY'))
%! ## A double click that misses the shape takes nothing
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Shape = solid.box (10, 20, 30);
%!   assert_equal (V.__dblclick__ ([2, 2]), []);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ! isempty (getenv ('DISPLAY'))
%! ## A pixel picks the face and the edge the queries name
%! B = solid.box (10, 20, 30);
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Shape = B;
%!   r = V.__pickat__ ('face', V.__project__ ([5, 10, 30]));
%!   assert_equal (r, sprintf ("face %d", faces (B, 'Normal', [0, 0, 1])));
%!   r = V.__pickat__ ('edge', V.__project__ ([5, 0, 30]));
%!   assert_equal (r, sprintf ("edge %d", ...
%!                             edges (B, 'Within', [0, 0, 30, 10, 0, 30])));
%!   assert_equal (V.__pickat__ ('face', [2, 2]), 'none');
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ! isempty (getenv ('DISPLAY'))
%! ## The seam of a cylinder is never offered
%! C = solid.cylinder (4, 12);
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Shape = C;
%!   assert_equal (V.__pickat__ ('edge', V.__project__ ([4, 0, 6])), 'none');
%!   assert_equal (V.__pickat__ ('any', V.__project__ ([4, 0, 6])), ...
%!                 sprintf ("face %d", faces (C, 'Type', 'cylinder')));
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ! isempty (getenv ('DISPLAY'))
%! ## A new shape replaces the old one, and the empty shape clears the view
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Shape = solid.box (10, 20, 30);
%!   px = V.__project__ ([5, 10, 30]);
%!   V.Shape = solid.Shape ();
%!   assert_equal (V.__pickat__ ('face', px), 'none');
%!   V.Shape = solid.box (10, 20, 30);
%!   assert_equal (V.__pickat__ ('face', px)(1:4), 'face');
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ! isempty (getenv ('DISPLAY'))
%! ## What a pick holds is drawn in orange, so that a click visibly took
%! orange = @(I) I(:,:,1) > 200 & I(:,:,2) < 150 & I(:,:,3) < 60;
%! near = @(M, p) any (any (M(round (p(2)) + (-3:5), round (p(1)) + (-3:5))));
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Shape = solid.box (10, 20, 30);
%!   pe = V.__project__ ([5, 0, 30]);
%!   pf = V.__project__ ([10, 10, 15]);
%!   V.__pickstart__ ('any');
%!   M = orange (V.__dump__ ());
%!   assert_equal ([near(M, pe), near(M, pf)], [false, false]);
%!   assert_equal (V.__click__ (pe), 1);
%!   M = orange (V.__dump__ ());
%!   assert_equal (near (M, pe), true);
%!   assert_equal (near (M, pf), false);
%!   assert_equal (V.__click__ (pf), 2);
%!   assert_equal (near (orange (V.__dump__ ()), pf), true);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ! isempty (getenv ('DISPLAY'))
%! ## A bore cut by a tool longer than the part is picked where it is, not in
%! ## the air beside the part (Open CASCADE 7.8 places its analytic cylinder
%! ## where the untrimmed surface begins)
%! B = hole (solid.box (80, 40, 12), [20, 20, 12], 8, Inf);
%! W = sprintf ("face %d", faces (B, 'Type', 'cylinder'));
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Shape = B;
%!   wall = V.__pickat__ ('face', V.__project__ ([17.17, 22.83, 10]));
%!   air = V.__pickat__ ('face', V.__project__ ([16, 20, 20]));
%!   assert_equal (wall, W);
%!   assert_equal (strcmp (air, W), false);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!test  # the query for four upright edges
%! B = solid.box (10, 20, 30);
%! [Q, N] = model.Viewer.__query__ (B, 'edge', edges (B, 'Direction', ...
%!                                                    [0, 0, 1]), 'part');
%! assert_equal (Q, strcat ("edges (part, 'Type', 'line', 'Direction',", ...
%!                          " [0, 0, 1], 'Within', [0, 0, 0, 10, 20, 30])"));
%! assert_equal (N, 4);

%!test  # a query that finds more than was picked
%! B = solid.box (10, 20, 30);
%! [Q, N] = model.Viewer.__query__ (B, 'face', faces (B, 'Normal', ...
%!                                                    [0, 0, 1]), 'B');
%! assert_equal (Q, strcat ("faces (B, 'Type', 'plane', 'Normal',", ...
%!                          " [0, 0, 1], 'Within', [0, 0, 30, 10, 20, 30])"));
%! assert_equal (N, 1);
%! C = solid.cylinder (4, 12);
%! [Q, N] = model.Viewer.__query__ (C, 'face', 1:3, 'C');
%! assert_equal (Q, "faces (C, 'Within', [-4, -4, 0, 4, 4, 12])");
%! assert_equal (N, 3);

%!testif ; ! isempty (getenv ('DISPLAY'))
%! ## The window is titled with the name, before it opens and after
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Name = 'plate';
%!   V.Shape = solid.box (10, 20, 30);
%!   assert_equal (V.__title__ (), 'plate (drafting)');
%!   V.Name = 'bracket';
%!   assert_equal (V.__title__ (), 'bracket (drafting)');
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ! isempty (getenv ('DISPLAY'))
%! ## The empty shape opens the window empty
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Shape = solid.Shape ();
%!   assert_equal (isopen (V), true);
%!   assert_equal (V.__pickat__ ('any', [450, 350]), 'none');
%!   V.Shape = solid.box (10, 20, 30);
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

%!testif ; ! isempty (getenv ('DISPLAY'))
%! ## A face and two corners, then a hole's rim for the origin: its centre
%! B = hole (solid.box (80, 40, 12), [20, 20, 12], 8, Inf);
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Shape = B;
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

%!testif ; ! isempty (getenv ('DISPLAY'))
%! ## A curved face is refused and asked for again; a datum corner from a
%! ## point on the right face and one on the front
%! B = hole (solid.box (80, 40, 12), [20, 20, 12], 8, Inf);
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Shape = B;
%!   px = @(p) V.__project__ (p);
%!   C = [px([17.17, 22.83, 10]); px([40, 30, 12]); px([0, 0, 12]); ...
%!        px([80, 0, 12]); px([80, 20, 6]); px([40, 0, 6])];
%!   evalc ("U = V.__pickucs__ ('face', C);");
%!   assert_equal (U.Origin, [80, 0, 12], 1e-9);
%!   assert_equal (U.Normal, [0, 0, 1]);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ! isempty (getenv ('DISPLAY'))
%! ## Three corners, Enter keeping the first, and the line it prints
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Shape = solid.box (80, 40, 12);
%!   px = @(p) V.__project__ (p);
%!   C = [px([0, 0, 12]); px([80, 0, 12]); px([0, 40, 12]); NaN, NaN];
%!   out = evalc ("U = V.__pickucs__ ('points', C);");
%!   assert_equal (strtrim (out), ...
%!                 "U = geom.UCS ([0, 0, 1], [0, 0, 12], [1, 0, 12]);");
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ! isempty (getenv ('DISPLAY'))
%! ## Escape cancels the pick with an error, and the viewer goes on
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Shape = solid.box (80, 40, 12);
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

%!testif ; ! isempty (getenv ('DISPLAY'))
%! ## A mesh is shown and handed back; a click on it is a facet or a point
%! M = boxmesh (80, 40, 12);
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Shape = M;
%!   assert_equal (V.Shape.Vertices, M.Vertices);
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

%!testif ; ! isempty (getenv ('DISPLAY'))
%! ## A UCS picked on a mesh: a facet and two corners, Enter for the origin
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Shape = boxmesh (80, 40, 12);
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

%!testif ; ! isempty (getenv ('DISPLAY'))
%! ## Points picked on a mesh, with the triangle each lies on and its normal;
%! ## a click that misses adds nothing, and a shape replaces the mesh.  The
%! ## top's triangles 3 and 4 meet on its diagonal, y = x / 2; the side's 7
%! ## lies below z = 0.3 y
%! M = boxmesh (80, 40, 12);
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Shape = M;
%!   V.__pickstart__ ('any');
%!   T = [60, 10, 12; 20, 30, 12; 80, 30, 4];
%!   assert_equal (V.__click__ (V.__project__ (T(1,:))), 1);
%!   assert_equal (V.__click__ ([2, 2]), 1);
%!   assert_equal (V.__click__ (V.__project__ (T(2,:))), 2);
%!   assert_equal (V.__click__ (V.__project__ (T(3,:))), 3);
%!   [P, F] = V.__pickend__ ();
%!   assert_equal (P, T, 0.5);
%!   assert_equal (F, [3, 0, 0, 1; 4, 0, 0, 1; 7, 1, 0, 0], 1e-12);
%!   V.Shape = solid.box (10, 20, 30);
%!   assert_equal (volume (V.Shape), 6000, 1e-9);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ! isempty (getenv ('DISPLAY'))
%! ## Each solid is shown in its colour, one without a colour in grey
%! B = solid.box (10, 10, 10);
%! U = union (B, translate (B, [20, 0, 0]));
%! U.Colour = [1, 0, 0; NaN, NaN, NaN];
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Shape = U;
%!   I = double (V.__dump__ ());
%!   p = round ([V.__project__([5, 5, 10]); V.__project__([25, 5, 10])]);
%!   c = [squeeze(I(p(1,2), p(1,1), :))'; squeeze(I(p(2,2), p(2,1), :))'];
%!   red = c(:,1) > 100 & c(:,2) < 40 & c(:,3) < 40;
%!   grey = max (c, [], 2) - min (c, [], 2) < 30;
%!   assert_equal (sort ([red, grey], 1), [false, false; true, true]);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ! isempty (getenv ('DISPLAY'))
%! ## A mesh is shown in its faces' colours, its vertices' or grey
%! M = boxmesh (80, 40, 12);
%! M.FaceColour = repmat ([1, 0, 0], 12, 1);
%! M.VertexColour = repmat ([0, 0, 1], 8, 1);
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Shape = M;
%!   p = round (V.__project__ ([40, 20, 12]));
%!   at = @(I) double (squeeze (I(p(2), p(1), :)))';
%!   assert_equal (V.__look__ (), 'face');
%!   c = at (V.__dump__ ());
%!   assert_equal (c(1) > 100 && c(2) < 40 && c(3) < 40, true);
%!   V.__colours__ ('vertex');
%!   assert_equal (V.__look__ (), 'vertex');
%!   c = at (V.__dump__ ());
%!   assert_equal (c(3) > 100 && c(1) < 40 && c(2) < 40, true);
%!   V.__colours__ ('grey');
%!   c = at (V.__dump__ ());
%!   assert_equal (max (c) - min (c) < 30 && min (c) > 60, true);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ! isempty (getenv ('DISPLAY'))
%! ## A colouring chosen holds for the meshes after that have it; one that
%! ## lacks it is shown in the first it has
%! M = boxmesh (10, 20, 30);
%! M.FaceColour = repmat ([1, 0, 0], 12, 1);
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Shape = M;
%!   V.__colours__ ('vertex');
%!   assert_equal (V.__look__ (), 'face');
%!   M.VertexColour = repmat ([0, 0, 1], 8, 1);
%!   V.Shape = M;
%!   assert_equal (V.__look__ (), 'vertex');
%!   V.Shape = boxmesh (10, 20, 30);
%!   assert_equal (V.__look__ (), 'grey');
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; ! isempty (getenv ('DISPLAY'))
%! ## A mesh's triangle edges are drawn when asked for, and only then
%! dark = @(I) all (I < 90, 3);
%! near = @(D, p) any (any (D(round (p(2)) + (-3:3), round (p(1)) + (-3:3))));
%! V = model.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Shape = boxmesh (80, 40, 12);
%!   p = V.__project__ ([40, 20, 12]);
%!   [~, edges] = V.__look__ ();
%!   assert_equal (edges, 'off');
%!   assert_equal (near (dark (V.__dump__ ()), p), false);
%!   V.__edges__ ('on');
%!   [~, edges] = V.__look__ ();
%!   assert_equal (edges, 'on');
%!   assert_equal (near (dark (V.__dump__ ()), p), true);
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!test
%! V = model.Viewer ();
%! assert_equal (isopen (V), false);
%! assert_equal (isempty (V.Shape), true);
%! assert_equal (V.Name, 'S');
%! V.Name = 'part';
%! assert_equal (V.Name, 'part');

%!error<model.Viewer: Name/Value arguments must come in pairs.> ...
%! model.Viewer ('Hidden')
%!error<model.Viewer: unknown option 'Visible'.> model.Viewer ('Visible', true)
%!error<model.Viewer: option names must be character vectors.> model.Viewer (1, true)
## Option names ignore case
%!testif ; ! isempty (getenv ('DISPLAY'))
%! V = model.Viewer ('hidden', true);
%! assert_equal (isopen (V), false);
%!error<model.Viewer: Hidden must be a logical scalar.> ...
%! model.Viewer ('Hidden', 2)
%!error<model.Viewer: Shape must be a solid.Shape or a polymesh.Mesh object.>
%! V = model.Viewer ();
%! V.Shape = 1;
%!error<model.Viewer: Name must be a valid variable name.>
%! V = model.Viewer ();
%! V.Name = '1part';
%!error<model.Viewer.pick: KIND must be 'edge', 'face' or 'any'.>
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
%!error<model.Viewer: the viewer needs a display, and none is set.>
%! d = getenv ('DISPLAY');
%! unwind_protect
%!   setenv ('DISPLAY', '');
%!   V = model.Viewer ();
%!   V.Shape = solid.Shape (uint8 (sprintf ("\nOpen CASCADE Topology V3")));
%! unwind_protect_cleanup
%!   setenv ('DISPLAY', d);
%! end_unwind_protect
%!error<model.Viewer.pickucs: MODE must be 'face' or 'points'.> ...
%! pickucs (model.Viewer (), 'edges')
%!error<model.Viewer.pickucs: the viewer is showing no shape.> ...
%! pickucs (model.Viewer ())
