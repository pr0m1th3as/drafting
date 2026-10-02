/*
Copyright (C) 2026 Andreas Bertsatos <abertsatos@biol.uoa.gr>

This file is part of the drafting package for GNU Octave.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
details.

You should have received a copy of the GNU General Public License along with
this program; if not, see <http://www.gnu.org/licenses/>.
*/

// The viewer behind solid.show and solid.Viewer: an Open CASCADE view in a
// window of its own, run as a separate process so that drawing never blocks
// Octave.  It reads commands from stdin and writes replies to stdout, one line
// each:
//
//   shape N        followed by N bytes of a shape in Open CASCADE's binary
//                  format; replaces the shape shown, keeping the camera, or
//                  clears the view when N is zero
//   pick KIND      KIND is edge, face or any: clicks toggle a selection until
//                  Enter, which replies with "edge K" and "face K" lines and
//                  then "done", or Escape, which replies "cancel"
//   cancel         ends a pick as Escape does
//   message TEXT   shows TEXT at the foot of the view; no TEXT clears it
//   project X Y Z  replies "point PX PY", the pixel the model point lands on
//   pickat KIND PX PY
//                  replies "edge K", "face K" or "none", what lies at a pixel
//   close          closes the window
//
// K is a 1-based index into the map of all edges or faces of the shape, the
// numbering solid.Shape.edges and solid.Shape.faces use.  Seam and degenerate
// edges are never reported.  On start the viewer replies "ready", or
// "error TEXT" and exits; when the window is closed it replies "closed".  It
// exits when stdin closes, so it never outlives Octave.  With --hidden the
// window is never shown, which is how it is tested.

#include <cstdio>
#include <cstdlib>
#include <set>
#include <sstream>
#include <string>

#include <sys/select.h>
#include <unistd.h>

#include <AIS_InteractiveContext.hxx>
#include <AIS_Shape.hxx>
#include <AIS_TextLabel.hxx>
#include <AIS_ViewController.hxx>
#include <BRep_Tool.hxx>
#include <BinTools.hxx>
#include <Graphic3d_TransformPers.hxx>
#include <Message.hxx>
#include <Message_Messenger.hxx>
#include <OpenGl_GraphicDriver.hxx>
#include <Prs3d_Drawer.hxx>
#include <Quantity_Color.hxx>
#include <SelectMgr_Filter.hxx>
#include <Standard_Failure.hxx>
#include <StdSelect_BRepOwner.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedDataMapOfShapeListOfShape.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Shape.hxx>
#include <V3d_View.hxx>
#include <V3d_Viewer.hxx>

// Xlib defines macros, Status among them, that break Open CASCADE headers
// included after it, so it comes last, before the two that need it
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <Aspect_DisplayConnection.hxx>
#include <Xw_Window.hxx>

using namespace std;

static void
reply (const string& line)
{
  fputs (line.c_str (), stdout);
  fputc ('\n', stdout);
  fflush (stdout);
}

// Keeps seam and degenerate edges from ever being detected, so that a click
// on a seam finds the face beneath it
class seamfilter : public SelectMgr_Filter
{
public:

  seamfilter (const TopTools_IndexedMapOfShape& edges, const set<int>& skip)
    : m_edges (edges), m_skip (skip)
  { }

  Standard_Boolean IsOk (const Handle (SelectMgr_EntityOwner)& owner)
    const override
  {
    Handle (StdSelect_BRepOwner) o = Handle (StdSelect_BRepOwner)::DownCast
                                       (owner);
    if (o.IsNull () || ! o->HasShape ()
        || o->Shape ().ShapeType () != TopAbs_EDGE)
    {
      return Standard_True;
    }
    return m_skip.count (m_edges.FindIndex (o->Shape ())) == 0;
  }

private:

  const TopTools_IndexedMapOfShape& m_edges;
  const set<int>& m_skip;
};

class viewer : public AIS_ViewController
{
public:

  viewer (bool hidden)
  {
    m_display = new Aspect_DisplayConnection ();
    m_viewer = new V3d_Viewer (new OpenGl_GraphicDriver (m_display));
    m_viewer->SetDefaultLights ();
    m_viewer->SetLightOn ();
    m_context = new AIS_InteractiveContext (m_viewer);
    m_window = new Xw_Window (m_display, "drafting: solid.show", 0, 0, 900,
                              700);
    m_view = m_viewer->CreateView ();
    m_view->SetWindow (m_window);
    m_view->SetBgGradientColors (Quantity_Color (0.85, 0.87, 0.9,
                                                 Quantity_TOC_sRGB),
                                 Quantity_Color (0.55, 0.6, 0.66,
                                                 Quantity_TOC_sRGB),
                                 Aspect_GradientFillMethod_Vertical);
    m_view->SetProj (V3d_XposYnegZpos);
    if (hidden)
    {
      m_window->SetVirtual (Standard_True);
    }
    else
    {
      Display *d = (Display *) m_display->GetDisplayAspect ();
      Window w = static_cast<Window> (m_window->NativeHandle ());
      XSelectInput (d, w, ExposureMask | KeyPressMask | KeyReleaseMask
                          | ButtonPressMask | ButtonReleaseMask
                          | PointerMotionMask | StructureNotifyMask
                          | FocusChangeMask);
      Atom close = XInternAtom (d, "WM_DELETE_WINDOW", False);
      XSetWMProtocols (d, w, &close, 1);
      m_window->Map ();
    }

    // Draw sharp and tangent edges over the shading, but not the seams where
    // a curved face closes on itself
    const Handle (Prs3d_Drawer)& dr = m_context->DefaultDrawer ();
    dr->SetFaceBoundaryDraw (Standard_True);
    dr->SetFaceBoundaryUpperContinuity (GeomAbs_G1);
    m_context->SetAutomaticHilight (Standard_True);
    m_context->AddFilter (new seamfilter (m_edges, m_skip));

    // A click toggles what it lands on, so a pick can gather several
    ChangeMouseSelectionSchemes ().Bind (Aspect_VKeyMouse_LeftButton,
                                         AIS_SelectionScheme_XOR);
  }

  int fd () const
  {
    return ConnectionNumber ((Display *) m_display->GetDisplayAspect ());
  }

  bool done () const
  {
    return m_quit;
  }

  // Every pending window event, then a redraw if anything needs one
  void events ()
  {
    Display *d = (Display *) m_display->GetDisplayAspect ();
    while (XPending (d) > 0)
    {
      XEvent e;
      XNextEvent (d, &e);
      m_window->ProcessMessage (*this, e);
    }
    FlushViewEvents (m_context, m_view, Standard_True);
  }

  void command (const string& line, const string& data)
  {
    istringstream in (line);
    string cmd;
    in >> cmd;
    if (cmd == "shape")
    {
      setshape (data);
    }
    else if (cmd == "pick")
    {
      string kind;
      in >> kind;
      if (m_pick != 0)
      {
        finish (false);
      }
      m_pick = kindcode (kind);
      activate (m_pick);
      label ("Click to select, Enter to finish, Escape to cancel");
    }
    else if (cmd == "cancel")
    {
      if (m_pick != 0)
      {
        finish (false);
      }
    }
    else if (cmd == "message")
    {
      string text;
      getline (in, text);
      label (text.empty () ? text : text.substr (1));
    }
    else if (cmd == "project")
    {
      double x, y, z;
      in >> x >> y >> z;
      Standard_Integer px, py;
      m_view->Convert (x, y, z, px, py);
      reply ("point " + to_string (px) + " " + to_string (py));
    }
    else if (cmd == "pickat")
    {
      string kind;
      int px, py;
      in >> kind >> px >> py;
      activate (kindcode (kind));
      m_context->MoveTo (px, py, m_view, Standard_False);
      string r = "none";
      if (m_context->HasDetected ())
      {
        r = describe (m_context->DetectedOwner ());
      }
      m_context->ClearDetected (Standard_False);
      activate (m_pick);
      reply (r.empty () ? "none" : r);
    }
    else if (cmd == "close")
    {
      m_quit = true;
    }
    m_view->Invalidate ();
    FlushViewEvents (m_context, m_view, Standard_True);
  }

  void ProcessExpose () override
  {
    m_view->Invalidate ();
    FlushViewEvents (m_context, m_view, Standard_True);
  }

  void ProcessConfigure (bool resized) override
  {
    if (resized)
    {
      m_view->MustBeResized ();
    }
    m_view->Invalidate ();
    FlushViewEvents (m_context, m_view, Standard_True);
  }

  void ProcessClose () override
  {
    m_quit = true;
  }

  void KeyDown (Aspect_VKey key, double time, double pressure) override
  {
    AIS_ViewController::KeyDown (key, time, pressure);
    switch (key)
    {
      case Aspect_VKey_Enter:
        if (m_pick != 0)
        {
          finish (true);
        }
        break;
      case Aspect_VKey_Escape:
        if (m_pick != 0)
        {
          finish (false);
        }
        break;
      case Aspect_VKey_F:
        m_view->FitAll (0.05, Standard_False);
        break;
      case Aspect_VKey_0:
        turn (V3d_XposYnegZpos);
        break;
      case Aspect_VKey_1:
        turn (V3d_Yneg);
        break;
      case Aspect_VKey_2:
        turn (V3d_Zpos);
        break;
      case Aspect_VKey_3:
        turn (V3d_Xpos);
        break;
      default:
        break;
    }
    m_view->Invalidate ();
  }

private:

  static int kindcode (const string& kind)
  {
    return kind == "edge" ? 1 : kind == "face" ? 2 : 3;
  }

  void turn (V3d_TypeOfOrientation o)
  {
    m_view->SetProj (o);
    m_view->FitAll (0.05, Standard_False);
  }

  void setshape (const string& data)
  {
    if (m_pick != 0)
    {
      finish (false);
    }
    TopoDS_Shape s;
    if (! data.empty ())
    {
      istringstream is (data);
      BinTools::Read (s, is);
    }

    m_edges.Clear ();
    m_faces.Clear ();
    m_skip.clear ();
    TopExp::MapShapes (s, TopAbs_EDGE, m_edges);
    TopExp::MapShapes (s, TopAbs_FACE, m_faces);
    TopTools_IndexedDataMapOfShapeListOfShape anc;
    TopExp::MapShapesAndAncestors (s, TopAbs_EDGE, TopAbs_FACE, anc);
    for (int i = 1; i <= m_edges.Extent (); i++)
    {
      const TopoDS_Edge& e = TopoDS::Edge (m_edges (i));
      bool skip = BRep_Tool::Degenerated (e);
      const int k = anc.FindIndex (e);
      if (k > 0)
      {
        for (const TopoDS_Shape& f : anc (k))
        {
          skip = skip || BRep_Tool::IsClosed (e, TopoDS::Face (f));
        }
      }
      if (skip)
      {
        m_skip.insert (i);
      }
    }

    const bool first = m_shape.IsNull ();
    if (! first)
    {
      m_context->Remove (m_shape, Standard_False);
      m_shape.Nullify ();
    }
    if (s.IsNull ())
    {
      return;
    }
    m_shape = new AIS_Shape (s);
    m_shape->SetColor (Quantity_Color (0.72, 0.74, 0.78, Quantity_TOC_sRGB));
    m_shape->SetMaterial (Graphic3d_NameOfMaterial_Plastified);
    // Displayed selectable, which no later activation can make it if it is
    // not, then left with nothing active until a pick asks for something
    m_context->Display (m_shape, AIS_Shaded,
                        AIS_Shape::SelectionMode (TopAbs_FACE),
                        Standard_False);
    activate (m_pick);
    if (first)
    {
      m_view->FitAll (0.05, Standard_False);
    }
  }

  // Make edges, faces or both selectable, or nothing when not picking
  void activate (int kind)
  {
    if (m_shape.IsNull ())
    {
      return;
    }
    const int edge = AIS_Shape::SelectionMode (TopAbs_EDGE);
    const int face = AIS_Shape::SelectionMode (TopAbs_FACE);
    m_context->Deactivate (m_shape, edge);
    m_context->Deactivate (m_shape, face);
    if (kind & 1)
    {
      m_context->Activate (m_shape, edge);
    }
    if (kind & 2)
    {
      m_context->Activate (m_shape, face);
    }
  }

  // "edge K" or "face K" for a picked owner, empty for a seam or anything
  // that is not an edge or a face of the shape
  string describe (const Handle (SelectMgr_EntityOwner)& owner) const
  {
    Handle (StdSelect_BRepOwner) o = Handle (StdSelect_BRepOwner)::DownCast
                                       (owner);
    if (o.IsNull () || ! o->HasShape ())
    {
      return "";
    }
    const TopoDS_Shape& s = o->Shape ();
    if (s.ShapeType () == TopAbs_EDGE)
    {
      const int k = m_edges.FindIndex (s);
      if (k > 0 && m_skip.count (k) == 0)
      {
        return "edge " + to_string (k);
      }
    }
    else if (s.ShapeType () == TopAbs_FACE)
    {
      const int k = m_faces.FindIndex (s);
      if (k > 0)
      {
        return "face " + to_string (k);
      }
    }
    return "";
  }

  void finish (bool accept)
  {
    if (accept)
    {
      for (m_context->InitSelected (); m_context->MoreSelected ();
           m_context->NextSelected ())
      {
        const string r = describe (m_context->SelectedOwner ());
        if (! r.empty ())
        {
          reply (r);
        }
      }
    }
    reply (accept ? "done" : "cancel");
    m_context->ClearSelected (Standard_False);
    m_pick = 0;
    activate (0);
    label ("");
  }

  void label (const string& text)
  {
    if (! m_label.IsNull ())
    {
      m_context->Remove (m_label, Standard_False);
      m_label.Nullify ();
    }
    if (text.empty ())
    {
      return;
    }
    m_label = new AIS_TextLabel ();
    m_label->SetText (TCollection_ExtendedString (text.c_str (), true));
    m_label->SetColor (Quantity_NOC_BLACK);
    m_label->SetHeight (16);
    m_label->SetTransformPersistence
      (new Graphic3d_TransformPers (Graphic3d_TMF_2d, Aspect_TOTP_LEFT_LOWER,
                                    Graphic3d_Vec2i (20, 20)));
    m_label->SetZLayer (Graphic3d_ZLayerId_TopOSD);
    m_context->Display (m_label, 0, -1, Standard_False);
  }

  Handle (Aspect_DisplayConnection) m_display;
  Handle (V3d_Viewer) m_viewer;
  Handle (AIS_InteractiveContext) m_context;
  Handle (Xw_Window) m_window;
  Handle (V3d_View) m_view;
  Handle (AIS_Shape) m_shape;
  Handle (AIS_TextLabel) m_label;
  TopTools_IndexedMapOfShape m_edges;
  TopTools_IndexedMapOfShape m_faces;
  set<int> m_skip;
  int m_pick = 0;
  bool m_quit = false;
};

int
main (int argc, char **argv)
{
  const bool hidden = (argc > 1 && string (argv[1]) == "--hidden");
  Message::DefaultMessenger ()->ChangePrinters ().Clear ();

  viewer *v = nullptr;
  try
  {
    v = new viewer (hidden);
  }
  catch (const Standard_Failure& e)
  {
    reply (string ("error ") + e.GetMessageString ());
    return 1;
  }
  reply ("ready");

  // Commands arrive as lines; a shape's bytes follow its line
  string pending;
  char buf[65536];
  bool open = true;
  while (open && ! v->done ())
  {
    v->events ();

    fd_set fds;
    FD_ZERO (&fds);
    FD_SET (0, &fds);
    FD_SET (v->fd (), &fds);
    timeval tv = {0, 20000};
    if (select (v->fd () + 1, &fds, nullptr, nullptr, &tv) < 0)
    {
      break;
    }
    if (! FD_ISSET (0, &fds))
    {
      continue;
    }
    const ssize_t n = read (0, buf, sizeof (buf));
    if (n <= 0)
    {
      break;
    }
    pending.append (buf, n);
    for (;;)
    {
      const size_t eol = pending.find ('\n');
      if (eol == string::npos)
      {
        break;
      }
      const string line = pending.substr (0, eol);
      size_t need = 0;
      if (line.compare (0, 6, "shape ") == 0)
      {
        need = strtoul (line.c_str () + 6, nullptr, 10);
      }
      if (pending.size () < eol + 1 + need)
      {
        break;
      }
      const string data = pending.substr (eol + 1, need);
      pending.erase (0, eol + 1 + need);
      try
      {
        v->command (line, data);
      }
      catch (const Standard_Failure& e)
      {
        reply (string ("error ") + e.GetMessageString ());
      }
      if (v->done ())
      {
        break;
      }
    }
  }

  reply ("closed");
  delete v;
  return 0;
}
