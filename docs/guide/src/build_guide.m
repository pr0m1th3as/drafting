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

## Build the drafting guide, the pages in docs/guide.
##
## build_guide () runs every tutorial in this folder, the scripts named
## NN_name.m, and writes each as a page of docs/guide: its prose, every block
## of code, what the block printed and a picture of every figure it drew and
## every shape it showed.  It writes index.html, and the sidebar of every page,
## the hand-written ones included, so that each lists all the others.
##
## build_guide ('check') runs every tutorial and writes nothing, to find a
## block that fails before a build.
##
## Run it from the root of the repository with the compiled files built,
## under the GUI toolkit, for example:
##
##   cd src && make && cd ..
##   octave --no-gui --eval "addpath (fullfile (pwd, 'docs/guide/src')); build_guide ()"
##
## The path must be absolute: the tutorials run in a folder of their own.
##
## The package is taken from this working tree, never from an installed copy.
##
## A tutorial is an Octave script.  The licence header is skipped; the page
## starts at the line '## # Title'.  Lines starting with '##' are prose in a
## subset of Markdown: '#', '##' and '###' headings, paragraphs, '-' and '1.'
## lists, `code`, **bold**, *italic* and [text](url).  Code naming a function
## or class of the package, exactly as INDEX lists it, links to its reference
## page.  Every other line is code, and the code between two runs of prose is
## one block, run in one workspace for the whole tutorial.  A code line ending
## in '#: not run' is shown without being run, for what needs a person at the
## mouse.
##
## primer.m, A brief Octave primer, is written the same way and run the same
## way, but it is no tutorial: its page stands in a section of its own, before
## the tutorials and outside their sequence.
##
## A figure a block draws is captured when the block ends.  A shape a block
## shows with show (X) or X.show is drawn by Open CASCADE in a hidden viewer
## and captured from it, so no window opens.

function build_guide (MODE = 'build')

  if (! any (strcmp (MODE, {'build', 'check'})))
    error ("build_guide: MODE must be 'build' or 'check'.");
  endif
  build = strcmp (MODE, 'build');

  src = fileparts (mfilename ('fullpath'));
  out = fileparts (src);
  root = fileparts (fileparts (out));
  addpath (fullfile (root, 'inst'), fullfile (root, 'src'));
  if (exist ('__occt__') != 3 || isempty (file_in_loadpath ('__occtview__')))
    error (strcat ("build_guide: the compiled files are not built; run", ...
                   " make in src first."));
  endif

  ## The tutorials, in the order of their numbers
  files = sort (glob (fullfile (src, '[0-9][0-9]_*.m')));
  if (isempty (files))
    error ("build_guide: no tutorials in %s.", src);
  endif
  T = parse (files{1});
  for k = 2:numel (files)
    T(k) = parse (files{k});
  endfor
  P = parse (fullfile (src, 'primer.m'));
  names = index_names (fullfile (root, 'INDEX'));

  ## Every page of the guide, for the sidebar
  pages = struct ('file', {'index.html', 'layout.html', 'dxf.html'}, ...
                  'title', {'Overview', 'Package layout', ...
                            'DXF and the classes'}, ...
                  'group', 'Guide');
  pages(end+1) = struct ('file', [P.base, '.html'], 'title', P.title, ...
                         'group', 'Octave');
  for k = 1:numel (T)
    pages(end+1) = struct ('file', [T(k).base, '.html'], ...
                           'title', T(k).title, 'group', 'Tutorials');
  endfor

  imgdir = fullfile (out, 'img');
  if (build)
    old = [glob(fullfile (out, '[0-9][0-9]_*.html')); ...
           glob(fullfile (out, 'index.html')); ...
           glob(fullfile (out, [P.base, '.html']))];
    for k = 1:numel (old)
      unlink (old{k});
    endfor
    if (exist (imgdir, 'dir'))
      confirm_recursive_rmdir (false, 'local');
      rmdir (imgdir, 's');
    endif
    mkdir (imgdir);
  endif

  ## Files a tutorial writes land in a folder of their own
  work = tempname ();
  mkdir (work);
  here = pwd ();
  vis = get (0, 'defaultfigurevisible');
  set (0, 'defaultfigurevisible', 'off');
  unwind_protect
    cd (work);
    printf ("build_guide: %s\n", P.base);
    ctx = struct ('base', P.base, 'imgdir', imgdir, 'build', build);
    P.cells = run_tutorial (P.cells, ctx);
    for k = 1:numel (T)
      printf ("build_guide: %s\n", T(k).base);
      ctx = struct ('base', T(k).base, 'imgdir', imgdir, 'build', build);
      T(k).cells = run_tutorial (T(k).cells, ctx);
    endfor
  unwind_protect_cleanup
    cd (here);
    set (0, 'defaultfigurevisible', vis);
    close all;
    confirm_recursive_rmdir (false, 'local');
    rmdir (work, 's');
  end_unwind_protect

  if (! build)
    printf (["build_guide: the primer and %d tutorials run,", ...
             " nothing written.\n"], numel (T));
    return;
  endif

  ## The pages
  tmpl = fileread (fullfile (src, 'page.html'));
  for k = 1:numel (T)
    body = tutorial_html (T, k, names);
    write_page (fullfile (out, [T(k).base, '.html']), tmpl, T(k).title, ...
                body, nav (pages, [T(k).base, '.html']));
  endfor
  body = [cells_html(P, names), ...
          "<nav class=\"d-flex justify-content-between my-5\">\n", ...
          "<span></span>\n", ...
          sprintf("<a href=\"%s.html\">%s &rarr;</a>\n", T(1).base, ...
                  esc (T(1).title)), ...
          "</nav>\n"];
  write_page (fullfile (out, [P.base, '.html']), tmpl, P.title, body, ...
              nav (pages, [P.base, '.html']));
  write_page (fullfile (out, 'index.html'), tmpl, 'Overview', ...
              index_html (T, P), nav (pages, 'index.html'));
  for f = {'layout.html', 'dxf.html'}
    p = fullfile (out, f{1});
    write_text (p, set_nav (fileread (p), nav (pages, f{1})));
  endfor
  printf ("build_guide: the primer and %d tutorials written to %s\n", ...
          numel (T), out);

endfunction

## A tutorial script as its title, its lead paragraph and its cells
function T = parse (file)

  L = strsplit (fileread (file), "\n", 'CollapseDelimiters', false);
  first = find (strncmp (L, '## # ', 5), 1);
  if (isempty (first))
    error ("build_guide: %s has no '## # Title' line.", file);
  endif
  [~, base] = fileparts (file);
  T.base = base;
  T.title = strtrim (L{first}(6:end));

  cells = struct ('type', {}, 'lines', {}, 'line', {});
  for k = first+1:numel (L)
    s = L{k};
    if (! isempty (regexp (s, '^##( |$)', 'once')))
      type = 'prose';
      s = regexprep (s, '^## ?', '');
    elseif (isempty (strtrim (s)) && ! isempty (cells))
      type = cells(end).type;
    else
      type = 'code';
    endif
    if (isempty (cells) || ! strcmp (cells(end).type, type))
      cells(end+1) = struct ('type', type, 'lines', {{}}, 'line', k);
    endif
    cells(end).lines{end+1} = s;
  endfor

  ## Blank lines around a block are not part of it
  keep = true (1, numel (cells));
  for k = 1:numel (cells)
    t = cells(k).lines;
    e = cellfun (@(s) isempty (strtrim (s)), t);
    if (all (e))
      keep(k) = false;
    else
      cells(k).lines = t(find (! e, 1):find (! e, 1, 'last'));
    endif
  endfor
  T.cells = cells(keep);

  ## The lead is the first paragraph of prose
  T.lead = '';
  if (! isempty (T.cells) && strcmp (T.cells(1).type, 'prose'))
    t = T.cells(1).lines;
    stop = find (cellfun (@(s) isempty (strtrim (s)), t), 1);
    if (isempty (stop))
      stop = numel (t) + 1;
    endif
    T.lead = strjoin (strtrim (t(1:stop-1)), ' ');
  endif

endfunction

## Run every code cell of a tutorial in one workspace, keeping what each
## printed and the pictures it made.  Its own variables are named so that no
## tutorial can meet them.
function __cells__ = run_tutorial (__cells__, __ctx__)

  __n__ = 0;
  for __k__ = 1:numel (__cells__)
    __cells__(__k__).out = '';
    __cells__(__k__).img = {};
    if (! strcmp (__cells__(__k__).type, 'code'))
      continue;
    endif
    __run__ = __cells__(__k__).lines;
    __run__ = __run__(cellfun (@isempty, regexp (__run__, '#: not run\s*$')));
    __run__ = strjoin (__run__, "\n");
    __views__ = arm_viewers (__run__);
    try
      __cells__(__k__).out = evalc (__run__);
    catch __err__
      disarm_viewers (__views__);
      error ("build_guide: %s, the block at line %d: %s", __ctx__.base, ...
             __cells__(__k__).line, __err__.message);
    end_try_catch
    [__cells__(__k__).img, __n__] = capture (__ctx__, __views__, __n__);
  endfor

endfunction

## A hidden viewer for every variable a block shows, registered where show
## looks for the viewer of that name, so that show draws in it
function views = arm_viewers (code)

  views = struct ('key', {}, 'id', {});
  if (isempty (regexp (code, '\<show\>', 'once')))
    return;
  endif
  [t1, s1] = regexp (code, '\<show\s*\(\s*([A-Za-z]\w*)\s*[,)]', ...
                     'tokens', 'start');
  [t2, s2] = regexp (code, '\<([A-Za-z]\w*)\.show\>', 'tokens', 'start');
  [~, i] = sort ([s1, s2]);
  t = [t1, t2](i);
  keys = cellfun (@(c) ['v_', c{1}], t, 'UniformOutput', false);
  keys = unique ([keys, {'unnamed'}], 'stable');
  ids = struct ();
  for k = 1:numel (keys)
    V = model.Viewer ('Hidden', true);
    ids.(keys{k}) = V.Id;
    views(end+1) = struct ('key', keys{k}, 'id', V.Id);
  endfor
  setappdata (0, 'drafting_model_show', ids);

endfunction

## Close the viewers of a block and forget them
function disarm_viewers (views)

  for k = 1:numel (views)
    V = model.Viewer ('__id__', views(k).id);
    if (isopen (V))
      close (V);
    endif
  endfor
  setappdata (0, 'drafting_model_show', struct ());

endfunction

## The pictures a block made: every figure it drew, then every shape it
## showed, in the order the block showed them
function [img, n] = capture (ctx, views, n)

  img = {};
  h = sort (get (0, 'children'));
  for k = 1:numel (h)
    n += 1;
    f = sprintf ("%s-%d.png", ctx.base, n);
    if (ctx.build)
      ## At 200 dots per inch, twice the size it is shown at: a line weight is
      ## in points, and only a resolution turns points into pixels
      set (h(k), 'paperunits', 'inches', 'paperposition', [0, 0, 9, 7]);
      print (h(k), fullfile (ctx.imgdir, f), '-dpng', '-r200');
    endif
    img{end+1} = f;
    close (h(k));
  endfor
  for k = 1:numel (views)
    V = model.Viewer ('__id__', views(k).id);
    if (! isopen (V))
      continue;
    endif
    n += 1;
    f = sprintf ("%s-%d.png", ctx.base, n);
    if (ctx.build)
      imwrite (V.__dump__ (), fullfile (ctx.imgdir, f));
    endif
    img{end+1} = f;
  endfor
  disarm_viewers (views);

endfunction

## The body of a tutorial's page, with the tutorials before and after it
function html = tutorial_html (T, k, names)

  html = cells_html (T(k), names);
  html = [html, "<nav class=\"d-flex justify-content-between my-5\">\n"];
  if (k > 1)
    html = [html, sprintf("<a href=\"%s.html\">&larr; %s</a>\n", ...
                          T(k-1).base, esc (T(k-1).title))];
  else
    html = [html, "<span></span>\n"];
  endif
  if (k < numel (T))
    html = [html, sprintf("<a href=\"%s.html\">%s &rarr;</a>\n", ...
                          T(k+1).base, esc (T(k+1).title))];
  endif
  html = [html, "</nav>\n"];

endfunction

## The title, prose, code, output and pictures of the page of the script T
function html = cells_html (t, names)

  html = sprintf ("<h1>%s</h1>\n", esc (t.title));
  for c = t.cells
    if (strcmp (c.type, 'prose'))
      html = [html, markdown(c.lines, names)];
      continue;
    endif
    shown = regexprep (c.lines, '\s*#: not run\s*$', '');
    html = [html, sprintf("<pre class=\"code-in\"><code>%s</code></pre>\n", ...
                          esc (strjoin (shown, "\n")))];
    o = regexprep (c.out, '^\n+|\s+$', '');
    if (! isempty (o))
      html = [html, sprintf("<pre class=\"code-out\"><code>%s</code></pre>\n", ...
                            esc (o))];
    endif
    for i = 1:numel (c.img)
      n = regexp (c.img{i}, '-(\d+)\.png$', 'tokens', 'once'){1};
      html = [html, sprintf(["<figure class=\"shot\"><img src=\"img/%s\"", ...
                             " alt=\"%s, picture %s\"></figure>\n"], ...
                            c.img{i}, esc (t.title), n)];
    endfor
  endfor

endfunction

## The body of the guide's front page
function html = index_html (T, P)

  html = ["<h1>The drafting guide</h1>\n", ...
          "<p class=\"lead\">What the package is made of, how it meets DXF,", ...
          " a brief Octave primer, and tutorials that build parts and", ...
          " drawings step by step.  Every picture is made by the code", ...
          " above it, and every output is what that code printed.</p>\n", ...
          "<h2>How the package is built</h2>\n<ul>\n", ...
          "<li><a href=\"layout.html\">Package layout</a>: the five", ...
          " namespaces, the classes, and how an object of one becomes an", ...
          " object of another.</li>\n", ...
          "<li><a href=\"dxf.html\">DXF and the classes</a>: what each class", ...
          " is written as, what each entity is read as, and how frames,", ...
          " layers and versions are kept.</li>\n</ul>\n", ...
          "<h2>New to Octave?</h2>\n<ul>\n", ...
          sprintf("<li><a href=\"%s.html\">%s</a>: %s</li>\n", P.base, ...
                  esc (P.title), inline (esc (P.lead), {})), ...
          "</ul>\n<h2>Tutorials</h2>\n<ol>\n"];
  for k = 1:numel (T)
    html = [html, sprintf("<li><a href=\"%s.html\">%s</a>", T(k).base, ...
                          esc (T(k).title))];
    if (! isempty (T(k).lead))
      html = [html, ": ", inline(esc (T(k).lead), {})];
    endif
    html = [html, "</li>\n"];
  endfor
  html = [html, "</ol>\n"];

endfunction

## The sidebar, with the page FILE marked
function html = nav (pages, file)

  html = '';
  for g = {'Guide', 'Octave', 'Tutorials'}
    p = pages(strcmp ({pages.group}, g{1}));
    if (isempty (p))
      continue;
    endif
    html = [html, sprintf("            <h6>%s</h6>\n            <ul>\n", g{1})];
    for k = 1:numel (p)
      a = '';
      if (strcmp (p(k).file, file))
        a = ' class="active"';
      endif
      html = [html, sprintf("              <li><a href=\"%s\"%s>%s</a></li>\n", ...
                            p(k).file, a, esc (p(k).title))];
    endfor
    html = [html, "            </ul>\n"];
  endfor

endfunction

## TEXT with the sidebar between its markers replaced by NAV
function text = set_nav (text, nav)

  a = strfind (text, '<!-- guide-nav -->');
  b = strfind (text, '<!-- /guide-nav -->');
  if (numel (a) != 1 || numel (b) != 1 || b < a)
    error ("build_guide: a page has no single pair of guide-nav markers.");
  endif
  text = [text(1:a+numel ('<!-- guide-nav -->')), nav, text(b:end)];

endfunction

function write_page (file, tmpl, title, body, nav)

  html = strrep (tmpl, '{{TITLE}}', esc (title));
  html = strrep (html, '{{BODY}}', body);
  write_text (file, set_nav (html, nav));

endfunction

function write_text (file, text)

  fid = fopen (file, 'w');
  if (fid < 0)
    error ("build_guide: cannot write %s.", file);
  endif
  fputs (fid, text);
  fclose (fid);

endfunction

## The functions and classes INDEX lists, which have reference pages
function names = index_names (file)

  L = strsplit (fileread (file), "\n");
  names = strtrim (L(strncmp (L, ' ', 1)));

endfunction

## Prose lines in the subset of Markdown, as HTML
function html = markdown (lines, names)

  html = '';
  para = {};
  list = {};
  ltag = '';
  for k = 1:numel (lines)
    s = lines{k};
    h = regexp (s, '^(#{1,3}) (.*)$', 'tokens', 'once');
    li = regexp (s, '^(-|\d+\.) (.*)$', 'tokens', 'once');
    if (isempty (strtrim (s)))
      [html, para] = flush_para (html, para, names);
      [html, list] = flush_list (html, list, ltag, names);
    elseif (! isempty (h))
      [html, para] = flush_para (html, para, names);
      [html, list] = flush_list (html, list, ltag, names);
      n = numel (h{1});
      html = [html, sprintf("<h%d>%s</h%d>\n", n, ...
                            inline (esc (h{2}), names), n)];
    elseif (! isempty (li))
      [html, para] = flush_para (html, para, names);
      tag = 'ul';
      if (! strcmp (li{1}, '-'))
        tag = 'ol';
      endif
      if (! isempty (list) && ! strcmp (tag, ltag))
        [html, list] = flush_list (html, list, ltag, names);
      endif
      ltag = tag;
      list{end+1} = li{2};
    elseif (! isempty (list) && ! isempty (regexp (s, '^\s', 'once')))
      list{end} = [list{end}, ' ', strtrim(s)];
    else
      [html, list] = flush_list (html, list, ltag, names);
      para{end+1} = strtrim (s);
    endif
  endfor
  [html, para] = flush_para (html, para, names);
  [html, list] = flush_list (html, list, ltag, names);

endfunction

function [html, para] = flush_para (html, para, names)

  if (! isempty (para))
    html = [html, sprintf("<p>%s</p>\n", ...
                          inline (esc (strjoin (para, ' ')), names))];
    para = {};
  endif

endfunction

function [html, list] = flush_list (html, list, tag, names)

  if (! isempty (list))
    html = [html, sprintf("<%s>\n", tag)];
    for k = 1:numel (list)
      html = [html, sprintf("<li>%s</li>\n", inline (esc (list{k}), names))];
    endfor
    html = [html, sprintf("</%s>\n", tag)];
    list = {};
  endif

endfunction

## Inline Markdown on escaped text: code spans first, so that nothing inside
## one is read as markup
function s = inline (s, names)

  p = strsplit (s, '`');
  for k = 1:numel (p)
    if (mod (k, 2) == 0)
      if (any (strcmp (p{k}, names)))
        p{k} = sprintf ("<a href=\"../%s.html\"><code>%s</code></a>", ...
                        p{k}, p{k});
      else
        p{k} = sprintf ("<code>%s</code>", p{k});
      endif
    else
      t = regexprep (p{k}, '\[([^\]]+)\]\(([^)\s]+)\)', '<a href="$2">$1</a>');
      t = regexprep (t, '\*\*(.+?)\*\*', '<b>$1</b>');
      p{k} = regexprep (t, '\*([^*\s][^*]*?)\*', '<i>$1</i>');
    endif
  endfor
  s = [p{:}];

endfunction

function s = esc (s)

  s = strrep (s, '&', '&amp;');
  s = strrep (s, '<', '&lt;');
  s = strrep (s, '>', '&gt;');

endfunction
