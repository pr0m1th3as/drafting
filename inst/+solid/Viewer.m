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
## @deftypefn  {drafting} {@var{V} =} solid.Viewer ()
## @deftypefnx {drafting} {@var{V} =} solid.Viewer (@qcode{'Hidden'}, @var{TF})
##
## A window showing a solid, in which edges and faces can be picked.
##
## @code{@var{V} = solid.Viewer ()} returns a viewer that shows nothing yet.
## Assigning a @code{solid.Shape} to @code{@var{V}.Shape} opens its window,
## even for the empty shape, or redraws it in place, keeping the camera where
## it was:
##
## @example
## @group
## V = solid.Viewer ();
## V.Shape = solid.box (80, 40, 12);
## V.Shape = hole (V.Shape, [20, 20, 12], 8, Inf);
## @end group
## @end example
##
## @code{solid.show} keeps one viewer for you and is the usual way in; a
## viewer of your own is for showing two shapes side by side.
##
## The window is drawn by Open CASCADE in a process of its own, so a complex
## model turns smoothly and never holds up the Octave prompt.  The left mouse
## button rotates, the middle one pans and the wheel zooms.  Keys:
##
## @multitable @columnfractions 0.15 0.85
## @item @kbd{F} @tab fit the shape to the window
## @item @kbd{0} @tab isometric view
## @item @kbd{1} @tab front view, looking along @math{+y}
## @item @kbd{2} @tab top view, looking down @math{z}
## @item @kbd{3} @tab right view, looking along @math{-x}
## @end multitable
##
## Closing the window ends the viewer; assigning a shape again opens a new
## one.  The window closes with Octave.
##
## @code{solid.Viewer (@qcode{'Hidden'}, true)} never shows its window.  It
## draws and picks all the same, which is how the viewer is tested.
##
## The viewer is built with the package when Open CASCADE and X11 are found,
## and needs a display to run.  It runs on Linux.
##
## @seealso{solid.show, solid.Viewer.pick}
## @end deftypefn

classdef Viewer < handle

  properties (Dependent)

    ## -*- texinfo -*-
    ## @deftypefn {solid.Viewer} {} Shape
    ##
    ## The @code{solid.Shape} shown.
    ##
    ## Assigning a shape opens the window if it is not open and redraws it in
    ## place if it is.  The empty shape opens the window empty, or clears it
    ## if it is open; the first shape shown after it is fitted to the window.
    ##
    ## @end deftypefn
    Shape

    ## -*- texinfo -*-
    ## @deftypefn {solid.Viewer} {} Name
    ##
    ## The name of the variable holding the shape shown.
    ##
    ## Setting it titles the window with the name, so that several viewers can
    ## be told apart, and the queries @code{solid.Viewer.pick} prints use it.
    ## Until it is set the window is titled @qcode{drafting} and the queries
    ## use @qcode{'S'}.
    ##
    ## @end deftypefn
    Name

  endproperties

  properties (Hidden, SetAccess = private)

    Id = 0;

  endproperties

  methods (Hidden)

    function disp (this)

      st = state (this);
      if (isopen (this))
        printf ("  solid.Viewer: open, showing %s\n", st.name);
      else
        printf ("  solid.Viewer: closed\n");
      endif

    endfunction

    ## The pixel at which the model point P lands
    function PX = __project__ (this, P)

      send (this, sprintf ("project %.17g %.17g %.17g", P));
      r = strsplit (receive (this, 10));
      PX = str2double (r(2:3));

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

    ## The query that finds the edges or faces IDX of S, and how many it finds
    function [Q, N] = __query__ (S, KIND, IDX, NAME)

      if (strcmp (KIND, 'edge'))
        info = __occt__ ('edges', 'solid.Viewer.pick', S.Data);
        [type, dir, box] = info{1:3};
        args = {};
        if (all (strcmp (type(IDX), type{IDX(1)})))
          args(end+1:end+2) = {'Type', type{IDX(1)}};
        endif
        if (alike (dir(IDX,:)))
          args(end+1:end+2) = {'Direction', dir(IDX(1),:)};
        endif
      else
        info = __occt__ ('faces', 'solid.Viewer.pick', S.Data);
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

    function this = Viewer (varargin)

      ## A wrapper over an existing viewer, for solid.show
      if (nargin == 2 && strcmp (varargin{1}, '__id__'))
        this.Id = varargin{2};
        return;
      endif

      ## Input validation
      if (mod (numel (varargin), 2) != 0)
        error ("solid.Viewer: Name/Value arguments must come in pairs.");
      endif
      hidden = false;
      for k = 1:2:numel (varargin)
        if (! ischar (varargin{k}) || ! strcmp (varargin{k}, 'Hidden'))
          error ("solid.Viewer: unknown parameter.");
        endif
        hidden = varargin{k+1};
        if (! (islogical (hidden) || isnumeric (hidden)) ...
            || ! isscalar (hidden) || ! any (hidden == [0, 1]))
          error ("solid.Viewer: Hidden must be a logical scalar.");
        endif
      endfor

      ## The state lives in the graphics root, where it outlasts clear all
      id = getappdata (0, 'drafting_solid_viewer_next');
      if (isempty (id))
        id = 1;
      endif
      setappdata (0, 'drafting_solid_viewer_next', id + 1);
      this.Id = id;
      setstate (this, struct ('pid', -1, 'in', -1, 'out', -1, ...
                              'hidden', logical (hidden), ...
                              'data', uint8 ([]), 'name', 'S', ...
                              'named', false));

    endfunction

    function S = get.Shape (this)

      S = solid.Shape (state (this).data);

    endfunction

    function set.Shape (this, S)

      if (! isa (S, 'solid.Shape') || ! isscalar (S))
        error ("solid.Viewer: Shape must be a solid.Shape object.");
      endif
      st = state (this);
      st.data = S.Data;
      setstate (this, st);
      if (! isopen (this))
        launch (this);
      endif
      send (this, sprintf ("shape %d", numel (S.Data)), S.Data);

    endfunction

    function N = get.Name (this)

      N = state (this).name;

    endfunction

    function set.Name (this, N)

      if (! ischar (N) || ! isvarname (N))
        error ("solid.Viewer: Name must be a valid variable name.");
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
    ## @deftypefn  {solid.Viewer} {[@var{E}, @var{F}] =} pick (@var{V})
    ## @deftypefnx {solid.Viewer} {@var{E} =} pick (@var{V}, @qcode{'edge'})
    ## @deftypefnx {solid.Viewer} {@var{F} =} pick (@var{V}, @qcode{'face'})
    ##
    ## Pick edges and faces with the mouse.
    ##
    ## @code{[@var{E}, @var{F}] = pick (@var{V})} waits while you click edges
    ## and faces in the viewer's window, then returns the indices of the edges
    ## in @var{E} and of the faces in @var{F}, in the numbering
    ## @code{solid.Shape.edges} and @code{solid.Shape.faces} use.  A click
    ## selects what is under the pointer and a second click on it lets it go;
    ## the shape can still be turned between clicks.  @kbd{Enter} finishes and
    ## @kbd{Escape} cancels, returning nothing.  With @qcode{'edge'} or
    ## @qcode{'face'} only that kind can be picked, and its indices are the one
    ## output.
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
    ## @seealso{solid.Shape.edges, solid.Shape.faces, solid.show}
    ## @end deftypefn
    function varargout = pick (this, KIND = 'any')

      ## Input validation
      if (! ischar (KIND) || ! any (strcmp (KIND, {'edge', 'face', 'any'})))
        error ("solid.Viewer.pick: KIND must be 'edge', 'face' or 'any'.");
      endif
      if (! isopen (this) || isempty (state (this).data))
        error ("solid.Viewer.pick: the viewer is showing no shape.");
      endif

      ## Lines left from an earlier exchange are stale
      st = state (this);
      while (ischar (fgetl (st.out)))
      endwhile
      fclear (st.out);

      send (this, ["pick " KIND]);
      E = zeros (1, 0);
      F = zeros (1, 0);
      finished = false;
      unwind_protect
        do
          r = receive (this, Inf);
          if (strncmp (r, 'edge ', 5))
            E(end+1) = str2double (r(6:end));
          elseif (strncmp (r, 'face ', 5))
            F(end+1) = str2double (r(6:end));
          endif
        until (any (strcmp (r, {'done', 'cancel', 'closed'})))
        finished = true;
      unwind_protect_cleanup
        if (! finished && isopen (this))
          send (this, "cancel");
        endif
      end_unwind_protect
      if (strcmp (r, 'closed'))
        error ("solid.Viewer.pick: the window was closed during the pick.");
      endif
      E = unique (E);
      F = unique (F);

      ## The queries that find them again
      S = this.Shape;
      if (! isempty (E))
        [Q, N] = solid.Viewer.__query__ (S, 'edge', E, st.name);
        report (Q, N, numel (E), 'edge');
      endif
      if (! isempty (F))
        [Q, N] = solid.Viewer.__query__ (S, 'face', F, st.name);
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
    ## @deftypefn {solid.Viewer} {} close (@var{V})
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
    ## @deftypefn {solid.Viewer} {@var{TF} =} isopen (@var{V})
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

    function st = state (this)

      st = getappdata (0, sprintf ('drafting_solid_viewer_%d', this.Id));

    endfunction

    function setstate (this, st)

      setappdata (0, sprintf ('drafting_solid_viewer_%d', this.Id), st);

    endfunction

    function launch (this)

      if (isempty (getenv ('DISPLAY')))
        error ("solid.Viewer: the viewer needs a display, and none is set.");
      endif
      exe = file_in_loadpath ('__occtview__');
      if (isempty (exe))
        error (strcat ("solid.Viewer: the viewer is not available: the", ...
                       " drafting package was built without it."));
      endif
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
        error ("solid.Viewer: the viewer could not start: %s", r);
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
          error ("solid.Viewer: the viewer did not reply.");
        endif
        pause (0.01);
      endwhile

    endfunction

  endmethods

endclassdef

## The window's title: the name of the variable shown, once it is known
function T = title (st)

  if (st.named)
    T = sprintf ("%s (drafting)", st.name);
  else
    T = "drafting";
  endif

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

%!testif ; exist ('__occt__') == 3 && ! isempty (getenv ('DISPLAY')) && ! isempty (file_in_loadpath ('__occtview__'))
%! ## The window opens with the first shape and closes on demand
%! V = solid.Viewer ('Hidden', true);
%! assert_equal (isopen (V), false);
%! V.Shape = solid.box (10, 20, 30);
%! assert_equal (isopen (V), true);
%! assert_equal (volume (V.Shape), 6000, 1e-9);
%! close (V);
%! assert_equal (isopen (V), false);

%!testif ; exist ('__occt__') == 3 && ! isempty (getenv ('DISPLAY')) && ! isempty (file_in_loadpath ('__occtview__'))
%! ## A pixel picks the face and the edge the queries name
%! B = solid.box (10, 20, 30);
%! V = solid.Viewer ('Hidden', true);
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

%!testif ; exist ('__occt__') == 3 && ! isempty (getenv ('DISPLAY')) && ! isempty (file_in_loadpath ('__occtview__'))
%! ## The seam of a cylinder is never offered
%! C = solid.cylinder (4, 12);
%! V = solid.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Shape = C;
%!   assert_equal (V.__pickat__ ('edge', V.__project__ ([4, 0, 6])), 'none');
%!   assert_equal (V.__pickat__ ('any', V.__project__ ([4, 0, 6])), ...
%!                 sprintf ("face %d", faces (C, 'Type', 'cylinder')));
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; exist ('__occt__') == 3 && ! isempty (getenv ('DISPLAY')) && ! isempty (file_in_loadpath ('__occtview__'))
%! ## A new shape replaces the old one, and the empty shape clears the view
%! V = solid.Viewer ('Hidden', true);
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

%!testif ; exist ('__occt__') == 3  # the query for four upright edges
%! B = solid.box (10, 20, 30);
%! [Q, N] = solid.Viewer.__query__ (B, 'edge', edges (B, 'Direction', ...
%!                                                    [0, 0, 1]), 'part');
%! assert_equal (Q, strcat ("edges (part, 'Type', 'line', 'Direction',", ...
%!                          " [0, 0, 1], 'Within', [0, 0, 0, 10, 20, 30])"));
%! assert_equal (N, 4);

%!testif ; exist ('__occt__') == 3  # a query that finds more than was picked
%! B = solid.box (10, 20, 30);
%! [Q, N] = solid.Viewer.__query__ (B, 'face', faces (B, 'Normal', ...
%!                                                    [0, 0, 1]), 'B');
%! assert_equal (Q, strcat ("faces (B, 'Type', 'plane', 'Normal',", ...
%!                          " [0, 0, 1], 'Within', [0, 0, 30, 10, 20, 30])"));
%! assert_equal (N, 1);
%! C = solid.cylinder (4, 12);
%! [Q, N] = solid.Viewer.__query__ (C, 'face', 1:3, 'C');
%! assert_equal (Q, "faces (C, 'Within', [-4, -4, 0, 4, 4, 12])");
%! assert_equal (N, 3);

%!testif ; exist ('__occt__') == 3 && ! isempty (getenv ('DISPLAY')) && ! isempty (file_in_loadpath ('__occtview__'))
%! ## The window is titled with the name, before it opens and after
%! V = solid.Viewer ('Hidden', true);
%! unwind_protect
%!   V.Name = 'plate';
%!   V.Shape = solid.box (10, 20, 30);
%!   assert_equal (V.__title__ (), 'plate (drafting)');
%!   V.Name = 'bracket';
%!   assert_equal (V.__title__ (), 'bracket (drafting)');
%! unwind_protect_cleanup
%!   close (V);
%! end_unwind_protect

%!testif ; exist ('__occt__') == 3 && ! isempty (getenv ('DISPLAY')) && ! isempty (file_in_loadpath ('__occtview__'))
%! ## The empty shape opens the window empty
%! V = solid.Viewer ('Hidden', true);
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

%!test
%! V = solid.Viewer ();
%! assert_equal (isopen (V), false);
%! assert_equal (isempty (V.Shape), true);
%! assert_equal (V.Name, 'S');
%! V.Name = 'part';
%! assert_equal (V.Name, 'part');

%!error<solid.Viewer: Name/Value arguments must come in pairs.> ...
%! solid.Viewer ('Hidden')
%!error<solid.Viewer: unknown parameter.> solid.Viewer ('Visible', true)
%!error<solid.Viewer: Hidden must be a logical scalar.> ...
%! solid.Viewer ('Hidden', 2)
%!error<solid.Viewer: Shape must be a solid.Shape object.>
%! V = solid.Viewer ();
%! V.Shape = 1;
%!error<solid.Viewer: Name must be a valid variable name.>
%! V = solid.Viewer ();
%! V.Name = '1part';
%!error<solid.Viewer.pick: KIND must be 'edge', 'face' or 'any'.>
%! pick (solid.Viewer (), 'vertex')
%!error<solid.Viewer.pick: the viewer is showing no shape.>
%! pick (solid.Viewer ())
%!error<solid.Viewer: the viewer needs a display, and none is set.>
%! d = getenv ('DISPLAY');
%! unwind_protect
%!   setenv ('DISPLAY', '');
%!   V = solid.Viewer ();
%!   V.Shape = solid.Shape (uint8 (sprintf ("\nOpen CASCADE Topology V3")));
%! unwind_protect_cleanup
%!   setenv ('DISPLAY', d);
%! end_unwind_protect
