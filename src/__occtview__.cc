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
//   mesh NV NF     followed by NV vertices, three doubles each, and NF
//                  triangles, three 0-based uint32 indices each; replaces the
//                  shape shown with the triangle mesh, flat shaded
//   pick KIND      KIND is edge, face or any: clicks toggle a selection until
//                  Enter, which replies with "edge K" and "face K" lines and
//                  then "done", or Escape, which replies "cancel"
//   pickone KIND   KIND is face or point: the next click replies at once with
//                  "face K X Y Z", the face and the point on it, or with
//                  "point X Y Z SNAP", the point snapped to a vertex, the
//                  centre of a circular edge, the midpoint of another edge or
//                  a point on a face, SNAP naming which, and marks it; Enter
//                  replies "skip" and Escape "cancel".  On a mesh a face is
//                  "facet NX NY NZ X Y Z", the normal of the triangle clicked
//                  and the point on it, and a point snaps to a corner of the
//                  triangle or the midpoint of one of its sides, near enough
//                  on the screen, or else lies on it
//   enter          during a pickone, as the Enter key: replies "skip"
//   prompt TEXT    shows TEXT at the foot of the view, a backslash and n
//                  starting a new line; no TEXT clears it
//   clearmarks     removes the marks of picked points
//   cancel         ends a pick as Escape does
//   title TEXT     sets the window's title
//   gettitle       replies "title TEXT", the title the window carries
//   project X Y Z  replies "point PX PY", the pixel the model point lands on
//   pickat KIND PX PY
//                  replies "edge K", "face K" or "none", what lies at a pixel
//   click PX PY    a click at a pixel: during a pick replies "selected N",
//                  how many items the pick now holds, and during a pickone
//                  replies as the pick does
//   dump FILE      writes the view to an image file (PPM); replies "dumped"
//   close          closes the window
//
// K is a 1-based index into the map of all edges or faces of the shape, the
// numbering solid.Shape.edges and solid.Shape.faces use.  Seam and degenerate
// edges are never reported.  On start the viewer replies "ready", or
// "error TEXT" and exits; when the window is closed it replies "closed".  It
// exits when stdin closes, so it never outlives Octave.  With --hidden the
// window is never shown, which is how it is tested.

#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <set>
#include <sstream>
#include <string>
#include <vector>

#include <sys/select.h>
#include <unistd.h>

#include <AIS_InteractiveContext.hxx>
#include <AIS_Point.hxx>
#include <AIS_Shape.hxx>
#include <AIS_TextLabel.hxx>
#include <AIS_ViewController.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepBndLib.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRep_Builder.hxx>
#include <Bnd_Box.hxx>
#include <BRep_Tool.hxx>
#include <Geom_CartesianPoint.hxx>
#include <BinTools.hxx>
#include <Graphic3d_TransformPers.hxx>
#include <Message.hxx>
#include <Message_Messenger.hxx>
#include <OpenGl_GraphicDriver.hxx>
#include <Prs3d_Drawer.hxx>
#include <Prs3d_LineAspect.hxx>
#include <Quantity_Color.hxx>
#include <Poly_Triangulation.hxx>
#include <Select3D_SensitiveTriangulation.hxx>
#include <SelectMgr_Filter.hxx>
#include <SelectMgr_Selection.hxx>
#include <StdSelect_BRepSelectionTool.hxx>
#include <TopExp_Explorer.hxx>
#include <SelectMgr_ViewerSelector.hxx>
#include <Standard_Failure.hxx>
#include <StdSelect_BRepOwner.hxx>
#include <TopExp.hxx>
#include <TopTools_IndexedDataMapOfShapeListOfShape.hxx>
#include <TopTools_IndexedMapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Vertex.hxx>
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

// Keeps seam and degenerate edges, and the vertices that only close such
// edges or circles, from ever being detected, so that a click there finds
// what lies beneath: the face, or the circle and its centre
class seamfilter : public SelectMgr_Filter
{
public:

  seamfilter (const TopTools_IndexedMapOfShape& edges, const set<int>& skip,
              const TopTools_IndexedMapOfShape& vertices,
              const set<int>& vskip)
    : m_edges (edges), m_skip (skip), m_vertices (vertices), m_vskip (vskip)
  { }

  Standard_Boolean IsOk (const Handle (SelectMgr_EntityOwner)& owner)
    const override
  {
    Handle (StdSelect_BRepOwner) o = Handle (StdSelect_BRepOwner)::DownCast
                                       (owner);
    if (o.IsNull () || ! o->HasShape ())
    {
      return Standard_True;
    }
    const TopoDS_Shape& s = o->Shape ();
    if (s.ShapeType () == TopAbs_EDGE)
    {
      return m_skip.count (m_edges.FindIndex (s)) == 0;
    }
    if (s.ShapeType () == TopAbs_VERTEX)
    {
      return m_vskip.count (m_vertices.FindIndex (s)) == 0;
    }
    return Standard_True;
  }

private:

  const TopTools_IndexedMapOfShape& m_edges;
  const set<int>& m_skip;
  const TopTools_IndexedMapOfShape& m_vertices;
  const set<int>& m_vskip;
};

// A shape whose faces are picked by their own triangles.  Open CASCADE 7.8
// picks a cylindrical face with an analytic cylinder that it places where the
// untrimmed surface begins, not where the face lies: a bore cut by a cylinder
// longer than the part is then picked in the air beside the part and missed
// where it is.  Edges and vertices are picked as Open CASCADE does.
class pickshape : public AIS_Shape
{
public:

  pickshape (const TopoDS_Shape& s) : AIS_Shape (s) { }

  void ComputeSelection (const Handle (SelectMgr_Selection)& sel,
                         const Standard_Integer mode) override
  {
    if (mode != AIS_Shape::SelectionMode (TopAbs_FACE))
    {
      AIS_Shape::ComputeSelection (sel, mode);
      return;
    }
    for (TopExp_Explorer x (myshape, TopAbs_FACE); x.More (); x.Next ())
    {
      const TopoDS_Face& f = TopoDS::Face (x.Current ());
      TopLoc_Location loc;
      const Handle (Poly_Triangulation) tri = BRep_Tool::Triangulation (f,
                                                                        loc);
      if (tri.IsNull ())
      {
        continue;
      }
      Handle (StdSelect_BRepOwner) owner
        = new StdSelect_BRepOwner (f, this,
                                   StdSelect_BRepSelectionTool::
                                   GetStandardPriority (f, TopAbs_FACE));
      sel->Add (new Select3D_SensitiveTriangulation (owner, tri, loc,
                                                     Standard_True));
    }
  }
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
    m_window = new Xw_Window (m_display, "drafting", 0, 0, 900, 700);
    m_view = m_viewer->CreateView ();
    m_view->SetWindow (m_window);
    m_view->SetBgGradientColors (Quantity_Color (0.85, 0.87, 0.9,
                                                 Quantity_TOC_sRGB),
                                 Quantity_Color (0.55, 0.6, 0.66,
                                                 Quantity_TOC_sRGB),
                                 Aspect_GradientFillMethod_Vertical);
    m_view->SetProj (V3d_XposYnegZpos);

    // The world axes in a corner, turning with the view, clear of the
    // prompts at the lower left
    m_view->TriedronDisplay (Aspect_TOTP_RIGHT_LOWER, Quantity_NOC_BLACK, 0.12,
                             V3d_ZBUFFER);
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

    // What a pick holds stays drawn in a strong colour, edges thick and faces
    // filled, so that a click visibly took; what lies under the pointer keeps
    // Open CASCADE's cyan
    const Quantity_Color picked (1.0, 0.35, 0.0, Quantity_TOC_sRGB);
    for (const Prs3d_TypeOfHighlight t : {Prs3d_TypeOfHighlight_Selected,
                                          Prs3d_TypeOfHighlight_LocalSelected})
    {
      const Handle (Prs3d_Drawer)& hs = m_context->HighlightStyle (t);
      hs->SetColor (picked);
      hs->SetDisplayMode (AIS_Shaded);
      // Drawn after the part against its depth, so a face's fill is not lost
      // to the face it lies on, while what stands in front still hides it
      hs->SetZLayer (Graphic3d_ZLayerId_Top);
      hs->SetWireAspect (new Prs3d_LineAspect (picked, Aspect_TOL_SOLID, 4));
      hs->SetFreeBoundaryAspect (new Prs3d_LineAspect (picked,
                                                       Aspect_TOL_SOLID, 4));
      hs->SetUnFreeBoundaryAspect (new Prs3d_LineAspect (picked,
                                                         Aspect_TOL_SOLID, 4));
    }
    m_context->AddFilter (new seamfilter (m_edges, m_skip, m_vertices,
                                          m_vskip));

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
      TopoDS_Shape s;
      if (! data.empty ())
      {
        istringstream is (data);
        BinTools::Read (s, is);
      }
      setshape (s, false);
    }
    else if (cmd == "mesh")
    {
      size_t nv, nf;
      in >> nv >> nf;
      setshape (meshface (data, nv, nf), true);
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
      if (m_one != 0)
      {
        endone ("cancel");
      }
    }
    else if (cmd == "pickone")
    {
      string kind;
      in >> kind;
      if (m_pick != 0)
      {
        finish (false);
      }
      m_one = (kind == "face") ? 2 : 7;
      activate (m_one);
    }
    else if (cmd == "enter")
    {
      if (m_one != 0)
      {
        endone ("skip");
      }
    }
    else if (cmd == "prompt")
    {
      // A backslash and n in the text starts a new line
      string text;
      getline (in, text);
      text = text.empty () ? text : text.substr (1);
      for (size_t k = text.find ("\\n"); k != string::npos;
           k = text.find ("\\n", k + 1))
      {
        text.replace (k, 2, "\n");
      }
      label (text);
    }
    else if (cmd == "clearmarks")
    {
      for (const Handle (AIS_Point)& m : m_marks)
      {
        m_context->Remove (m, Standard_False);
      }
      m_marks.clear ();
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
    else if (cmd == "click")
    {
      int px, py;
      in >> px >> py;
      if (m_one != 0)
      {
        onepick (px, py);
      }
      else
      {
        m_context->MoveTo (px, py, m_view, Standard_False);
        m_context->SelectDetected (AIS_SelectionScheme_XOR);
        reply ("selected " + to_string (m_context->NbSelected ()));
      }
    }
    else if (cmd == "dump")
    {
      string file;
      getline (in, file);
      m_view->Redraw ();
      const bool ok = m_view->Dump (file.empty () ? "" : file.c_str () + 1);
      reply (ok ? "dumped" : "error the view could not be written");
    }
    else if (cmd == "title")
    {
      string text;
      getline (in, text);
      m_window->SetTitle (TCollection_AsciiString (text.empty () ? text.c_str ()
                                                   : text.c_str () + 1));
    }
    else if (cmd == "gettitle")
    {
      char *name = nullptr;
      XFetchName ((Display *) m_display->GetDisplayAspect (),
                  static_cast<Window> (m_window->NativeHandle ()), &name);
      reply (string ("title ") + (name != nullptr ? name : ""));
      if (name != nullptr)
      {
        XFree (name);
      }
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
        else if (m_one != 0)
        {
          endone ("skip");
        }
        break;
      case Aspect_VKey_Escape:
        if (m_pick != 0)
        {
          finish (false);
        }
        else if (m_one != 0)
        {
          endone ("cancel");
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

protected:

  // A click during a pickone answers at once instead of selecting
  void handleSelectionPick (const Handle (AIS_InteractiveContext)& ctx,
                            const Handle (V3d_View)& view) override
  {
    if (m_one != 0 && ! myGL.Selection.Points.IsEmpty ())
    {
      const Graphic3d_Vec2i p = myGL.Selection.Points.Last ();
      myGL.Selection.Points.Clear ();
      onepick (p.x (), p.y ());
      return;
    }
    AIS_ViewController::handleSelectionPick (ctx, view);
  }

private:

  // The face of a triangle mesh: the mesh's vertices DATA, NV of them, and
  // its NF triangles.  Each triangle has corners of its own carrying its own
  // normal, so that the mesh is shaded flat, facet by facet, and the K-th
  // triangle keeps the corners 3 K + 1 to 3 K + 3.
  static TopoDS_Face meshface (const string& data, size_t nv, size_t nf)
  {
    const double *v = reinterpret_cast<const double *> (data.data ());
    const uint32_t *f = reinterpret_cast<const uint32_t *>
                          (data.data () + 24 * nv);
    Handle (Poly_Triangulation) tri
      = new Poly_Triangulation (3 * nf, nf, Standard_False, Standard_True);
    for (size_t t = 0; t < nf; t++)
    {
      gp_Pnt c[3];
      for (int k = 0; k < 3; k++)
      {
        const double *p = v + 3 * static_cast<size_t> (f[3 * t + k]);
        c[k] = gp_Pnt (p[0], p[1], p[2]);
        tri->SetNode (3 * t + k + 1, c[k]);
      }
      gp_Vec n = gp_Vec (c[0], c[1]).Crossed (gp_Vec (c[0], c[2]));
      const gp_Dir d = (n.Magnitude () > 0) ? gp_Dir (n) : gp_Dir (0, 0, 1);
      for (int k = 1; k <= 3; k++)
      {
        tri->SetNormal (3 * t + k, d);
      }
      tri->SetTriangle (t + 1, Poly_Triangle (3 * t + 1, 3 * t + 2,
                                              3 * t + 3));
    }
    TopoDS_Face face;
    BRep_Builder ().MakeFace (face, tri);
    return face;
  }

  // The corners of the triangle of a mesh that the last detection found
  bool facet (gp_Pnt c[3]) const
  {
    Handle (Select3D_SensitiveTriangulation) e
      = Handle (Select3D_SensitiveTriangulation)::DownCast
          (m_context->MainSelector ()->PickedEntity (1));
    Poly_Triangle t;
    return ! e.IsNull () && e->LastDetectedTriangle (t, c);
  }

  // A pickone on a mesh: the triangle at the pixel PX, PY, as its normal and
  // the point clicked, or a point snapped to a corner of it, else to the
  // middle of a side, within 12 pixels on the screen
  void meshpick (int px, int py)
  {
    gp_Pnt c[3];
    if (! facet (c))
    {
      return;
    }
    const gp_Pnt hit = m_context->MainSelector ()->PickedPoint (1);
    m_context->ClearDetected (Standard_False);
    if (m_one == 2)
    {
      gp_Vec n = gp_Vec (c[0], c[1]).Crossed (gp_Vec (c[0], c[2]));
      if (n.Magnitude () == 0)
      {
        return;
      }
      n.Normalize ();
      reply ("facet" + num (gp_Pnt (n.XYZ ())) + num (hit));
      endone ("");
      return;
    }
    auto near = [&] (const gp_Pnt& p)
    {
      Standard_Integer qx, qy;
      m_view->Convert (p.X (), p.Y (), p.Z (), qx, qy);
      return std::hypot (qx - px, qy - py);
    };
    gp_Pnt p = hit;
    string snap = "face";
    double best = 12;
    for (int k = 0; k < 3; k++)
    {
      if (near (c[k]) <= best)
      {
        best = near (c[k]);
        p = c[k];
        snap = "vertex";
      }
    }
    if (snap == "face")
    {
      for (int k = 0; k < 3; k++)
      {
        const gp_Pnt m ((c[k].XYZ () + c[(k + 1) % 3].XYZ ()) / 2);
        if (near (m) <= best)
        {
          best = near (m);
          p = m;
          snap = "midpoint";
        }
      }
    }
    mark (p);
    reply ("point" + num (p) + " " + snap);
    endone ("");
  }

  // What lies at a pixel during a pickone: replies and marks it, or does
  // nothing when the click found nothing
  void onepick (int px, int py)
  {
    m_context->MoveTo (px, py, m_view, Standard_False);
    if (! m_context->HasDetected ())
    {
      return;
    }
    if (m_mesh)
    {
      meshpick (px, py);
      return;
    }
    Handle (StdSelect_BRepOwner) o = Handle (StdSelect_BRepOwner)::DownCast
                                       (m_context->DetectedOwner ());
    if (o.IsNull () || ! o->HasShape ())
    {
      return;
    }
    const TopoDS_Shape& s = o->Shape ();
    const gp_Pnt hit = m_context->MainSelector ()->PickedPoint (1);
    string r;
    gp_Pnt p = hit;
    if (m_one == 2)
    {
      const int k = m_faces.FindIndex (s);
      if (s.ShapeType () != TopAbs_FACE || k == 0)
      {
        return;
      }
      r = "face " + to_string (k);
    }
    else
    {
      string snap = "face";
      if (s.ShapeType () == TopAbs_VERTEX)
      {
        p = BRep_Tool::Pnt (TopoDS::Vertex (s));
        snap = "vertex";
      }
      else if (s.ShapeType () == TopAbs_EDGE)
      {
        const BRepAdaptor_Curve c (TopoDS::Edge (s));
        if (c.GetType () == GeomAbs_Circle)
        {
          p = c.Circle ().Location ();
          snap = "centre";
        }
        else
        {
          p = c.Value ((c.FirstParameter () + c.LastParameter ()) / 2);
          snap = "midpoint";
        }
      }
      r = "point";
      mark (p);
      r += num (p) + " " + snap;
      m_context->ClearDetected (Standard_False);
      reply (r);
      endone ("");
      return;
    }
    m_context->ClearDetected (Standard_False);
    reply (r + num (p));
    endone ("");
  }

  static string num (const gp_Pnt& p)
  {
    char b[128];
    snprintf (b, sizeof (b), " %.17g %.17g %.17g", p.X (), p.Y (), p.Z ());
    return b;
  }

  // Leave a pickone, replying R unless it is empty
  void endone (const string& r)
  {
    if (! r.empty ())
    {
      reply (r);
    }
    m_one = 0;
    activate (m_pick);
  }

  void mark (const gp_Pnt& p)
  {
    Handle (AIS_Point) m = new AIS_Point (new Geom_CartesianPoint (p));
    m->SetMarker (Aspect_TOM_BALL);
    m->SetColor (Quantity_Color (1.0, 0.35, 0.0, Quantity_TOC_sRGB));
    m->SetZLayer (Graphic3d_ZLayerId_Topmost);
    m_context->Display (m, 0, -1, Standard_False);
    m_marks.push_back (m);
  }

  static int kindcode (const string& kind)
  {
    return kind == "edge" ? 1 : kind == "face" ? 2 : 3;
  }

  void turn (V3d_TypeOfOrientation o)
  {
    m_view->SetProj (o);
    m_view->FitAll (0.05, Standard_False);
  }

  // Show the shape S, or the face of a triangle mesh when MESH is true
  void setshape (const TopoDS_Shape& s, bool mesh)
  {
    if (m_pick != 0)
    {
      finish (false);
    }
    if (m_one != 0)
    {
      endone ("cancel");
    }
    m_mesh = mesh;

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

    // A vertex is a feature of the part only where an edge that is neither
    // skipped nor closed on itself meets it
    m_vertices.Clear ();
    m_vskip.clear ();
    TopExp::MapShapes (s, TopAbs_VERTEX, m_vertices);
    TopTools_IndexedDataMapOfShapeListOfShape vanc;
    TopExp::MapShapesAndAncestors (s, TopAbs_VERTEX, TopAbs_EDGE, vanc);
    for (int i = 1; i <= m_vertices.Extent (); i++)
    {
      bool feature = false;
      const int k = vanc.FindIndex (m_vertices (i));
      if (k > 0)
      {
        for (const TopoDS_Shape& e : vanc (k))
        {
          const TopoDS_Edge& ed = TopoDS::Edge (e);
          feature = feature
                    || (m_skip.count (m_edges.FindIndex (ed)) == 0
                        && ! TopExp::FirstVertex (ed).IsSame
                               (TopExp::LastVertex (ed)));
        }
      }
      if (! feature)
      {
        m_vskip.insert (i);
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
    // Mesh every face to the same fine tolerance, set by the size of the
    // whole shape, before it is shown.  Left to itself the viewer can mesh a
    // face cut from a long tool so coarsely that a click on it misses it.  A
    // triangle mesh is shown as its own triangles, never meshed again.
    if (! mesh)
    {
      Bnd_Box b;
      BRepBndLib::Add (s, b);
      const double size = sqrt (b.SquareExtent ());
      BRepMesh_IncrementalMesh (s, 1e-3 * size, Standard_False, 0.25,
                                Standard_True);
    }

    m_shape = new pickshape (s);
    if (mesh)
    {
      m_shape->Attributes ()->SetAutoTriangulation (Standard_False);
    }
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

  // Make edges, faces or both selectable, or nothing when not picking; a
  // mesh has its triangles only
  void activate (int kind)
  {
    if (m_shape.IsNull ())
    {
      return;
    }
    if (m_mesh && kind != 0)
    {
      kind = 2;
    }
    const int edge = AIS_Shape::SelectionMode (TopAbs_EDGE);
    const int face = AIS_Shape::SelectionMode (TopAbs_FACE);
    const int vertex = AIS_Shape::SelectionMode (TopAbs_VERTEX);
    m_context->Deactivate (m_shape, edge);
    m_context->Deactivate (m_shape, face);
    m_context->Deactivate (m_shape, vertex);
    if (kind & 1)
    {
      m_context->Activate (m_shape, edge);
    }
    if (kind & 2)
    {
      m_context->Activate (m_shape, face);
    }
    if (kind & 4)
    {
      m_context->Activate (m_shape, vertex);
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
  TopTools_IndexedMapOfShape m_vertices;
  set<int> m_skip;
  set<int> m_vskip;
  vector<Handle (AIS_Point)> m_marks;
  int m_pick = 0;
  int m_one = 0;
  bool m_mesh = false;
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

  // Commands arrive as lines; a shape's or a mesh's bytes follow its line
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
      else if (line.compare (0, 5, "mesh ") == 0)
      {
        char *q;
        const size_t nv = strtoul (line.c_str () + 5, &q, 10);
        need = 24 * nv + 12 * strtoul (q, nullptr, 10);
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
